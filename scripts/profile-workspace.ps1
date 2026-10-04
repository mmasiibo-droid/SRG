[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$inputDir = Join-Path $root 'data\demo'
$outputDir = Join-Path $root 'output'
$dashboardDir = Join-Path $root 'dashboard'
$manifestRows = New-Object 'System.Collections.Generic.List[object]'
$profileRows = New-Object 'System.Collections.Generic.List[object]'

function Import-CsvRows {
    param([string]$Name)
    $path = Join-Path $inputDir $Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return @()
    }
    return @(Import-Csv -LiteralPath $path)
}

function Add-Profile {
    param(
        [string]$Dataset,
        [string]$Phase,
        [string]$Dimension,
        [string]$Metric,
        [int]$Numerator,
        [Nullable[int]]$Denominator,
        [string]$Unit,
        [string]$Rule,
        [string]$Interpretation
    )
    $percent = $null
    if ($null -ne $Denominator -and $Denominator.Value -gt 0) {
        $percent = [Math]::Round(($Numerator * 100.0) / $Denominator.Value, 2)
    }
    $profileRows.Add([pscustomobject]@{
        dataset = $Dataset
        phase = $Phase
        dimension = $Dimension
        metric = $Metric
        numerator = $Numerator
        denominator = $Denominator
        percent = $percent
        unit = $Unit
        rule = $Rule
        interpretation = $Interpretation
    })
}

function Get-ColumnValue {
    param($Row, [string]$Name)
    $prop = $Row.PSObject.Properties[$Name]
    if ($null -eq $prop -or $null -eq $prop.Value) { return '' }
    return ([string]$prop.Value).Trim()
}

function Get-FileHashSafe {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

$sourceSpecs = @(
    @{ Name='SRG_Customers.csv'; Kind='CSV'; Description='8 demo customer rows' },
    @{ Name='SRG_Products.csv'; Kind='CSV'; Description='6 demo product rows' },
    @{ Name='SRG_Sales.csv'; Kind='CSV'; Description='8 demo sales rows' },
    @{ Name='SRG_Suppliers.csv'; Kind='CSV'; Description='2 demo supplier rows' },
    @{ Name='SRG_Loyalty.csv'; Kind='CSV'; Description='3 demo loyalty rows' },
    @{ Name='SRG_HR_SAMPLE.csv'; Kind='CSV'; Description='1 synthetic HR schema example; not the assignment XLSX' },
    @{ Name='footfall_stream_sample.json'; Kind='JSON'; Description='3 demo sensor events' },
    @{ Name='etl_error_log.txt'; Kind='TEXT'; Description='Assignment log not present' },
    @{ Name='SRG_HR.xlsx'; Kind='XLSX'; Description='Assignment HR workbook not present' }
)
foreach ($spec in $sourceSpecs) {
    $path = Join-Path $inputDir $spec.Name
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $item = Get-Item -LiteralPath $path
        $recordCount = $null
        if ($spec.Kind -eq 'CSV') { $recordCount = @(Import-Csv -LiteralPath $path).Count }
        elseif ($spec.Kind -eq 'JSON') { $recordCount = @((Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)).Count }
        $manifestRows.Add([pscustomobject]@{
            file = $spec.Name
            status = 'Present'
            format = $spec.Kind
            data_rows_or_events = $recordCount
            bytes = $item.Length
            sha256 = Get-FileHashSafe $path
            evidence_note = $spec.Description
        })
    } else {
        $manifestRows.Add([pscustomobject]@{
            file = $spec.Name
            status = 'Not present'
            format = $spec.Kind
            data_rows_or_events = $null
            bytes = $null
            sha256 = ''
            evidence_note = $spec.Description
        })
    }
}
$manifestRows | Export-Csv -LiteralPath (Join-Path $outputDir 'workspace_dataset_inventory.csv') -NoTypeInformation -Encoding UTF8

