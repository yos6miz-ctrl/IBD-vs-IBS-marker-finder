---
name: indirect-response
description: Identify indirect bacterial sensing opportunities for stool-associated molecules by linking each molecule to a scientifically supported secondary physiological consequence and then mapping bacterial genes, operons, promoters, and regulators that respond to that consequence. Use when direct sensing is weak or unknown and the user wants indirect-response biosensor candidates for IBD vs IBS stool markers.
---

# Indirect Response

Perform the indirect-response mapping stage for stool biomarker candidates.

## Goal

Find bacterial sensing opportunities where the original stool-associated molecule is not necessarily sensed directly, but instead creates a secondary physiological condition that bacteria can detect.

Examples of valid logic:

- calprotectin -> metal sequestration -> iron or zinc starvation -> metal-responsive promoters
- lipocalin -> iron restriction or siderophore stress -> iron acquisition genes
- inflammatory metabolites -> oxidative or nitrosative stress -> stress-response promoters
- bile or detergent-like molecules -> membrane or envelope stress -> envelope-stress systems

## Direct vs Indirect Rule

- `Direct response`: the molecule itself is sensed by a dedicated regulator or signaling system.
- `Indirect response`: the molecule causes a secondary physiological consequence, and bacteria respond to that consequence.

Only include mappings in this skill if they truly follow the indirect-response logic.

Do not re-label direct sensing systems as indirect systems.
Before keeping any indirect route, read the source and extract what the promoter actually responds to, not just the biomarker of interest.
The previously trialed probiotic chassis and its discarded zinc-starvation calprotectin route are globally excluded from this project.
Do not retain the discarded legacy zinc-starvation reporter route in indirect-response outputs.

## Input Discovery

- Start from the latest Skill 1 molecule list.
- Prefer the dedicated Skill 1 folder `skill_1_stool-data-analyzer/`.
- If that folder does not exist but `skill_1_stool-deta-analyzer/` does, use the typo variant as a fallback.
- Find the most recent file matching `YYYY-MM-DD_stool-data-analyzer.md`.
- Read it carefully and extract the molecules selected for further analysis.
- Optionally use Skill 2 outputs as cross-reference material, but keep Skill 1 as the primary input source.
- If no Skill 1 result file exists, stop and tell the user that Skill 1 must run first.

## Allowed Indirect Consequences

Evaluate whether each molecule can create a supported secondary condition such as:

- iron starvation
- zinc starvation
- other metal limitation
- oxidative stress
- nitrosative stress
- membrane stress
- envelope stress
- DNA damage
- redox imbalance
- osmotic stress
- pH stress
- carbon limitation
- nitrogen limitation
- sulfur limitation
- amino acid starvation
- toxic metabolite stress
- host inflammatory environment mimics

Infer these links only when supported by scientific evidence.

## Host Constraints

Focus on genetically tractable bacteria, prioritizing:

- Escherichia coli
- Pseudomonas aeruginosa PAO1
- Pseudomonas putida
- Bacillus subtilis
- other realistically engineerable bacteria when needed
- Search exhaustively across relevant retained laboratory strains for every molecule-consequence pair, including `K12`, `PAO1`, and `KT2440` when source-backed biology exists.
- Do not stop after the first valid organism or consequence-responsive system.
- If multiple valid laboratory-strain options exist for the same indirect consequence, keep all distinct downstream signals, but retain only the single best promoter for each molecule-consequence-species combination.
- Rank that retained promoter in this order: response strength, sensitivity, specificity, then evidence or validation quality.

Prefer systems that are useful for biosensor engineering.

## Research Scope

Search as broadly as possible across:

- microbiology papers
- molecular genetics papers
- transcriptomics studies
- proteomics studies
- metal starvation studies
- stress response literature
- regulatory network databases
- host-pathogen interaction studies
- systems biology studies

Useful source types include:

- PubMed
- Google Scholar
- RegulonDB
- EcoCyc
- KEGG
- Pseudomonas databases
- primary research articles
- reviews as supporting sources, not as the only evidence when primary evidence is available

## Research Workflow

### 1. Build the input molecule list

- Extract every candidate molecule from the most recent Skill 1 result file.
- Keep original molecule names visible in the final outputs.
- Use synonyms only to broaden the literature search.

### 2. Evaluate indirect physiological effects

For each molecule:

- determine whether it can cause a secondary physiological consequence that bacteria may sense
- require scientific support for the proposed link
- discard purely speculative consequence chains

### 3. Map bacterial response systems

For each supported molecule -> consequence pair, identify:

- bacterial species
- gene or operon
- promoter
- regulatory protein or regulatory system
- response type:
  - activation
  - repression
- evidence type
- reference

Look across:

