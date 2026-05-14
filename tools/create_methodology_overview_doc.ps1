param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Escape-Xml {
    param([string]$Text)
    return [System.Security.SecurityElement]::Escape([string]$Text)
}

function New-RunXml {
    param(
        [string]$Text,
        [bool]$Bold = $false,
        [int]$FontSize = 22
    )
    $propParts = @(
        ("<w:sz w:val=`"{0}`"/><w:szCs w:val=`"{0}`"/>" -f $FontSize)
    )
    if ($Bold) {
        $propParts += "<w:b/>"
    }
    $runProps = "<w:rPr>$($propParts -join '')</w:rPr>"
    return "<w:r>$runProps<w:t xml:space=`"preserve`">$([string](Escape-Xml $Text))</w:t></w:r>"
}

function New-ParagraphXml {
    param(
        [string]$Text = "",
        [bool]$Bold = $false,
        [int]$FontSize = 22,
        [int]$SpaceBefore = 120,
        [int]$SpaceAfter = 120,
        [bool]$KeepNext = $false
    )
    $pprParts = @(
        ("<w:spacing w:before=`"{0}`" w:after=`"{1}`" w:line=`"276`" w:lineRule=`"auto`"/>" -f $SpaceBefore, $SpaceAfter)
    )
    if ($KeepNext) {
        $pprParts += "<w:keepNext/>"
    }
    $ppr = "<w:pPr>$($pprParts -join '')</w:pPr>"
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return "<w:p>$ppr</w:p>"
    }
    return "<w:p>$ppr$(New-RunXml -Text $Text -Bold $Bold -FontSize $FontSize)</w:p>"
}

function New-SectionTitle {
    param([string]$Text)
    return New-ParagraphXml -Text $Text -Bold $true -FontSize 28 -SpaceBefore 240 -SpaceAfter 80 -KeepNext $true
}

function New-SubsectionTitle {
    param([string]$Text)
    return New-ParagraphXml -Text $Text -Bold $true -FontSize 24 -SpaceBefore 180 -SpaceAfter 60 -KeepNext $true
}

function New-Bullet {
    param([string]$Text)
    return New-ParagraphXml -Text ("- {0}" -f $Text) -FontSize 22 -SpaceBefore 40 -SpaceAfter 40
}

