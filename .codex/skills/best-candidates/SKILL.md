---
name: best-candidates
description: Integrate the outputs of Skills 1-4 and rank the most feasible molecule-promoter detector systems for engineered bacterial biosensors that distinguish IBD from IBS. Use when the user wants final candidate prioritization, feasibility scoring, or a unified direct-vs-indirect detector ranking.
---

# Best Candidates

Perform the final integration and detector-feasibility ranking stage.

## Goal

Read the outputs of Skills 1-4, combine them into one unified dataset, and rank the best bacterial biosensor detector candidates for IBD vs IBS stool signals.

This is the final summarizing and decision-making stage of the workflow.

## Input Sources

Read and integrate the most recent results from:

- Skill 1: stool molecule discovery
- Skill 2: direct bacterial sensing or promoter responses
- Skill 3: indirect sensing through secondary physiological consequences
- Skill 4: promoter upstream length determination

## Input Discovery

### Skill 1 source

- Prefer `skill_1_stool_deta/` if it exists, because it is the legacy Skill 1 input alias.
- Otherwise fall back to the existing Skill 1 results folders if present:
  - `skill_1_stool-data-analyzer/`
  - `skill_1_stool-deta-analyzer/`
- Find the most recent file matching `YYYY-MM-DD_stool-data-analyzer.md`.

### Skill 2 source

- Use `skill_2_criss_cross/`.
- Find the most recent dated run folder matching `YYYY-MM-DD_criss_cross/`.
- Read the summary file and the mapping CSV in that folder.

### Skill 3 source

- Use `skill_3_indirect_response/`.
- Find the most recent dated run folder matching `YYYY-MM-DD/`.
- Read the summary file and the mapping CSV in that folder.

If any required upstream result is missing, stop and tell the user which skill must run first.

### Skill 4 source

- Use `skill_4_promoter_upstream_length/`.
- Find the most recent dated run folder matching `YYYY-MM-DD/`.
- Read the promoter-length markdown report and the promoter-length CSV in that folder.

## Data Loading

After locating the latest upstream results:

- read all relevant summary files and mapping tables carefully
- read the Skill 4 per-promoter report for boundary-confidence context
- extract candidate entries including:
  - molecule
  - bacterial species
  - gene or operon
  - promoter
  - response type
  - evidence
- combine them into one unified dataset
- attach the promoter-upstream-length recommendation for every retained detector route
- attach the upstream-length confidence and any important operon or promoter-boundary caveats from Skill 4 when they affect ranking
- before ranking, verify that every retained row is tied to one exact promoter anchor from Skills 2 and 3 rather than a mixed pathway label
- if a retained route was originally written with an ambiguous blended label such as `geneA / operonB`, resolve it to one exact promoter and one exact gene or operon before continuing
- when the retained route is operon-based, carry the full operon name into Skill 5 instead of truncating it to one gene
- before final ranking, merge duplicate detector entries when the retained promoter system is the same shared detector route
- treat rows as duplicates for this merge step when they share the same retained promoter, gene or operon, and bacterial species, even if they were linked to different upstream stool markers
- in the merged row, combine the linked marker names into a single shared molecule field, for example `Lactoferrin and Lipocalin-2 / NGAL`

Retain the mechanism origin of each candidate:

- `Direct sensing` for Skill 2 entries
- `Indirect sensing` for Skill 3 entries

Before preserving any mechanism label from upstream outputs, verify that the upstream source-based classification is still defensible. If a route is actually a proxy readout, keep it labeled indirect or proxy rather than direct.

Keep negative coverage rows from upstream outputs when they exist, but rank actual usable detector systems above unsupported entries.

## Feasibility Evaluation

Rebuild the final ranking around an explicit three-layer biological framework. Do not rely on loose overall impressions, and do not treat simple promoter availability as a major ranking advantage.

### Core Ranking Logic

Use promoter availability in an allowed laboratory strain as an `inclusion filter`, not as the main reason a candidate ranks highly. Once a route is source-backed and buildable, rank it using these three layers:

