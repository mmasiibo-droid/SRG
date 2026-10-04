[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputDirectory,
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

function Import-RequiredCsv {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required input file is missing: $Path"
    }
    $rows = @(Import-Csv -LiteralPath $Path)
    if ($rows.Count -eq 0) {
        throw "Input CSV contains no data rows: $Path"
    }
    return $rows
}

function Get-Cell {
    param($Row, [string]$Name)
    $property = $Row.PSObject.Properties[$Name]
    if ($null -eq $property) { return '' }
    if ($null -eq $property.Value) { return '' }
    return ([string]$property.Value).Trim()
}

function Get-Percent {
    param([int]$Numerator, [int]$Denominator)
    if ($Denominator -eq 0) { return 0 }
    return [Math]::Round(($Numerator * 100.0) / $Denominator, 2)
}

function Add-Metric {
    param(
        [System.Collections.Generic.List[object]]$Target,
        [string]$Source,
        [string]$Phase,
        [string]$Dimension,
        [string]$Metric,
        [Nullable[int]]$Numerator,
        [Nullable[int]]$Denominator,
        [string]$Unit,
        [string]$Limitation
    )
    $percent = $null
    if ($null -ne $Numerator -and $null -ne $Denominator -and $Denominator -gt 0) {
        $percent = Get-Percent -Numerator $Numerator -Denominator $Denominator
    }
    $Target.Add([pscustomobject]@{
        source = $Source
        phase = $Phase
        dimension = $Dimension
        metric = $Metric
        numerator = $Numerator
        denominator = $Denominator
        percent = $percent
        unit = $Unit
        limitation = $Limitation
    })
}

function Get-DuplicateCandidateCount {
    param([object[]]$Rows, [string]$PhoneProperty, [string]$NameProperty, [string]$EmailProperty)
    $keys = @{}
    foreach ($row in $Rows) {
        $phoneValue = Get-Cell $row $PhoneProperty
        $phone = Normalize-Phone $phoneValue
        if (-not $phone) { $phone = $phoneValue -replace '[^0-9]', '' }
        $name = ((Get-Cell $row $NameProperty).ToLowerInvariant() -replace '[^a-z0-9 ]', '' -replace '\s+', ' ').Trim()
        $email = (Get-Cell $row $EmailProperty).ToLowerInvariant()
        $key = ''
        if ($phone.Length -ge 9) { $key = 'P:' + $phone }
        elseif ($name -and $email) { $key = 'NE:' + $name + '|' + $email }
        if ($key) {
            if (-not $keys.ContainsKey($key)) { $keys[$key] = 0 }
            $keys[$key]++
        }
    }
    $duplicates = 0
    foreach ($count in $keys.Values) {
        if ($count -gt 1) { $duplicates += ($count - 1) }
    }
    return $duplicates
}

function Normalize-Phone {
    param([string]$Value)
    $digits = $Value -replace '[^0-9]', ''
    if ($Value.Trim().StartsWith('+256') -and $digits.Length -eq 12) {
        return '+256' + $digits.Substring(3)
    }
    if ($digits.StartsWith('256') -and $digits.Length -eq 12) {
        return '+' + $digits
    }
    if ($digits.StartsWith('0') -and $digits.Length -eq 10) {
        return '+256' + $digits.Substring(1)
    }
    if ($digits.Length -eq 9) {
        return '+256' + $digits
    }
    return ''
}

