[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$output = Join-Path $root 'output'
& (Join-Path $PSScriptRoot 'run-demo.ps1')

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Test failed: $Message" }
}

$customers = @(Import-Csv (Join-Path $output 'customers_cleaned.csv'))
$products = @(Import-Csv (Join-Path $output 'products_cleaned.csv'))
$sales = @(Import-Csv (Join-Path $output 'sales_cleaned.csv'))
$salesRejects = @(Import-Csv (Join-Path $output 'sales_rejects.csv'))
$webRows = @($sales | Where-Object { $_.source_order_id -eq 'P003' -and $_.source_system -eq 'E-COMMERCE' })
$unexplainedReturns = @($sales | Where-Object { [decimal]$_.quantity -lt 0 -and -not $_.return_reason })
$candidates = @(Import-Csv (Join-Path $output 'customer_duplicate_candidates.csv'))
$metrics = @(Import-Csv (Join-Path $output 'quality_metrics.csv'))
$maskedText = Get-Content -LiteralPath (Join-Path $output 'customers_masked.csv') -Raw
$candidateText = Get-Content -LiteralPath (Join-Path $output 'customer_duplicate_candidates.csv') -Raw
$manifest = Get-Content -LiteralPath (Join-Path $output 'run_manifest.json') -Raw | ConvertFrom-Json
$publicSales = @(Import-Csv (Join-Path (Split-Path -Parent $PSScriptRoot) 'dashboard\workspace-synthetic-sales-aggregates.csv'))
$publicSalesText = Get-Content -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) 'dashboard\workspace-synthetic-sales-aggregates.csv') -Raw

Assert-True ($customers.Count -eq 8) 'all synthetic customer rows are retained'
Assert-True ($products.Count -eq 6) 'all synthetic product rows are retained'
Assert-True ($candidates.Count -eq 1) 'the duplicate customer is flagged for review, not deleted'
Assert-True ($customers[0].phone_canonical -eq '+256772123456') 'Ugandan phone normalization'
Assert-True ($customers[1].duplicate_candidate -eq 'True') 'normalized duplicate is linked to review queue'
Assert-True ($customers[1].created_date_iso -eq '') 'ambiguous date is quarantined from automatic interpretation'
Assert-True ($products[1].unit_canonical -eq 'kg') 'unit standardization'
Assert-True ($products[1].duplicate_sku_candidate -eq 'True') 'duplicate SKU is retained and flagged'
Assert-True (($sales.Count + $salesRejects.Count) -eq 8) 'every sales line is either accepted or explained in quarantine'
Assert-True ($webRows.Count -eq 1) 'web source classification follows channel, not order ID shape'
Assert-True ($unexplainedReturns.Count -eq 0) 'negative quantities require return reasons'
Assert-True (-not $maskedText.Contains('amina@example.com')) 'masked output excludes full email addresses'
Assert-True (-not $maskedText.Contains('+256772123456')) 'masked output excludes full phone numbers'
Assert-True (-not $candidateText.Contains('+256772123456')) 'duplicate review output does not expose the matching phone key'
Assert-True (($metrics | Where-Object { $_.dimension -eq 'accuracy' -and $_.percent -eq '' }).Count -gt 0) 'accuracy is explicitly marked unmeasured without a trusted reference'
Assert-True ($manifest.evidence_label -match 'Synthetic demo') 'generated evidence is labeled synthetic'
Assert-True ($publicSales.Count -eq 7) 'publication-safe aggregates represent the seven accepted sales groups'
Assert-True (($publicSales[0].PSObject.Properties.Name -join ',') -eq 'month,district,channel,category,net_sales_ugx,transactions,net_units') 'public dataset contains only grouped dashboard dimensions and measures'
Assert-True (-not $publicSalesText.Contains('source_customer_id') -and -not $publicSalesText.Contains('payment_reference') -and -not $publicSalesText.Contains('P001')) 'public dataset excludes customer, payment, and order identifiers'

Write-Output 'PASS: 19 pipeline assertions'