$customers = @(Import-CsvRows 'SRG_Customers.csv')
$products = @(Import-CsvRows 'SRG_Products.csv')
$sales = @(Import-CsvRows 'SRG_Sales.csv')
$suppliers = @(Import-CsvRows 'SRG_Suppliers.csv')
$loyalty = @(Import-CsvRows 'SRG_Loyalty.csv')
$cleanCustomers = @(Import-Csv -LiteralPath (Join-Path $outputDir 'customers_cleaned.csv'))
$cleanProducts = @(Import-Csv -LiteralPath (Join-Path $outputDir 'products_cleaned.csv'))
$cleanSales = @(Import-Csv -LiteralPath (Join-Path $outputDir 'sales_cleaned.csv'))
$saleRejects = @(Import-Csv -LiteralPath (Join-Path $outputDir 'sales_rejects.csv'))

$customerIds = @{}
foreach ($row in $customers) { $customerIds[(Get-ColumnValue $row 'customer_id')] = $true }
$cleanProductBySku = @{}
foreach ($row in $cleanProducts) { $cleanProductBySku[(Get-ColumnValue $row 'canonical_sku')] = $row }

# Customer and product measurements are emitted by the tested cleansing pipeline.
$baseMetrics = @(Import-Csv -LiteralPath (Join-Path $outputDir 'quality_metrics.csv'))
foreach ($row in $baseMetrics) {
    $profileRows.Add([pscustomobject]@{
        dataset = $row.source
        phase = $row.phase
        dimension = $row.dimension
        metric = $row.metric
        numerator = $row.numerator
        denominator = $row.denominator
        percent = $row.percent
        unit = $row.unit
        rule = 'See output/quality_metrics.csv limitation and scripts/profile-and-clean.ps1'
        interpretation = $row.limitation
    })
}

# Sales: count source completeness, format, validation, returns and reconciliation gaps.
$salesFields = @('order_id','line_no','customer_id','sku','store_id','order_date','quantity','unit_price','currency','channel')
$salesComplete = 0
foreach ($row in $sales) {
    $complete = $true
    foreach ($field in $salesFields) { if (-not (Get-ColumnValue $row $field)) { $complete = $false } }
    if ($complete) { $salesComplete++ }
}
$acceptedIds = @{}
foreach ($row in $cleanSales) { $acceptedIds[(Get-ColumnValue $row 'source_order_id')] = $true }
$dateFormats = @{}
$lineKeys = @{}
$duplicateLines = 0
$currencyValid = 0
$missingPaymentRef = 0
$negativeQty = 0
$negativeWithReason = 0
foreach ($row in $sales) {
    $dateValue = Get-ColumnValue $row 'order_date'
    if ($dateValue -match '^\d{4}-\d{2}-\d{2}$') { $format = 'ISO yyyy-MM-dd' }
    elseif ($dateValue -match '^\d{4}/\d{1,2}/\d{1,2}$') { $format = 'yyyy/M/d' }
    elseif ($dateValue -match '^\d{1,2}/\d{1,2}/\d{4}$') { $format = 'ambiguous slash date' }
    else { $format = 'other or invalid' }
    $dateFormats[$format] = $true
    $lineKey = (Get-ColumnValue $row 'order_id') + '|' + (Get-ColumnValue $row 'line_no')
    if ($lineKeys.ContainsKey($lineKey)) { $duplicateLines++ } else { $lineKeys[$lineKey] = $true }
    if ((Get-ColumnValue $row 'currency').ToUpperInvariant() -match '^[A-Z]{3}$') { $currencyValid++ }
    if (-not (Get-ColumnValue $row 'payment_ref')) { $missingPaymentRef++ }
    $qty = [decimal]0
    if ([decimal]::TryParse((Get-ColumnValue $row 'quantity'), [Globalization.NumberStyles]::Number, [Globalization.CultureInfo]::InvariantCulture, [ref]$qty) -and $qty -lt 0) {
        $negativeQty++
        if (Get-ColumnValue $row 'return_reason') { $negativeWithReason++ }
    }
}
Add-Profile 'sales' 'before' 'completeness' 'Rows complete on required sales fields' $salesComplete $sales.Count 'percent' 'All ten listed fields must be non-empty; payment reference and return reason are conditional/optional.' 'A syntactically complete date can remain ambiguous.'
Add-Profile 'sales' 'before' 'validity' 'Rows accepted by cleansing validation' $cleanSales.Count $sales.Count 'percent' 'ISO or unambiguous date, numeric quantity/price, ISO-like three-letter currency, valid key, and reason for negative quantity.' 'The ambiguous P002 date is rejected, not guessed.'
Add-Profile 'sales' 'before' 'validity' 'Currency values matching three-letter code rule' $currencyValid $sales.Count 'percent' 'Regex ^[A-Z]{3}$ after case normalization.' 'Does not prove ISO membership or settlement currency.'
Add-Profile 'sales' 'before' 'uniqueness' 'Duplicate (order_id,line_no) keys' $duplicateLines $sales.Count 'rows' 'Source order ID and line number form composite key.' 'No repeated composite keys in fixture.'
Add-Profile 'sales' 'before' 'consistency' 'Distinct order-date format categories' $dateFormats.Count $null 'categories' 'ISO date, yyyy/M/d, ambiguous slash date, other.' 'One slash-formatted date has both components <= 12 and is left unresolved.'
Add-Profile 'sales' 'before' 'completeness' 'Missing payment references' $missingPaymentRef $sales.Count 'rows' 'payment_ref null or blank.' '1 of 8; keep as a finance exception rather than fabricate reference.'
Add-Profile 'sales' 'before' 'validity' 'Negative quantities with return reason' $negativeWithReason $negativeQty 'percent' 'Negative quantity accepted only with non-empty return reason.' 'Fixture contains one explained return.'
Add-Profile 'sales' 'after' 'timeliness' 'Arrival-time SLA compliance' 0 $null 'not measured' 'No source arrival/ingestion timestamp or SLA in file.' 'Cannot measure freshness.'
Add-Profile 'sales' 'after' 'accuracy' 'Reconciled to authoritative payment/inventory totals' 0 $null 'not measured' 'Requires system-of-record control totals.' 'No source extracts or control totals provided.'