1. `Human biomarker evidence strength`
   - This is a major ranking axis.
   - Score how strongly the original stool marker is supported in the human literature for differentiating `IBD` and `IBS`, or for a strong adjacent comparator such as `IBD vs healthy` or `IBS vs healthy` when direct `IBD vs IBS` evidence is limited.
   - Consider replication across studies, consistency across patients, effect size, disease specificity, and clinical entrenchment.

2. `Marker-to-signal biological linkage`
   - Score how tightly the sensed bacterial signal is connected to the original host marker or disease biology.
   - Prefer:
     - direct sensing of the retained molecule
     - first-order physiological consequences tightly caused by the molecule
   - Penalize:
     - broad downstream stress states
     - weak proxy logic
     - remote inflammation-associated side effects

3. `Detector quality`
   - Score whether the retained bacterial response is likely to work as a meaningful detector in practice.
   - This layer should combine:
     - signal directness
     - specificity
     - stool or sample persistence
     - likelihood of a meaningful exposure window
     - strength and clarity of the documented bacterial response
     - concentration plausibility
     - exact-strain evidence quality
     - upstream-length confidence
     - practicality of the required promoter length
     - likelihood that the retained regulatory behavior is preserved in the proposed capture region

### Detector Quality Interpretation

Within `Detector quality`, explicitly evaluate:

- `Signal directness`
  - direct sensing of the retained molecule is strongest
  - first-order consequences are next
  - broad downstream stress or proxy states are weaker

- `Specificity`
  - penalize signals shared by many unrelated gut stresses or inflammatory states

- `Stability / persistence`
  - if the sensed entity is chemically short-lived, transient, or highly handling-sensitive, penalize it unless the retained readout is clearly a durable downstream consequence

- `Exposure window`
  - score whether the signal is likely to be present long enough, and at meaningful enough levels, to trigger bacterial transcription

- `Promoter quality`
  - prefer strong ON/OFF behavior, clear regulatory logic, and source-backed response quality

- `Promoter region deployability`
  - reward higher-confidence upstream-length estimates
  - reward promoter lengths that are practical to clone and test without likely truncating relevant regulation
  - penalize unusually long or weakly justified promoter captures when they create more uncertainty that the regulatory behavior is preserved

- `Exact-strain support`
  - do not assume one strain behaves like another
  - penalize cross-strain extrapolation when the retained exact-strain evidence is weaker

### Required Modifiers

After assigning the three layer scores, apply:

- `Primary vs secondary modifier`
  - reward primary disease-linked signals and tight first-order consequences
  - penalize broad downstream stress states

- `Redundancy / overlap penalty`
  - if two candidates capture nearly the same biology, penalize the weaker, broader, or less informative one
  - if two candidates are in the same retained strain and mainly report the same downstream signal class, such as two different `PAO1` zinc-starvation promoters, keep only the stronger retained detector unless a source-backed reason shows that both provide meaningfully distinct detector value
  - when one same-strain route is removed for this reason, merge the applicable upstream marker names into the stronger retained row and explain any weaker evidence for the added marker in notes

### Interpreting Indirect Routes

For indirect routes, explicitly distinguish:

- `first-order consequence`: still close to the original marker biology
- `broad downstream stress`: weaker and less specific

Do not let a broad inflammatory stress outrank a tighter first-order consequence unless the evidence and practical detectability are clearly stronger.

### Critical Biomarker Logic

- For `calprotectin` and `S100A12`, zinc-withholding biology is central and should generally outrank iron-starvation branches unless a clear source-backed reason justifies the opposite in a specific strain.
- For `calprotectin`, manganese withholding can remain important, but score it below zinc withholding when the retained evidence is narrower, more context-limited, or less resolved.
- For unstable oxidants such as `HOCl`, `ROS`, or similar short-lived chemistry, penalize them unless the retained readout is clearly a durable consequence rather than the transient molecule itself.
- Do not treat iron-starvation readouts in `K12` and `PAO1` as different signal classes unless the biology, sensing mechanism, or evidence quality truly differs. Explain the reason explicitly.

### Species-Neutral Rule

- Do not rank candidates higher or lower because of species identity alone.
- Compare strain-specific options on evidence, linkage, specificity, stability, response quality, and exact-strain support.
- If two strains receive different ranks for similar biology, explain whether the difference is caused by:
  1. true strain biology
  2. presence or absence of the sensing system
  3. evidence quality
  4. an earlier ranking artifact that is now being corrected