function Normalize-Date {
    param([string]$Value)
    if (-not $Value) { return '' }
    $parsed = [datetime]::MinValue
    $formats = @('yyyy-MM-dd', 'yyyy/M/d')
    foreach ($format in $formats) {
        if ([datetime]::TryParseExact($Value.Trim(), $format, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
            return $parsed.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        }
    }
    if ($Value -match '^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$') {
        $first = [int]$Matches[1]
        $second = [int]$Matches[2]
        $year = [int]$Matches[3]
        if ($first -le 12 -and $second -le 12) {
            return ''
        }
        $format = if ($first -gt 12) { 'd-M-yyyy' } else { 'M-d-yyyy' }
        if ($Value.Contains('/')) {
            $format = if ($first -gt 12) { 'd/M/yyyy' } else { 'M/d/yyyy' }
        }
        if ([datetime]::TryParseExact($Value.Trim(), $format, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
            return $parsed.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        }
    }
    return ''
}

function Get-PhoneFormatCategory {
    param([string]$Value)
    if (-not $Value) { return '' }
    $digits = $Value -replace '[^0-9]', ''
    if ($Value.Trim().StartsWith('+') -and $digits.StartsWith('256')) { return 'E.164 plus country code' }
    if ($digits.StartsWith('256')) { return 'Country code without plus' }
    if ($digits.StartsWith('0')) { return 'National trunk prefix' }
    if ((Normalize-Phone $Value) -and $Value -match '[^0-9]') { return 'Valid number with separators' }
    return 'Invalid or unsupported'
}

function Get-DateFormatCategory {
    param([string]$Value)
    if (-not $Value) { return '' }
    if ($Value -match '^\d{4}-\d{2}-\d{2}$') { return 'ISO year-month-day' }
    if ($Value -match '^\d{4}/\d{1,2}/\d{1,2}$') { return 'Year/month/day' }
    if ($Value -match '^(\d{1,2})/(\d{1,2})/(\d{4})$') {
        if ([int]$Matches[1] -le 12 -and [int]$Matches[2] -le 12) { return 'Ambiguous slash date' }
        if ([int]$Matches[1] -gt 12) { return 'Day/month/year slash' }
        return 'Month/day/year slash'
    }
    if ($Value -match '^(\d{1,2})-(\d{1,2})-(\d{4})$') {
        if ([int]$Matches[1] -le 12 -and [int]$Matches[2] -le 12) { return 'Ambiguous hyphen date' }
        if ([int]$Matches[1] -gt 12) { return 'Day-month-year' }
        return 'Month-day-year'
    }
    return 'Invalid or unsupported'
}

function Get-MaskedPhone {
    param([string]$Value)
    if ($Value -match '^(\+\d{3})\d+(\d{4})$') { return $Matches[1] + '******' + $Matches[2] }
    return '[masked]'
}

function Get-MaskedEmail {
    param([string]$Value)
    if ($Value -match '^[^@]+@([^@]+)$') { return '***@' + $Matches[1].ToLowerInvariant() }
    return '[masked]'
}

if (-not (Test-Path -LiteralPath $InputDirectory -PathType Container)) {
    throw "Input directory does not exist: $InputDirectory"
}
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$customers = Import-RequiredCsv (Join-Path $InputDirectory 'SRG_Customers.csv')
$products = Import-RequiredCsv (Join-Path $InputDirectory 'SRG_Products.csv')
$salesPath = Join-Path $InputDirectory 'SRG_Sales.csv'
$sales = @()
if (Test-Path -LiteralPath $salesPath -PathType Leaf) {
    $sales = @(Import-Csv -LiteralPath $salesPath)
}

$districtMap = @{
    'kampala' = 'Kampala'
    'kla' = 'Kampala'
    'jinja' = 'Jinja'
    'mbarara' = 'Mbarara'
    'gulu' = 'Gulu'
}
$unitMap = @{
    'kg' = 'kg'; 'kgs' = 'kg'; 'kilogram' = 'kg'; 'kilograms' = 'kg'
    'l' = 'L'; 'lt' = 'L'; 'litre' = 'L'; 'liter' = 'L'; 'litres' = 'L'; 'liters' = 'L'
    'each' = 'each'; 'ea' = 'each'; 'piece' = 'each'; 'pieces' = 'each'
}
$categoryMap = @{
    'bevrages' = 'Beverages'
    'beverages' = 'Beverages'
    'snacks' = 'Snacks'
    'household' = 'Household'
    'produce' = 'Produce'
}

$metrics = New-Object 'System.Collections.Generic.List[object]'
$customerRequired = @('full_name', 'phone', 'district')
$customerBeforeMissing = 0
$customerBeforePhoneValid = 0
$customerBeforeDistrictValid = 0
$customerBeforeDatesValid = 0
$customerAfterMissing = 0
$customerAfterPhoneValid = 0
$customerAfterDistrictValid = 0
$customerAfterDatesValid = 0
$customerPhoneBeforeFormats = @{}
$customerPhoneAfterFormats = @{}
$customerDateBeforeFormats = @{}
$customerDateAfterFormats = @{}
$cleanCustomers = New-Object 'System.Collections.Generic.List[object]'
$duplicateCandidates = New-Object 'System.Collections.Generic.List[object]'
$customerCanonicalPhones = @{}

foreach ($row in $customers) {
    $name = Get-Cell $row 'full_name'
    $phone = Get-Cell $row 'phone'
    $email = Get-Cell $row 'email'
    $district = Get-Cell $row 'district'
    $createdDate = Get-Cell $row 'created_date'
    $phoneCanonical = Normalize-Phone $phone
    $districtKey = $district.ToLowerInvariant()
    $districtCanonical = ''
    if ($districtMap.ContainsKey($districtKey)) { $districtCanonical = $districtMap[$districtKey] }
    $dateCanonical = Normalize-Date $createdDate
    $missingBefore = 0
    foreach ($field in $customerRequired) {
        if (-not (Get-Cell $row $field)) { $missingBefore++ }
    }
    if ($missingBefore -eq 0) { $customerBeforeMissing++ }
    if ($phoneCanonical) { $customerBeforePhoneValid++ }
    if ($districtCanonical) { $customerBeforeDistrictValid++ }
    if ($dateCanonical) { $customerBeforeDatesValid++ }
    $phoneFormat = Get-PhoneFormatCategory $phone
    $dateFormat = Get-DateFormatCategory $createdDate
    if ($phoneFormat) { $customerPhoneBeforeFormats[$phoneFormat] = $true }
    if ($dateFormat) { $customerDateBeforeFormats[$dateFormat] = $true }
    if ($phone) {
        $afterPhoneFormat = if ($phoneCanonical) { 'E.164 canonical' } else { 'Unresolved or invalid' }
        $customerPhoneAfterFormats[$afterPhoneFormat] = $true
    }
    if ($createdDate) {
        $afterDateFormat = if ($dateCanonical) { 'ISO canonical' } else { 'Unresolved or ambiguous' }
        $customerDateAfterFormats[$afterDateFormat] = $true
    }

    $missingAfter = 0
    if (-not $name) { $missingAfter++ }
    if (-not $phone) { $missingAfter++ }
    if (-not $district) { $missingAfter++ }
    if ($missingAfter -eq 0) { $customerAfterMissing++ }
    if ($phoneCanonical) { $customerAfterPhoneValid++ }
    if ($districtCanonical) { $customerAfterDistrictValid++ }
    if ($dateCanonical) { $customerAfterDatesValid++ }

    $sourceId = Get-Cell $row 'customer_id'
    $candidateKey = ''
    if ($phoneCanonical) { $candidateKey = 'P:' + $phoneCanonical }
    elseif ($name -and $email) { $candidateKey = 'NE:' + (($name.ToLowerInvariant() -replace '[^a-z0-9 ]', '' -replace '\s+', ' ').Trim()) + '|' + $email.ToLowerInvariant() }
    $candidateFlag = $false
    if ($candidateKey) {
        if ($customerCanonicalPhones.ContainsKey($candidateKey)) {
            $candidateFlag = $true
            $duplicateCandidates.Add([pscustomobject]@{
                candidate_group_id = $customerCanonicalPhones[$candidateKey].candidate_group_id
                source_customer_id = $sourceId
                possible_existing_id = $customerCanonicalPhones[$candidateKey].source_id
                review_required = $true
                disposition = 'Pending human review; no automatic merge'
            })
        } else {
            $customerCanonicalPhones[$candidateKey] = [pscustomobject]@{
                candidate_group_id = [guid]::NewGuid().ToString()
                source_id = $sourceId
            }
        }
    }
    $cleanCustomers.Add([pscustomobject]@{
        customer_id = $sourceId
        full_name = (($name -replace '\s+', ' ').Trim())
        phone_source = $phone
        phone_canonical = $phoneCanonical
        email_source = $email
        email_normalized = $email.ToLowerInvariant()
        district_source = $district
        district_canonical = $districtCanonical
        created_date_source = $createdDate
        created_date_iso = $dateCanonical
        marketing_opt_in_source = Get-Cell $row 'marketing_opt_in'
        duplicate_candidate = $candidateFlag
        data_quality_action = if (-not $districtCanonical -or (-not $phoneCanonical -and $phone)) { 'Review required' } else { 'Standardized; inspect match queue' }
    })
}

$customerBeforeDuplicates = Get-DuplicateCandidateCount $customers 'phone' 'full_name' 'email'
$customerAfterDuplicates = Get-DuplicateCandidateCount $cleanCustomers 'phone_canonical' 'full_name' 'email_normalized'
foreach ($phase in @('before', 'after')) {
    $requiredCount = if ($phase -eq 'before') { $customerBeforeMissing } else { $customerAfterMissing }
    $phoneCount = if ($phase -eq 'before') { $customerBeforePhoneValid } else { $customerAfterPhoneValid }
    $districtCount = if ($phase -eq 'before') { $customerBeforeDistrictValid } else { $customerAfterDistrictValid }
    $dateCount = if ($phase -eq 'before') { $customerBeforeDatesValid } else { $customerAfterDatesValid }
    $dupCount = if ($phase -eq 'before') { $customerBeforeDuplicates } else { $customerAfterDuplicates }
    Add-Metric $metrics 'customers' $phase 'completeness' 'Rows complete across name, phone, district' $requiredCount $customers.Count 'percent' 'Completeness is defined on the three required fields; invalid-but-present values are handled under validity.'
    Add-Metric $metrics 'customers' $phase 'validity' 'Phone values passing documented syntax rule' $phoneCount $customers.Count 'percent' 'Syntax does not prove ownership or reachability.'
    Add-Metric $metrics 'customers' $phase 'validity' 'District values mapped to approved demo reference' $districtCount $customers.Count 'percent' 'Reference list is a pilot fixture and must be approved by the business owner.'
    Add-Metric $metrics 'customers' $phase 'validity' 'Creation dates parsed to ISO date' $dateCount $customers.Count 'percent' 'Ambiguous dates require source-system confirmation.'
    Add-Metric $metrics 'customers' $phase 'uniqueness' 'Duplicate candidates under conservative key rule' $dupCount $customers.Count 'candidate rows' 'Candidates are preserved for human review; no person is automatically merged.'
    Add-Metric $metrics 'customers' $phase 'consistency' 'Distinct phone format categories' $(if ($phase -eq 'before') { $customerPhoneBeforeFormats.Count } else { $customerPhoneAfterFormats.Count }) $null 'count' 'Categories describe representation patterns, not distinct people or phone values.'
    Add-Metric $metrics 'customers' $phase 'consistency' 'Distinct date format categories' $(if ($phase -eq 'before') { $customerDateBeforeFormats.Count } else { $customerDateAfterFormats.Count }) $null 'count' 'Unresolved and ambiguous source dates remain flagged instead of being guessed.'
    Add-Metric $metrics 'customers' $phase 'accuracy' 'Verified customer facts against trusted reference' $null $null 'not measured' 'No authoritative reference or customer confirmation supplied.'
    Add-Metric $metrics 'customers' $phase 'timeliness' 'On-time customer updates against approved SLA' $null $null 'not measured' 'No update timestamp, arrival timestamp, or approved SLA supplied.'
}

$productCompleteBefore = 0
$productCompleteAfter = 0
$productBeforeUnits = @{}
$productAfterUnits = @{}
$productBeforeSkus = @{}
$productAfterSkus = @{}
$cleanProducts = New-Object 'System.Collections.Generic.List[object]'
$skuFirst = @{}
$productUnitValidBefore = 0
$productUnitValidAfter = 0
foreach ($row in $products) {
    $sku = Get-Cell $row 'sku'
    $name = Get-Cell $row 'product_name'
    $category = Get-Cell $row 'category'
    $unit = Get-Cell $row 'unit'
    $skuCanonical = $sku.ToUpperInvariant()
    $unitKey = $unit.ToLowerInvariant()
    $unitCanonical = ''
    if ($unitMap.ContainsKey($unitKey)) { $unitCanonical = $unitMap[$unitKey] }
    $categoryKey = $category.ToLowerInvariant()
    $categoryCanonical = ''
    if ($categoryMap.ContainsKey($categoryKey)) { $categoryCanonical = $categoryMap[$categoryKey] }
    if ($sku -and $name -and $unit -and $category) { $productCompleteBefore++ }
    if ($skuCanonical -and $name -and $unitCanonical -and $categoryCanonical) { $productCompleteAfter++ }
    if ($unitMap.ContainsKey($unitKey)) { $productUnitValidBefore++ }
    if ($unitCanonical) { $productUnitValidAfter++ }
    if ($unit) { $productBeforeUnits[$unit] = $true }
    if ($unitCanonical) { $productAfterUnits[$unitCanonical] = $true }
    if ($sku) { $productBeforeSkus[$sku] = $true }
    if ($skuCanonical) { $productAfterSkus[$skuCanonical] = $true }
    $cleanProducts.Add([pscustomobject]@{
        sku_source = $sku
        canonical_sku = $skuCanonical
        product_name = (($name -replace '\s+', ' ').Trim())
        category_source = $category
        category_canonical = $categoryCanonical
        unit_source = $unit
        unit_canonical = $unitCanonical
        unit_price = Get-Cell $row 'unit_price'
        duplicate_sku_candidate = $skuFirst.ContainsKey($skuCanonical)
        data_quality_action = if (-not $unitCanonical -or -not $categoryCanonical) { 'Review required' } else { 'Standardized; inspect duplicate SKU candidates' }
    })
    if ($skuCanonical -and -not $skuFirst.ContainsKey($skuCanonical)) { $skuFirst[$skuCanonical] = $sku }
}

$productDuplicateBefore = $products.Count - $productBeforeSkus.Count
$productDuplicateAfter = $products.Count - $productAfterSkus.Count
foreach ($phase in @('before', 'after')) {
    $completeCount = if ($phase -eq 'before') { $productCompleteBefore } else { $productCompleteAfter }
    $unitCount = if ($phase -eq 'before') { $productUnitValidBefore } else { $productUnitValidAfter }
    $skuCount = if ($phase -eq 'before') { $productDuplicateBefore } else { $productDuplicateAfter }
    $unitVariants = if ($phase -eq 'before') { $productBeforeUnits.Count } else { $productAfterUnits.Count }
    Add-Metric $metrics 'products' $phase 'completeness' 'Rows complete across SKU, name, category, unit' $completeCount $products.Count 'percent' 'Presence check only; business approval of values is separate.'
    Add-Metric $metrics 'products' $phase 'validity' 'Units mapped to controlled demo unit list' $unitCount $products.Count 'percent' 'Unit list must be approved and extended for variable-weight items.'
    Add-Metric $metrics 'products' $phase 'validity' 'Categories matching approved demo category spellings' $(if ($phase -eq 'before') { @($products | Where-Object { (Get-Cell $_ 'category').ToLowerInvariant() -in @('beverages', 'snacks', 'household', 'produce') }).Count } else { @($cleanProducts | Where-Object { $_.category_canonical }).Count }) $products.Count 'percent' 'Category mappings are demonstration values and require product-owner approval.'
    Add-Metric $metrics 'products' $phase 'uniqueness' 'Duplicate SKU rows after case normalization' $skuCount $products.Count 'candidate rows' 'Duplicate products are flagged, not deleted or merged automatically.'
    Add-Metric $metrics 'products' $phase 'consistency' 'Distinct non-empty unit spellings' $unitVariants $null 'count' 'A lower distinct count after standardization is a format indicator, not proof of accuracy.'
    Add-Metric $metrics 'products' $phase 'accuracy' 'Verified product attributes against approved catalog' $null $null 'not measured' 'No authoritative product catalog or physical verification supplied.'
    Add-Metric $metrics 'products' $phase 'timeliness' 'Current product attributes against approved freshness SLA' $null $null 'not measured' 'No product update timestamps or freshness SLA supplied.'
}

$cleanCustomers | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'customers_cleaned.csv') -NoTypeInformation -Encoding UTF8
$cleanProducts | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'products_cleaned.csv') -NoTypeInformation -Encoding UTF8
$duplicateCandidates | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'customer_duplicate_candidates.csv') -NoTypeInformation -Encoding UTF8
$metrics | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'quality_metrics.csv') -NoTypeInformation -Encoding UTF8