function Get-DocumentXml {
    $blocks = New-Object 'System.Collections.Generic.List[string]'

    $blocks.Add((New-ParagraphXml -Text "IBD vs IBS Marker Finder - Methodology Overview" -Bold $true -FontSize 36 -SpaceBefore 120 -SpaceAfter 220 -KeepNext $true))

    $blocks.Add((New-SectionTitle "Introduction"))
    $blocks.Add((New-ParagraphXml -Text "The goal of the IBD vs IBS Marker Finder is to identify stool-associated biological signals that can distinguish inflammatory bowel disease from irritable bowel syndrome and connect those signals to bacterial detector routes. The workflow is organized into five skills. Each skill handles one layer of the pipeline, from biomarker discovery to promoter mapping, promoter sizing, and final detector ranking."))

    $blocks.Add((New-SectionTitle "Skill 1 - Marker Identification"))
    $blocks.Add((New-ParagraphXml -Text "Skill 1 is the discovery stage. It gathers stool biomarker evidence and builds the candidate marker set that is strong enough to move into downstream bacterial-sensing analysis."))
    $blocks.Add((New-SubsectionTitle "What input data is used"))
    $blocks.Add((New-Bullet "Human stool biomarker studies, with direct IBD vs IBS evidence preferred whenever available."))
    $blocks.Add((New-Bullet "Adjacent comparisons such as IBD vs healthy or IBS vs healthy when direct head-to-head studies are limited."))
    $blocks.Add((New-Bullet "Protein markers, metabolites, blood-related stool signals, mucosal-damage markers, immune markers, and dysbiosis-associated chemistry."))
    $blocks.Add((New-SubsectionTitle "How candidate biomarkers are identified"))
    $blocks.Add((New-Bullet "Markers are retained only if they are stool-detectable and show a clear disease-linked pattern."))
    $blocks.Add((New-Bullet "The search favors signals that are biologically interpretable and plausibly usable as bacterial detector inputs."))
    $blocks.Add((New-Bullet "Established controls such as calprotectin and lactoferrin are used as internal checks so the search remains anchored to known benchmark markers."))
    $blocks.Add((New-SubsectionTitle "How markers are included or excluded"))
    $blocks.Add((New-Bullet "Markers are favored when the literature shows a consistent increase or decrease linked to IBD, IBS, or a strong adjacent comparator."))
    $blocks.Add((New-Bullet "Markers are held back when the signal is weak, poorly replicated, not clearly measurable in stool, or too disconnected from later sensing design."))
    $blocks.Add((New-Bullet "The output is filtered into advance, hold, or drop decisions so only the strongest candidates move forward."))
    $blocks.Add((New-SubsectionTitle "Output of Skill 1"))
    $blocks.Add((New-ParagraphXml -Text "The output is a ranked stool-marker list with explicit disease patterns, evidence strength, and a clear handoff status for the next stage."))

    $blocks.Add((New-SectionTitle "Skill 2 - Promoter Mapping"))
    $blocks.Add((New-ParagraphXml -Text "Skill 2 translates each retained biomarker into direct bacterial sensing options. The goal is to identify promoters or regulatory systems that respond to the original molecule itself whenever such a route is biologically supported."))
    $blocks.Add((New-SubsectionTitle "How biomarkers are translated into sensing options"))
    $blocks.Add((New-Bullet "Each marker from Skill 1 is searched against bacterial regulatory literature and curated organism biology resources."))
    $blocks.Add((New-Bullet "The search asks whether bacteria have a promoter, operon, or regulator that changes expression in response to that molecule."))
    $blocks.Add((New-Bullet "The scan is done across relevant laboratory strains such as K12, PAO1, KT2440, and B. subtilis when the biology supports it."))
    $blocks.Add((New-SubsectionTitle "How promoters are selected"))
    $blocks.Add((New-Bullet "For direct sensing, only the single best promoter per species is retained."))
    $blocks.Add((New-Bullet "The best promoter is chosen by response strength, sensitivity, specificity, and evidence quality."))
    $blocks.Add((New-Bullet "Weaker same-species alternatives are dropped from the retained set so the output stays focused and buildable."))
    $blocks.Add((New-SubsectionTitle "How results are organized"))
    $blocks.Add((New-ParagraphXml -Text "The output is a structured direct-sensing map. Each retained marker is linked to the best-supported direct promoter option per species, with ranked alternatives kept only in the detailed backup mapping."))

    $blocks.Add((New-SectionTitle "Skill 3 - Indirect Response Mapping"))
    $blocks.Add((New-ParagraphXml -Text "Skill 3 handles molecules that are not sensed directly but create a secondary physiological state that bacteria can detect. This stage expands the pipeline from direct sensing to mechanistically supported proxy sensing."))
    $blocks.Add((New-SubsectionTitle "How indirect sensing is identified"))
    $blocks.Add((New-Bullet "Each retained host marker is checked for biologically supported downstream consequences such as zinc starvation, iron limitation, manganese starvation, oxidative stress, bile stress, or nitrosative stress."))
    $blocks.Add((New-Bullet "Only consequences that are defensible from literature or curated biology are kept."))
    $blocks.Add((New-Bullet "Broad unrelated stress responses are not accepted simply because they are easy to find."))
    $blocks.Add((New-SubsectionTitle "How promoters are selected"))
    $blocks.Add((New-Bullet "All distinct downstream consequences are kept when they are biologically meaningful."))
    $blocks.Add((New-Bullet "Within each consequence and species, only the single best promoter is retained."))
    $blocks.Add((New-Bullet "This keeps the indirect stage complete without allowing weaker same-branch duplicates to crowd the results."))
    $blocks.Add((New-SubsectionTitle "What defines a good indirect route"))
    $blocks.Add((New-ParagraphXml -Text "A good indirect route is one where the host marker, the downstream consequence, and the bacterial readout form a clear mechanistic chain rather than a vague inflammation-associated proxy."))

    $blocks.Add((New-SectionTitle "Skill 4 - Promoter Upstream Length Determination"))
    $blocks.Add((New-ParagraphXml -Text "Skill 4 determines how much upstream sequence should be taken for each retained promoter so the relevant regulatory behavior is preserved in a construct."))
    $blocks.Add((New-SubsectionTitle "How the upstream boundary is determined"))
    $blocks.Add((New-Bullet "Primary literature with promoter or transcription-start mapping is used first whenever available."))
    $blocks.Add((New-Bullet "If literature is insufficient, curated databases such as EcoCyc for E. coli and the Pseudomonas Genome Database for PAO1 are used next."))
    $blocks.Add((New-Bullet "Sequence-based promoter prediction is used only as a last fallback when stronger evidence is not available."))
    $blocks.Add((New-SubsectionTitle "What is checked before assigning a length"))
    $blocks.Add((New-Bullet "The target gene, locus tag, strain, and coding start are normalized first."))
    $blocks.Add((New-Bullet "Operon structure is checked so a downstream gene is not mistakenly assigned a promoter that actually sits upstream of another gene."))
    $blocks.Add((New-Bullet "Promoter start, transcription start site, and translation start codon are kept separate during the calculation."))
    $blocks.Add((New-SubsectionTitle "Output of Skill 4"))
    $blocks.Add((New-ParagraphXml -Text "The output is one promoter-sizing recommendation per retained route, together with a confidence label and the evidence basis used to justify that boundary."))

    $blocks.Add((New-SectionTitle "Skill 5 - Final Ranking and Selection"))
    $blocks.Add((New-ParagraphXml -Text "Skill 5 integrates the full pipeline and produces the final ranked detector panel. This is the decision stage: it asks which marker-promoter systems are strongest overall once evidence, biology, promoter behavior, and promoter-length practicality are considered together."))
    $blocks.Add((New-SubsectionTitle "How final candidates are ranked"))
    $blocks.Add((New-Bullet "First, human biomarker evidence strength is scored. This captures how strongly the original stool marker is supported for separating IBD and IBS or a strong adjacent comparator."))
    $blocks.Add((New-Bullet "Second, marker-to-signal biological linkage is scored. This asks how directly the bacterial readout reflects the host marker or a tight first-order consequence."))
    $blocks.Add((New-Bullet "Third, detector quality is scored. This includes specificity, stability, exposure window, promoter behavior, exact-strain evidence, and promoter-length practicality from Skill 4."))
    $blocks.Add((New-SubsectionTitle "How trade-offs are handled"))
    $blocks.Add((New-Bullet "Strong clinical markers remain important even when the sensing route is indirect, but unstable or weakly specific detector routes are penalized."))
    $blocks.Add((New-Bullet "Same-strain redundancy is reduced so two promoters that mainly report the same biology do not both occupy top ranks without a clear reason."))
    $blocks.Add((New-Bullet "Species identity alone is not treated as a ranking advantage or penalty; differences must come from evidence or biology."))
    $blocks.Add((New-SubsectionTitle "What the final panel provides"))
    $blocks.Add((New-ParagraphXml -Text "The final output is a ranked detector shortlist with a practical explanation of why each candidate sits where it does and what still weakens it."))

    $blocks.Add((New-SectionTitle "Summary"))
    $blocks.Add((New-ParagraphXml -Text "Together, the five skills form one connected pipeline: Skill 1 finds the right stool markers, Skill 2 maps direct sensing routes, Skill 3 adds mechanistically supported indirect routes, Skill 4 sizes the retained promoters, and Skill 5 ranks the final detector systems. This layered structure is robust because it combines human biomarker evidence, mechanistic bacterial biology, promoter design constraints, and practical detector reasoning in one workflow."))

    $body = $blocks -join "`n"

    return @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $body
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
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
  <dc:title>IBD vs IBS Marker Finder - Methodology Overview</dc:title>
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

$tempRoot = Join-Path $env:TEMP ("methodology-doc-" + [Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Force (Join-Path $tempRoot "_rels") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $tempRoot "word") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $tempRoot "word\\_rels") | Out-Null
New-Item -ItemType Directory -Force (Join-Path $tempRoot "docProps") | Out-Null

[System.IO.File]::WriteAllText((Join-Path $tempRoot "[Content_Types].xml"), (Get-ContentTypesXml), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot "_rels\\.rels"), (Get-RootRelsXml), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot "word\\document.xml"), (Get-DocumentXml), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot "word\\styles.xml"), (Get-StylesXml), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot "word\\_rels\\document.xml.rels"), (Get-DocumentRelsXml), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot "docProps\\core.xml"), (Get-CoreXml), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText((Join-Path $tempRoot "docProps\\app.xml"), (Get-AppXml), [System.Text.Encoding]::UTF8)

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
