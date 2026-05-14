---
name: stool-data-analyzer
description: Perform deep scientific research on stool-detectable molecules that differentiate IBD from IBS and produce a ranked Stage 1 candidate list for biosensor-oriented discovery workflows. Use when the user wants comprehensive stool biomarker mining, differential molecule discovery, or a literature-backed list of stool markers distinguishing IBD vs IBS.
---

# Stool Data Analyzer

Perform the Stage 1 discovery pass for IBD vs IBS stool markers.

## Goal

Identify biological or chemical molecules present in human stool whose levels differ between inflammatory bowel disease and irritable bowel syndrome.

Include molecules that are:

- higher in IBD than IBS
- higher in IBS than IBD
- useful through concentration ratios or multivariate concentration patterns

Cover both established stool biomarkers and less-known or emerging candidates.

## Operating Rules

- Focus on molecules detectable in stool or feces.
- Prioritize direct IBD vs IBS evidence over disease-vs-healthy evidence.
- Prefer human stool data over serum, tissue, or animal-only findings.
- Use multiple scientific source types and cite each candidate with specific references.
- Prefer peer-reviewed primary literature, systematic reviews, and meta-analyses.
- Never invent biomarkers, effect directions, or references.
- Keep table entries compact; move long explanation outside tables.
- Treat this skill as a Stage 1 specialist and stop after Stage 1 outputs are saved.

Direct IBD-vs-IBS stool evidence is preferred, but it is not the only acceptable entry route into Stage 1. A molecule may still enter the Stage 1 pool when it shows a strong and biologically coherent increase or decrease relative to healthy controls in one disease state, as long as the signal is stool-detectable and relevant to later detector design.

## Run Folder Behavior

- If an active run folder is already established in the current task, reuse it.
- Otherwise create a new folder under `research_runs/` using `YYYY-MM-DD_IBD_IBS_run`.
- If that exact folder already exists, create the next available suffixed variant instead of overwriting prior runs.
- Save Stage 1 outputs immediately to:
  - `stage1_candidates.md`
  - `stage1_summary.md`
  - `run_summary.md`
- Also maintain a dedicated Skill 1 results folder at `skill_1_stool-data-analyzer/`.
- At the end of each Skill 1 research run, create or update a dated summary file in that folder named `YYYY-MM-DD_stool-data-analyzer.md`.
- Also preserve a per-run archive snapshot under:
  - `skill_1_stool-data-analyzer/archive/<research_run_folder>/YYYY-MM-DD_stool-data-analyzer.md`
- This archive snapshot is required when multiple runs occur on the same date, so historical skill outputs are not lost.
- Also export a human-readable Word summary for the run under:
  - `C:\Users\Popovtzer lab\.codex\IBD vs IBS marker finder\YYYY-MM-DD\Skill1.docx`
- Use the local exporter script:
  - `tools/export_skill_docs.ps1`

Ensure `stage1_summary.md` includes a section titled `Suggestions for improvement`.

## Research Workflow

### 1. Search broadly across source types

Search across as many relevant scientific sources as available, including:

- peer-reviewed scientific papers
- systematic reviews and meta-analyses
- biomedical and clinical biomarker databases
- metabolomics databases and repositories
- microbiome and gastroenterology literature
- conference publications and scientific reports when they add unique biomarker leads

Examples of search surfaces to prioritize when available:

- PubMed
- Google Scholar
- Web of Science
- Scopus
- clinical biomarker databases
- metabolomics repositories
- microbiome datasets

### 2. Expand across molecule classes

Search for stool-detectable candidates across classes such as:

- proteins
- host-derived inflammatory markers
- fecal blood signals
- mucosal-damage signals
- immune-system signals
- enzymes
- metabolites
- microbial metabolites
- lipids
- small molecules
- microbial products
- microbiome dysbiosis signals

Do not restrict the search to a single molecule class.

In practice, the search should keep a strong emphasis on inflammatory biomarkers and metabolomics, but it must also explicitly scan for:

- fecal hemoglobin, heme, occult-blood, and related blood-derived stool signals
- host mucosal-damage markers
- stool immune mediators and antimicrobial effectors
- dysbiosis-linked microbial or host-microbial chemistry patterns

### 3. Extract structured evidence for each candidate

For every candidate molecule, capture:

- molecule name
- synonyms when useful
- molecule type
- direction of change:
  - `IBD up`
  - `IBS up`
  - `ratio or pattern difference`
- biological source:
  - host
  - microbiota
  - diet
  - inflammation-linked mixed origin
- evidence level:
  - primary study
  - systematic review
  - meta-analysis
  - clinical biomarker use
  - database-supported lead
- sample matrix
- stability notes if directly reported
- rationale for discrimination
- caveats or conflicts
- references

### 4. Favor candidates useful for detectors

Prioritize molecules that are:

- detectable in stool
- stable enough for diagnostic or biosensor use
- supported by more than one study when possible
- strongly differentiated between IBD and IBS
- plausible inputs for later bacterial sensing or detector engineering

Also allow a controlled secondary pathway into Stage 1 for molecules that do not yet have direct IBD-vs-IBS head-to-head support but do have:

- clear stool detectability
- a significant and replicated change versus healthy controls in either IBD or IBS
- no strong contradictory stool evidence in the opposite condition
- biologically plausible discriminatory value
- plausible later-stage sensing or biosensor relevance

These molecules may enter the broad Stage 1 pool, but they should usually rank below direct IBD-vs-IBS comparators unless the later evidence is unusually strong.

### 5. Run the mandatory internal self-check

After the first pass, verify whether the candidate set includes established stool biomarkers used in the literature to distinguish IBD from IBS.

Always explicitly check for:

- calprotectin
- lactoferrin
- BAFF
- lipocalin-2
- S100 family stool markers
- defensins
- neopterin
- MMP-related stool markers

If important known biomarkers are missing, assume the search is incomplete. Then:

1. expand the search scope
2. use broader search terms
3. add review papers and biomarker screening studies
4. repeat until both established biomarkers and less-known or emerging candidates are represented

If any mandatory biomarker is still excluded from the final ranked list, state the reason explicitly.

### 6. Apply the normal checklist to optional exploratory molecules

Exploratory molecules such as:

- succinate
- itaconate
- spermidine
- spermine
- ethanolamine

may be considered when they arise naturally in the search, but they do not need to be force-checked in every run.

Include them only if they satisfy the normal Stage 1 checklist strongly enough, especially:

- direct human stool evidence, especially IBD vs IBS when available
- or strong disease-vs-healthy stool evidence with plausible discriminatory value
- stool detectability and plausibility as a real fecal input
- later-stage bacterial sensing feasibility

If one of these exploratory molecules is discussed and then excluded, state the reason clearly rather than implying it was retained.

## Output Format

### Summary

Briefly explain the strongest evidence patterns and the major biomarker classes represented.

### Ranked candidate table

Include columns:

Rank  
Molecule  
Synonyms  
Molecule type  
Direction of change  
Biological source  
Evidence level  
Comparison basis  
Sample matrix  
Stability notes  
References  
Notes

Use `Comparison basis` to distinguish between:

- direct `IBD vs IBS`
- `IBD vs healthy`
- `IBS vs healthy`
- mixed or multigroup evidence

Do not treat these comparison bases as equivalent in ranking.

### Established biomarker check

Provide a short table or checklist showing whether each mandatory known biomarker was:

- included
- excluded with reason
- found only with weak or indirect evidence

### Emerging candidates

List less-known molecules that still have enough signal to justify downstream evaluation.

### Recommended handoff set

Produce a ranked shortlist suitable for downstream stability filtering and detector design.

Aim for a broad candidate pool first, then identify the best handoff set for later stages.

### Dedicated Skill 1 summary file

Every run must also create a file at:

`skill_1_stool-data-analyzer/YYYY-MM-DD_stool-data-analyzer.md`

And every run must also preserve a per-run snapshot copy at:

`skill_1_stool-data-analyzer/archive/<research_run_folder>/YYYY-MM-DD_stool-data-analyzer.md`

And every run must also export:

`C:\Users\Popovtzer lab\.codex\IBD vs IBS marker finder\<date_folder>\Skill1.docx`

This file should be refreshed in the same date folder if the workflow is rerun on that date rather than creating a separate suffixed export folder.

The `Skill1.docx` export should contain only molecules that passed Stage 1 and should include a clean table with exactly these columns:

- `Molecule name`
- `Function`
- `State in disease`

If a molecule does not have a clear and interpretable disease pattern, omit it from the exported table rather than using vague wording. Disease-state text should be explicit, for example `up in IBD vs IBS`.

This file must include the following sections:

#### 1. Data sources used

- folder files used
- articles used or article groups used

#### 2. Strategy applied

- which comparison layers were emphasized
- which biological layers were included
- how the search was widened or narrowed

#### 3. What was NEW in this run

- new molecule classes added
- new comparison emphasis
- new evidence branches checked

#### 4. What was FIXED or corrected

- contradictions resolved
- misannotations corrected
- exclusions or reinstatements explained

#### 5. Filtering / ranking logic

- how candidates were selected
- how direct `IBD vs IBS` evidence was weighted
- how broader evidence was allowed or rejected

#### 6. Anti-repetition action

- what was changed to avoid repeating a prior output pattern

#### 7. Results Table

Include a structured table with at least these columns:

Molecule | Molecule Type | Change Pattern | Disease Association | Biological Source | Evidence Level | Reference

The table may include additional columns, but these seven are required.

For `Skill1.docx`, the `Function` column must use `2-5` words only.

#### 8. Key Findings

Add a short bullet list summarizing:

- the most promising molecules
- molecules that strongly distinguish IBD from IBS
- molecules that appear suitable for diagnostic biosensors

#### 9. Internal Validation Check

Include a short section confirming that the research explicitly checked for known stool biomarkers such as:

- Calprotectin
- Lactoferrin

If known biomarkers were initially missing, state that the search was expanded and rerun before finalizing the results.

## Stopping Rule

After saving the Stage 1 artifacts and the dedicated Skill 1 summary file, stop and wait for the user before continuing to any later-stage analysis.
