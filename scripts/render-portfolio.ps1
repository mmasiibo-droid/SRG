[CmdletBinding()]
param(
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$docs = Join-Path $root 'docs'
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root 'output' }
if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

function Convert-InlineMarkdown {
    param([string]$Text)
    $encoded = [System.Net.WebUtility]::HtmlEncode($Text)
    $encoded = [regex]::Replace($encoded, '`([^`]+)`', '<code>$1</code>')
    $encoded = [regex]::Replace($encoded, '\*\*([^*]+)\*\*', '<strong>$1</strong>')
    $encoded = [regex]::Replace($encoded, '\*([^*]+)\*', '<em>$1</em>')
    $encoded = [regex]::Replace($encoded, '\[([^\]]+)\]\(([^)]+)\)', '<a href="$2">$1</a>')
    return $encoded
}

function Convert-MarkdownDocument {
    param([string]$Path)
    $lines = [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)
    $html = New-Object 'System.Collections.Generic.List[string]'
    $paragraph = New-Object 'System.Collections.Generic.List[string]'
    $listItems = New-Object 'System.Collections.Generic.List[string]'
    $tableRows = New-Object 'System.Collections.Generic.List[object]'
    $inCode = $false
    $codeLanguage = ''
    $codeLines = New-Object 'System.Collections.Generic.List[string]'
    $inQuote = $false

    $flushParagraph = {
        if ($paragraph.Count -gt 0) {
            $text = [string]::Join(' ', $paragraph)
            $html.Add('<p>' + (Convert-InlineMarkdown $text) + '</p>')
            $paragraph.Clear()
        }
    }
    $flushList = {
        if ($listItems.Count -gt 0) {
            $html.Add('<ul>')
            foreach ($item in $listItems) { $html.Add('<li>' + (Convert-InlineMarkdown $item) + '</li>') }
            $html.Add('</ul>')
            $listItems.Clear()
        }
    }
    $flushTable = {
        if ($tableRows.Count -gt 0) {
            $html.Add('<table>')
            for ($rowIndex = 0; $rowIndex -lt $tableRows.Count; $rowIndex++) {
                $row = $tableRows[$rowIndex]
                if ($row -match '^\s*\|?\s*:?-{3,}') { continue }
                $cells = @($row.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
                $tag = if ($rowIndex -eq 0) { 'th' } else { 'td' }
                $html.Add('<tr>')
                foreach ($cell in $cells) { $html.Add('<' + $tag + '>' + (Convert-InlineMarkdown $cell) + '</' + $tag + '>') }
                $html.Add('</tr>')
            }
            $html.Add('</table>')
            $tableRows.Clear()
        }
    }

    foreach ($line in $lines) {
        if ($line -match '^```(.*)$') {
            if (-not $inCode) {
                & $flushParagraph
                & $flushList
                & $flushTable
                $inCode = $true
                $codeLanguage = $Matches[1].Trim()
                $codeLines.Clear()
            } else {
                if ($codeLanguage -eq 'mermaid') {
                    $html.Add('<figure class="diagram-source"><figcaption>Editable Mermaid diagram source</figcaption><pre>' + [System.Net.WebUtility]::HtmlEncode([string]::Join("`n", $codeLines)) + '</pre></figure>')
                } else {
                    $html.Add('<pre><code>' + [System.Net.WebUtility]::HtmlEncode([string]::Join("`n", $codeLines)) + '</code></pre>')
                }
                $inCode = $false
                $codeLanguage = ''
            }
            continue
        }
        if ($inCode) {
            $codeLines.Add($line)
            continue
        }
        if ([string]::IsNullOrWhiteSpace($line)) {
            & $flushParagraph
            & $flushList
            & $flushTable
            if ($inQuote) { $html.Add('</blockquote>'); $inQuote = $false }
            continue
        }
        if ($line -match '^\s*\|') {
            & $flushParagraph
            & $flushList
            if ($inQuote) { $html.Add('</blockquote>'); $inQuote = $false }
            $tableRows.Add($line)
            continue
        }
        if ($line -match '^\s*\|?\s*:?-{3,}') {
            $tableRows.Add($line)
            continue
        }
        if ($tableRows.Count -gt 0) { & $flushTable }
        if ($line -match '^(#{1,6})\s+(.*)$') {
            & $flushParagraph
            & $flushList
            if ($inQuote) { $html.Add('</blockquote>'); $inQuote = $false }
            $level = $Matches[1].Length
            $heading = Convert-InlineMarkdown $Matches[2]
            $html.Add("<h$level>$heading</h$level>")
            continue
        }
        if ($line -match '^\s*>\s?(.*)$') {
            & $flushParagraph
            & $flushList
            if (-not $inQuote) { $html.Add('<blockquote>'); $inQuote = $true }
            $html.Add('<p>' + (Convert-InlineMarkdown $Matches[1]) + '</p>')
            continue
        }
        if ($inQuote) { $html.Add('</blockquote>'); $inQuote = $false }
        if ($line -match '^\s*[-*]\s+(.*)$') {
            & $flushParagraph
            $listItems.Add($Matches[1])
            continue
        }
        if ($line -match '^\s*\d+\.\s+(.*)$') {
            & $flushParagraph
            $listItems.Add($Matches[1])
            continue
        }
        & $flushList
        $paragraph.Add($line.Trim())
    }
    & $flushParagraph
    & $flushList
    & $flushTable
    if ($inQuote) { $html.Add('</blockquote>') }
    if ($inCode) {
        $html.Add('<pre><code>' + [System.Net.WebUtility]::HtmlEncode([string]::Join("`n", $codeLines)) + '</code></pre>')
    }
    return [string]::Join("`n", $html)
}

function Add-DocumentSection {
    param([System.Collections.Generic.List[string]]$Parts, [string]$Path, [bool]$NewPage)
    $name = [IO.Path]::GetFileNameWithoutExtension($Path)
    if ($NewPage) { $Parts.Add('<section class="appendix">') } else { $Parts.Add('<section>') }
    $Parts.Add((Convert-MarkdownDocument $Path))
    $Parts.Add('</section>')
}

function Convert-CsvAppendix {
    param([string]$Path)
    $rows = @(Import-Csv -LiteralPath $Path)
    $html = New-Object 'System.Collections.Generic.List[string]'
    $title = [IO.Path]::GetFileNameWithoutExtension($Path) -replace '[-_]', ' '
    $html.Add('<section class="appendix"><h1>' + (Convert-InlineMarkdown $title) + '</h1>')
    if ($rows.Count -eq 0) {
        $html.Add('<p>No records.</p></section>')
        return [string]::Join("`n", $html)
    }
    $columns = @($rows[0].PSObject.Properties.Name)
    $html.Add('<table class="register"><thead><tr>')
    foreach ($column in $columns) { $html.Add('<th>' + (Convert-InlineMarkdown $column) + '</th>') }
    $html.Add('</tr></thead><tbody>')
    foreach ($row in $rows) {
        $html.Add('<tr>')
        foreach ($column in $columns) {
            $value = [string]$row.$column
            $html.Add('<td>' + [System.Net.WebUtility]::HtmlEncode($value) + '</td>')
        }
        $html.Add('</tr>')
    }
    $html.Add('</tbody></table></section>')
    return [string]::Join("`n", $html)
}

$parts = New-Object 'System.Collections.Generic.List[string]'
$parts.Add('<!doctype html><html lang="en"><head><meta charset="utf-8"><base href="' + ([uri]$docs).AbsoluteUri + '/"><title>Project Savanna EDM Portfolio - Working Draft</title>')
$parts.Add('<style>
@page { size: A4; margin: 16mm 14mm 17mm; }
* { box-sizing:border-box; }
body { color:#172b3a; font:10pt/1.42 "Segoe UI",Arial,sans-serif; }
h1 { color:#126b5b; font-size:23pt; line-height:1.15; margin:0 0 12pt; }
h2 { color:#126b5b; font-size:15pt; margin:19pt 0 7pt; break-after:avoid; }
h3 { color:#28465a; font-size:11pt; margin:12pt 0 5pt; break-after:avoid; }
p { margin:0 0 7pt; orphans:3; widows:3; }
ul,ol { margin:3pt 0 9pt 18pt; padding:0; }
li { margin:0 0 3pt; }
table { border-collapse:collapse; width:100%; margin:7pt 0 11pt; font-size:8pt; break-inside:auto; }
tr { break-inside:avoid; }
th { background:#eaf4f1; color:#172b3a; text-align:left; }
th,td { border:0.5pt solid #bccbd2; padding:4pt 5pt; vertical-align:top; }
blockquote { margin:8pt 0; padding:8pt 11pt; background:#fff6dc; border-left:3pt solid #d99b19; }
code,pre { font-family:Consolas,"Courier New",monospace; font-size:7.5pt; }
pre { white-space:pre-wrap; overflow-wrap:anywhere; border:0.5pt solid #d7e0e5; padding:7pt; background:#f6f8f9; }
a { color:#126b5b; }
.appendix { break-before:page; }
.diagram-source { break-inside:avoid; }
.diagram-source figcaption { color:#526575; font-weight:bold; margin-bottom:4pt; }
.register { font-size:6.6pt; }
.register th,.register td { padding:2.5pt 3pt; }
footer { color:#526575; border-top:1px solid #cad5da; margin-top:14pt; padding-top:4pt; font-size:8pt; }
.draft-banner { background:#fff3d5; border:1px solid #d99b19; padding:10pt; margin:12pt 0 16pt; font-weight:bold; }
</style></head><body>')
$parts.Add('<div class="draft-banner">WORKING DRAFT - synthetic demonstration only. Not a final academic submission. Review missing source evidence, personal reflection, and legal obligations before use.</div>')
$parts.Add((Convert-MarkdownDocument (Join-Path $docs 'portfolio.md')))

$appendixDocs = @(
    'board-brief.md',
    'red-team.md',
    'reflective-essay-draft.md',
    'dpia-loyalty-eu.md',
    'workspace-data-profile.md',
    'legal-citation-review.md',
    'dashboard-publication.md',
    'finalization-checklist.md',
    'etl-log-diagnosis-template.md',
    'executive-insight-brief.md',
    'viva-prep.md'
)
foreach ($file in $appendixDocs) {
    $path = Join-Path $docs $file
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $parts.Add('<section class="appendix">' + (Convert-MarkdownDocument $path) + '</section>')
    }
}

$appendixCsv = @(
    'assumptions-register.csv',
    'decision-log.csv',
    'risk-register.csv',
    'data-dictionary.csv',
    'validation-rules.csv',
    'compliance-register.csv',
    'access-control-matrix.csv',
    'etl-vs-elt.csv',
    'catalog-tool-evaluation.csv'
)
foreach ($file in $appendixCsv) {
    $path = Join-Path $docs $file
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $parts.Add((Convert-CsvAppendix $path))
    }
}
$parts.Add('<footer>Project Savanna EDM portfolio • AI-assisted working draft • synthetic test evidence only</footer></body></html>')

$htmlPath = Join-Path $OutputDirectory 'Project-Savanna-Portfolio-DRAFT.html'
$pdfPath = Join-Path $OutputDirectory 'Project-Savanna-Portfolio-DRAFT.pdf'
[IO.File]::WriteAllText($htmlPath, [string]::Join("`n", $parts), (New-Object Text.UTF8Encoding($false)))

$chromeCandidates = @(
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
)
$chrome = $chromeCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $chrome) {
    throw "Chrome was not found. HTML draft is available at $htmlPath"
}
$userData = Join-Path $env:TEMP ('srg-chrome-print-' + [guid]::NewGuid().ToString('N'))
$uri = ([uri]$htmlPath).AbsoluteUri
$arguments = @('--headless=new', '--disable-gpu', '--no-first-run', "--user-data-dir=$userData", "--print-to-pdf=$pdfPath", $uri)
$process = Start-Process -FilePath $chrome -ArgumentList $arguments -PassThru -Wait
if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $pdfPath -PathType Leaf)) {
    throw "Chrome PDF rendering failed (exit code $($process.ExitCode)). HTML draft: $htmlPath"
}
$pdf = Get-Item -LiteralPath $pdfPath
Write-Output "HTML draft: $htmlPath"
Write-Output "PDF draft: $pdfPath ($($pdf.Length) bytes)"
