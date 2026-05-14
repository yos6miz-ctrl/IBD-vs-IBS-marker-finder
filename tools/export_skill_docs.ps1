param(
    [Parameter(Mandatory = $true)]
    [string]$RunDir,
    [Parameter(Mandatory = $true)]
    [string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression.FileSystem

$Workspace = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$RunPath = (Resolve-Path $RunDir).Path
$RunItem = Get-Item $RunPath
$OutputRootPath = $OutputRoot
$MainFolderName = "IBD vs IBS marker finder"

function Get-RunDate {
    param([string]$RunName)
    if ($RunName -match '^(\d{4}-\d{2}-\d{2})') {
        return $Matches[1]
    }
    throw "Could not extract run date from $RunName"
}

function Get-OutputDir {
    param(
        [string]$Root,
        [string]$RunDate
    )
    $mainDir = Join-Path $Root $MainFolderName
    $dateDir = Join-Path $mainDir $RunDate
    New-Item -ItemType Directory -Force $mainDir | Out-Null
    New-Item -ItemType Directory -Force $dateDir | Out-Null
    return $dateDir
}

function Get-KnowledgeFolderContextText {
    param([string]$Root)
    $knowledgeDir = Join-Path $Root $MainFolderName
    if (-not (Test-Path $knowledgeDir)) {
        return "Folder context incorporated: no prior dated export folder was available yet, so the run relies on the current stage summaries and archived mapping tables."
    }
    $datedFolders = @(
        Get-ChildItem $knowledgeDir -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name |
            Select-Object -ExpandProperty Name
    )
    if ($datedFolders.Count -eq 0) {
        return "Folder context incorporated: the current stage summaries and archived mapping tables were used because no earlier dated export folders were available."
    }
    return ("Folder context incorporated: dated Skill 1, Skills 2/3, Skill 4, and Skill 5 outputs in `{0}` were treated as mandatory prior context together with the current run's stage summaries and archived mapping tables." -f ($datedFolders -join ", "))
}

function Get-PreviousExportDate {
    param([string]$CurrentRunDate)
    $knowledgeDir = Join-Path $OutputRootPath $MainFolderName
    if (-not (Test-Path $knowledgeDir)) {
        return ""
    }
    $datedFolders = @(
        Get-ChildItem $knowledgeDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' -and $_.Name -lt $CurrentRunDate } |
            Sort-Object Name
    )
    if ($datedFolders.Count -eq 0) {
        return ""
    }
    return $datedFolders[-1].Name
}

function Convert-ToComparisonBullet {
    param(
        [string]$Bullet,
        [string]$PreviousDate
    )
    $text = [string]$Bullet
    if ($text.StartsWith("- ")) {
        $text = $text.Substring(2)
    }
    $text = $text.Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return ""
    }
    if ([string]::IsNullOrWhiteSpace($PreviousDate) -or $text -match '^Compared with ') {
        return "- $text"
    }
    return ("- Compared with {0}, {1}" -f $PreviousDate, $text)
}

function Get-ComparisonFreeBulletText {
    param([string]$Bullet)
    $text = [string]$Bullet
    if ($text.StartsWith("- ")) {
        $text = $text.Substring(2)
    }
    $text = $text -replace '^Compared with \d{4}-\d{2}-\d{2},\s*', ''
    return $text.Trim()
}

function Get-CarryForwardConstraintText {
    return "Carried-forward constraints: preserve prior user corrections on explicit disease-state wording, compact one-row-per-molecule summaries, ranked within-cell alternatives, numbered references, K-12-preferred summaries when compatible, and previously documented engineering caveats or reinstatements."
}

function Read-Text {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path)
}

function Escape-Xml {
    param([string]$Text)
    return [System.Security.SecurityElement]::Escape([string]$Text)
}

function Get-CompletedSkills {
    param([string]$RunFolder)
    $runSummaryPath = Join-Path $RunFolder "run_summary.md"
    if (-not (Test-Path $runSummaryPath)) {
        return @{
            Skill1 = $true
            Skill23 = $false
            Skill4 = $false
            Skill5 = $false
        }
    }
    $text = Read-Text $runSummaryPath
    return @{
        Skill1 = $true
        Skill23 = ($text -match '\| 3\. Bacterial response / gene mapping \| Completed \|')
        Skill4 = (Test-Path (Join-Path $Workspace "skill_4_promoter_upstream_length/archive/$($RunItem.Name)")) -or (Test-Path (Join-Path $Workspace "skill_4_promoter_upstream_length/$((Get-RunDate $RunItem.Name))")) -or (Test-Path (Join-Path $RunFolder "stage4_upstream_length.md"))
        Skill5 = (Test-Path (Join-Path $Workspace "skill_5_detector_ranking/archive/$($RunItem.Name)")) -or (Test-Path (Join-Path $Workspace "skill_5_detector_ranking/$((Get-RunDate $RunItem.Name))")) -or (Test-Path (Join-Path $Workspace "skill_4_detector_ranking/archive/$($RunItem.Name)")) -or (Test-Path (Join-Path $Workspace "skill_4_detector_ranking/$((Get-RunDate $RunItem.Name))"))
    }
}

function Get-MarkdownTableRows {
    param(
        [string]$Text,
        [string]$Heading
    )
    $lines = $Text -split "`r?`n"
    $rows = @()
    $inSection = $false
    $inTable = $false
    foreach ($line in $lines) {
        if ($line.StartsWith("## ")) {
            if ($inSection -and $rows.Count -gt 0) {
                break
            }
            $inSection = ($line.Trim() -eq $Heading)
            $inTable = $false
            continue
        }
        if (-not $inSection) {
            continue
        }
        if ($line.Trim().StartsWith("|")) {
            $inTable = $true
            $cells = @($line.Trim().Trim("|").Split("|") | ForEach-Object { $_.Trim() })
            $isSeparator = $true
            foreach ($cell in $cells) {
                if ($cell -notmatch '^[-:]+$') {
                    $isSeparator = $false
                    break
                }
            }
            if (-not $isSeparator) {
                $rows += ,$cells
            }
            continue
        }
        if ($inTable -and $rows.Count -gt 0) {
            break
        }
    }
    if ($rows.Count -gt 0) {
        $first = $rows[0][0].ToLowerInvariant()
        if ($first -in @("rank", "molecule", "signal", "candidate from uploaded panel")) {
            if ($rows.Count -gt 1) {
                return $rows[1..($rows.Count - 1)]
            }
            return @()
        }
    }
    return $rows
}

function Get-MarkdownBulletLines {
    param(
        [string]$Text,
        [string]$Heading
    )
    $lines = $Text -split "`r?`n"
    $bullets = New-Object 'System.Collections.Generic.List[string]'
    $inSection = $false
    foreach ($line in $lines) {
        if ($line.StartsWith("## ")) {
            if ($inSection) {
                break
            }
            $inSection = ($line.Trim() -eq $Heading)
            continue
        }
        if (-not $inSection) {
            continue
        }
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith("- ")) {
            $bullets.Add($trimmed)
            continue
        }
        if ($trimmed -eq "") {
            continue
        }
        if ($bullets.Count -gt 0) {
            break
        }
    }
    return @($bullets)
}

function Get-Skill1NewRunBullets {
    param([string]$RunFolder)
    $previousDate = Get-PreviousExportDate -CurrentRunDate (Get-RunDate $RunItem.Name)
    $path = Join-Path $RunFolder "stage1_summary.md"
    if (-not (Test-Path $path)) {
        return @((Convert-ToComparisonBullet -Bullet "- the current Stage 1 screen did not expose a new molecule-level change worth documenting." -PreviousDate $previousDate))
    }

    $text = Read-Text $path
    $rows = @(Get-MarkdownTableRows -Text $text -Heading "## Specificity Recheck Outcomes")
    $priority = @(
        'Alanine',
        'Tyrosine',
        'Leucine',
        'Valine',
        'Hydrocinnamate / 3-phenylpropionate',
        'Threonine',
        'Cadaverine',
        'Putrescine',
        'Phenylalanine',
        'Tryptophan',
        'Lactate',
        'Nitrate / nitrite (NO metabolites)',
        'Butyrate',
        'BAFF',
        'MMP-9',
        'HBD2'
    )
    $bullets = New-Object 'System.Collections.Generic.List[string]'

    foreach ($molecule in $priority) {
        foreach ($row in $rows) {
            if ($row.Count -lt 4) {
                continue
            }
            if ([string]$row[0] -ne $molecule) {
                continue
            }
            $decision = [string]$row[2]
            $reason = Get-Skill1StageOnlyText -Text ([string]$row[3])
            if (-not [string]::IsNullOrWhiteSpace($reason) -and $reason.Length -gt 1) {
                $reason = $reason.Substring(0,1).ToLowerInvariant() + $reason.Substring(1)
            }
            if ($decision -match 'Advanced') {
                $bullets.Add(("- `{0}` was kept in the active handoff because {1}." -f $molecule, $reason))
            }
            elseif ($decision -match 'Broad pool only') {
                $bullets.Add(("- `{0}` was deliberately held out of the active handoff because {1}." -f $molecule, $reason))
            }
            else {
                $bullets.Add(("- `{0}` was rechecked in this run because {1}." -f $molecule, $reason))
            }
            break
        }
    }

    if ($bullets.Count -eq 0) {
        return @((Convert-ToComparisonBullet -Bullet "- the current Stage 1 screen did not expose a new molecule-level change worth documenting." -PreviousDate $previousDate))
    }
    return @($bullets | ForEach-Object { Convert-ToComparisonBullet -Bullet $_ -PreviousDate $previousDate })
}

function Get-Skill23NewRunBullets {
    param([string]$RunFolder)
    $previousDate = Get-PreviousExportDate -CurrentRunDate (Get-RunDate $RunItem.Name)
    $path = Join-Path $RunFolder "stage3_summary.md"
    if (-not (Test-Path $path)) {
        return @((Convert-ToComparisonBullet -Bullet "- the current Stage 3 screen did not expose a new branch-level change worth documenting." -PreviousDate $previousDate))
    }
    $text = Read-Text $path
    $bullets = @(Get-MarkdownBulletLines -Text $text -Heading "## What Changed In This Run")
    if ($bullets.Count -eq 0) {
        $bullets = @(Get-MarkdownBulletLines -Text $text -Heading "## What's New")
    }
    if ($bullets.Count -eq 0) {
        return @((Convert-ToComparisonBullet -Bullet "- the current Stage 3 screen did not expose a new branch-level change worth documenting." -PreviousDate $previousDate))
    }
    return @($bullets | ForEach-Object { Convert-ToComparisonBullet -Bullet $_ -PreviousDate $previousDate })
}

function Find-FirstFile {
    param(
        [string]$Dir,
        [string]$Pattern
    )
    if (-not (Test-Path $Dir)) {
        return $null
    }
    $file = Get-ChildItem $Dir -Filter $Pattern -File | Sort-Object Name | Select-Object -First 1
    if ($null -eq $file) {
        return $null
    }
    return $file.FullName
}

function Get-DiseaseDirectionMap {
    param([string]$RunFolder)
    $map = @{}
    $stage3Path = Join-Path $RunFolder "stage3_bacterial_response.md"
    if (Test-Path $stage3Path) {
        $text = Read-Text $stage3Path
        $rows = @(Get-MarkdownTableRows -Text $text -Heading "## Detector Candidate Ranking")
        foreach ($row in $rows) {
            if ($row.Count -ge 3 -and -not $map.ContainsKey($row[1])) {
                $map[$row[1]] = $row[2]
            }
        }
    }
    if ($map.Count -eq 0) {
        $stage1Path = Join-Path $RunFolder "stage1_candidates.md"
        if (Test-Path $stage1Path) {
            $text = Read-Text $stage1Path
            $rows = @(Get-MarkdownTableRows -Text $text -Heading "## Ranked Candidate Pool")
            foreach ($row in $rows) {
                if ($row.Count -ge 5 -and -not $map.ContainsKey($row[1])) {
                    $map[$row[1]] = $row[4]
                }
            }
        }
    }
    return $map
}

function Get-FunctionalRole {
    param(
        [string]$Signal,
        [string]$SignalClass = "",
        [string]$Notes = ""
    )
    switch -Regex ($Signal) {
        'Calprotectin|S100A12|Lactoferrin|Lipocalin-2|NGAL|BAFF|Neopterin|HMGB1|CHI3L1|Alpha-1 antitrypsin' { return "Inflammation marker" }
        'Myeloperoxidase|PMN-elastase|M2-PK|MMP-9|EDN|EPX|ECP|Lysozyme|Human beta-defensin-2' { return "Host defense marker" }
        'Hemoglobin|heme' { return "Barrier damage" }
        'Nitrate|Nitrite|NO metabolites|nitric oxide' { return "Nitrosative signal" }
        'Cadaverine|Spermidine|Spermine|Putrescine' { return "Polyamine signal" }
        'Hydrocinnamate|3-phenylpropionate' { return "Aromatic acid signal" }
        'Alanine|Tryptophan|Phenylalanine|Tyrosine|Threonine|Valine|Leucine' { return "Amino acid signal" }
        'Taurine' { return "Sulfur metabolism" }
        'Succinate|Butyrate|Valerate|Isobutyrate|Isovalerate|Acetate|Propionate|Lactate' { return "Fermentation metabolite" }
        'Cholic acid|Chenodeoxycholic|bile acid|bile' { return "Bile acid signal" }
        'Chromogranin|Secretogranin' { return "Neuroendocrine marker" }
        'CCL|CXCL' { return "Immune chemokine" }
        'Propan|cyclohexa|VOC' { return "Volatile metabolite" }
        default {
            switch -Regex ($SignalClass) {
                'Protein|Protein complex|Cytokine|Glycoprotein|Peptide' { return "Protein marker" }
                'Enzyme|Protease' { return "Enzyme marker" }
                'Host damage marker' { return "Barrier damage" }
                'Microbial metabolite|SCFA|Small molecule|Ratio pattern|Primary bile acid|Metabolite' { return "Chemical signal" }
                default { return "Stool signal" }
            }
        }
    }
}

function Format-DiseaseState {
    param([string]$RawState)
    if ([string]::IsNullOrWhiteSpace($RawState)) {
        return "See Stage 1 evidence"
    }
    if ($RawState -match 'IBD up|Higher in IBD|Elevated in IBD') {
        return "Up in IBD"
    }
    if ($RawState -match 'IBD trend') {
        return "Up in IBD vs healthy"
    }
    if ($RawState -match 'IBS-D up') {
        return "Up in IBS-D vs healthy"
    }
    if ($RawState -match 'IBS up|Higher in IBS|Elevated in IBS') {
        return "Up in IBS vs healthy"
    }
    if ($RawState -match 'IBS-associated depletion|Lower in IBS') {
        return "Lower in IBS vs comparator"
    }
    if ($RawState -match 'IBS-D pattern / IBD dysregulation') {
        return "Higher in IBS-D with parallel IBD dysregulation"
    }
    if ($RawState -match 'Pattern difference') {
        return "Pattern differs between IBD and IBS"
    }
    if ($RawState -match 'ratio') {
        return "Ratio differs between IBD and IBS"
    }
    if ($RawState -match 'dysregulation') {
        return "Dysregulated across IBD and IBS comparators"
    }
    return $RawState
}