$cleanSales = New-Object 'System.Collections.Generic.List[object]'
$salesRejects = New-Object 'System.Collections.Generic.List[object]'
$salesKeys = @{}
foreach ($row in $sales) {
    $sourceOrderId = Get-Cell $row 'order_id'
    $sourceLineNo = Get-Cell $row 'line_no'
    $skuSource = Get-Cell $row 'sku'
    $storeId = Get-Cell $row 'store_id'
    $dateSource = Get-Cell $row 'order_date'
    $quantityText = Get-Cell $row 'quantity'
    $priceText = Get-Cell $row 'unit_price'
    $currency = (Get-Cell $row 'currency').ToUpperInvariant()
    $returnReason = Get-Cell $row 'return_reason'
    $dateIso = Normalize-Date $dateSource
    $quantity = [decimal]0
    $unitPrice = [decimal]0
    $quantityValid = ($quantityText -match '^-?\d+(\.\d+)?$') -and [decimal]::TryParse($quantityText, [Globalization.NumberStyles]::AllowLeadingSign -bor [Globalization.NumberStyles]::AllowDecimalPoint, [Globalization.CultureInfo]::InvariantCulture, [ref]$quantity)
    $priceValid = ($priceText -match '^\d+(\.\d+)?$') -and [decimal]::TryParse($priceText, [Globalization.NumberStyles]::AllowDecimalPoint, [Globalization.CultureInfo]::InvariantCulture, [ref]$unitPrice)
    $channelSource = (Get-Cell $row 'channel').ToUpperInvariant()
    $sourceSystem = if ($channelSource -match '^(WEB|E-COMMERCE|ECOMMERCE)$') { 'E-COMMERCE' } else { 'POS' }
    $sourceKey = $sourceSystem + '|' + $sourceOrderId + '|' + $sourceLineNo
    $reason = ''
    if (-not $sourceOrderId) { $reason = 'Missing order ID' }
    elseif (-not $sourceLineNo -or $sourceLineNo -notmatch '^\d+$' -or [int]$sourceLineNo -lt 1) { $reason = 'Invalid line number' }
    elseif (-not $skuSource) { $reason = 'Missing SKU' }
    elseif (-not $storeId) { $reason = 'Missing store ID' }
    elseif (-not $dateIso) { $reason = 'Missing, invalid, or ambiguous order date' }
    elseif (-not $quantityValid) { $reason = 'Invalid quantity' }
    elseif (-not $priceValid -or $unitPrice -lt 0) { $reason = 'Invalid unit price' }
    elseif ($currency -notin @('UGX', 'KES', 'RWF', 'USD')) { $reason = 'Unapproved or missing currency code' }
    elseif ($quantity -lt 0 -and -not $returnReason) { $reason = 'Negative quantity lacks return reason' }
    elseif ($salesKeys.ContainsKey($sourceKey)) { $reason = 'Duplicate source order-line key' }
    if ($reason) {
        $salesRejects.Add([pscustomobject]@{
            source_order_id = $sourceOrderId
            source_line_number = $sourceLineNo
            source_sku = $skuSource
            reason = $reason
            source_record = ($row | ConvertTo-Json -Compress)
        })
        continue
    }
    $salesKeys[$sourceKey] = $true
    $cleanSales.Add([pscustomobject]@{
        source_system = $sourceSystem
        source_order_id = $sourceOrderId
        line_number = [int]$sourceLineNo
        source_customer_id = Get-Cell $row 'customer_id'
        source_sku = $skuSource
        canonical_sku = $skuSource.ToUpperInvariant()
        store_code = $storeId.ToUpperInvariant()
        order_date = $dateIso
        quantity = $quantity
        unit_price = $unitPrice
        net_amount = [Math]::Round($quantity * $unitPrice, 2)
        currency_code = $currency
        payment_reference = Get-Cell $row 'payment_ref'
        payment_reference_review = -not [bool](Get-Cell $row 'payment_ref')
        channel = $channelSource
        return_reason = $returnReason
    })
}
$cleanSales | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'sales_cleaned.csv') -NoTypeInformation -Encoding UTF8
$salesRejects | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'sales_rejects.csv') -NoTypeInformation -Encoding UTF8