# Suppliers: exact crosswalk and canonical unit mapping are visible in the input fixture.
$supplierComplete = 0
$supplierSkuMapped = 0
$supplierUnitMapped = 0
$supplierIds = @{}
foreach ($row in $suppliers) {
    $complete = $true
    foreach ($field in @('supplier_id','supplier_name','supplier_sku','canonical_sku','unit','pack_size')) { if (-not (Get-ColumnValue $row $field)) { $complete = $false } }
    if ($complete) { $supplierComplete++ }
    if ($cleanProductBySku.ContainsKey((Get-ColumnValue $row 'canonical_sku').ToUpperInvariant())) { $supplierSkuMapped++ }
    if ((Get-ColumnValue $row 'unit').ToLowerInvariant() -in @('kg','kgs','kilogram','kilograms','l','lt','litre','liter','litres','liters','each','ea','piece','pieces')) { $supplierUnitMapped++ }
    $supplierId = Get-ColumnValue $row 'supplier_id'
    if ($supplierIds.ContainsKey($supplierId)) { $supplierIds[$supplierId]++ } else { $supplierIds[$supplierId] = 1 }
}
$supplierDuplicateIds = 0
foreach ($count in $supplierIds.Values) { if ($count -gt 1) { $supplierDuplicateIds += ($count - 1) } }
Add-Profile 'suppliers' 'before' 'completeness' 'Rows complete on six supplier fields' $supplierComplete $suppliers.Count 'percent' 'All six source columns required for this fixture.' '2-row sample only.'
Add-Profile 'suppliers' 'after' 'consistency' 'Canonical SKU references resolving to product fixture' $supplierSkuMapped $suppliers.Count 'percent' 'Case-normalized canonical_sku equals known cleaned product SKU.' 'Both supplier items map; not independently verified against a real catalog.'
Add-Profile 'suppliers' 'after' 'validity' 'Units recognized by unit mapping rule' $supplierUnitMapped $suppliers.Count 'percent' 'Controlled alias list used by product cleansing.' 'Units are mapped, not converted for pack-size semantics.'
Add-Profile 'suppliers' 'before' 'uniqueness' 'Duplicate supplier IDs' $supplierDuplicateIds $suppliers.Count 'rows' 'supplier_id must be unique in file.' 'No duplicates in fixture.'
Add-Profile 'suppliers' 'after' 'accuracy' 'Supplier/SKU mapping confirmed by procurement owner' 0 $null 'not measured' 'Requires purchase order/catalog corroboration.' 'No authoritative supplier master or transaction evidence supplied.'
Add-Profile 'suppliers' 'after' 'timeliness' 'Supplier records within freshness SLA' 0 $null 'not measured' 'No created/modified timestamp or approved SLA.' 'Cannot measure freshness.'