### Total Score

Use the three layer scores plus the modifiers to produce a transparent final ranking.

- A strong human biomarker should not be pushed too low merely because the sensing route is indirect.
- A detector should still be penalized if the signal is unstable, nonspecific, poorly matched to physiological concentration, or weakly supported in the retained strain.
- In other words, `human evidence strength` and `detector quality` both matter. Neither should be allowed to dominate blindly.

## Direct vs Indirect Mechanism Handling

- Keep the mechanism label for every candidate as either `Direct sensing` or `Indirect sensing`.
- If a route is actually a proxy for metal starvation, oxidative stress, or another secondary state, do not upgrade it to `Direct sensing`.
- Do not penalize indirect systems automatically if the indirect consequence is well supported and the bacterial response is strong and engineerable.
- Prefer direct systems only when the five scoring criteria are otherwise effectively tied.

## Ranking Workflow

### 1. Load and normalize upstream entries

- normalize column names across Skill 2 and Skill 3 outputs
- preserve original molecule names from Skill 1
- preserve references and evidence types
- normalize the Skill 4 promoter-length table and join it onto retained routes by promoter, gene or operon, and species when possible
- if the Skill 4 length is attached to a different promoter than the one retained for Skill 5, stop and correct the promoter identity or recompute the upstream-length call before final ranking
- if the Skill 4 table uses only promoter names, join conservatively and flag any ambiguous promoter-name collisions for manual review
- verify that source-backed options from all relevant retained laboratory strains, including `K12`, `PAO1`, and `KT2440` when applicable, are still present before ranking

### 2. Score every candidate system

- assign a `1-5` score for:
  - human biomarker evidence strength
  - marker-to-signal biological linkage
  - detector quality
- compute the total score
- keep short notes justifying unusual high or low scores
- when a shared promoter entry has been merged across multiple markers, score it using the strongest defensible shared detector interpretation and mention in notes that the promoter is retained for multiple linked markers
- explicitly record the retained upstream-length recommendation and its confidence for every ranked row

### 3. Rank candidates

- rank systems from highest to lowest total score
- break ties by favoring:
  1. stronger human separation evidence
  2. tighter marker-to-signal linkage
  3. clearer promoter ON/OFF behavior
  4. better practical persistence and concentration fit
- if entries for the same molecule from different retained laboratory strains are tied or nearly tied, run an explicit species-bias audit before finalizing order
- in that audit, compare the paired options side by side and confirm that any ordering difference is explained by evidence strength, specificity, dynamic range, sensitivity fit, or separation quality rather than organism identity
- if two same-molecule cross-species options remain effectively tied after that audit, do not use species as a hidden fallback ordering rule; either keep them as a near-tie in notes or order them by neutral deterministic fields such as promoter or gene name
- do not describe a lower-ranked option as a mere `backup` or `secondary` route unless the scored evidence actually supports that weaker status
- for same-molecule indirect branches, check whether the ordering still matches the biological coupling of the marker to the downstream consequence; do not let a weaker consequence outrank a more central one without an explicit source-backed reason
- do not keep separate final-ranked rows for duplicate promoter systems that have already been merged across multiple markers

### 4. Handle unsupported or negative rows

If an upstream row indicates:

- `NO KNOWN BACTERIAL RESPONSE FOUND`
- `NO STRONG INDIRECT BACTERIAL RESPONSE FOUND`

retain it only as a low-ranked coverage record or summarize it in notes, but do not allow it to outrank real detector candidates.

## Output Storage

- Maintain a dedicated Skill 5 folder at `skill_5_detector_ranking/`.
- For each run, create a dated run folder:
  - `skill_5_detector_ranking/YYYY-MM-DD/`
- Save both required final files inside that dated folder.
- Also preserve a per-run archive snapshot under:
  - `skill_5_detector_ranking/archive/<research_run_folder>/`
- Also export a Word summary for the run under:
  - `C:\Users\Popovtzer lab\.codex\IBD vs IBS marker finder\<date_folder>\Skill5.docx`
