---
name: criss-cross
description: Map candidate molecules from Skill 1 stool analysis results to bacterial promoters, operons, and regulatory systems that respond to those molecules in genetically tractable bacteria. Use when the user wants molecule-to-promoter mapping, bacterial sensing research, or a literature-backed promoter shortlist for biosensor design.
---

# Criss-Cross

Perform the promoter-mapping stage for molecules discovered by Skill 1.

## Goal

Connect stool-associated candidate molecules from Skill 1 to bacterial promoters or transcriptional systems that respond to those molecules.

Accept only literature-supported responses where exposure to the molecule causes:

- activation of a gene, promoter, or operon
- repression of a gene, promoter, or operon

## Input Discovery

- Start from the dedicated Skill 1 results folder.
- Prefer `skill_1_stool-data-analyzer/`.
- If that folder does not exist but `skill_1_stool-deta-analyzer/` does, use the typo variant as a fallback.
- Find the most recent file matching `YYYY-MM-DD_stool-data-analyzer.md`.
- Read that file carefully and extract every candidate molecule selected for further analysis.
- Treat those molecules as the required input list for this skill.
- If no Skill 1 result file exists, stop and tell the user that Skill 1 must run first.

## Operating Rules

- Focus on genetically tractable bacteria only.
- Prioritize:
  - Escherichia coli
  - Pseudomonas aeruginosa PAO1
  - Pseudomonas putida
  - Bacillus subtilis
  - other clearly engineerable model bacteria when necessary
- Search exhaustively across relevant retained laboratory strains for every molecule, including `K12`, `PAO1`, and `KT2440` when source-backed biology exists.
- Do not stop after the first valid organism or promoter system.
- If multiple valid laboratory-strain options exist for the same molecule, keep all valid organisms, but retain only the single best promoter for each molecule-species pair.
- Rank that retained promoter in this order: response strength, sensitivity, specificity, then evidence or validation quality.
- For every retained route, anchor the result to one exact promoter and one exact gene or operon name.
- Do not keep ambiguous blended labels such as `geneA / operonB` for a single retained route.
- If a pathway contains both an upstream operon promoter and a weaker internal promoter, retain the one best-supported promoter anchor rather than mixing both into one label.
- When the retained route is operon-based, write the full operon name explicitly, for example `sigV-rsiV-oatA`, `tauABCD`, or `hasR-hasAp`.
- Prefer specific sensing or regulatory systems over vague global stress responses.
- Use scientific literature and curated biology resources to support every claim.
- Never invent promoters, operons, transcription factors, or response directions.
- Before calling any system `Direct`, read the source and confirm what is actually sensed and by what mechanism.
- Only laboratory wild-type strains are allowed in this project. Exclude isolate-derived, probiotic, pathogenic, and clinical strains from retained direct-mapping outputs.
- The previously trialed probiotic chassis and its discarded zinc-starvation calprotectin route are globally excluded from this project.
- If the direct response is supported only in a disallowed strain and no cited laboratory-strain replacement exists, mark the molecule as unsupported in the retained direct table.
- Never keep the discarded legacy calprotectin proxy route as a retained direct system.
- If the molecule is only inferred through a secondary consequence, move it to the indirect-response skill instead of keeping it here.
- Verify that every Skill 1 molecule was analyzed before finishing.

## Research Scope

Search broadly across evidence sources such as:

- microbiology papers
- gene regulation studies
- transcriptomics datasets
- proteomics studies
- metabolite response studies
- regulatory network databases
- bacterial sensing system literature
- metabolic regulation studies
- synthetic biology literature

Useful search surfaces include:

- PubMed
- Google Scholar
- RegulonDB
- EcoCyc
- KEGG
- Pseudomonas genome databases
- microbial transcriptome studies
- systems biology studies

## Research Workflow

### 1. Build the molecule list from Skill 1

- Extract all candidate molecules from the most recent Skill 1 result file.
- Normalize obvious synonym differences only when the literature uses alternate names.
- Keep the original Skill 1 molecule names visible in the final output.

### 2. Search for molecule-responsive systems

For each molecule, search for:

- promoters responsive to the molecule
- transcription factors sensing the molecule
- regulated genes or operons
- two-component systems
- catabolic or uptake operons
- metabolite-inducible promoters
- transcriptomic or proteomic evidence of induction or repression
- parallel options in multiple organisms, not just the first convincing route