function Get-PreciseDiseaseState {
    param([object[]]$CandidateRow)
    $higher = [string]$CandidateRow[4]
    $comparison = [string]$CandidateRow[6]

    if ($comparison -match 'IBD vs IBS' -and $higher -match 'IBD') {
        return "Up in IBD vs IBS"
    }
    if ($comparison -match 'IBD vs IBS' -and $higher -match '^IBS$') {
        return "Up in IBS vs IBD"
    }
    if ($comparison -match 'UC vs IBS' -and $higher -match 'IBD|UC') {
        return "Up in UC vs IBS"
    }
    if ($comparison -match 'UC vs IBS' -and $higher -match '^IBS$') {
        return "Up in IBS vs UC"
    }
    if ($comparison -match 'active UC vs healthy|UC vs healthy' -and $higher -match 'Active UC|UC') {
        return "Up in active UC vs healthy"
    }
    if ($comparison -match 'UC vs IBS' -and $higher -match 'depletion') {
        return "Lower in IBS vs UC"
    }
    if ($comparison -match 'IBS-D vs healthy' -and $higher -match 'IBS-D|IBS') {
        return "Up in IBS-D vs healthy"
    }
    if ($comparison -match 'IBS vs healthy' -and $higher -match '^IBS$') {
        return "Up in IBS vs healthy"
    }
    if ($comparison -match 'IBD vs healthy' -and $higher -match 'IBD') {
        return "Up in IBD vs healthy"
    }
    if ($comparison -match 'IBD vs non-IBD|pediatric controls|non-IBD pediatric controls' -and $higher -match 'IBD') {
        return "Up in IBD vs non-IBD"
    }
    if ($comparison -match 'IBS vs healthy' -and $higher -match 'depletion') {
        return "Lower in IBS vs healthy"
    }
    if ($higher -match 'Pattern difference') {
        return "Pattern differs between IBD and IBS"
    }
    if ($comparison -match 'Mixed multigroup evidence|multigroup evidence') {
        return "Pattern differs between IBD and IBS"
    }
    return ""
}

function Test-ClearSkill1Pattern {
    param([object[]]$CandidateRow)
    if ($CandidateRow.Count -lt 10) {
        return $false
    }
    $precise = Get-PreciseDiseaseState -CandidateRow $CandidateRow
    return (-not [string]::IsNullOrWhiteSpace($precise))
}

function Get-Skill1CandidateMap {
    param([string]$RunFolder)
    $map = @{}
    $candidatesPath = Join-Path $RunFolder "stage1_candidates.md"
    $text = Read-Text $candidatesPath
    $candidateRows = @(Get-MarkdownTableRows -Text $text -Heading "## Ranked Candidate Pool")
    foreach ($row in $candidateRows) {
        if ($row.Count -ge 10 -and -not $map.ContainsKey($row[1])) {
            $map[$row[1]] = $row
        }
    }
    return $map
}

function Get-Skill1SignalClassMap {
    param([string]$RunFolder)
    $candidateMap = Get-Skill1CandidateMap -RunFolder $RunFolder
    $classes = @{}
    foreach ($signal in $candidateMap.Keys) {
        $classes[$signal] = [string]$candidateMap[$signal][3]
    }
    return $classes
}

function Get-Skill1PassedStateMap {
    param([string]$RunFolder)
    $candidateMap = Get-Skill1CandidateMap -RunFolder $RunFolder
    $states = @{}
    $candidatesPath = Join-Path $RunFolder "stage1_candidates.md"
    $text = Read-Text $candidatesPath
    $shortlistRows = @(Get-MarkdownTableRows -Text $text -Heading "## Recommended Signals for Stage 2")
    foreach ($shortlistRow in $shortlistRows) {
        if ($shortlistRow.Count -lt 2) {
            continue
        }
        $signal = $shortlistRow[1]
        if (-not $candidateMap.ContainsKey($signal)) {
            continue
        }
        $candidateRow = $candidateMap[$signal]
        $state = Get-PreciseDiseaseState -CandidateRow $candidateRow
        if (-not [string]::IsNullOrWhiteSpace($state)) {
            $states[$signal] = $state
        }
    }
    return $states
}

function Get-Skill1Stage2StatusMap {
    param([string]$RunFolder)
    $status = @{}
    $candidateMap = Get-Skill1CandidateMap -RunFolder $RunFolder
    foreach ($signal in $candidateMap.Keys) {
        $status[$signal] = 'Hold'
    }
    $candidatesPath = Join-Path $RunFolder "stage1_candidates.md"
    if (-not (Test-Path $candidatesPath)) {
        return $status
    }
    $text = Read-Text $candidatesPath
    $shortlistRows = @(Get-MarkdownTableRows -Text $text -Heading "## Recommended Signals for Stage 2")
    foreach ($row in $shortlistRows) {
        if ($row.Count -ge 2) {
            $status[[string]$row[1]] = 'Advance'
        }
    }
    return $status
}

function Get-EvidenceStrengthLabel {
    param([string]$Raw)
    switch ([string]$Raw) {
        '3' { return 'Strong' }
        '2' { return 'Medium' }
        '1' { return 'Early' }
        default { return [string]$Raw }
    }
}

function Get-Skill1DiseasePattern {
    param([object[]]$CandidateRow)
    $precise = Get-PreciseDiseaseState -CandidateRow $CandidateRow
    if (-not [string]::IsNullOrWhiteSpace($precise)) {
        return $precise
    }
    $higher = [string]$CandidateRow[4]
    $comparison = [string]$CandidateRow[6]
    if ($higher -match 'IBS depletion') {
        return 'Lower in IBS vs comparator'
    }
    if ($higher -match 'Pattern difference') {
        return 'Mixed disease pattern'
    }
    if (-not [string]::IsNullOrWhiteSpace($higher) -and -not [string]::IsNullOrWhiteSpace($comparison)) {
        return ("{0} in {1}" -f $higher, $comparison)
    }
    return 'Needs comparator context'
}

function Get-Skill1ExportNote {
    param([string]$Notes)
    return (Get-Skill1StageOnlyText -Text $Notes)
}

function Get-Skill1StageOnlyText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }
    $clean = [string]$Text
    $clean = $clean -replace ',\s*promoted for explicit promoter-coverage checking', ''
    $clean = $clean -replace '\s+(with|and)\s+[^.]*?(promoter|promoters|sensing|sensor|logic|follow-up|coverage)[^.]*', ''
    $clean = $clean -replace '\s+because\s+[^.]*?(promoter|promoters|sensing|sensor|logic|coverage)[^.]*', ''
    $clean = $clean.Trim().TrimEnd('. ')
    return $clean
}

function Get-Skill4SeparationTag {
    param([string]$State)
    if ($State -match 'vs IBS|vs UC|vs IBD') {
        return 'High'
    }
    if ($State -match 'vs healthy') {
        return 'Medium'
    }
    return 'Low'
}

function Get-Skill4StabilityTag {
    param([string]$Stability)
    switch -Regex ([string]$Stability) {
        'Stable|High' { return 'High' }
        'Moderate' { return 'Medium' }
        default { return 'Low' }
    }
}

function Get-Skill4SpecificityTag {
    param(
        [string]$MechanismType,
        [string]$Notes,
        [string]$SenseLabel
    )
    $text = "{0} {1} {2}" -f [string]$MechanismType, [string]$Notes, [string]$SenseLabel
    if ($text -match 'most specific|clean|direct sensor|direct sensing') {
        return 'High'
    }
    if ($text -match 'proxy|not unique|cross-reactive|backup|stress') {
        return 'Low'
    }
    return 'Medium'
}

function Get-Skill4MainReason {
    param(
        [pscustomobject]$Row,
        [string]$State,
        [string]$Specificity
    )
    if ($Specificity -eq 'High' -and $State -match 'vs IBS|vs UC') {
        return 'Strong disease split with a clean retained promoter.'
    }
    if ([string]$Row.'Mechanism Type' -eq 'Direct sensing') {
        return 'Direct sensing with a source-backed retained promoter.'
    }
    if ([string]$Row.'Mechanism Type' -eq 'Mechanism unresolved') {
        return 'Molecule-responsive promoter retained, but the exact sensed ligand remains unresolved.'
    }
    return 'Good biomarker support with a workable proxy promoter.'
}

function Get-Skill4MainLimitation {
    param(
        [pscustomobject]$Row,
        [string]$State,
        [string]$Specificity
    )
    $notes = [string]$Row.Notes
    if ($notes -match 'cross-reactive|not unique') {
        return 'Specificity is limited by related competing signals.'
    }
    if ($State -match 'vs healthy' -and $State -notmatch 'vs IBS|vs UC') {
        return 'Human separation is stronger vs healthy than vs IBS.'
    }
    if ($Specificity -eq 'Low') {
        return 'The retained route is still a proxy rather than a direct readout.'
    }
    return 'The evidence package is slightly weaker than the top tier.'
}

function Normalize-BacterialSpecies {
    param(
        [string]$Species,
        [string]$Gene = "",
        [string]$Promoter = ""
    )
    if ($Species -eq 'Escherichia coli') {
        return 'Escherichia coli K-12'
    }
    return $Species
}

function Get-ShortOrganismName {
    param([string]$Species)
    if ([string]::IsNullOrWhiteSpace($Species)) {
        return "-"
    }
    $label = $Species
    $label = $label -replace 'Escherichia coli K-12', 'K12'
    $label = $label -replace 'Escherichia coli', 'K12'
    $label = $label -replace 'Pseudomonas aeruginosa PAO1', 'PAO1'
    $label = $label -replace 'Pseudomonas putida KT2440', 'KT2440'
    $label = $label -replace 'Bacillus subtilis', 'B. subtilis'
    return $label
}

function Get-CompactSenseLabel {
    param([string]$Trigger)
    if ([string]::IsNullOrWhiteSpace($Trigger)) {
        return "-"
    }
    switch -Regex ($Trigger) {
        'nitrate' { return 'nitrate' }
        'nitrite' { return 'nitrite' }
        'nitric oxide|nitrosative' { return 'nitric oxide' }
        'lactate' { return 'lactate isomers' }
        'zinc starvation|calprotectin-associated response' { return 'zinc starvation' }
        'iron starvation|enterobactin sequestration' { return 'iron starvation' }
        'reactive chlorine|HOCl' { return 'HOCl stress' }
        'lysozyme' { return 'lysozyme' }
        'heme' { return 'heme' }
        'phenylalanine and tyrosine|tyrosine and phenylalanine' { return 'aromatic amino acids' }
        'alanine' { return 'alanine' }
        'phenylalanine' { return 'phenylalanine' }
        'tyrosine' { return 'tyrosine' }
        'tryptophan' { return 'tryptophan' }
        'leucine' { return 'leucine' }
        'valine|branched-chain' { return 'branched-chain amino acids' }
        'putrescine' { return 'putrescine' }
        'hydrocinnamate|3-phenylpropionate' { return 'hydrocinnamate' }
        'taurine' { return 'taurine' }
        'cadaverine' { return 'cadaverine' }
        'succinate|C4-dicarboxylate|C4 dicarboxylate' { return 'C4 dicarboxylates' }
        'butyrate' { return 'butyrate' }
        'bile' { return 'bile stress' }
        'cationic-peptide|envelope stress' { return 'envelope stress' }
        default { return $Trigger }
    }
}

function Get-ReferenceStrengthScore {
    param([string]$ReferenceText)
    return @(Get-ReferenceTokens -ReferenceText $ReferenceText).Count
}