# Loyalty: referential and range checks; no identity merges or balances are inferred.
$loyaltyIds = @{}
$loyaltyComplete = 0
$loyaltyCustomerMapped = 0
$loyaltyBalanceValid = 0
$duplicateLoyalty = 0
foreach ($row in $loyalty) {
    $complete = $true
    foreach ($field in @('loyalty_account_id','customer_id','points_balance','marketing_opt_in')) { if (-not (Get-ColumnValue $row $field)) { $complete = $false } }
    if ($complete) { $loyaltyComplete++ }
    $customerId = Get-ColumnValue $row 'customer_id'
    if ($customerIds.ContainsKey($customerId)) { $loyaltyCustomerMapped++ }
    $points = [long]0
    if ([long]::TryParse((Get-ColumnValue $row 'points_balance'), [ref]$points) -and $points -ge 0) { $loyaltyBalanceValid++ }
    $loyaltyId = Get-ColumnValue $row 'loyalty_account_id'
    if ($loyaltyIds.ContainsKey($loyaltyId)) { $duplicateLoyalty++ } else { $loyaltyIds[$loyaltyId] = $true }
}
Add-Profile 'loyalty' 'before' 'completeness' 'Rows complete on four loyalty fields' $loyaltyComplete $loyalty.Count 'percent' 'All four listed fields non-empty.' 'All three fixture rows complete.'
Add-Profile 'loyalty' 'before' 'validity' 'Customer IDs resolving to customer file' $loyaltyCustomerMapped $loyalty.Count 'percent' 'Exact customer_id referential check.' 'All fixture IDs resolve; this is not proof of person identity.'
Add-Profile 'loyalty' 'before' 'validity' 'Non-negative integer point balances' $loyaltyBalanceValid $loyalty.Count 'percent' 'Integer parsing and balance >= 0.' 'Business rules for reversals/expiry are not present.'
Add-Profile 'loyalty' 'before' 'uniqueness' 'Duplicate loyalty account IDs' $duplicateLoyalty $loyalty.Count 'rows' 'loyalty_account_id is unique in extract.' 'No duplicate account IDs in fixture.'
Add-Profile 'loyalty' 'after' 'accuracy' 'Point balances reconciled to event ledger' 0 $null 'not measured' 'Requires point transactions, not only current balances.' 'The balances are unverified.'
Add-Profile 'loyalty' 'after' 'timeliness' 'Preference freshness against approved SLA' 0 $null 'not measured' 'No preference update timestamp or SLA.' 'Cannot measure freshness.'

# HR sample is a schema-only fixture; identify sensitivity without treating placeholders as people.
$hrPath = Join-Path $inputDir 'SRG_HR_SAMPLE.csv'
if (Test-Path -LiteralPath $hrPath -PathType Leaf) {
    $hrRows = @(Import-Csv -LiteralPath $hrPath)
    $hrHeaders = @((Get-Content -LiteralPath $hrPath -TotalCount 1) -split ',')
    $restrictedFields = @('bank_account','health_note','phone','pay_band')
    $restrictedPresent = @($hrHeaders | Where-Object { $_ -in $restrictedFields }).Count
    Add-Profile 'hr_sample' 'before' 'completeness' 'Sample HR rows present' $hrRows.Count $null 'rows' 'Only sample row count.' 'One fabricated schema row; assignment SRG_HR.xlsx is absent.'
    Add-Profile 'hr_sample' 'before' 'confidentiality' 'Sensitive/restricted columns identified' $restrictedPresent $hrHeaders.Count 'columns' 'bank_account, health_note, phone, pay_band treated as restricted.' 'Schema-level classification only; sample values are explicit placeholders, not real employee data.'
}

