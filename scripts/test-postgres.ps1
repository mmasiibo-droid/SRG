[CmdletBinding()]
param(
    [string]$Database = 'savanna_edm_demo',
    [string]$HostName = 'localhost',
    [int]$Port = 5432,
    [string]$Username = 'postgres'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$output = Join-Path $root 'output'
$psqlCommand = Get-Command psql -ErrorAction SilentlyContinue
if ($null -eq $psqlCommand) {
    $defaultPsql = 'C:\Program Files\PostgreSQL\17\bin\psql.exe'
    if (-not (Test-Path -LiteralPath $defaultPsql -PathType Leaf)) {
        throw 'psql was not found. Install PostgreSQL client tools or add psql.exe to PATH.'
    }
    $psql = $defaultPsql
} else {
    $psql = $psqlCommand.Source
}

& (Join-Path $PSScriptRoot 'run-demo.ps1')
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "Synthetic cleansing pipeline failed with exit code $LASTEXITCODE"
}

$cleanSalesPath = Join-Path $output 'sales_cleaned.csv'
$cleanSales = @(Import-Csv -LiteralPath $cleanSalesPath)
$batchId = '11111111-1111-4111-8111-111111111111'
$stagingRows = foreach ($row in $cleanSales) {
    [pscustomobject]@{
        batch_id = $batchId
        source_system = $row.source_system
        source_order_id = $row.source_order_id
        source_line_number = $row.line_number
        source_customer_id = $row.source_customer_id
        source_sku = $row.source_sku
        source_store_code = $row.store_code
        order_timestamp_raw = $row.order_date
        quantity_raw = $row.quantity
        unit_price_raw = $row.unit_price
        currency_raw = $row.currency_code
        payment_reference_raw = $row.payment_reference
        channel_raw = $row.channel
        return_reason_raw = $row.return_reason
    }
}

$stagingPath = Join-Path $output 'staging_sales.csv'
$stagingRows | Export-Csv -LiteralPath $stagingPath -NoTypeInformation -Encoding UTF8
$copyFile = Join-Path $output 'load-staging.psql'
$copyText = @'
\copy staging.sales_line (batch_id, source_system, source_order_id, source_line_number, source_customer_id, source_sku, source_store_code, order_timestamp_raw, quantity_raw, unit_price_raw, currency_raw, payment_reference_raw, channel_raw, return_reason_raw) FROM 'staging_sales.csv' WITH (FORMAT csv, HEADER true)
'@
Set-Content -LiteralPath $copyFile -Value $copyText -Encoding ASCII

$connectionArgs = @('-w', '-h', $HostName, '-p', "$Port", '-U', $Username, '-d', $Database, '-v', 'ON_ERROR_STOP=1')
$transcript = New-Object 'System.Collections.Generic.List[string]'
$psqlVersion = & $psql --version
$transcript.Add("PostgreSQL client: $psqlVersion")
$transcript.Add("Database: $Database at $HostName`:$Port")
$transcript.Add('Evidence: synthetic fixture records only')

function Invoke-PsqlCaptured {
    param([string]$Label, [string[]]$Arguments)
    $result = & $psql @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = $result | Out-String
    $transcript.Add("===== $Label (exit $exitCode) =====`n$text")
    if ($exitCode -ne 0) { throw "$Label failed with psql exit code $exitCode`n$text" }
    return $text
}

$seedSql = Join-Path $root 'sql\demo-seed.sql'
$null = Invoke-PsqlCaptured 'Synthetic dimension seed' (@($connectionArgs) + @('-f', $seedSql))

Push-Location $output
try {
    $null = Invoke-PsqlCaptured 'Staging CSV load' (@($connectionArgs) + @('-f', 'load-staging.psql'))
} finally {
    Pop-Location
}

$etlSql = Join-Path $root 'sql\etl-core.sql'
$null = Invoke-PsqlCaptured 'ETL first pass' (@($connectionArgs) + @('-f', $etlSql))

# Re-run the same staged batch to verify the target's source-key upsert is idempotent.
$null = Invoke-PsqlCaptured 'ETL idempotency replay' (@($connectionArgs) + @('-f', $etlSql))