function Get-SharedMoleculeParts {
    param([string]$MoleculeText)
    if ([string]::IsNullOrWhiteSpace($MoleculeText)) {
        return @("")
    }
    $parts = @([regex]::Split([string]$MoleculeText, '\s+and\s+') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($parts.Count -eq 0) {
        return @([string]$MoleculeText)
    }
    return $parts
}

function Get-Skill4CsvPath {
    param([string]$RunFolder)
    $archiveDir = Join-Path $Workspace "skill_4_promoter_upstream_length/archive/$($RunItem.Name)"
    $csvPath = Find-FirstFile -Dir $archiveDir -Pattern "*_promoter_upstream_lengths.csv"
    if ($null -eq $csvPath) {
        $datedDir = Join-Path $Workspace "skill_4_promoter_upstream_length/$((Get-RunDate $RunItem.Name))"
        $csvPath = Find-FirstFile -Dir $datedDir -Pattern "*_promoter_upstream_lengths.csv"
    }
    return $csvPath
}

function Get-Skill4ReportPath {
    param([string]$RunFolder)
    $runStagePath = Join-Path $RunFolder "stage4_upstream_length.md"
    if (Test-Path $runStagePath) {
        return $runStagePath
    }
    $archiveDir = Join-Path $Workspace "skill_4_promoter_upstream_length/archive/$($RunItem.Name)"
    $reportPath = Find-FirstFile -Dir $archiveDir -Pattern "*_promoter_upstream_lengths.md"
    if ($null -eq $reportPath) {
        $datedDir = Join-Path $Workspace "skill_4_promoter_upstream_length/$((Get-RunDate $RunItem.Name))"
        $reportPath = Find-FirstFile -Dir $datedDir -Pattern "*_promoter_upstream_lengths.md"
    }
    return $reportPath
}

function Get-Skill4StructuredEntries {
    param([string]$RunFolder)
    $reportPath = Get-Skill4ReportPath -RunFolder $RunFolder
    if ($null -eq $reportPath -or -not (Test-Path $reportPath)) {
        return @()
    }

    $lines = Get-Content $reportPath
    $entries = New-Object 'System.Collections.Generic.List[hashtable]'
    $current = $null

    foreach ($line in $lines) {
        if ($line -match '^###\s+(.+)$') {
            if ($null -ne $current) {
                $entries.Add($current)
            }
            $current = [ordered]@{
                Title = $Matches[1].Trim()
                Fields = New-Object 'System.Collections.Generic.List[object[]]'
            }
            continue
        }
        if ($null -eq $current) {
            continue
        }
        if ($line -match '^- ([^:]+):(.*)$') {
            $label = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            $current.Fields.Add(@($label, $value))
        }
    }

    if ($null -ne $current) {
        $entries.Add($current)
    }

    return @($entries)
}

function Get-Skill4LengthBasis {
    param(
        [string]$PromoterName,
        [string]$ConfidenceLevel
    )
    switch ([string]$PromoterName) {
        'PtnaA' { return "Retained Stage 4 method note: long upstream leader-region architecture from the tna system was preserved." }
        'PtdcABC' { return "Retained Stage 4 method note: broader upstream regulatory architecture justified a longer capture region." }
        'Pbkd' { return "Retained Stage 4 method note: sigma-54-style promoter plus upstream activating sequences justified a longer capture region." }
        'PilvIH' { return "Retained Stage 4 method note: multiple Lrp binding sites span roughly 250 bp upstream, so a longer capture region was preserved." }
        'PznuA' { return "Retained Stage 4 method note: compact metal-stress promoter with promoter-proximal regulatory logic." }
        'PrpmJ2' { return "Retained Stage 4 method note: compact zinc-starvation promoter with promoter-proximal regulatory logic." }
        'PfepA' { return "Retained Stage 4 method note: compact iron-stress promoter with promoter-proximal regulatory logic." }
        'PhasR' { return "Literature-backed heme-route anchor: the retained detector now uses the Fur-regulated hasR promoter for the hasR-hasAp operon, based on experimental hasR TSS mapping and promoter-reporter evidence rather than the weaker internal hasAp branch (PMID 10658665; PMID 30593511; Pseudomonas Genome Database motifs)." }
        'PsigV' { return "Retained Stage 4 method note: compact stress-response promoter with promoter-proximal control." }
        default {
            switch ([string]$ConfidenceLevel) {
                'High' { return "Article-backed or experimentally used promoter-region logic from the retained Stage 4 evidence set." }
                'Medium' { return "Curated-database-guided or architecture-guided estimate from the retained Stage 4 evidence set." }
                'Low' { return "Weak boundary evidence in the retained Stage 4 set; approximate architecture-based estimate." }
                default { return "Retained Stage 4 method: literature first, database second, architecture inference when exact boundaries were not explicit." }
            }
        }
    }
}

function Get-Skill5CsvPath {
    param([string]$RunFolder)
    $archiveDir = Join-Path $Workspace "skill_5_detector_ranking/archive/$($RunItem.Name)"
    $csvPath = Find-FirstFile -Dir $archiveDir -Pattern "*_detector_candidates_ranked.csv"
    if ($null -eq $csvPath) {
        $datedDir = Join-Path $Workspace "skill_5_detector_ranking/$((Get-RunDate $RunItem.Name))"
        $csvPath = Find-FirstFile -Dir $datedDir -Pattern "*_detector_candidates_ranked.csv"
    }
    if ($null -eq $csvPath) {
        $archiveDir = Join-Path $Workspace "skill_4_detector_ranking/archive/$($RunItem.Name)"
        $csvPath = Find-FirstFile -Dir $archiveDir -Pattern "*_detector_candidates_ranked.csv"
    }
    if ($null -eq $csvPath) {
        $datedDir = Join-Path $Workspace "skill_4_detector_ranking/$((Get-RunDate $RunItem.Name))"
        $csvPath = Find-FirstFile -Dir $datedDir -Pattern "*_detector_candidates_ranked.csv"
    }
    return $csvPath
}

function Get-Skill5OptionRankMap {
    param([string]$RunFolder)
    $rankMap = @{}
    $csvPath = Get-Skill5CsvPath -RunFolder $RunFolder
    if ($null -eq $csvPath) {
        return $rankMap
    }
    $rows = @(Import-Csv -Path $csvPath | Sort-Object { [int]$_.Rank })
    foreach ($row in $rows) {
        $species = Normalize-BacterialSpecies -Species $row.'Bacterial Species' -Gene $row.'Gene / Operon' -Promoter $row.Promoter
        foreach ($moleculePart in @(Get-SharedMoleculeParts -MoleculeText ([string]$row.Molecule))) {
            $key = "{0}|{1}|{2}|{3}" -f $moleculePart, $species, $row.'Gene / Operon', $row.Promoter
            if (-not $rankMap.ContainsKey($key)) {
                $rankMap[$key] = [int]$row.Rank
            }
        }
    }
    return $rankMap
}

function Get-DirectResponseTrigger {
    param(
        [string]$Molecule,
        [string]$Promoter = "",
        [string]$Gene = ""
    )
    switch -Regex ($Molecule) {
        'Calprotectin' { return 'zinc starvation proxy' }
        'Lysozyme' { return 'lysozyme-mediated envelope stress' }
        'Hemoglobin|heme' { return 'heme availability' }
        'Taurine' { return 'taurine availability and sulfur-source use' }
        'Phenylalanine.*Tyrosine|Tyrosine.*Phenylalanine' { return 'phenylalanine and tyrosine' }
        'Alanine' { return 'alanine with leucine cross-response' }
        'Phenylalanine' { return 'phenylalanine' }
        'Tyrosine' { return 'tyrosine' }
        'Tryptophan' { return 'tryptophan' }
        'Threonine' { return 'threonine and serine with anaerobic context' }
        'Leucine' { return 'leucine' }
        'Valine' { return 'valine with branched-chain cross-response' }
        'Hydrocinnamate|3-phenylpropionate' { return 'hydrocinnamate / 3-phenylpropionate' }
        'Putrescine' { return 'putrescine' }
        'Cadaverine' { return 'cadaverine with acid-stress context' }
        'Succinate' { return 'succinate and related C4-dicarboxylate availability' }
        'Lactate' { return 'lactate isomers' }
        'Butyrate' { return 'butyrate-linked carbon source availability' }
        'Nitrate|Nitrite|NO metabolites' {
            if ($Promoter -match 'Pnar' -or $Gene -match '^nar') { return 'nitrate' }
            if ($Promoter -match 'Pnir|Pnrf' -or $Gene -match '^nir|^nrf') { return 'nitrite' }
            return 'nitrate'
        }
        default { return "direct response to $Molecule" }
    }
}

function Get-Skill1ReferenceMap {
    return @{
        'Calprotectin' = 'PMID 24788223'
        'S100A12' = 'PMID 17675327'
        'Lactoferrin' = 'PMID 25002150'
        'BAFF' = 'PMID 27056038'
        'Lipocalin-2 / NGAL' = 'PMID 38920307'
        'Myeloperoxidase' = 'PMID 38920307'
        'Lysozyme' = 'PMID 15819166'
        'Hemoglobin / heme' = 'PMID 28572616'
        'MMP-9' = 'PMID 39031736; PMID 28723856'
        'Taurine' = 'PMID 21761941'
        'Hydrocinnamate / 3-phenylpropionate' = 'PMID 39997746; PMID 36624530'
        'Leucine' = 'PMID 40503566; PMID 34757415'
        'Valine' = 'PMID 34757415; PMID 32404754'
        'Threonine' = 'PMID 34200772'
        'Cadaverine' = 'PMID 21761941'
        'Succinate' = 'PMID 40082467'
        'Lactate' = 'PMID 25598765; PMID 3181680'
        'Alanine' = 'PMID 31798278; PMID 34757415'
        'Putrescine' = 'PMID 34200772; PMID 38987012'
        'Phenylalanine' = 'PMID 32125749'
        'Tyrosine' = 'PMID 31798278; PMID 25598765'
        'Tryptophan' = 'PMID 32125749'
        'Primary:secondary bile acid ratio' = 'PMID 22356587; PMID 37980492'
        'Butyrate' = 'PMID 38946176; PMID 21761941'
        'Nitrate / nitrite (NO metabolites)' = 'PMID 9443117; PMID 17852876'
    }
}

function Get-Skill1FallbackSource {
    param(
        [string]$Signal,
        [string]$SignalClass = "",
        [string]$Notes = ""
    )
    switch -Regex ($Signal) {
        'Calprotectin|S100A12|Lactoferrin|Lipocalin-2|NGAL|BAFF|Myeloperoxidase|Lysozyme|MMP-9' { return 'common inflammatory marker' }
        'Hemoglobin|heme' { return 'textbook immunology' }
        'Taurine|Cadaverine|Succinate|Butyrate|Hydrocinnamate|3-phenylpropionate|Valine|Leucine|Tyrosine|Alanine' { return 'bacterial metabolism knowledge' }
        'bile acid|ratio' { return 'inferred from pathway biology' }
        default {
            switch -Regex ($SignalClass) {
                'Protein|Protein complex|Cytokine|Glycoprotein|Peptide|Enzyme|Protease' { return 'common inflammatory marker' }
                'Host damage marker' { return 'textbook immunology' }
                'Microbial metabolite|SCFA|Small molecule|Ratio pattern|Primary bile acid|Metabolite' { return 'bacterial metabolism knowledge' }
                default { return 'well-known pathway' }
            }
        }
    }
}

function Get-ReferenceCatalog {
    return @{
        'PMID 24788223' = 'Faecal calprotectin as a novel biomarker for differentiating between inflammatory bowel disease and irritable bowel syndrome.'
        'PMID 17675327' = 'Faecal S100A12 in distinguishing inflammatory bowel disease from irritable bowel syndrome.'
        'PMID 25002150' = 'Fecal lactoferrin in discriminating inflammatory bowel disease from irritable bowel syndrome: a diagnostic meta-analysis.'
        'PMID 27640344' = 'Fecal neutrophil gelatinase-associated lipocalin as a biomarker for inflammatory bowel disease.'
        'PMID 38920307' = 'Fecal and Serum Granulocyte Protein Levels in Inflammatory Bowel Disease and Irritable Bowel Syndrome and Their Relation to Disease Activity.'
        'PMID 15819166' = 'Fecal leukocyte proteins in inflammatory bowel disease and irritable bowel syndrome.'
        'PMID 28572616' = 'Comparison of non-invasive biomarkers faecal BAFF, calprotectin and FOBT in discriminating IBS from IBD and evaluation of intestinal inflammation.'
        'PMID 21761941' = 'Distinct profile of human fecal microbiota and metabolome in patients with ulcerative colitis and irritable bowel syndrome.'
        'PMID 36624530' = 'Multiomics analysis reveals metabolomic and microbiome shifts associated with irritable bowel syndrome, including reduced hydrocinnamate.'
        'PMID 36958817' = 'Fecal metabolomic signatures of inflammatory bowel disease dysbiosis identify reduced 3-phenylpropionate in a dysbiotic IBD subset.'
        'PMID 32404754' = 'Fecal amino acid profiles exceed accuracy of serum amino acids in diagnosing pediatric inflammatory bowel disease, including elevated fecal valine.'
        'PMID 34757415' = 'Fecal amino acid analysis in newly diagnosed pediatric inflammatory bowel disease identified alanine, histidine, leucine, tryptophan, taurine, and valine among the most differentiating stool amino acids.'
        'PMID 40503566' = 'Validated fecal microbiota and amino acid model for pediatric inflammatory bowel disease identified leucine as the strongest single amino-acid discriminator against non-IBD controls.'
        'PMID 25598765' = 'Metabonomics of human fecal extracts characterize ulcerative colitis, Crohn''s disease and healthy individuals.'
        'PMID 31798278' = 'Targeted fecal metabolomics in IBS-D identified reduced tyrosine, histidine, and alanine linked to symptom severity.'
        'PMID 8955407' = 'Lrp is a direct repressor of the dad operon in Escherichia coli, and dad expression increases in the presence of alanine or leucine.'
        'PMID 10216857' = 'Alanine or leucine antagonizes Lrp repression and activates the dadAX promoter region of Escherichia coli through multiple Lrp-binding sites.'
        'PMID 19666712' = 'The Pseudomonas aeruginosa dad operon is inducible by L-alanine, D-alanine, and L-valine and is controlled by Lrp.'
        'PMID 3181680' = 'Fecal lactate and ulcerative colitis.'
        'PMID 32125749' = 'The fecal metabolome as a noninvasive biomarker of gut diseases.'
        'PMID 34200772' = 'A distinct faecal microbiota and metabolite profile linked to bowel habits in patients with irritable bowel syndrome.'
        'PMID 2115866' = 'A novel membrane-associated threonine permease encoded by the tdcC gene of Escherichia coli.'
        'PMID 6348023' = 'Synthesis of biodegradative threonine dehydratase in Escherichia coli: role of amino acids, electron acceptors, and certain intermediary metabolites.'
        'PMID 7928991' = 'Functional analysis of the tdcABC promoter of Escherichia coli: roles of TdcA and TdcR.'
        'PMID 8413189' = 'TdcA, a transcriptional activator of the tdcABC operon of Escherichia coli, is a member of the LysR family of proteins.'
        'PMID 38987012' = 'Transcriptomic and metabolomic correlates of increased colonic permeability in postinfection irritable bowel syndrome.'
        'PMID 39997746' = 'Large-cohort stool multiomics analysis links reduced 3-phenylpropionate to irritable bowel syndrome.'
        'PMID 9443117' = 'Faecal nitrite and nitrate in paediatric inflammatory bowel disease: relation to disease activity.'
        'PMID 17852876' = 'Fecal nitrate levels are increased in individuals with active inflammatory bowel disease.'
        'PMID 40082467' = 'Potential inflammatory bowel disease biomarkers identified in pediatric and adult fecal metagenomic and metabolomic profiles.'
        'PMID 37523538' = 'Engineered calprotectin-sensing probiotics for IBD surveillance in humans.'
        'PMID 21856855' = 'The Bacillus subtilis extracytoplasmic function sigma factor sigma(V) is induced by lysozyme and provides resistance to lysozyme.'
        'PMID 30593511' = 'Post-transcriptional regulation of the Pseudomonas aeruginosa heme assimilation system (Has) fine-tunes extracellular heme sensing.'
        'PMID 32522817' = 'Contributions of the heme coordinating ligands of the Pseudomonas aeruginosa outer membrane receptor HasR to extracellular heme sensing and transport.'
        'PMID 8808933' = 'Identification of sulfate starvation-regulated genes in Escherichia coli: a gene cluster involved in the utilization of taurine as a sulfur source.'
        'PMID 9401024' = 'Involvement of CysB and Cbl regulatory proteins in expression of the tauABCD operon and other sulfate starvation-inducible genes in Escherichia coli.'
        'PMID 16491024' = 'CadC-mediated activation of the cadBA promoter in Escherichia coli.'
        'PMID 22999955' = 'Deactivation of the E. coli pH stress sensor CadC by cadaverine.'
        'PMID 18263722' = 'Dual role of LldR in regulation of the lldPRD operon, involved in L-lactate metabolism in Escherichia coli.'
        'PMID 37219924' = 'Expanded roles of lactate-sensing LldR in transcription regulation of the Escherichia coli K-12 genome: lactate utilisation and acid resistance.'
        'PMID 18495664' = 'gamma-Glutamylputrescine synthetase in the putrescine utilization pathway of Escherichia coli K-12.'
        'PMID 22522900' = 'Mechanism for regulation of the putrescine utilization pathway by the transcription factor PuuR in Escherichia coli K-12.'
        'PMID 3525516' = 'Activation of the tyrP promoter by TyrR in Escherichia coli.'
        'PMID 15049824' = 'Molecular studies of TyrR-mediated activation of the tyrP promoter of Escherichia coli K-12.'
        'PMID 1447135' = 'In vitro transcription from the Escherichia coli ilvIH promoter established direct Lrp-dependent activation and leucine-mediated reversal.'
        'PMID 8071194' = 'In vivo footprinting of the Escherichia coli ilvIH promoter showed Lrp-leucine complex formation and leucine-dependent loss of promoter occupancy.'
        'PMID 10094682' = 'Role of BkdR, a transcriptional activator of the SigL-dependent isoleucine and valine degradation pathway in Bacillus subtilis.'
        'PMID 19763274' = 'Time-resolved transcriptome analysis of Bacillus subtilis responding to valine, glutamate, and glutamine.'
        'PMID 9603882' = 'Genetic organization and regulation of the Escherichia coli hca catabolic region for hydroxycinnamate and phenylpropionate metabolism.'
        'PMID 11200225' = 'Characterization of HcaR-dependent regulation of the hca operon in Escherichia coli.'
        'PMID 15808934' = 'Functional analysis of phenylpropionate and hydroxycinnamate catabolic genes in Escherichia coli K-12.'
        'PMID 17217960' = 'L-phenylalanine and L-tyrosine as effectors for PhhR-mediated activation of phhAB in Pseudomonas putida.'
        'PMID 20050871' = 'Identification and characterization of the PhhR regulon in Pseudomonas putida.'
        'PMID 1917834' = 'Physiological studies of tryptophan transport and tryptophanase operon induction in Escherichia coli.'
        'PMID 8501042' = 'Tryptophan induction of the tryptophanase operon is regulated by the tnaC peptide in Escherichia coli.'
        'PMID 24505391' = 'The Bacillus subtilis TRAP protein can induce transcription termination in the leader region of the tryptophan biosynthetic (trp) operon independent of the trp attenuator RNA.'
        'PMID 9765574' = 'C4-dicarboxylate-sensing DcuS-DcuR system of Escherichia coli.'
        'PMID 18957436' = 'The C4-dicarboxylate DcuS-DcuR two-component system in Escherichia coli.'
        'PMID 38432210' = 'Regulation of Aerobic Succinate Transporter dctA of E. coli by cAMP-CRP, DcuS-DcuR, and EIIAGlc: Succinate as a Carbon Substrate and Signaling Molecule.'
        'PMID 21725012' = 'Identification of C(4)-dicarboxylate transport systems in Pseudomonas aeruginosa PAO1.'
        'PMID 23253107' = 'Catabolite repression in Pseudomonas aeruginosa PAO1 regulates the uptake of C4-dicarboxylates depending on succinate concentration.'
        'PMID 22423963' = 'Zinc sequestration by the neutrophil protein calprotectin enhances Salmonella growth in the inflamed gut.'
        'PMID 35883222' = 'Zinc-binding metallophores protect Pseudomonas aeruginosa from calprotectin-mediated metal starvation.'
        'PMID 9680209' = 'The ZnuABC high-affinity zinc uptake system and its regulator Zur in Escherichia coli.'
        'PMID 26913170' = 'Exploring Metal-Binding and Biofilm-Inhibitory Properties of Human Calprotectin in Pseudomonas aeruginosa and Escherichia coli.'
        'PMID 29969091' = 'Intergenic evolution during host adaptation increases expression of the metallophore pseudopaline in Pseudomonas aeruginosa.'
        'PMID 28898501' = 'Growth of Pseudomonas aeruginosa in zinc poor environments is promoted by a nicotianamine-related metallophore.'
        'PMID 9245831' = 'Iron acquisition from transferrin and lactoferrin by Pseudomonas aeruginosa pyoverdin.'
        'PMID 8636031' = 'Iron-regulated transcription of the pvdA gene in Pseudomonas aeruginosa: effect of Fur and PvdS on promoter activity.'
        'PMID 9621228' = 'Inhibition of in vitro growth of coliform bacteria by a monoclonal antibody directed against ferric enterobactin receptor FepA.'
        'PMID 8021177' = 'Promoter and operator determinants for fur-mediated iron regulation in the bidirectional fepA-fes control region of the Escherichia coli enterobactin gene system.'
        'PMID 25964185' = 'Interplay between enterobactin, myeloperoxidase and lipocalin 2 regulates E. coli survival in the inflamed gut.'
        'PMID 17060628' = 'The pathogen-associated iroA gene cluster mediates bacterial evasion of lipocalin 2.'
        'PMID 33351093' = 'Induction of the reactive chlorine-responsive transcription factor RclR in Escherichia coli following ingestion by neutrophils.'
        'PMID 10398829' = 'Bile salt activation of stress response promoters in Escherichia coli.'
        'PMID 10464201' = 'NarXL and NarQP signal transduction circuits sense both nitrate and nitrite, but only nitrate is a true substrate for NarX and NarQ.'
        'PMID 8437517' = 'A family of anaerobically induced operons of Escherichia coli that responds to nitrate and nitrite.'
        'PMID 11004182' = 'Expression of nrfA and nirB is regulated in response to the availability of alternative electron acceptors in Escherichia coli K-12.'
        'PMID 12142437' = 'Nitric oxide activates the nitric oxide reductase operon in Escherichia coli.'
        'PMID 15375149' = 'Regulation of the norVW nitric oxide reductase genes in Escherichia coli K-12: involvement of NorR and sigma54.'
        'PMID 16183308' = 'Dietary nitrate plus vitamin C increases gastric and faecal nitric oxide in humans.'
        'PMID 16391109' = 'Involvement of NarK1 and NarK2 proteins in transport of nitrate and nitrite in the denitrifying bacterium Pseudomonas aeruginosa PAO1.'
        'PMID 18832311' = 'Nitrate-responsive NarX-NarL represses arginine-mediated induction of the Pseudomonas aeruginosa arginine fermentation arcDABC operon.'
        'PMID 19477902' = 'The transcription factor DNR from Pseudomonas aeruginosa specifically requires nitric oxide and haem for the activation of a target promoter in Escherichia coli.'
        'PMID 15937158' = 'Transcriptional regulation of the flavohemoglobin gene for aerobic nitric oxide detoxification by the second nitric oxide-responsive regulator of Pseudomonas aeruginosa.'
        'PMID 26459101' = 'The OpdQ porin of Pseudomonas aeruginosa is regulated by environmental signals associated with cystic fibrosis including nitrate-induced regulation involving the NarXL two-component system.'
        'PMID 32457749' = 'The Antimicrobial Peptide Human Beta-Defensin 2 Inhibits Biofilm Production of Pseudomonas aeruginosa Without Compromising Metabolic Activity.'
        'PMID 23006746' = 'The two-component system CprRS senses cationic peptides and triggers adaptive resistance in Pseudomonas aeruginosa independently of ParRS.'
        'PMID 19202100' = 'Regulation of virulence by butyrate sensing in enterohaemorrhagic Escherichia coli.'
        'PMID 25069663' = 'Physiological activity of E. coli engineered to produce butyric acid.'
        'PMID 32443851' = 'Production and Sensing of Butyrate in a Probiotic E. coli Strain.'
        'PMID 30622135' = 'The human innate immune protein calprotectin induces iron starvation responses in Pseudomonas aeruginosa.'
        'PMID 33927050' = 'A calprotectin-induced zinc-starvation reporter reveals zinc availability in cystic fibrosis sputum.'
        'PMID 40135923' = 'Calprotectin elicits aberrant iron starvation responses in Pseudomonas aeruginosa under anaerobic conditions.'
    }
}

function Get-ReferenceTokens {
    param([string]$ReferenceText)
    if ([string]::IsNullOrWhiteSpace($ReferenceText)) {
        return @()
    }
    return @([regex]::Matches($ReferenceText, 'PMID \d+') | ForEach-Object { $_.Value } | Select-Object -Unique)
}

function Get-ReferenceLabel {
    param(
        [string]$ReferenceText,
        [hashtable]$Catalog,
        [hashtable]$NumberMap,
        [System.Collections.Generic.List[string]]$OrderedTokens
    )
    $tokens = @(Get-ReferenceTokens -ReferenceText $ReferenceText)
    if ($tokens.Count -eq 0) {
        return ""
    }
    $labels = New-Object 'System.Collections.Generic.List[string]'
    foreach ($token in $tokens) {
        if (-not $NumberMap.ContainsKey($token)) {
            $NumberMap[$token] = $OrderedTokens.Count + 1
            $OrderedTokens.Add($token)
        }
        $labels.Add(("[{0}]" -f $NumberMap[$token]))
    }
    return ($labels -join ", ")
}

function Get-ReferenceBlocks {
    param(
        [hashtable]$Catalog,
        [hashtable]$NumberMap,
        [System.Collections.Generic.List[string]]$OrderedTokens
    )
    $blocks = @()
    if ($OrderedTokens.Count -eq 0) {
        return $blocks
    }
    $blocks += (New-ParagraphBlock -Text "References" -Style "Heading1")
    foreach ($token in $OrderedTokens) {
        $citation = if ($Catalog.ContainsKey($token)) { $Catalog[$token] } else { "$token." }
        $blocks += (New-ParagraphBlock -Text ("[{0}] {1}" -f $NumberMap[$token], $citation) -IndentLeft 360 -Hanging 360 -SpaceAfter 60)
    }
    return $blocks
}

function Test-IsMetaboliteSignal {
    param(
        [string]$Signal,
        [string]$SignalClass = ""
    )
    if ($SignalClass -match 'Metabolite|Small molecule|SCFA|Ratio pattern|Primary bile acid|Microbial') {
        return $true
    }
    if ($Signal -match 'Taurine|Cadaverine|Succinate|Butyrate|Nitrate|Nitrite|NO metabolites|bile acid|Cholic acid|Chenodeoxycholic|Valerate|Isobutyrate|Isovalerate|Acetate|Propionate|Lactate') {
        return $true
    }
    return $false
}

function Get-SeparationStrengthRank {
    param([string]$State)
    if ([string]::IsNullOrWhiteSpace($State)) {
        return 1
    }
    if ($State -match 'vs IBS|vs UC|vs IBD') {
        return 3
    }
    if ($State -match 'vs healthy') {
        return 2
    }
    return 1
}

function Get-StabilityRank {
    param([string]$Stability)
    switch -Regex ([string]$Stability) {
        'Stable|High' { return 3 }
        'Moderate' { return 2 }
        default { return 1 }
    }
}

function Get-Skill4ComparisonReason {
    param(
        [pscustomobject]$CurrentRow,
        [string]$CurrentState,
        [pscustomobject]$OtherRow,
        [string]$OtherState,
        [bool]$ShouldFavorCurrent
    )

    $currentScore = [int]$CurrentRow.'Total Score'
    $otherScore = [int]$OtherRow.'Total Score'
    $sameMoleculeDifferentSpecies = (
        ([string]$CurrentRow.Molecule -eq [string]$OtherRow.Molecule) -and
        ([string]$CurrentRow.'Bacterial Species' -ne [string]$OtherRow.'Bacterial Species')
    )

    if ($sameMoleculeDifferentSpecies -and [Math]::Abs($currentScore - $otherScore) -le 1) {
        if ($ShouldFavorCurrent -and $currentScore -ge $otherScore) {
            return "it only edges the paired alternative by a narrow margin on the scored criteria, so the ordering reflects a small evidence difference rather than any organism preference"
        }
        if ((-not $ShouldFavorCurrent) -and $currentScore -le $otherScore) {
            return "the paired alternative only sits above it by a narrow margin on the scored criteria, so this is not a species-based gap"
        }
    }

    $currentSeparation = Get-SeparationStrengthRank -State $CurrentState
    $otherSeparation = Get-SeparationStrengthRank -State $OtherState
    if ($ShouldFavorCurrent -and $currentSeparation -gt $otherSeparation) {
        return "its biomarker evidence is anchored more directly in IBD-vs-IBS separation rather than leaning mainly on healthy-control comparisons"
    }
    if ((-not $ShouldFavorCurrent) -and $currentSeparation -lt $otherSeparation) {
        return "the clinical separation is a little less direct, with more of the support coming from broader comparator groups rather than the strongest IBD-vs-IBS evidence"
    }

    $currentStability = Get-StabilityRank -Stability ([string]$CurrentRow.'Stability in Stool')
    $otherStability = Get-StabilityRank -Stability ([string]$OtherRow.'Stability in Stool')
    if ($ShouldFavorCurrent -and $currentStability -gt $otherStability) {
        return "the stool signal is more stable and therefore more dependable as a practical detector input"
    }
    if ((-not $ShouldFavorCurrent) -and $currentStability -lt $otherStability) {
        return "the stool signal is a little more handling-sensitive, which weakens its practical advantage"
    }

    $currentNotes = [string]$CurrentRow.Notes
    $otherNotes = [string]$OtherRow.Notes
    if ($ShouldFavorCurrent -and $currentNotes -match 'specific|clean|strong disease signal|stronger promoter biology|reporter support' -and $otherNotes -match 'cross-reactive|proxy|not unique|less specific|unresolved control logic') {
        return "it offers a cleaner or more specific readout than the lower-ranked alternative"
    }
    if ((-not $ShouldFavorCurrent) -and $currentNotes -match 'cross-reactive|proxy|not unique|less specific|unresolved control logic' -and $otherNotes -match 'specific|clean|strong disease signal|stronger promoter biology|reporter support') {
        return "the options above it have a cleaner or more specific readout in the current evidence base"
    }
    if ($ShouldFavorCurrent -and $currentScore -gt $otherScore) {
        return ("its overall balance across stool stability, separation strength, patient consistency, promoter behavior, and concentration fit is still slightly stronger ({0} vs {1})" -f $currentScore, $otherScore)
    }
    if ((-not $ShouldFavorCurrent) -and $currentScore -lt $otherScore) {
        return ("the options above it keep a slightly stronger overall balance across the five ranking criteria ({0} vs {1})" -f $otherScore, $currentScore)
    }

    return "the overall package is close, but the neighboring option edges it out only slightly on the combined ranking criteria"
}

function Get-Skill4RankingExplanation {
    param(
        [pscustomobject]$Row,
        [string]$State,
        [string]$SenseLabel,
        [pscustomobject]$PreviousRow = $null,
        [string]$PreviousState = "",
        [pscustomobject]$NextRow = $null,
        [string]$NextState = ""
    )

    $mechanismText = if ([string]$Row.'Mechanism Type' -eq 'Direct sensing') {
        "The promoter is linked to a direct sensing route, which helps keep the detector logic easier to interpret."
    }
    elseif ([string]$Row.'Mechanism Type' -eq 'Mechanism unresolved') {
        "The promoter is clearly molecule responsive, but the exact sensed ligand or binding mechanism has not been resolved cleanly enough to call it direct."
    }
    else {
        "The promoter reads out a secondary physiological consequence rather than the original marker itself, so the biological logic is still useful but inherently more proxy-like."
    }

    $stateText = if ($State -match 'vs IBS|vs UC|vs IBD') {
        "The clinical signal is supported by a direct disease-separation pattern rather than only a disease-vs-healthy effect."
    }
    else {
        "The clinical signal is still relevant, but more of the support comes from disease-vs-healthy comparisons than from the cleanest IBD-vs-IBS studies."
    }

    $stabilityText = switch -Regex ([string]$Row.'Stability in Stool') {
        'Stable|High' { "The molecule itself is relatively durable in stool, which strengthens its value as a detector input." }
        'Moderate' { "The molecule is usable in stool, but it is more sensitive to handling or sample conditions than the most robust markers in the panel." }
        default { "The stool handling profile is less favorable, which limits how confidently it can outrank the stronger entries." }
    }

    $notesText = if (-not [string]::IsNullOrWhiteSpace([string]$Row.Notes)) {
        ((([string]$Row.Notes) -replace '\bbackup\b', 'alternative route')).TrimEnd('. ') + "."
    }
    else {
        "Its retained position is supported by the current combined evidence package."
    }

    $parts = New-Object 'System.Collections.Generic.List[string]'
    $parts.Add(("This entry sits at rank {0}. {1} {2} {3}" -f [string]$Row.Rank, $notesText, $stateText, $stabilityText))
    $parts.Add($mechanismText)

    if ($null -ne $PreviousRow) {
        $reasonBelowPrevious = Get-Skill4ComparisonReason -CurrentRow $Row -CurrentState $State -OtherRow $PreviousRow -OtherState $PreviousState -ShouldFavorCurrent $false
        $parts.Add(("It remains below {0} because {1}." -f [string]$PreviousRow.Molecule, $reasonBelowPrevious))
    }

    if ($null -ne $NextRow) {
        $reasonAboveNext = Get-Skill4ComparisonReason -CurrentRow $Row -CurrentState $State -OtherRow $NextRow -OtherState $NextState -ShouldFavorCurrent $true
        $parts.Add(("It stays ahead of {0} because {1}." -f [string]$NextRow.Molecule, $reasonAboveNext))
    }

    return ($parts -join " ")
}

function Get-RankStars {
    param(
        [int]$Rank,
        [int]$Count
    )
    $filledStar = [string][char]0x2605
    $emptyStar = [string][char]0x2606
    if ($Count -le 1) {
        $starCount = 5
    }
    else {
        $starCount = 5 - [Math]::Min(4, [Math]::Floor((($Rank - 1) * 5.0) / $Count))
    }
    if ($starCount -lt 1) {
        $starCount = 1
    }
    return (($filledStar * $starCount) + ($emptyStar * (5 - $starCount)))
}

function Get-Skill4MechanismLabel {
    param([string]$MechanismType)
    if ([string]$MechanismType -eq 'Direct sensing') {
        return 'Direct'
    }
    if ([string]$MechanismType -eq 'Mechanism unresolved') {
        return 'Unresolved'
    }
    return 'Indirect'
}

function Get-Skill4CandidateSignal {
    param([pscustomobject]$Row)
    if (-not [string]::IsNullOrWhiteSpace([string]$Row.'Indirect Consequence')) {
        return Get-CompactSenseLabel -Trigger ([string]$Row.'Indirect Consequence')
    }
    return Get-CompactSenseLabel -Trigger (Get-DirectResponseTrigger -Molecule ([string]$Row.Molecule) -Promoter ([string]$Row.Promoter) -Gene ([string]$Row.'Gene / Operon'))
}

function Get-Skill4DisplayPromoter {
    param([string]$Promoter)
    if ([string]::IsNullOrWhiteSpace($Promoter)) {
        return ""
    }
    if ($Promoter -match '^P([A-Za-z].*)$') {
        return $Matches[1]
    }
    return $Promoter
}

function Get-Skill4SpecificityAssessment {
    param([pscustomobject]$Row)
    if ($Row.PSObject.Properties.Name -contains 'Specificity Assessment' -and -not [string]::IsNullOrWhiteSpace([string]$Row.'Specificity Assessment')) {
        return [string]$Row.'Specificity Assessment'
    }
    return Get-Skill4SpecificityTag -Notes ([string]$Row.Notes)
}

function Get-Skill4StabilityAssessment {
    param([pscustomobject]$Row)
    if ($Row.PSObject.Properties.Name -contains 'Stability Assessment' -and -not [string]::IsNullOrWhiteSpace([string]$Row.'Stability Assessment')) {
        return [string]$Row.'Stability Assessment'
    }
    return [string]$Row.'Stability in Stool'
}

function Get-Skill4MechanisticRationale {
    param([pscustomobject]$Row)
    if ($Row.PSObject.Properties.Name -contains 'Mechanistic Rationale' -and -not [string]::IsNullOrWhiteSpace([string]$Row.'Mechanistic Rationale')) {
        return [string]$Row.'Mechanistic Rationale'
    }
    return Get-Skill4CandidateSignal -Row $Row
}

function Get-Skill5UpstreamLength {
    param([pscustomobject]$Row)
    foreach ($name in @('Upstream length (bp)', 'Recommended upstream length from ATG (bp)')) {
        if ($Row.PSObject.Properties.Name -contains $name -and -not [string]::IsNullOrWhiteSpace([string]$Row.$name)) {
            return [string]$Row.$name
        }
    }
    return "Not added"
}

function Get-Skill5UpstreamConfidence {
    param([pscustomobject]$Row)
    foreach ($name in @('Upstream confidence', 'Confidence level')) {
        if ($Row.PSObject.Properties.Name -contains $name -and -not [string]::IsNullOrWhiteSpace([string]$Row.$name)) {
            return [string]$Row.$name
        }
    }
    return "Not added"
}

function Split-TextIntoBullets {
    param(
        [string]$Text,
        [int]$MaxItems = 2
    )
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }
    $parts = @([regex]::Split($Text.Trim(), '(?<=[\.\;\:])\s+') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
    if ($parts.Count -eq 0) {
        return @($Text.Trim())
    }
    return @($parts | Select-Object -First $MaxItems)
}

function Get-Skill4WhyBullets {
    param(
        [pscustomobject]$Row,
        [string]$State,
        [string]$CandidateSignal,
        [string]$MechanismLabel,
        [string]$MechanisticRationale,
        [string]$RankingExplanation
    )
    $bullets = New-Object 'System.Collections.Generic.List[string]'
    $bullets.Add(("Represents `{0}` linked to `{1}` through a `{2}` sensing route." -f $CandidateSignal, $State, $MechanismLabel.ToLowerInvariant()))
    $bullets.Add(("Biological link: {0}." -f $MechanisticRationale.TrimEnd('.')))
    foreach ($part in (Split-TextIntoBullets -Text $RankingExplanation -MaxItems 1)) {
        $bullets.Add(("Position driver: {0}" -f $part.TrimEnd('.')))
    }
    return @($bullets | Select-Object -First 3)
}

function Get-Skill4StrengthBullets {
    param(
        [pscustomobject]$Row,
        [string]$StabilityAssessment,
        [string]$SpecificityAssessment
    )
    $bullets = New-Object 'System.Collections.Generic.List[string]'
    $bullets.Add(("Stability: {0}." -f $StabilityAssessment.TrimEnd('.')))
    $bullets.Add(("Specificity: {0}." -f $SpecificityAssessment.TrimEnd('.')))
    $upstreamConfidence = Get-Skill5UpstreamConfidence -Row $Row
    if ($upstreamConfidence -ne "Not added") {
        $bullets.Add(("Promoter-region confidence: {0}." -f $upstreamConfidence.TrimEnd('.')))
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$Row.Evidence)) {
        $bullets.Add(("Evidence base: {0}." -f ([string]$Row.Evidence).TrimEnd('.')))
    }
    return @($bullets | Select-Object -First 3)
}