# Footfall: schema validity and duplicate ids; no arrival time or person identifiers expected.
$footfallPath = Join-Path $inputDir 'footfall_stream_sample.json'
if (Test-Path -LiteralPath $footfallPath -PathType Leaf) {
    $events = @((Get-Content -LiteralPath $footfallPath -Raw | ConvertFrom-Json))
    $eventIds = @{}
    $validEvents = 0
    $validTimes = 0
    $identifyingFields = @('person_id','customer_id','device_id','face_id','email','phone')
    $identifyingCount = 0
    foreach ($event in $events) {
        $valid = $true
        foreach ($field in @('event_id','store_id','event_time','count_delta')) {
            if (-not $event.PSObject.Properties[$field]) { $valid = $false }
        }
        if ($valid) { $validEvents++ }
        $parsedTime = [datetimeoffset]::MinValue
        if ([datetimeoffset]::TryParse([string]$event.event_time, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsedTime)) { $validTimes++ }
        $eventId = [string]$event.event_id
        if ($eventIds.ContainsKey($eventId)) { $eventIds[$eventId]++ } else { $eventIds[$eventId] = 1 }
        foreach ($field in $identifyingFields) { if ($event.PSObject.Properties[$field]) { $identifyingCount++ } }
    }
    $duplicateEventIds = 0
    foreach ($count in $eventIds.Values) { if ($count -gt 1) { $duplicateEventIds += ($count - 1) } }
    Add-Profile 'footfall' 'before' 'completeness' 'Events containing required fields' $validEvents $events.Count 'percent' 'event_id, store_id, event_time, count_delta required.' 'Three fixture events.'
    Add-Profile 'footfall' 'before' 'validity' 'Timestamps parse with offset' $validTimes $events.Count 'percent' 'ISO 8601 datetime with timezone/offset.' 'All fixture timestamps include Z.'
    Add-Profile 'footfall' 'before' 'uniqueness' 'Duplicate event IDs' $duplicateEventIds $events.Count 'rows' 'event_id unique in sample.' 'No duplicates in fixture.'
    Add-Profile 'footfall' 'before' 'privacy' 'Events containing enumerated direct/linked identifiers' $identifyingCount $events.Count 'fields' 'Scan for person_id/customer_id/device_id/face_id/email/phone keys.' 'Zero in this tiny fixture does not prove sensor privacy.'
    Add-Profile 'footfall' 'after' 'timeliness' 'Arrival latency against stream SLA' 0 $null 'not measured' 'No ingestion timestamp or latency SLA.' 'Cannot assess event delivery delay.'
}

$profileRows | Export-Csv -LiteralPath (Join-Path $outputDir 'workspace_quality_profile.csv') -NoTypeInformation -Encoding UTF8