$masked = foreach ($row in $cleanCustomers) {
    [pscustomobject]@{
        customer_id = $row.customer_id
        phone_masked = Get-MaskedPhone $row.phone_canonical
        email_masked = Get-MaskedEmail $row.email_normalized
        district = $row.district_canonical
        marketing_opt_in = $row.marketing_opt_in_source
        duplicate_candidate = $row.duplicate_candidate
    }
}
$masked | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'customers_masked.csv') -NoTypeInformation -Encoding UTF8

$manifest = [pscustomobject]@{
    generated_at_utc = [datetime]::UtcNow.ToString('o')
    evidence_label = 'Synthetic demo only unless inputs have independently been authorized and verified'
    input_directory = (Resolve-Path -LiteralPath $InputDirectory).Path
    customer_rows = $customers.Count
    product_rows = $products.Count
    sales_rows = $sales.Count
    sales_rows_accepted = $cleanSales.Count
    sales_rows_quarantined = $salesRejects.Count
    duplicate_customer_candidates = $duplicateCandidates.Count
    product_duplicate_candidate_rows = $productDuplicateAfter
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'run_manifest.json') -Encoding UTF8
Write-Output "Completed customer rows: $($customers.Count)"
Write-Output "Completed product rows: $($products.Count)"
Write-Output "Customer duplicate candidates requiring review: $($duplicateCandidates.Count)"
Write-Output "Outputs: $OutputDirectory"