function Get-Skill4LimitationBullets {
    param(
        [pscustomobject]$Row,
        [string]$MainLimitations,
        [string]$MechanismLabel
    )
    $bullets = New-Object 'System.Collections.Generic.List[string]'
    foreach ($part in (Split-TextIntoBullets -Text $MainLimitations -MaxItems 2)) {
        $bullets.Add($part.TrimEnd('.'))
    }
    $upstreamConfidence = Get-Skill5UpstreamConfidence -Row $Row
    if ($upstreamConfidence -eq 'Low') {
        $bullets.Add("Promoter capture boundary remains low-confidence and may miss or overextend relevant regulation")
    }
    if ($bullets.Count -eq 0 -and $MechanismLabel -eq 'Indirect') {
        $bullets.Add("Readout remains a proxy branch rather than direct sensing of the original host marker")
    }
    return @($bullets | Select-Object -First 3)
}

function Get-Skill4TopSystemsTable {
    param([object[]]$Rows)
    $tableRows = @(
        ,@("Rank", "Host marker", "Candidate signal", "Promoter/gene", "Strain")
    )
    foreach ($row in ($Rows | Select-Object -First 3)) {
        $rank = [int]$row.Rank
        $tableRows += ,@(
            ("{0} {1}" -f $rank, (Get-RankStars -Rank $rank -Count $Rows.Count)),
            [string]$row.Molecule,
            (Get-Skill4CandidateSignal -Row $row),
            ("{0} / {1}" -f (Get-Skill4DisplayPromoter -Promoter ([string]$row.Promoter)), [string]$row.'Gene / Operon'),
            (Get-ShortOrganismName -Species ([string]$row.'Bacterial Species'))
        )
    }
    return $tableRows
}