# Build reproducible dashboard aggregate rows from the cleaned sales fixture.
$districtByStore = @{
    'KLA01'='Kampala'; 'GUL01'='Gulu'; 'JIN01'='Jinja'; 'MBR01'='Mbarara'
}
$aggregate = @{}
foreach ($sale in $cleanSales) {
    $sku = (Get-ColumnValue $sale 'canonical_sku').ToUpperInvariant()
    $product = $cleanProductBySku[$sku]
    $date = [datetime]::ParseExact((Get-ColumnValue $sale 'order_date'), 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $storeCode = (Get-ColumnValue $sale 'store_code').ToUpperInvariant()
    $district = if ($districtByStore.ContainsKey($storeCode)) { $districtByStore[$storeCode] } else { 'Unmapped' }
    $category = if ($product -and $product.category_canonical) { [string]$product.category_canonical } else { 'Unmapped' }
    $channel = (Get-ColumnValue $sale 'channel').ToUpperInvariant()
    $key = @($date.ToString('yyyy-MM'), $district, $channel, $category) -join '|'
    if (-not $aggregate.ContainsKey($key)) {
        $aggregate[$key] = [pscustomobject]@{
            month = $date.ToString('yyyy-MM')
            district = $district
            channel = $channel
            category = $category
            sales = [decimal]0
            orders = 0
            units = [decimal]0
            order_ids = @{}
        }
    }
    $amount = [decimal]0
    [decimal]::TryParse((Get-ColumnValue $sale 'net_amount'), [ref]$amount) | Out-Null
    $quantity = [decimal]0
    [decimal]::TryParse((Get-ColumnValue $sale 'quantity'), [ref]$quantity) | Out-Null
    $aggregate[$key].sales += $amount
    $aggregate[$key].units += $quantity
    $aggregate[$key].order_ids[(Get-ColumnValue $sale 'source_order_id')] = $true
}
$dashboardRows = foreach ($row in $aggregate.Values) {
    $row.orders = $row.order_ids.Count
    [pscustomobject]@{
        month = $row.month
        district = $row.district
        channel = $row.channel
        category = $row.category
        sales = $row.sales
        orders = $row.orders
        units = $row.units
    }
}
$dashboardRows = @($dashboardRows | Sort-Object month,district,channel,category)
$dashboardData = [pscustomobject]@{
    evidence_label = 'Workspace data, synthetic demonstration fixtures'
    generated_at_utc = [datetime]::UtcNow.ToString('o')
    source_sales_rows = $sales.Count
    accepted_sales_rows = $cleanSales.Count
    rejected_sales_rows = $saleRejects.Count
    rows = $dashboardRows
}
$json = $dashboardData | ConvertTo-Json -Depth 8
$jsonPath = Join-Path $outputDir 'dashboard-source-data.json'
Set-Content -LiteralPath $jsonPath -Value $json -Encoding UTF8
$jsonLiteral = ConvertTo-Json -InputObject $dashboardRows -Depth 8 -Compress
$dataJs = "window.srgDemoRows = $jsonLiteral;`nwindow.srgDemoMetadata = " + (ConvertTo-Json -InputObject ([pscustomobject]@{
    label = $dashboardData.evidence_label
    generated_at_utc = $dashboardData.generated_at_utc
    source_sales_rows = $sales.Count
    accepted_sales_rows = $cleanSales.Count
    rejected_sales_rows = $saleRejects.Count
}) -Compress) + ';'
Set-Content -LiteralPath (Join-Path $dashboardDir 'demo-data.js') -Value $dataJs -Encoding UTF8

$publicationRows = foreach ($row in $dashboardRows) {
    [pscustomobject]@{
        month = [string]$row.month
        district = [string]$row.district
        channel = [string]$row.channel
        category = [string]$row.category
        net_sales_ugx = ([decimal]$row.sales).ToString('0.################', [Globalization.CultureInfo]::InvariantCulture)
        transactions = [int]$row.orders
        net_units = ([decimal]$row.units).ToString('0.################', [Globalization.CultureInfo]::InvariantCulture)
    }
}
$publicationCsv = $publicationRows | ConvertTo-Csv -NoTypeInformation
$publicationCsvPath = Join-Path $dashboardDir 'workspace-synthetic-sales-aggregates.csv'
[IO.File]::WriteAllLines($publicationCsvPath, $publicationCsv, (New-Object Text.UTF8Encoding($true)))

# Data-backed findings from the accepted fixture: calculate only simple observed facts.
$totalNet = ($cleanSales | Measure-Object -Property net_amount -Sum).Sum
$totalQty = ($cleanSales | Measure-Object -Property quantity -Sum).Sum
$returns = @($cleanSales | Where-Object { [decimal]$_.quantity -lt 0 }).Count
$categorySummary = $cleanSales | Group-Object canonical_sku | ForEach-Object {
    [pscustomobject]@{
        canonical_sku = $_.Name
        accepted_lines = $_.Count
        net_amount = [decimal](($_.Group | Measure-Object -Property net_amount -Sum).Sum)
        units = [decimal](($_.Group | Measure-Object -Property quantity -Sum).Sum)
    }
}
$report = @"
# Workspace dataset profile and execution summary

**Scope:** every data file currently present under ``data/demo/``. The accompanying
``data/demo/README.md`` explicitly states these values are fabricated testing
fixtures; findings below are calculations on those workspace fixtures only,
not verified observations about Savanna Retail Group. Per the user's instruction,
this directory was treated as the complete available dataset for this run.

## File inventory

See ``output/workspace_dataset_inventory.csv`` for row/event counts, hashes,
byte sizes, and explicit missing-file entries. Present files: customer,
product, sales, supplier, loyalty, synthetic HR sample, and synthetic footfall
sample. Not present: the assignment ``etl_error_log.txt`` and ``SRG_HR.xlsx``.

## Profile metrics

See ``output/workspace_quality_profile.csv`` for numerator, denominator,
percentage (where meaningful), rule, phase, and limitation for each metric.
Customer/product before-and-after metrics are also in
``output/quality_metrics.csv``. Accuracy and timeliness are marked not measured
where no independent reference, arrival timestamp, or SLA exists.

### Executed sales fixture results

- Rows read: **$($sales.Count)**; accepted: **$($cleanSales.Count)**; quarantined:
  **$($saleRejects.Count)**. The sole rejected record is reported with source
  record and reason in ``output/sales_rejects.csv``.
- Accepted synthetic net amount: **UGX $([Math]::Round([decimal]$totalNet, 2))**;
  accepted net quantity: **$totalQty**; lines with negative quantity:
  **$returns**. Amount is a computed fixture total, not a validated SRG total.
- Missing payment references: **$missingPaymentRef of $($sales.Count)**. These
  remain explicitly marked for Finance; the missing value is not fabricated.
- Negative quantity lines with a reason: **$negativeWithReason of $negativeQty**.
  Return quantity and amount remain negative in the analytics fact by design.
- Duplicate source order/line keys: **$duplicateLines**. No duplicate line keys
  were observed in the fixture.

| SKU | Accepted lines | Net amount (UGX in fixture) | Net units |
|---|---:|---:|---:|
"@
foreach ($row in $categorySummary) {
    $report += "`n| $($row.canonical_sku) | $($row.accepted_lines) | $([Math]::Round($row.net_amount,2)) | $($row.units) |"
}
$report += @"

## Cleansing decisions and assumptions

1. Phone normalization is only for recognizable Ugandan formats; malformed or
   missing numbers remain unresolved. Matching numbers create a review candidate,
   never an automatic identity merge.
2. ``KLA`` is mapped to Kampala and the fixture's listed districts are accepted
   only as a demonstration reference; an owner-approved reference is required
   for production.
3. Unit aliases ``kg/KGS/Kilograms`` and ``L/lt/Litre`` normalize to kg/L.
   Pack-size and variable-weight conversions require procurement approval.
4. Ambiguous slash dates are quarantined rather than interpreted by locale.
   The rejected P002 record shows this rule in use.
5. A three-letter currency string is a syntax check only. FX conversion and
   authoritative settlement are not inferred.
6. CSV files are the supplied representation. ``SRG_HR_SAMPLE.csv`` is treated
   only as a one-row schema example, not as the requested HR workbook.
7. The missing ``etl_error_log.txt`` is not replaced with a fabricated log.
   The successful run transcript at ``output/postgres-demo-etl-log.txt`` is
   execution evidence, not evidence of the assignment's broken job.

## ETL log diagnosis

No ``etl_error_log.txt`` exists anywhere in the workspace inventory. Therefore,
there is no evidence from which to identify a specific broken-job root cause.
The reproducible SQL path itself was executed twice: seven rows stage and load,
the second run upserts rather than duplicates facts, the ambiguous-date row is
excluded, and the explained return remains negative. The only error observed
in the RBAC test is the expected permission denial when analytics attempts
restricted access; it is a passing security control, not an ETL failure.

For the absent broken-job log, diagnosis remains **not evidenced**. Inspect its
first exception, job/run ID, watermarks, source schema/counts, credentials,
network/lock events, transaction boundaries, and partial target state when a
real log is supplied. Do not claim any one hypothesis as the cause.

## Remaining validity limits

These fixture sizes (customers=$($customers.Count), products=$($products.Count),
sales=$($sales.Count), suppliers=$($suppliers.Count), loyalty=$($loyalty.Count),
footfall events=$(@((Get-Content -LiteralPath $footfallPath -Raw | ConvertFrom-Json)).Count))
are smaller than the scale stated in the assignment scenario. Thus, this run
demonstrates the profiling/ETL scripts and provides exact results for current
files, but does not validate scenario-scale percentages, business trends,
stock-variance root cause, or actual HR exposure.
"@
Set-Content -LiteralPath (Join-Path $outputDir 'workspace-data-profile.md') -Value $report -Encoding UTF8

Write-Output "Profiled workspace files: $($manifestRows.Count)"
Write-Output "Sales rows: $($sales.Count); accepted $($cleanSales.Count); rejected $($saleRejects.Count)"
Write-Output "Generated workspace_quality_profile.csv, workspace_dataset_inventory.csv, workspace-data-profile.md, dashboard/demo-data.js, and dashboard/workspace-synthetic-sales-aggregates.csv"