- regulons
- transcription factors
- stress response systems
- metabolic sensors
- two-component systems
- sigma factor programs
- consequence-responsive operons
- parallel consequence-readout options in multiple organisms, not just the first convincing route
- only one retained promoter per molecule-consequence-species branch after within-species ranking by response strength, sensitivity, specificity, then evidence or validation quality

### 4. Filter weak or unrelated links

Remove links that are:

- unsupported by literature
- merely generic stress responses without a clear molecule-to-consequence connection
- actually direct sensing events instead of indirect ones
- too speculative for biosensor design

### 5. Mark molecules with no strong indirect candidate

If a molecule has no well-supported indirect-response system after an expanded search, keep it in the final dataset and mark it clearly as:

`NO STRONG INDIRECT BACTERIAL RESPONSE FOUND`

### 6. Expand and repeat when coverage is incomplete

If results are sparse or important cases appear to be missing:

1. broaden search terms using synonyms and mechanism words
2. search stress-specific and metal-homeostasis literature
3. search transcriptomic and proteomic datasets
4. search additional tractable bacterial hosts

Repeat until the analysis is as complete as reasonably possible.

## Output Storage

- Maintain a dedicated Skill 3 results folder at `skill_3_indirect_response/`.
- For each run, create a dated subfolder:
  - `skill_3_indirect_response/YYYY-MM-DD/`
- Save both required output files inside that dated subfolder.
- Also preserve a per-run archive snapshot under:
  - `skill_3_indirect_response/archive/<research_run_folder>/`
- Also contribute to the combined Skills 2 and 3 Word summary for the run under:
  - `C:\Users\Popovtzer lab\.codex\IBD vs IBS marker finder\<date_folder>\Skills2_3.docx`
- Use the local exporter script:
  - `tools/export_skill_docs.ps1`
- If an active project run folder already exists, also update downstream artifacts there when appropriate.

## Required Output Files

### File 1: Research Summary

Create:

`YYYY-MM-DD_indirect_response_summary.md`

This file must contain:

#### 1. Data sources used

- folder files used
- article types used

#### 2. Strategy applied

- which indirect consequences were emphasized
- which organisms were searched and how completeness across valid laboratory strains was checked
- how weak chains were rejected

#### 3. What was NEW in this run

- new consequence types checked
- new promoters added
- new molecule classes explored

#### 4. What was FIXED or corrected

- direct versus indirect corrections
- misannotations removed
- unsupported chains removed

#### 5. Filtering / ranking logic

- how molecule-to-consequence links were accepted
- how specificity and tractability were weighted

#### 6. Anti-repetition action

- what changed to avoid repeating prior outputs

#### 7. Key Findings

Summarize:

- which molecules produced strong indirect sensing hypotheses
- which indirect mechanisms were most promising
- which bacterial systems seem most useful for biosensor design

#### 8. Validation Note

State clearly that each retained bacterial response was checked for linkage to a secondary physiological consequence of the molecule, not just to a general unrelated stress response.

### File 2: Indirect Response Mapping Table

Create:

`YYYY-MM-DD_indirect_response_mapping.csv`

Required columns:

Molecule,Indirect Consequence,Bacterial Species,Gene / Operon,Promoter,Regulatory Protein / System,Response Type,Evidence Type,Reference,Notes

Column meanings:

- `Molecule`: the original stool-associated molecule from Skill 1
- `Indirect Consequence`: the secondary condition caused by the molecule
- `Bacterial Species`: the organism in which the response system was identified
- `Gene / Operon`: the responding gene or operon
- `Promoter`: the promoter associated with that response
- `Regulatory Protein / System`: the transcription factor, sigma factor, two-component system, or other regulator involved
- `Response Type`: `Activation` or `Repression`
- `Evidence Type`: for example `Transcriptomics`, `Proteomics`, `Genetic study`, `Promoter study`, or `Regulatory study`
- `Reference`: PMID, DOI, or paper citation
- `Notes`: a short explanation of the indirect link

For molecules without a strong supported system, still include them and mark them clearly as `NO STRONG INDIRECT BACTERIAL RESPONSE FOUND`.

For human-readable tables and doc exports, use compact organism labels such as `K12`, `PAO1`, and `B. subtilis`, and keep mechanism labels to `2-5` words when possible.

## Internal Validation

Before finishing:

- confirm that every candidate molecule from Skill 1 was evaluated
- confirm that each retained result reflects an indirect mechanism rather than a direct sensing event
- remove weak or speculative links that are not sufficiently supported
- mark important molecules with no strong candidate as `NO STRONG INDIRECT BACTERIAL RESPONSE FOUND`

## Final Goal

Produce a high-quality list of indirect bacterial promoter candidates that could be used in engineered biosensors to detect disease-associated stool environments, especially when the original molecule is not directly sensed but creates a measurable physiological condition.

## Stopping Rule

After saving the summary file and the mapping table, stop and wait for the user before continuing.