### 3. Capture the core biological mapping

For each supported mapping, record:

- molecule
- bacterial species
- gene or operon
- promoter
- regulatory protein
- response type:
  - activation
  - repression
- evidence type
- reference

Prefer mappings with:

- strong transcriptional response
- clear metabolite specificity
- characterized regulatory proteins
- direct evidence in engineerable bacteria
- no unjustified organism-based filtering
- only one retained promoter per molecule per bacterial species after within-species ranking by response strength, sensitivity, specificity, then evidence or validation quality

### 4. Handle molecules with no supported response

If no literature-supported sensing or transcriptional response can be found after an expanded search, still include the molecule in the final dataset and mark it clearly as:

`NO KNOWN BACTERIAL RESPONSE FOUND`

### 5. Expand and repeat when needed

If a molecule lacks clear support on the first pass:

1. expand the search to synonyms and related biochemical names
2. search transcriptomic and proteomic datasets
3. check curated regulatory databases
4. search additional model bacteria within the allowed host set

Stop only when the analysis is as complete as reasonably possible.

## Output Storage

- Maintain a dedicated Skill 2 results folder at `skill_2_criss_cross/`.
- For each run, create a dated subfolder:
  - `skill_2_criss_cross/YYYY-MM-DD_criss_cross/`
- Save both required files inside that dated subfolder.
- Also preserve a per-run archive snapshot under:
  - `skill_2_criss_cross/archive/<research_run_folder>/`
- Also contribute to the combined Skills 2 and 3 Word summary for the run under:
  - `C:\Users\Popovtzer lab\.codex\IBD vs IBS marker finder\<date_folder>\Skills2_3.docx`
- Use the local exporter script:
  - `tools/export_skill_docs.ps1`
- If an active project run folder already exists, also update downstream stage artifacts there when appropriate.

## Required Output Files

### File 1: Research Summary

Create:

`YYYY-MM-DD_criss_cross_summary.md`

This file must contain:

#### 1. Data sources used

- folder files used
- article types used

#### 2. Strategy applied

- what direct-sensing criteria were used
- which organism set was searched and how completeness across valid laboratory strains was checked
- how candidate systems were screened

#### 3. What was NEW in this run

- new molecules tested
- new organisms or systems tested
- new direct-sensing branches explored

#### 4. What was FIXED or corrected

- misannotations corrected
- direct versus indirect reclassifications
- unsupported systems removed

#### 5. Filtering / ranking logic

- how direct routes were prioritized
- how unsupported rows were handled

#### 6. Anti-repetition action

- what changed to avoid repeating prior outputs

#### 7. Key Findings

Summarize:

- which molecules had known sensing systems
- which molecules lacked clear bacterial regulatory responses
- the most promising promoter systems for biosensing

### File 2: Molecule-Promoter Mapping Table

Create:

`YYYY-MM-DD_promoter_molecule_mapping.csv`

Required columns:

Molecule,Bacterial Species,Gene / Operon,Promoter,Regulatory Protein,Response Type,Evidence,Reference

Column meanings:

- `Molecule`: the metabolite or marker imported from Skill 1
- `Bacterial Species`: the organism where the response system was identified
- `Gene / Operon`: the responding gene or operon
- `Promoter`: the promoter controlling the response
- `Regulatory Protein`: the transcription factor or regulator involved
- `Response Type`: `Activation` or `Repression`
- `Evidence`: for example `Transcriptomics`, `Proteomics`, `Genetic study`, `Regulatory characterization`, or `Review article`
- `Reference`: PMID, DOI, or paper title

For molecules with no identified system, keep them in the CSV and mark the row clearly with `NO KNOWN BACTERIAL RESPONSE FOUND`.

For human-readable tables and doc exports, use compact organism labels such as `K12`, `PAO1`, and `B. subtilis`, and keep `Senses` entries to `2-5` words.

## Internal Validation

Before finishing:

- verify that every molecule from the Skill 1 input file appears in the final dataset
- confirm that every positive mapping is supported by scientific literature
- expand and repeat the search if coverage is incomplete
- explicitly note which molecules have no known bacterial response

## Stopping Rule

After saving the summary file and the mapping CSV, stop and wait for the user before continuing.