$assertionSql = @'
DO $$
BEGIN
    IF (
        SELECT count(*)
        FROM warehouse.fact_sales_line
        WHERE source_order_id IN ('P001', 'P003', 'P004', 'P005', 'P006', 'P007', 'P008')
    ) <> 7 THEN
        RAISE EXCEPTION 'Expected exactly seven accepted synthetic sales lines';
    END IF;

    IF (
        SELECT count(*)
        FROM warehouse.fact_sales_line
        WHERE source_order_id = 'P002'
    ) <> 0 THEN
        RAISE EXCEPTION 'Ambiguous-date sales line P002 must not load to the fact';
    END IF;

    IF (
        SELECT quantity
        FROM warehouse.fact_sales_line
        WHERE source_order_id = 'P005'
    ) <> -1 THEN
        RAISE EXCEPTION 'Documented return quantity must remain negative';
    END IF;

    IF (
        SELECT count(*)
        FROM staging.sales_line
        WHERE batch_id = '11111111-1111-4111-8111-111111111111'
    ) <> 7 THEN
        RAISE EXCEPTION 'Expected seven staged source rows for the fixed demo batch';
    END IF;
END
$$;

SELECT 'synthetic sales fact rows' AS check_name, count(*) AS result
FROM warehouse.fact_sales_line
WHERE source_order_id IN ('P001', 'P003', 'P004', 'P005', 'P006', 'P007', 'P008')
UNION ALL
SELECT 'ambiguous-date P002 fact rows', count(*)
FROM warehouse.fact_sales_line
WHERE source_order_id = 'P002'
UNION ALL
SELECT 'negative return rows', count(*)
FROM warehouse.fact_sales_line
WHERE source_order_id = 'P005' AND quantity = -1;
'@

$assertionFile = Join-Path $output 'assert-postgres-demo.sql'
Set-Content -LiteralPath $assertionFile -Value $assertionSql -Encoding ASCII
$verification = & $psql @connectionArgs -f $assertionFile 2>&1
$verifyExit = $LASTEXITCODE
$verificationText = $verification | Out-String
$transcript.Add("===== ETL assertions (exit $verifyExit) =====`n$verificationText")
Set-Content -LiteralPath (Join-Path $output 'postgres-demo-verification.txt') -Value $verificationText -Encoding UTF8
if ($verifyExit -ne 0) {
    throw "PostgreSQL demo verification failed:`n$verificationText"
}

$maskedAccess = & $psql @connectionArgs -c 'SET ROLE srg_analytics; SELECT count(*) AS masked_view_rows FROM warehouse.customer_masked_v; RESET ROLE;' 2>&1
$maskedExit = $LASTEXITCODE
$maskedText = $maskedAccess | Out-String
$transcript.Add("===== Analytics masked-view access (exit $maskedExit) =====`n$maskedText")
if ($maskedExit -ne 0 -or $maskedText -notmatch 'masked_view_rows') {
    throw "Analytics role could not query its masked view:`n$maskedText"
}

$denialSqlPath = Join-Path $output 'assert-restricted-access.sql'
$stdoutPath = Join-Path $output 'restricted-access-stdout.txt'
$stderrPath = Join-Path $output 'restricted-access-stderr.txt'
Set-Content -LiteralPath $denialSqlPath -Value 'SET ROLE srg_analytics; SELECT * FROM core.customer_contact_restricted LIMIT 1;' -Encoding ASCII
$denialArguments = (@($connectionArgs) + @('-f', $denialSqlPath)) -join ' '
$restrictedProcess = Start-Process -FilePath $psql -ArgumentList $denialArguments -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
$restrictedExit = $restrictedProcess.ExitCode
$restrictedText = (Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue) + (Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue)
$transcript.Add("===== Analytics restricted-table denial (exit $restrictedExit) =====`n$restrictedText")
if ($restrictedExit -eq 0 -or $restrictedText -notmatch 'permission denied') {
    throw "Expected restricted customer access to be denied:`n$restrictedText"
}

$accessPath = Join-Path $output 'postgres-access-test.txt'
Set-Content -LiteralPath $accessPath -Value @(
    'Synthetic demo RBAC verification'
    'srg_analytics SELECT on warehouse.customer_masked_v: allowed'
    'srg_analytics SELECT on core.customer_contact_restricted: denied as expected'
    ''
    $maskedText
    $restrictedText
) -Encoding UTF8
$transcriptPath = Join-Path $output 'postgres-demo-etl-log.txt'
Set-Content -LiteralPath $transcriptPath -Value ([string]::Join("`r`n", $transcript)) -Encoding UTF8

Write-Output $verificationText
Write-Output 'PASS: PostgreSQL staging, ETL replay/idempotency, returns, invalid-date handling, and RBAC checks.'