function Get-Skill4SummaryTable {
    param([object[]]$Rows)
    $tableRows = @(
        ,@("Rank", "Host marker", "Candidate signal", "Promoter/gene", "Strain", "Stability", "Specificity", "Upstream length", "Upstream confidence")
    )
    foreach ($row in $Rows) {
        $rank = [int]$row.Rank
        $tableRows += ,@(
            ("{0} {1}" -f $rank, (Get-RankStars -Rank $rank -Count $Rows.Count)),
            [string]$row.Molecule,
            (Get-Skill4CandidateSignal -Row $row),
            ("{0} / {1}" -f (Get-Skill4DisplayPromoter -Promoter ([string]$row.Promoter)), [string]$row.'Gene / Operon'),
            (Get-ShortOrganismName -Species ([string]$row.'Bacterial Species')),
            (Get-Skill4StabilityAssessment -Row $row),
            (Get-Skill4SpecificityAssessment -Row $row),
            (Get-Skill5UpstreamLength -Row $row),
            (Get-Skill5UpstreamConfidence -Row $row)
        )
    }
    return $tableRows
}

function Get-Skill4RecommendationLines {
    param([object[]]$Rows)
    $overall = @($Rows | Select-Object -First 3 | ForEach-Object { ("{0} -> {1}" -f [string]$_.Molecule, (Get-Skill4DisplayPromoter -Promoter ([string]$_.Promoter))) })
    $direct = @($Rows | Where-Object { $_.'Mechanism Type' -eq 'Direct sensing' } | Select-Object -First 3 | ForEach-Object { ("{0} -> {1}" -f [string]$_.Molecule, (Get-Skill4DisplayPromoter -Promoter ([string]$_.Promoter))) })
    $stable = @($Rows | Where-Object { (Get-Skill4StabilityAssessment -Row $_) -match 'High|Stable' } | Select-Object -First 3 | ForEach-Object { ("{0} -> {1}" -f [string]$_.Molecule, (Get-Skill4DisplayPromoter -Promoter ([string]$_.Promoter))) })
    return @{
        Experimental = if ($overall.Count -gt 0) { $overall -join "; " } else { "No candidates available" }
        Direct = if ($direct.Count -gt 0) { $direct -join "; " } else { "No retained direct sensors in the current panel" }
        Stable = if ($stable.Count -gt 0) { $stable -join "; " } else { "No high-stability routes identified in the current panel" }
    }
}

function New-ParagraphBlock {
    param(
        [string]$Text,
        [bool]$Bold = $false,
        [int]$FontSize = 0,
        [bool]$KeepNext = $false,
        [bool]$KeepLines = $false,
        [string]$Style = "",
        [string]$Align = "",
        [int]$SpaceAfter = 120,
        [int]$SpaceBefore = 0,
        [bool]$PageBreakBefore = $false,
        [string]$TextColor = "",
        [string]$ShadingFill = "",
        [int]$IndentLeft = 0,
        [int]$Hanging = 0
    )
    return @{
        Type = "paragraph"
        Text = $Text
        Bold = $Bold
        FontSize = $FontSize
        KeepNext = $KeepNext
        KeepLines = $KeepLines
        Style = $Style
        Align = $Align
        SpaceAfter = $SpaceAfter
        SpaceBefore = $SpaceBefore
        PageBreakBefore = $PageBreakBefore
        TextColor = $TextColor
        ShadingFill = $ShadingFill
        IndentLeft = $IndentLeft
        Hanging = $Hanging
    }
}

function New-LabeledParagraphBlock {
    param(
        [string]$Label,
        [string]$Value,
        [int]$FontSize = 0,
        [bool]$KeepNext = $false,
        [bool]$KeepLines = $false,
        [string]$Style = "",
        [string]$Align = "",
        [int]$SpaceAfter = 120,
        [int]$SpaceBefore = 0
    )
    return @{
        Type = "labeled"
        Label = $Label
        Value = $Value
        FontSize = $FontSize
        KeepNext = $KeepNext
        KeepLines = $KeepLines
        Style = $Style
        Align = $Align
        SpaceAfter = $SpaceAfter
        SpaceBefore = $SpaceBefore
    }
}

function New-TableBlock {
    param(
        [object]$Rows,
        [bool]$PreventRowSplit = $true,
        [string]$HeaderFill = "EAEAEA",
        [string]$AlternateRowFill = "",
        [string]$FirstColumnFill = "",
        [int[]]$ColumnWidths = @()
    )
    return @{
        Type = "table"
        Rows = $Rows
        PreventRowSplit = $PreventRowSplit
        HeaderFill = $HeaderFill
        AlternateRowFill = $AlternateRowFill
        FirstColumnFill = $FirstColumnFill
        ColumnWidths = $ColumnWidths
    }
}

function New-PageBreakBlock {
    return @{
        Type = "pagebreak"
    }
}