- Use the local exporter script:
  - `tools/export_skill_docs.ps1`
- In the human-readable Word export, do not use a table for Skill 5.
- Render Skill 5 as a ranked list from best to worst, and for each detector include:
  - `Marker`
  - `Functional`
  - `Promoter / gene`
  - `Organism`
  - `What it senses`
  - `Direction`
  - `Recommended upstream length from ATG (bp)`
  - `Upstream length confidence`
  - `Reference`
  - `Why it received this ranking`
- In the Word export, make document headers and per-entry section titles bold.
- For each ranked detector entry, visually separate the fixed template fields from the custom ranking explanation.
- Write the ranking explanation as a comparative analysis that explains why the entry sits where it does relative to the entries above and below it, without using explicit `pros` or `cons` labels.

## Required Output Files

### File 1: Final Analysis Report

Create:

`YYYY-MM-DD_detector_analysis_report.md`

This report must include:

#### 1. Data sources used

- folder files used
- articles or evidence groups used
- what each skill contributed

#### 2. Strategy applied

- ranking emphasis
- mechanism-handling rules
- species-neutral rules

#### 3. What was NEW in this run

- new candidate systems added
- new weighting or comparison emphasis
- new organisms or mechanisms considered

#### 4. What was FIXED or corrected

- misannotations corrected
- direct versus indirect reclassifications
- unsupported rows demoted

#### 5. Filtering / ranking logic

- how scores were assigned
- how ties were broken
- how unsupported rows were handled

#### 6. Anti-repetition action

- what changed to avoid repeating earlier rankings

#### 7. Key Insights

Summarize:

- the strongest candidate detector systems
- promising molecule classes
- promising promoter systems
- any gaps or limitations

#### 8. Top Candidate Systems

Present the top-ranked detector systems and explain briefly why they scored highly.

### File 2: Unified Ranked Candidate Table

Create:

`YYYY-MM-DD_detector_candidates_ranked.csv`

Required columns:

Rank,Molecule,Mechanism Type,Indirect Consequence,Bacterial Species,Gene / Operon,Promoter,Response Type,Disease Association,Stability in Stool,Evidence,Total Score,Reference,Notes

Column meanings:

- `Rank`: position in the feasibility ranking
- `Molecule`: the stool-associated candidate molecule
  - this field may contain multiple linked markers joined into one shared entry when the same promoter system is retained for more than one marker, for example `Lactoferrin and Lipocalin-2 / NGAL`
- `Mechanism Type`: `Direct sensing` or `Indirect sensing`
- `Indirect Consequence`: only when applicable for indirect systems
- `Bacterial Species`: the host organism
- `Gene / Operon`: the responding gene or operon
- `Promoter`: the promoter controlling the response
- `Response Type`: activation or repression
- `Disease Association`: for example `IBD up` or `IBS up`
- `Stability in Stool`: `High`, `Moderate`, or `Low`
- `Evidence`: transcriptomics, genetic study, clinical biomarker study, regulatory study, and related evidence labels
- `Total Score`: combined feasibility score
- `Reference`: supporting citation
- `Notes`: brief explanation of ranking context, limitations, or integration logic

Do not add ranking bonuses or penalties based only on bacterial species or strain origin.
Do not keep duplicate final-ranked rows when the retained promoter system is the same shared detector route across multiple markers; merge them into one shared entry instead.
If a source-backed candidate has biosafety, chassis-history, or engineering caveats, keep it in the ranking and state the caveat explicitly in `Notes`.
For human-readable doc exports, keep `Functional role` to `2-5` words only and use compact organism labels such as `K12`, `PAO1`, `KT2440`, and `B. subtilis`.

## Final Consistency Check

Before saving the results, verify that:

- all candidate systems from Skills 2 and 3 were evaluated
- molecules from Skill 1 are represented in the combined dataset or explicitly accounted for through upstream negative-coverage rows
- rankings reflect realistic biosensor feasibility

If inconsistencies are found, correct the dataset before generating the final output.

## Final Goal

Produce a clear ranked list of molecule-promoter detector systems most likely to work as engineered bacterial biosensors for distinguishing IBD vs IBS using stool signals.
