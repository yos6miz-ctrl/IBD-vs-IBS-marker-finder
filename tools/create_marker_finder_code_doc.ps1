param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression.FileSystem

$Workspace = Split-Path -Parent $PSScriptRoot

$IncludedFiles = @(
    "AGENTS.md",
    ".codex\skills\ibd-vs-ibs-marker-finder\SKILL.md",
    ".codex\skills\stool-data-analyzer\SKILL.md",
    ".codex\skills\criss-cross\SKILL.md",
    ".codex\skills\indirect-response\SKILL.md",
    ".codex\skills\promoter-upstream-length\SKILL.md",
    ".codex\skills\best-candidates\SKILL.md",
    ".codex\skills\ibd_ibs_molecule_mining\SKILL.md",
    "tools\export_skill_docs.ps1",
    "tools\create_methodology_overview_doc.ps1"
)

function Escape-Xml {
    param([string]$Text)
    return [System.Security.SecurityElement]::Escape([string]$Text)
}

function New-ParagraphXml {
    param(
        [string]$Text = "",
        [bool]$Bold = $false,
        [int]$FontSize = 22,
        [int]$SpaceBefore = 120,
        [int]$SpaceAfter = 120,
        [bool]$KeepNext = $false,
        [string]$FontName = "Calibri",
        [string]$ShadingFill = ""
    )

    $pprParts = @(
        ("<w:spacing w:before=`"{0}`" w:after=`"{1}`" w:line=`"276`" w:lineRule=`"auto`"/>" -f $SpaceBefore, $SpaceAfter)
    )
    if ($KeepNext) {
        $pprParts += "<w:keepNext/>"
    }
    if (-not [string]::IsNullOrWhiteSpace($ShadingFill)) {
        $pprParts += ("<w:shd w:val=`"clear`" w:color=`"auto`" w:fill=`"{0}`"/>" -f $ShadingFill)
    }
    $ppr = "<w:pPr>$($pprParts -join '')</w:pPr>"

    $rprParts = @(
        ("<w:rFonts w:ascii=`"{0}`" w:hAnsi=`"{0}`" w:eastAsia=`"{0}`" w:cs=`"{0}`"/>" -f $FontName),
        ("<w:sz w:val=`"{0}`"/><w:szCs w:val=`"{0}`"/>" -f $FontSize)
    )
    if ($Bold) {
        $rprParts += "<w:b/>"
    }
    $rpr = "<w:rPr>$($rprParts -join '')</w:rPr>"

    if ($null -eq $Text) {
        $Text = ""
    }

    return "<w:p>$ppr<w:r>$rpr<w:t xml:space=`"preserve`">$([string](Escape-Xml $Text))</w:t></w:r></w:p>"
}

function New-TitleXml {
    param([string]$Text)
    return New-ParagraphXml -Text $Text -Bold $true -FontSize 34 -SpaceBefore 120 -SpaceAfter 220 -KeepNext $true
}

function New-SectionTitleXml {
    param([string]$Text)
    return New-ParagraphXml -Text $Text -Bold $true -FontSize 28 -SpaceBefore 240 -SpaceAfter 90 -KeepNext $true
}

function New-FileTitleXml {
    param([string]$Text)
    return New-ParagraphXml -Text $Text -Bold $true -FontSize 24 -SpaceBefore 180 -SpaceAfter 60 -KeepNext $true
}

function New-BulletXml {
    param([string]$Text)
    return New-ParagraphXml -Text ("- {0}" -f $Text) -FontSize 22 -SpaceBefore 40 -SpaceAfter 40
}

function New-CodeLineXml {
    param([string]$Text)
    return New-ParagraphXml -Text $Text -FontSize 16 -SpaceBefore 0 -SpaceAfter 0 -FontName "Consolas" -ShadingFill "F3F4F6"
}

function Get-DocumentXml {
    $blocks = New-Object 'System.Collections.Generic.List[string]'

    $blocks.Add((New-TitleXml "IBD vs IBS Marker Finder - Full Code"))
    $blocks.Add((New-ParagraphXml -Text "This document contains the current core implementation files for the IBD vs IBS Marker Finder agent, including the top-level project instructions, orchestration skill, stage skills, and local report-generation helpers."))

    $blocks.Add((New-SectionTitleXml "Included Files"))
    foreach ($relativePath in $IncludedFiles) {
        $blocks.Add((New-BulletXml $relativePath))
    }

    $blocks.Add((New-SectionTitleXml "Code"))
    foreach ($relativePath in $IncludedFiles) {
        $fullPath = Join-Path $Workspace $relativePath
        $blocks.Add((New-FileTitleXml $relativePath))
        if (-not (Test-Path $fullPath)) {
            $blocks.Add((New-ParagraphXml -Text "File not found at export time." -FontName "Consolas" -FontSize 18 -ShadingFill "FDECEC"))
            continue
        }

        $lines = Get-Content $fullPath
        if ($lines.Count -eq 0) {
            $blocks.Add((New-CodeLineXml "0001: "))
            continue
        }

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $lineNumber = "{0:D4}" -f ($i + 1)
            $text = [string]$lines[$i]
            $text = $text -replace "`t", "    "
            $blocks.Add((New-CodeLineXml ("{0}: {1}" -f $lineNumber, $text)))
        }
        $blocks.Add((New-ParagraphXml ""))
    }

    $body = $blocks -join "`n"

    return @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $body
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1080" w:right="900" w:bottom="1080" w:left="900" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>
"@
}

function Get-StylesXml {
    return @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Calibri" w:cs="Calibri"/>
        <w:sz w:val="22"/>
        <w:szCs w:val="22"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault/>
  </w:docDefaults>
</w:styles>
"@
}

function Get-ContentTypesXml {
    return @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
"@
}

function Get-RootRelsXml {
    return @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
"@
}

function Get-DocumentRelsXml {
    return @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
"@
}

function Get-CoreXml {
    $now = [DateTime]::UtcNow.ToString("s") + "Z"
    return @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:dcmitype="http://purl.org/dc/dcmitype/"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>IBD vs IBS Marker Finder - Full Code</dc:title>
  <dc:creator>Codex</dc:creator>
  <cp:lastModifiedBy>Codex</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">$now</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$now</dcterms:modified>
</cp:coreProperties>
"@
}

function Get-AppXml {
    return @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
  xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Codex</Application>
</Properties>
"@
}

$parent = Split-Path -Parent $OutputPath
if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Force $parent | Out-Null
}

$tempRoot = Join-Path $env:TEMP ("marker-finder-code-doc-" + [Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Force (Join-Path $tempRoot "_rels") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $tempRoot "word") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $tempRoot "word\_rels") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $tempRoot "docProps") | Out-Null

[System.IO.File]::WriteAllText((Join-Path $tempRoot "[Content_Types].xml"), (Get-ContentTypesXml), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot "_rels\.rels"), (Get-RootRelsXml), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot "word\document.xml"), (Get-DocumentXml), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot "word\styles.xml"), (Get-StylesXml), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot "word\_rels\document.xml.rels"), (Get-DocumentRelsXml), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot "docProps\core.xml"), (Get-CoreXml), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot "docProps\app.xml"), (Get-AppXml), [System.Text.Encoding]::UTF8)

$zipPath = "$OutputPath.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}
if (Test-Path $OutputPath) {
    Remove-Item $OutputPath -Force
}

[System.IO.Compression.ZipFile]::CreateFromDirectory($tempRoot, $zipPath)
Move-Item -LiteralPath $zipPath -Destination $OutputPath -Force
Remove-Item $tempRoot -Recurse -Force