function Get-ParagraphXml {
    param(
        [string]$Text,
        [bool]$Bold = $false,
        [int]$FontSize = 0,
        [bool]$KeepNext = $false,
        [bool]$KeepLines = $false,
        [string]$Style = "",
        [string]$Align = "",
        [int]$SpaceAfter = 120,
        [int]$SpaceBefore = 0,
        [bool]$PageBreakBefore = $false,
        [string]$TextColor = "",
        [string]$ShadingFill = "",
        [int]$IndentLeft = 0,
        [int]$Hanging = 0
    )
    $runProps = ""
    if ($Bold -or $FontSize -gt 0) {
        $propParts = @()
        if ($Bold) {
            $propParts += "<w:b/>"
        }
        if ($FontSize -gt 0) {
            $propParts += ("<w:sz w:val=`"{0}`"/>" -f $FontSize)
            $propParts += ("<w:szCs w:val=`"{0}`"/>" -f $FontSize)
        }
        if (-not [string]::IsNullOrWhiteSpace($TextColor)) {
            $propParts += ("<w:color w:val=`"{0}`"/>" -f $TextColor)
        }
        $runProps = "<w:rPr>$($propParts -join '')</w:rPr>"
    }
    $paragraphProps = @()
    if (-not [string]::IsNullOrWhiteSpace($Style)) {
        $paragraphProps += ("<w:pStyle w:val=`"{0}`"/>" -f $Style)
    }
    if ($KeepNext) {
        $paragraphProps += "<w:keepNext/>"
    }
    if ($KeepLines) {
        $paragraphProps += "<w:keepLines/>"
    }
    if ($PageBreakBefore) {
        $paragraphProps += "<w:pageBreakBefore/>"
    }
    if (-not [string]::IsNullOrWhiteSpace($Align)) {
        $paragraphProps += ("<w:jc w:val=`"{0}`"/>" -f $Align)
    }
    if ($SpaceAfter -gt 0 -or $SpaceBefore -gt 0) {
        $paragraphProps += ("<w:spacing w:before=`"{0}`" w:after=`"{1}`"/>`n" -f $SpaceBefore, $SpaceAfter)
    }
    if ($IndentLeft -gt 0 -or $Hanging -gt 0) {
        $indentProps = @()
        if ($IndentLeft -gt 0) {
            $indentProps += ("w:left=`"{0}`"" -f $IndentLeft)
        }
        if ($Hanging -gt 0) {
            $indentProps += ("w:hanging=`"{0}`"" -f $Hanging)
        }
        $paragraphProps += ("<w:ind {0}/>" -f ($indentProps -join " "))
    }
    if (-not [string]::IsNullOrWhiteSpace($ShadingFill)) {
        $paragraphProps += ("<w:shd w:val=`"clear`" w:color=`"auto`" w:fill=`"{0}`"/>" -f $ShadingFill)
    }
    $paragraphPropsXml = if ($paragraphProps.Count -gt 0) { "<w:pPr>$($paragraphProps -join '')</w:pPr>" } else { "" }
    return "<w:p>$paragraphPropsXml<w:r>$runProps<w:t xml:space=`"preserve`">$([string](Escape-Xml $Text))</w:t></w:r></w:p>"
}

function Get-LabeledParagraphXml {
    param(
        [string]$Label,
        [string]$Value,
        [int]$FontSize = 0,
        [bool]$KeepNext = $false,
        [bool]$KeepLines = $false,
        [string]$Style = "",
        [string]$Align = "",
        [int]$SpaceAfter = 120,
        [int]$SpaceBefore = 0
    )
    $labelProps = @("<w:b/>")
    if ($FontSize -gt 0) {
        $labelProps += ("<w:sz w:val=`"{0}`"/>" -f $FontSize)
        $labelProps += ("<w:szCs w:val=`"{0}`"/>" -f $FontSize)
    }
    $valueProps = ""
    if ($FontSize -gt 0) {
        $valueProps = "<w:rPr><w:sz w:val=`"$FontSize`"/><w:szCs w:val=`"$FontSize`"/></w:rPr>"
    }
    $paragraphProps = @()
    if (-not [string]::IsNullOrWhiteSpace($Style)) {
        $paragraphProps += ("<w:pStyle w:val=`"{0}`"/>" -f $Style)
    }
    if ($KeepNext) {
        $paragraphProps += "<w:keepNext/>"
    }
    if ($KeepLines) {
        $paragraphProps += "<w:keepLines/>"
    }
    if (-not [string]::IsNullOrWhiteSpace($Align)) {
        $paragraphProps += ("<w:jc w:val=`"{0}`"/>" -f $Align)
    }
    if ($SpaceAfter -gt 0 -or $SpaceBefore -gt 0) {
        $paragraphProps += ("<w:spacing w:before=`"{0}`" w:after=`"{1}`"/>`n" -f $SpaceBefore, $SpaceAfter)
    }
    $paragraphPropsXml = if ($paragraphProps.Count -gt 0) { "<w:pPr>$($paragraphProps -join '')</w:pPr>" } else { "" }
    return "<w:p>$paragraphPropsXml<w:r><w:rPr>$($labelProps -join '')</w:rPr><w:t xml:space=`"preserve`">$([string](Escape-Xml $Label))</w:t></w:r><w:r>$valueProps<w:t xml:space=`"preserve`">$([string](Escape-Xml $Value))</w:t></w:r></w:p>"
}

function Get-CellRunXml {
    param(
        [string]$Text,
        [bool]$Bold = $false,
        [string]$TextColor = ""
    )
    $runProps = ""
    if ($Bold -or -not [string]::IsNullOrWhiteSpace($TextColor)) {
        $propParts = @()
        if ($Bold) {
            $propParts += "<w:b/>"
        }
        if (-not [string]::IsNullOrWhiteSpace($TextColor)) {
            $propParts += ("<w:color w:val=`"{0}`"/>" -f $TextColor)
        }
        $runProps = "<w:rPr>$($propParts -join '')</w:rPr>"
    }
    $parts = @([string]$Text -split "`r?`n")
    if ($parts.Count -eq 0) {
        $parts = @("")
    }
    $content = @()
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($i -gt 0) {
            $content += "<w:br/>"
        }
        $content += "<w:t xml:space=`"preserve`">$([string](Escape-Xml $parts[$i]))</w:t>"
    }
    return "<w:r>$runProps$($content -join '')</w:r>"
}

function Get-TableXml {
    param(
        [object]$Rows,
        [bool]$PreventRowSplit = $true,
        [string]$HeaderFill = "EAEAEA",
        [string]$AlternateRowFill = "",
        [string]$FirstColumnFill = "",
        [int[]]$ColumnWidths = @()
    )
    $sourceRows = @()
    if ($Rows -is [System.Array] -or $Rows -is [System.Collections.IList]) {
        $sourceRows = @($Rows)
    }
    else {
        $sourceRows = @($Rows)
    }
    $normalizedRows = @()
    foreach ($row in $sourceRows) {
        if ($row -is [System.Array] -or $row -is [System.Collections.IList]) {
            $normalizedRows += ,@($row)
        }
        else {
            $normalizedRows += ,@([string]$row)
        }
    }
    $columnCount = ($normalizedRows | ForEach-Object { $_.Count } | Measure-Object -Maximum).Maximum
    if ($columnCount -lt 1) {
        return ""
    }
    if ($ColumnWidths.Count -eq $columnCount) {
        $widths = $ColumnWidths
    }
    else {
        $columnWidth = [Math]::Floor(9000 / $columnCount)
        $widths = @(1..$columnCount | ForEach-Object { $columnWidth })
    }
    $gridCols = @()
    foreach ($width in $widths) {
        $gridCols += ("<w:gridCol w:w=`"{0}`"/>" -f $width)
    }
    $rowXml = @()
    for ($rowIndex = 0; $rowIndex -lt $normalizedRows.Count; $rowIndex++) {
        $isHeader = ($rowIndex -eq 0)
        $cells = $normalizedRows[$rowIndex]
        $cellXml = @()
        for ($cellIndex = 0; $cellIndex -lt $columnCount; $cellIndex++) {
            $cellText = ""
            if ($cellIndex -lt $cells.Count) {
                $cellText = [string]$cells[$cellIndex]
            }
            $fill = ""
            if ($isHeader) {
                $fill = $HeaderFill
            }
            elseif ($cellIndex -eq 0 -and -not [string]::IsNullOrWhiteSpace($FirstColumnFill)) {
                $fill = $FirstColumnFill
            }
            elseif (($rowIndex % 2) -eq 0 -and -not [string]::IsNullOrWhiteSpace($AlternateRowFill)) {
                $fill = $AlternateRowFill
            }
            $shade = if (-not [string]::IsNullOrWhiteSpace($fill)) { ("<w:shd w:val=`"clear`" w:color=`"auto`" w:fill=`"{0}`"/>" -f $fill) } else { "" }
            $cellRunXml = Get-CellRunXml -Text $cellText -Bold $isHeader
            $cellXml += "<w:tc><w:tcPr><w:tcW w:w=`"$($widths[$cellIndex])`" w:type=`"dxa`"/>$shade</w:tcPr><w:p><w:pPr><w:spacing w:after=`"60`"/></w:pPr>$cellRunXml</w:p></w:tc>"
        }
        $rowProps = if ($PreventRowSplit) { "<w:trPr><w:cantSplit/></w:trPr>" } else { "" }
        $rowXml += "<w:tr>$rowProps$($cellXml -join '')</w:tr>"
    }
    return @"
<w:tbl>
  <w:tblPr>
    <w:tblW w:w="0" w:type="auto"/>
    <w:tblLook w:firstRow="1" w:lastRow="0" w:firstColumn="0" w:lastColumn="0" w:noHBand="0" w:noVBand="1"/>
    <w:tblBorders>
      <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>
      <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>
      <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
      <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>
      <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
      <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
    </w:tblBorders>
  </w:tblPr>
  <w:tblGrid>$($gridCols -join '')</w:tblGrid>
  $($rowXml -join "`n")
</w:tbl>
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
        <w:lang w:val="en-US"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:after="120" w:line="276" w:lineRule="auto"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:jc w:val="center"/>
      <w:spacing w:before="0" w:after="180"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="32"/>
      <w:szCs w:val="32"/>
      <w:color w:val="1F2937"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Subtitle">
    <w:name w:val="Subtitle"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:jc w:val="center"/>
      <w:spacing w:before="0" w:after="160"/>
    </w:pPr>
    <w:rPr>
      <w:sz w:val="22"/>
      <w:szCs w:val="22"/>
      <w:color w:val="4B5563"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="240" w:after="120"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="28"/>
      <w:szCs w:val="28"/>
      <w:color w:val="1F2937"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="180" w:after="100"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="26"/>
      <w:szCs w:val="26"/>
      <w:color w:val="1F2937"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="120" w:after="80"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="24"/>
      <w:szCs w:val="24"/>
      <w:color w:val="374151"/>
    </w:rPr>
  </w:style>
</w:styles>
"@
}

function Get-HeaderXml {
    param([string]$DocumentTitle)
    return @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p>
    <w:pPr>
      <w:jc w:val="center"/>
      <w:spacing w:after="0"/>
    </w:pPr>
    <w:r>
      <w:rPr><w:b/><w:sz w:val="18"/><w:szCs w:val="18"/><w:color w:val="4B5563"/></w:rPr>
      <w:t xml:space="preserve">$([string](Escape-Xml $DocumentTitle))</w:t>
    </w:r>
  </w:p>
</w:hdr>
"@
}

function Get-FooterXml {
    param([string]$RunDate)
    return @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p>
    <w:pPr>
      <w:jc w:val="center"/>
      <w:spacing w:before="0" w:after="0"/>
    </w:pPr>
    <w:r>
      <w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/><w:color w:val="6B7280"/></w:rPr>
      <w:t xml:space="preserve">Page </w:t>
    </w:r>
    <w:fldSimple w:instr=" PAGE "/>
    <w:r>
      <w:rPr><w:sz w:val="18"/><w:szCs w:val="18"/><w:color w:val="6B7280"/></w:rPr>
      <w:t xml:space="preserve"> | Run date $([string](Escape-Xml $RunDate))</w:t>
    </w:r>
  </w:p>
</w:ftr>
"@
}

function Get-DocumentRelationshipsXml {
    return @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>
</Relationships>
"@
}

function Write-Docx {
    param(
        [string]$Path,
        [object[]]$Blocks,
        [string]$DocumentTitle = "IBD vs IBS Marker Finder Report",
        [string]$RunDate = "",
        [int]$PageWidth = 12240,
        [int]$PageHeight = 15840,
        [int]$MarginTop = 1440,
        [int]$MarginRight = 1440,
        [int]$MarginBottom = 1440,
        [int]$MarginLeft = 1440
    )
    $tempRoot = Join-Path $Workspace ".docx-build"
    New-Item -ItemType Directory -Force $tempRoot | Out-Null
    $tempDir = Join-Path $tempRoot ([guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Force (Join-Path $tempDir "_rels") | Out-Null
    New-Item -ItemType Directory -Force (Join-Path $tempDir "word") | Out-Null
    New-Item -ItemType Directory -Force (Join-Path $tempDir "word/_rels") | Out-Null

    $bodyParts = @()
    foreach ($block in $Blocks) {
        if ($block.Type -eq "paragraph") {
            $bodyParts += Get-ParagraphXml -Text $block.Text -Bold ([bool]$block.Bold) -FontSize ([int]$block.FontSize) -KeepNext ([bool]$block.KeepNext) -KeepLines ([bool]$block.KeepLines) -Style ([string]$block.Style) -Align ([string]$block.Align) -SpaceAfter ([int]$block.SpaceAfter) -SpaceBefore ([int]$block.SpaceBefore) -PageBreakBefore ([bool]$block.PageBreakBefore) -TextColor ([string]$block.TextColor) -ShadingFill ([string]$block.ShadingFill) -IndentLeft ([int]$block.IndentLeft) -Hanging ([int]$block.Hanging)
        }
        elseif ($block.Type -eq "labeled") {
            $bodyParts += Get-LabeledParagraphXml -Label $block.Label -Value $block.Value -FontSize ([int]$block.FontSize) -KeepNext ([bool]$block.KeepNext) -KeepLines ([bool]$block.KeepLines) -Style ([string]$block.Style) -Align ([string]$block.Align) -SpaceAfter ([int]$block.SpaceAfter) -SpaceBefore ([int]$block.SpaceBefore)
        }
        elseif ($block.Type -eq "table") {
            $bodyParts += Get-TableXml -Rows $block.Rows -PreventRowSplit ([bool]$block.PreventRowSplit) -HeaderFill ([string]$block.HeaderFill) -AlternateRowFill ([string]$block.AlternateRowFill) -FirstColumnFill ([string]$block.FirstColumnFill) -ColumnWidths ([int[]]$block.ColumnWidths)
            $bodyParts += Get-ParagraphXml -Text "" -SpaceAfter 60
        }
        elseif ($block.Type -eq "pagebreak") {
            $bodyParts += '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'
        }
    }
    $body = $bodyParts -join "`n"

    $documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    $body
    <w:sectPr>
      <w:headerReference w:type="default" r:id="rId2"/>
      <w:footerReference w:type="default" r:id="rId3"/>
      <w:pgSz w:w="$PageWidth" w:h="$PageHeight"/>
      <w:pgMar w:top="$MarginTop" w:right="$MarginRight" w:bottom="$MarginBottom" w:left="$MarginLeft" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>
"@

    $contentTypes = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>
  <Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>
</Types>
"@

    $relationships = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
"@

    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path $tempDir "[Content_Types].xml"), $contentTypes, $utf8)
    [System.IO.File]::WriteAllText((Join-Path $tempDir "_rels/.rels"), $relationships, $utf8)
    [System.IO.File]::WriteAllText((Join-Path $tempDir "word/document.xml"), $documentXml, $utf8)
    [System.IO.File]::WriteAllText((Join-Path $tempDir "word/styles.xml"), (Get-StylesXml), $utf8)
    [System.IO.File]::WriteAllText((Join-Path $tempDir "word/header1.xml"), (Get-HeaderXml -DocumentTitle $DocumentTitle), $utf8)
    [System.IO.File]::WriteAllText((Join-Path $tempDir "word/footer1.xml"), (Get-FooterXml -RunDate $RunDate), $utf8)
    [System.IO.File]::WriteAllText((Join-Path $tempDir "word/_rels/document.xml.rels"), (Get-DocumentRelationshipsXml), $utf8)

    $zipPath = "$Path.zip"
    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }
    if (Test-Path $Path) {
        Remove-Item $Path -Force
    }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath)
    Move-Item $zipPath $Path
    Remove-Item $tempDir -Recurse -Force
}

function Get-WritableDocxPath {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return $Path
    }
    try {
        Remove-Item $Path -Force -ErrorAction Stop
        return $Path
    }
    catch {
        $directory = Split-Path -Parent $Path
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        $extension = [System.IO.Path]::GetExtension($Path)
        return (Join-Path $directory ("{0}_updated{1}" -f $baseName, $extension))
    }
}

function Get-Skill1Blocks {
    param([string]$RunFolder)
    $candidatesPath = Join-Path $RunFolder "stage1_candidates.md"
    $text = Read-Text $candidatesPath
    $candidateMap = Get-Skill1CandidateMap -RunFolder $RunFolder
    $referenceMap = Get-Skill1ReferenceMap
    $catalog = Get-ReferenceCatalog
    $numberMap = @{}
    $orderedTokens = New-Object 'System.Collections.Generic.List[string]'
    $newRunBullets = @(Get-Skill1NewRunBullets -RunFolder $RunFolder)
    $skill1WhatsNewBullets = @($newRunBullets | Select-Object -First 2)
    if ($skill1WhatsNewBullets.Count -eq 0) {
        $skill1WhatsNewBullets = @("- No molecule-level addition was documented for this run.")
    }

    $mainTableRows = @(
        ,@("Rank", "Molecule", "Class", "Disease pattern", "Evidence strength", "Notes")
    )
    foreach ($signal in ($candidateMap.Keys | Sort-Object { [int]$candidateMap[$_][0] })) {
        if (-not $referenceMap.ContainsKey($signal)) {
            continue
        }
        $candidateRow = $candidateMap[$signal]
        $state = Get-Skill1DiseasePattern -CandidateRow $candidateRow
        $notes = Get-Skill1ExportNote -Notes ([string]$candidateRow[9])
        $refText = [string]$referenceMap[$signal]
        $refLabel = Get-ReferenceLabel -ReferenceText $refText -Catalog $catalog -NumberMap $numberMap -OrderedTokens $orderedTokens
        if ([string]::IsNullOrWhiteSpace($refLabel)) {
            continue
        }
        $noteText = if ($notes.Length -gt 110) { $notes.Substring(0,110).TrimEnd() + '...' } else { $notes }
        $mainTableRows += ,@(
            [string]$candidateRow[0],
            $signal,
            [string]$candidateRow[3],
            $state,
            (Get-EvidenceStrengthLabel -Raw ([string]$candidateRow[8])),
            ("{0} {1}" -f $noteText, $refLabel).Trim()
        )
    }

    $blocks = @()
    $blocks += (New-ParagraphBlock -Text "Skill 1: Molecule Ranking" -Bold $true)
    $blocks += (New-ParagraphBlock "Purpose: rank stool molecules for downstream Stage 2 screening.")
    $blocks += (New-ParagraphBlock -Text "What was done" -Bold $true)
    $blocks += (New-ParagraphBlock "- Used the latest Stage 1 ranked candidate pool and kept only molecules with explicit supporting references.")
    $blocks += (New-ParagraphBlock "- Kept the exported table to rank, molecule, class, disease pattern, evidence strength, and notes only.")
    $blocks += (New-ParagraphBlock "- Removed downstream-response wording from Skill 1 notes so the export stays Stage 1 only.")
    $blocks += (New-ParagraphBlock -Text "Key takeaways" -Bold $true)
    $blocks += (New-ParagraphBlock "- The top end of the list is still dominated by IBD-high inflammatory proteins.")
    $blocks += (New-ParagraphBlock ("- {0}" -f (Get-ComparisonFreeBulletText -Bullet $newRunBullets[0])))
    $blocks += (New-ParagraphBlock "- The corrected `NOx` family was carried forward rather than replaced.")
    $blocks += (New-ParagraphBlock "- IBS-side chemistry is still present, but most of it remains below the current Stage 2 cutoff.")
    $blocks += (New-ParagraphBlock -Text "What's new" -Bold $true)
    foreach ($bullet in $skill1WhatsNewBullets) {
        $blocks += (New-ParagraphBlock $bullet)
    }
    $blocks += (New-ParagraphBlock -Text "Main results" -Bold $true)
    $blocks += (New-TableBlock $mainTableRows)
    $blocks += (New-ParagraphBlock -Text "Coverage gaps" -Bold $true)
    $blocks += (New-ParagraphBlock "- `Butyrate`, `itaconate`, `spermidine`, `spermine`, and `ethanolamine` still lacked enough stool-discrimination support to advance.")
    $blocks += (New-ParagraphBlock "- Several IBS-side metabolites remain exploratory because they are driven mainly by disease-vs-healthy studies.")
    $blocks += (New-ParagraphBlock "- Biomarkers can remain clinically interesting even when they are only held here for later reassessment.")
    $blocks += (New-ParagraphBlock -Text "Run notes" -Bold $true)
    $blocks += (New-ParagraphBlock "- New: molecule-level additions or decision shifts are listed above in `What's new`.")
    $blocks += (New-ParagraphBlock "- Change: Skill 1 stays limited to Stage 1 evidence and does not carry promoter logic into the export.")
    $blocks += Get-ReferenceBlocks -Catalog $catalog -NumberMap $numberMap -OrderedTokens $orderedTokens
    return $blocks
}

function Get-Skill23Blocks {
    param([string]$RunFolder)
    $skill2Archive = Join-Path $Workspace "skill_2_criss_cross/archive/$($RunItem.Name)"
    $skill3Archive = Join-Path $Workspace "skill_3_indirect_response/archive/$($RunItem.Name)"
    $skill2Csv = Find-FirstFile -Dir $skill2Archive -Pattern "*_promoter_molecule_mapping.csv"
    $skill3Csv = Find-FirstFile -Dir $skill3Archive -Pattern "*_indirect_response_mapping.csv"

    if ($null -eq $skill2Csv -or $null -eq $skill3Csv) {
        return $null
    }

    $stateMap = Get-Skill1PassedStateMap -RunFolder $RunFolder
    $candidateMap = Get-Skill1CandidateMap -RunFolder $RunFolder
    $skill5RankMap = Get-Skill5OptionRankMap -RunFolder $RunFolder
    $catalog = Get-ReferenceCatalog
    $numberMap = @{}
    $orderedTokens = New-Object 'System.Collections.Generic.List[string]'
    $newRunBullets = @(Get-Skill23NewRunBullets -RunFolder $RunFolder)
    $skill23WhatsNewBullets = @($newRunBullets | Select-Object -First 2)
    if ($skill23WhatsNewBullets.Count -eq 0) {
        $skill23WhatsNewBullets = @("- No promoter- or branch-level addition was documented for this run.")
    }
    $mainTableRows = @(
        ,@("Molecule", "Gene", "Organism", "Senses", "Direction", "Reference")
    )
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $optionsByMolecule = @{}

    $directRows = @(Import-Csv -Path $skill2Csv | Where-Object { $_.'Gene / Operon' -notlike 'NO KNOWN*' })
    foreach ($row in $directRows | Sort-Object Molecule,Promoter) {
        if (-not $stateMap.ContainsKey($row.Molecule)) {
            continue
        }
        $species = Normalize-BacterialSpecies -Species $row.'Bacterial Species' -Gene $row.'Gene / Operon' -Promoter $row.Promoter
        $key = "{0}|{1}|{2}|{3}" -f $row.Molecule, $row.Promoter, $row.'Gene / Operon', $species
        if ($seen.Add($key)) {
            if (-not $optionsByMolecule.ContainsKey($row.Molecule)) {
                $optionsByMolecule[$row.Molecule] = New-Object 'System.Collections.Generic.List[object]'
            }
            $optionsByMolecule[$row.Molecule].Add([pscustomobject]@{
                Promoter = [string]$row.Promoter
                Gene = [string]$row.'Gene / Operon'
                Species = $species
                Mechanism = 'Direct sensing'
                Trigger = Get-DirectResponseTrigger -Molecule $row.Molecule -Promoter $row.Promoter -Gene $row.'Gene / Operon'
                Reference = [string]$row.Reference
            })
        }
    }

    $indirectRows = @(Import-Csv -Path $skill3Csv | Where-Object { $_.'Gene / Operon' -notlike 'NO STRONG*' })
    foreach ($row in $indirectRows | Sort-Object Molecule,Promoter) {
        if (-not $stateMap.ContainsKey($row.Molecule)) {
            continue
        }
        $species = Normalize-BacterialSpecies -Species $row.'Bacterial Species' -Gene $row.'Gene / Operon' -Promoter $row.Promoter
        $key = "{0}|{1}|{2}|{3}" -f $row.Molecule, $row.Promoter, $row.'Gene / Operon', $species
        if ($seen.Add($key)) {
            if (-not $optionsByMolecule.ContainsKey($row.Molecule)) {
                $optionsByMolecule[$row.Molecule] = New-Object 'System.Collections.Generic.List[object]'
            }
            $optionsByMolecule[$row.Molecule].Add([pscustomobject]@{
                Promoter = [string]$row.Promoter
                Gene = [string]$row.'Gene / Operon'
                Species = $species
                Mechanism = 'Indirect sensing'
                Trigger = if ([string]::IsNullOrWhiteSpace([string]$row.'Indirect Consequence')) { "indirect condition linked to $($row.Molecule)" } else { [string]$row.'Indirect Consequence' }
                Reference = [string]$row.Reference
            })
        }
    }

    foreach ($molecule in ($stateMap.Keys | Sort-Object { [int]$candidateMap[$_][0] })) {
        if (-not $optionsByMolecule.ContainsKey($molecule)) {
            $mainTableRows += ,@($molecule, "No retained route", "-", "-", $stateMap[$molecule], "-")
            continue
        }
        $scoredOptions = @()
        foreach ($option in $optionsByMolecule[$molecule]) {
            $matchKey = "{0}|{1}|{2}" -f $option.Species, $option.Gene, $option.Promoter
            $rankLookupKey = "{0}|{1}|{2}|{3}" -f $molecule, $option.Species, $option.Gene, $option.Promoter
            $scoredOptions += [pscustomobject]@{
                Promoter = $option.Promoter
                Gene = $option.Gene
                Species = $option.Species
                Mechanism = $option.Mechanism
                Trigger = $option.Trigger
                Reference = $option.Reference
                MatchKey = $matchKey
                HasSkill4Rank = $skill5RankMap.ContainsKey($rankLookupKey)
                Skill4Rank = if ($skill5RankMap.ContainsKey($rankLookupKey)) { $skill5RankMap[$rankLookupKey] } else { 999 }
                ReferenceScore = Get-ReferenceStrengthScore -ReferenceText $option.Reference
                MechanismScore = if ($option.Mechanism -eq 'Direct sensing') { 1 } else { 0 }
            }
        }

        $bestOptionsPerGroup = @()
        $optionGroups = @(
            $scoredOptions | Group-Object {
                $signalKey = if ($_.Mechanism -eq 'Indirect sensing') {
                    Get-CompactSenseLabel -Trigger $_.Trigger
                }
                else {
                    '__direct__'
                }
                "{0}|{1}|{2}" -f $_.Species, $_.Mechanism, $signalKey
            }
        )
        foreach ($group in $optionGroups) {
            $bestOptionsPerGroup += @(
                $group.Group | Sort-Object `
                    @{ Expression = 'HasSkill4Rank'; Descending = $true }, `
                    @{ Expression = 'Skill4Rank'; Descending = $false }, `
                    @{ Expression = 'ReferenceScore'; Descending = $true }, `
                    @{ Expression = 'MechanismScore'; Descending = $true }, `
                    Promoter, Gene | Select-Object -First 1
            )
        }

        $sortedOptions = @(
            $bestOptionsPerGroup | Sort-Object `
                @{ Expression = 'HasSkill4Rank'; Descending = $true }, `
                @{ Expression = 'Skill4Rank'; Descending = $false }, `
                @{ Expression = 'ReferenceScore'; Descending = $true }, `
                @{ Expression = 'MechanismScore'; Descending = $true }, `
                Promoter, Gene
        )
        $geneLines = New-Object 'System.Collections.Generic.List[string]'
        $organismLines = New-Object 'System.Collections.Generic.List[string]'
        $senseLines = New-Object 'System.Collections.Generic.List[string]'
        $referenceLines = New-Object 'System.Collections.Generic.List[string]'
        for ($i = 0; $i -lt $sortedOptions.Count; $i++) {
            $option = $sortedOptions[$i]
            $referenceLabel = Get-ReferenceLabel -ReferenceText $option.Reference -Catalog $catalog -NumberMap $numberMap -OrderedTokens $orderedTokens
            $prefix = if ($sortedOptions.Count -gt 1) { "{0}. " -f ($i + 1) } else { "" }
            $geneLines.Add(("{0}{1}" -f $prefix, $option.Gene))
            $organismLines.Add(("{0}{1}" -f $prefix, (Get-ShortOrganismName -Species $option.Species)))
            $senseLines.Add(("{0}{1}" -f $prefix, (Get-CompactSenseLabel -Trigger $option.Trigger)))
            $referenceLines.Add(("{0}{1}" -f $prefix, $referenceLabel))
        }
        $mainTableRows += ,@(
            $molecule,
            ($geneLines -join "`n"),
            ($organismLines -join "`n"),
            ($senseLines -join "`n"),
            $stateMap[$molecule],
            ($referenceLines -join "`n")
        )
    }

    $blocks = @()
    $blocks += (New-ParagraphBlock -Text "Skills 2 and 3 Results" -Bold $true)
    $blocks += (New-ParagraphBlock -Text "Data sources used" -Bold $true -KeepNext $true)
    $blocks += (New-ParagraphBlock ("- Folder files: latest Skill 1 results plus archived Skill 2 and Skill 3 mapping tables. {0}" -f (Get-KnowledgeFolderContextText -Root $OutputRootPath)))
    $blocks += (New-ParagraphBlock "- Articles used: direct promoter papers, regulon studies, and consequence-response papers cited in the current run.")
    $blocks += (New-ParagraphBlock -Text "Strategy applied" -Bold $true -KeepNext $true)
    $blocks += (New-ParagraphBlock "- Comparison emphasis: passed Stage 1 molecules only, using the current retained direct and indirect mapping tables.")
    $blocks += (New-ParagraphBlock "- Biological layers: direct sensing, metal starvation, iron limitation, HOCl stress, nitric oxide, bile stress, and the newly retained chemistry branch from this run.")
    $blocks += (New-ParagraphBlock -Text "What's new" -Bold $true -KeepNext $true)
    foreach ($bullet in $skill23WhatsNewBullets) {
        $blocks += (New-ParagraphBlock $bullet)
    }
    $blocks += (New-ParagraphBlock -Text "What was FIXED or corrected" -Bold $true -KeepNext $true)
    $blocks += (New-ParagraphBlock "- Same-strain duplicate direct or indirect options were collapsed to one retained option per branch while keeping distinct indirect consequence types separate.")
    $blocks += (New-ParagraphBlock -Text "Filtering / ranking logic" -Bold $true -KeepNext $true)
    $blocks += (New-ParagraphBlock "- One row per molecule, with within-cell ranked options ordered by retained candidate rank, source strength, and mechanism clarity.")
    $blocks += (New-ParagraphBlock -Text "Anti-repetition action" -Bold $true -KeepNext $true)
    $blocks += (New-ParagraphBlock "- The rerun changed the chemistry search angle instead of repeating the previous branch unchanged.")
    $blocks += (New-ParagraphBlock -Text "Main results" -Bold $true -KeepNext $true)
    $blocks += (New-TableBlock $mainTableRows)
    $blocks += (New-ParagraphBlock -Text "Run notes" -Bold $true -KeepNext $true)
    $blocks += (New-ParagraphBlock "- New: promoter- and branch-level additions for this run are listed above in `What's new`.")
    $blocks += (New-ParagraphBlock "- Change: the main summary still keeps one retained best promoter per molecule while the detailed mapping preserves ranked alternatives.")
    $unsupported = @($stateMap.Keys | Where-Object { -not $optionsByMolecule.ContainsKey($_) })
    if ($unsupported.Count -gt 0) {
        $blocks += (New-ParagraphBlock ("- Coverage gap carried forward in this export: {0}." -f ($unsupported -join ", ")))
    }
    $blocks += Get-ReferenceBlocks -Catalog $catalog -NumberMap $numberMap -OrderedTokens $orderedTokens
    return $blocks
}

function Get-Skill4Blocks {
    param([string]$RunFolder)
    $structuredEntries = @(Get-Skill4StructuredEntries -RunFolder $RunFolder)
    $csvPath = Get-Skill4CsvPath -RunFolder $RunFolder
    if ($structuredEntries.Count -eq 0 -and $null -eq $csvPath) {
        return $null
    }

    $blocks = @()
    $blocks += (New-ParagraphBlock -Text "Skill 4: Promoter Upstream Length Determination" -Bold $true)
    $blocks += (New-ParagraphBlock "Purpose: determine how many nucleotides upstream of the ATG should be retained for each promoter so that the relevant regulation is preserved.")
    $blocks += (New-ParagraphBlock -Text "What was done" -Bold $true)
    $blocks += (New-ParagraphBlock "- Used the retained promoter set from the current Skills 2 and 3 outputs and evaluated each target individually.")
    $blocks += (New-ParagraphBlock "- Applied strict evidence priority: experimental literature first, curated organism databases second, motif-based prediction only as a last fallback.")
    $blocks += (New-ParagraphBlock "- Checked promoter identity, operon context, and promoter-versus-gene mapping before assigning the upstream capture length from the coding start.")
    $blocks += (New-ParagraphBlock -Text "Key takeaways" -Bold $true)
    $blocks += (New-ParagraphBlock "- Every retained promoter still receives a usable upstream recommendation, but exactness now depends explicitly on the evidence tier.")
    $blocks += (New-ParagraphBlock "- Operon structure is treated as mandatory, so promoter boundaries are not assumed to sit directly upstream of every coding sequence.")
    $blocks += (New-ParagraphBlock "- High-confidence calls require direct promoter or TSS evidence; database-backed answers remain medium unless the source is stronger.")
    $blocks += (New-ParagraphBlock "- Prediction-only answers remain usable fallbacks, but they should be treated as approximate capture regions.")
    $blocks += (New-ParagraphBlock -Text "Main results" -Bold $true)
    if ($structuredEntries.Count -gt 0) {
        foreach ($entry in $structuredEntries) {
            $blocks += (New-ParagraphBlock -Text $entry.Title -Bold $true -KeepNext $true -ShadingFill "EEF2FF" -TextColor "1F2937")
            foreach ($field in $entry.Fields) {
                $label = [string]$field[0]
                $value = [string]$field[1]
                if ([string]::IsNullOrWhiteSpace($value)) {
                    $value = "Not stated"
                }
                $blocks += (New-ParagraphBlock -Text ("- {0}: {1}" -f $label, $value) -KeepNext $true)
            }
            $blocks += (New-ParagraphBlock "")
        }
    }
    else {
        $rows = @(Import-Csv -Path $csvPath)
        $tableRows = @(
            ,@("Promoter name", "Recommended upstream length from ATG (bp)", "Confidence level", "Length basis")
        )
        foreach ($row in $rows) {
            $promoterName = if ($row.PSObject.Properties['Promoter name']) { [string]$row.PSObject.Properties['Promoter name'].Value } else { "" }
            $upstreamLength = if ($row.PSObject.Properties['Recommended upstream length from ATG (bp)']) { [string]$row.PSObject.Properties['Recommended upstream length from ATG (bp)'].Value } else { "" }
            $confidenceLevel = if ($row.PSObject.Properties['Confidence level']) { [string]$row.PSObject.Properties['Confidence level'].Value } else { "" }
            $tableRows += ,@(
                $promoterName,
                $upstreamLength,
                $confidenceLevel,
                (Get-Skill4LengthBasis -PromoterName $promoterName -ConfidenceLevel $confidenceLevel)
            )
        }
        $blocks += (New-TableBlock -Rows $tableRows -HeaderFill "D9E2F3" -AlternateRowFill "F7F9FC" -ColumnWidths @(1900, 1600, 1200, 4600))
    }
    $blocks += (New-ParagraphBlock -Text "Coverage gaps" -Bold $true)
    $blocks += (New-ParagraphBlock "- Promoters with `Low` confidence still need direct promoter or TSS mapping, especially when the current answer depends on motif-based fallback logic.")
    $blocks += (New-ParagraphBlock "- Operon-linked targets still need extra care during cloning because the biologically correct promoter may sit upstream of another gene.")
    $blocks += (New-ParagraphBlock -Text "References" -Bold $true)
    $blocks += (New-ParagraphBlock "- References for this stage are carried inside the per-target source fields in the Stage 4 report and in the compact downstream CSV handoff.")
    $blocks += (New-ParagraphBlock -Text "Run notes" -Bold $true)
    $blocks += (New-ParagraphBlock "- Fixed: Skill 4 now exports the upstream-length stage instead of accidentally reading the old ranking-stage path.")
    $blocks += (New-ParagraphBlock "- Change: future Skill 4 reports keep promoter-level evidence fields instead of collapsing the whole stage into only a three-column summary.")
    return $blocks
}

function Get-Skill5Blocks {
    param([string]$RunFolder)
    $csvPath = Get-Skill5CsvPath -RunFolder $RunFolder
    if ($null -eq $csvPath) {
        return $null
    }

    $rows = @(Import-Csv -Path $csvPath | Sort-Object { [int]$_.Rank })
    $stateMap = Get-Skill1PassedStateMap -RunFolder $RunFolder
    $catalog = Get-ReferenceCatalog
    $numberMap = @{}
    $orderedTokens = New-Object 'System.Collections.Generic.List[string]'
    $newRunBullets = @(Get-Skill23NewRunBullets -RunFolder $RunFolder)
    $recommendations = Get-Skill4RecommendationLines -Rows $rows
    $blocks = @()
    $blocks += (New-ParagraphBlock -Text "Skill 5 Final Ranking Report" -Style "Title" -Align "center" -SpaceAfter 120)
    $blocks += (New-ParagraphBlock -Text "Autogenerated analytical report" -Style "Subtitle" -Align "center" -SpaceAfter 240)
    $blocks += (New-ParagraphBlock -Text "Executive Summary" -Style "Heading1")
    $blocks += (New-ParagraphBlock -Text ("Date of run: {0}" -f (Get-RunDate $RunItem.Name)) -Bold $true)
    $blocks += (New-ParagraphBlock -Text "Purpose: rank the strongest stool-linked detector systems for distinguishing IBD from IBS using human biomarker evidence, marker-to-signal linkage, detector quality, and promoter-region deployability.")
    $blocks += (New-ParagraphBlock -Text "Top 3 ranked systems" -Style "Heading3")
    $blocks += (New-TableBlock -Rows (Get-Skill4TopSystemsTable -Rows $rows) -HeaderFill "D9E2F3" -AlternateRowFill "F7F9FC" -ColumnWidths @(1100, 3300, 2300, 4700, 1400))
    $blocks += (New-ParagraphBlock -Text "Key takeaways" -Style "Heading3")
    $blocks += (New-ParagraphBlock -Text "- Ranking now weights human biomarker evidence, marker-to-signal linkage, and detector quality separately rather than blending them into one loose score.")
    $blocks += (New-ParagraphBlock -Text "- Star ratings run from `★★★★★` to `★☆☆☆☆` and reflect the final rank tier across the full panel.")
    $blocks += (New-ParagraphBlock -Text "- Zinc-starvation routes linked to `S100A12` and `calprotectin` stay near the top because the host-marker evidence is strong and the biological linkage is tight.")
    $blocks += (New-ParagraphBlock -Text "- Unstable transient chemistries remain visible when biologically important, but they are penalized when the readout is unlikely to persist in stool long enough for reliable sensing.")
    $blocks += (New-ParagraphBlock -Text "- Promoter-region confidence and the practicality of the retained upstream capture now contribute to the detector-quality layer.")
    $blocks += (New-ParagraphBlock -Text ("- {0}" -f (Get-ComparisonFreeBulletText -Bullet $newRunBullets[0])))
    $blocks += (New-ParagraphBlock -Text "Major coverage gaps or limitations" -Style "Heading3")
    $blocks += (New-ParagraphBlock -Text "- `BAFF` and `MMP-9` remain strong stool markers without retained promoter systems.")
    $blocks += (New-ParagraphBlock -Text "- IBS-side chemistry is still less mature than the IBD-high inflammatory layer.")
    $blocks += (New-ParagraphBlock -Text "- Several useful systems remain indirect or proxy readouts rather than direct sensing of the original host marker.")
    $blocks += (New-ParagraphBlock -Text "- Cross-reactivity testing is still needed for several retained chemistry branches.")
    $blocks += (New-PageBreakBlock)

    $blocks += (New-ParagraphBlock -Text "How the ranking works" -Style "Heading1")
    $blocks += (New-ParagraphBlock -Text "- Layer 1: human biomarker evidence strength, including IBD-vs-IBS separation and consistency across patients.")
    $blocks += (New-ParagraphBlock -Text "- Layer 2: marker-to-signal biological linkage, favoring direct sensing and first-order consequences over broad stress proxies.")
    $blocks += (New-ParagraphBlock -Text "- Layer 3: detector quality, including stability in stool, persistence window, specificity, promoter behavior, concentration plausibility, exact-strain evidence, and promoter-region deployability.")
    $blocks += (New-ParagraphBlock -Text "- Promoter availability is an inclusion rule, not a major ranking advantage by itself.")

    $blocks += (New-ParagraphBlock -Text "Ranking Summary Table" -Style "Heading1")
    $blocks += (New-TableBlock -Rows (Get-Skill4SummaryTable -Rows $rows) -HeaderFill "D9E2F3" -AlternateRowFill "F7F9FC" -ColumnWidths @(1000, 2200, 2200, 2600, 1200, 1200, 1200, 1400, 1400))

    $blocks += (New-ParagraphBlock -Text "Detailed Ranked Candidates" -Style "Heading1")
    $blocks += (New-ParagraphBlock -Text "Top Tier Candidates" -Style "Heading2" -ShadingFill "E6F4EA" -TextColor "1F4D2E" -PageBreakBefore $true)

    foreach ($row in $rows) {
        $rank = [int]$row.Rank
        if ($rank -eq 6) {
            $blocks += (New-ParagraphBlock -Text "Remaining Ranked Candidates" -Style "Heading2" -ShadingFill "EEF2FF" -TextColor "1F2937" -PageBreakBefore $true)
        }

        $state = if ($stateMap.ContainsKey($row.Molecule)) { $stateMap[$row.Molecule] } else { Format-DiseaseState -RawState ([string]$row.'Disease Association') }
        $candidateSignal = Get-Skill4CandidateSignal -Row $row
        $mechanismLabel = Get-Skill4MechanismLabel -MechanismType ([string]$row.'Mechanism Type')
        $stabilityAssessment = Get-Skill4StabilityAssessment -Row $row
        $specificityAssessment = Get-Skill4SpecificityAssessment -Row $row
        $mechanisticRationale = Get-Skill4MechanisticRationale -Row $row
        $upstreamLength = Get-Skill5UpstreamLength -Row $row
        $upstreamConfidence = Get-Skill5UpstreamConfidence -Row $row
        $mainLimitations = if ($row.PSObject.Properties.Name -contains 'Main Limitations / Penalties' -and -not [string]::IsNullOrWhiteSpace([string]$row.'Main Limitations / Penalties')) { [string]$row.'Main Limitations / Penalties' } else { [string]$row.Notes }
        $refLabel = Get-ReferenceLabel -ReferenceText ([string]$row.Reference) -Catalog $catalog -NumberMap $numberMap -OrderedTokens $orderedTokens

        $previousRow = $null
        $previousState = ""
        if ($rank -gt 1) {
            $previousRow = $rows[$rank - 2]
            $previousState = if ($stateMap.ContainsKey($previousRow.Molecule)) { $stateMap[$previousRow.Molecule] } else { Format-DiseaseState -RawState ([string]$previousRow.'Disease Association') }
        }
        $nextRow = $null
        $nextState = ""
        if ($rank -lt $rows.Count) {
            $nextRow = $rows[$rank]
            $nextState = if ($stateMap.ContainsKey($nextRow.Molecule)) { $stateMap[$nextRow.Molecule] } else { Format-DiseaseState -RawState ([string]$nextRow.'Disease Association') }
        }
        $rankingExplanation = if ($row.PSObject.Properties.Name -contains 'Why it received this ranking' -and -not [string]::IsNullOrWhiteSpace([string]$row.'Why it received this ranking')) {
            [string]$row.'Why it received this ranking'
        } else {
            Get-Skill4RankingExplanation -Row $row -State $state -SenseLabel $candidateSignal -PreviousRow $previousRow -PreviousState $previousState -NextRow $nextRow -NextState $nextState
        }

        $headingFill = if ($rank -le 5) { "DCEFD8" } else { "F3F4F6" }
        $headingColor = if ($rank -le 5) { "1F4D2E" } else { "1F2937" }
        $displayPromoter = Get-Skill4DisplayPromoter -Promoter ([string]$row.Promoter)
        $blocks += (New-ParagraphBlock -Text ("Rank {0} {1} - {2} -> {3}" -f $rank, (Get-RankStars -Rank $rank -Count $rows.Count), [string]$row.Molecule, $displayPromoter) -Style "Heading2" -KeepNext $true -KeepLines $true -ShadingFill $headingFill -TextColor $headingColor -SpaceAfter 80 -PageBreakBefore ($rank -gt 1))
        if ($rank -le 5) {
            $blocks += (New-ParagraphBlock -Text "Top-tier candidate" -Bold $true -TextColor "1F4D2E" -SpaceAfter 60 -KeepNext $true)
        }

        $factsTable = @(
            ,@("Key field", "Value"),
            ,@("Candidate signal", $candidateSignal),
            ,@("Host marker / disease context", [string]$row.Molecule),
            ,@("Promoter / gene", ("{0} / {1}" -f $displayPromoter, [string]$row.'Gene / Operon')),
            ,@("Strain", (Get-ShortOrganismName -Species ([string]$row.'Bacterial Species'))),
            ,@("Stability", $stabilityAssessment),
            ,@("Specificity", $specificityAssessment),
            ,@("Upstream length", $upstreamLength),
            ,@("Upstream confidence", $upstreamConfidence),
            ,@("Mechanistic rationale", $mechanisticRationale),
            ,@("Reference", $refLabel)
        )
        $blocks += (New-TableBlock -Rows $factsTable -HeaderFill "E5E7EB" -FirstColumnFill "F3F4F6" -ColumnWidths @(3200, 11200))

        $blocks += (New-ParagraphBlock -Text "Why it ranks here" -Style "Heading3" -KeepNext $true)
        foreach ($bullet in (Get-Skill4WhyBullets -Row $row -State $state -CandidateSignal $candidateSignal -MechanismLabel $mechanismLabel -MechanisticRationale $mechanisticRationale -RankingExplanation $rankingExplanation)) {
            $blocks += (New-ParagraphBlock -Text ("- {0}" -f $bullet) -KeepNext $true)
        }

        $blocks += (New-ParagraphBlock -Text "Strengths" -Style "Heading3" -KeepNext $true)
        foreach ($bullet in (Get-Skill4StrengthBullets -Row $row -StabilityAssessment $stabilityAssessment -SpecificityAssessment $specificityAssessment)) {
            $blocks += (New-ParagraphBlock -Text ("- {0}" -f $bullet) -KeepNext $true)
        }

        $limitationBullets = @(Get-Skill4LimitationBullets -Row $row -MainLimitations $mainLimitations -MechanismLabel $mechanismLabel)
        $blocks += (New-ParagraphBlock -Text "Main limitations" -Style "Heading3" -KeepNext $true)
        for ($i = 0; $i -lt $limitationBullets.Count; $i++) {
            $keepNext = ($i -lt ($limitationBullets.Count - 1))
            $blocks += (New-ParagraphBlock -Text ("- {0}" -f $limitationBullets[$i]) -KeepNext $keepNext)
        }
    }

    $blocks += (New-ParagraphBlock -Text "Coverage Gaps" -Style "Heading1")
    $blocks += (New-ParagraphBlock -Text "- `BAFF` and `MMP-9` still need new promoter discovery.")
    $blocks += (New-ParagraphBlock -Text "- IBS-side routes still need stronger direct stool evidence than the current amino-acid, polyamine, and bile-stress branches.")
    $blocks += (New-ParagraphBlock -Text "- Some retained top-half systems still report a durable consequence rather than the original host marker itself.")

    $blocks += (New-ParagraphBlock -Text "Recommended Next Actions" -Style "Heading1")
    $blocks += (New-ParagraphBlock -Text ("- Best candidates for experimental validation: {0}." -f $recommendations.Experimental))
    $blocks += (New-ParagraphBlock -Text ("- Best candidates for direct sensing: {0}." -f $recommendations.Direct))
    $blocks += (New-ParagraphBlock -Text ("- Best candidates for stable stool detection: {0}." -f $recommendations.Stable))
    $blocks += (New-ParagraphBlock -Text "- Main unresolved gaps requiring new promoter discovery: BAFF, MMP-9, and stronger IBS-side direct-sensing systems.")

    $blocks += (New-ParagraphBlock -Text "Run notes" -Style "Heading1")
    foreach ($bullet in $newRunBullets | Select-Object -First 3) {
        $blocks += (New-ParagraphBlock -Text $bullet)
    }
    $blocks += (New-PageBreakBlock)
    $blocks += Get-ReferenceBlocks -Catalog $catalog -NumberMap $numberMap -OrderedTokens $orderedTokens
    return $blocks
}

$runDate = Get-RunDate $RunItem.Name
$outputDir = Get-OutputDir -Root $OutputRootPath -RunDate $runDate
$completed = Get-CompletedSkills -RunFolder $RunPath

$targetFiles = @(
    (Join-Path $outputDir "Skill1.docx"),
    (Join-Path $outputDir "Skill1_updated.docx"),
    (Join-Path $outputDir "Skill2.docx"),
    (Join-Path $outputDir "Skill3.docx"),
    (Join-Path $outputDir "Skill2_3.docx"),
    (Join-Path $outputDir "Skills2_3.docx"),
    (Join-Path $outputDir "Skills2_3_updated.docx"),
    (Join-Path $outputDir "Skill4.docx"),
    (Join-Path $outputDir "Skill4_updated.docx"),
    (Join-Path $outputDir "Skill5.docx"),
    (Join-Path $outputDir "Skill5_updated.docx")
)
foreach ($file in $targetFiles) {
    if (Test-Path $file) {
        try {
            Remove-Item $file -Force -ErrorAction Stop
        }
        catch {
        }
    }
}

if ($completed.Skill1) {
    $skill1Path = Get-WritableDocxPath -Path (Join-Path $outputDir "Skill1.docx")
    Write-Docx -Path $skill1Path -Blocks (Get-Skill1Blocks -RunFolder $RunPath) -DocumentTitle "IBD vs IBS Marker Finder - Skill 1" -RunDate $runDate
}

if ($completed.Skill23) {
    $skill23Blocks = Get-Skill23Blocks -RunFolder $RunPath
    if ($null -ne $skill23Blocks) {
        $skill23Path = Get-WritableDocxPath -Path (Join-Path $outputDir "Skills2_3.docx")
        Write-Docx -Path $skill23Path -Blocks $skill23Blocks -DocumentTitle "IBD vs IBS Marker Finder - Skills 2 and 3" -RunDate $runDate
    }
}

if ($completed.Skill4) {
    $skill4Blocks = Get-Skill4Blocks -RunFolder $RunPath
    if ($null -ne $skill4Blocks) {
        $skill4Path = Get-WritableDocxPath -Path (Join-Path $outputDir "Skill4.docx")
        Write-Docx -Path $skill4Path -Blocks $skill4Blocks -DocumentTitle "IBD vs IBS Marker Finder - Skill 4 Promoter Upstream Length Determination" -RunDate $runDate
    }
}

if ($completed.Skill5) {
    $skill5Blocks = Get-Skill5Blocks -RunFolder $RunPath
    if ($null -ne $skill5Blocks) {
        $skill5Path = Get-WritableDocxPath -Path (Join-Path $outputDir "Skill5.docx")
        Write-Docx -Path $skill5Path -Blocks $skill5Blocks -DocumentTitle "IBD vs IBS Marker Finder - Skill 5 Final Ranking Report" -RunDate $runDate -PageWidth 15840 -PageHeight 12240 -MarginTop 900 -MarginRight 720 -MarginBottom 900 -MarginLeft 720
    }
}

Write-Output $outputDir
