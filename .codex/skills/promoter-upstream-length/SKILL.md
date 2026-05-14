---
name: promoter-upstream-length
description: Determine the most accurate upstream promoter region length from the coding start for retained detector promoters using literature-first evidence, curated organism databases, and sequence-based fallback only when stronger evidence is unavailable.
---

# Promoter Upstream Length Determination

Determine, for each retained promoter or gene from the earlier marker-finder stages, how many nucleotides upstream of the translational start codon should be taken in order to preserve the promoter and its relevant regulatory elements.

## Goal

For each requested promoter or gene, determine the most accurate upstream promoter boundary and report the distance in nucleotides upstream of the start codon that should be taken as the promoter region.

The final reported value must be one of:

- an experimentally supported length
- a curated database-supported length
- a motif-predicted approximate length only when stronger evidence is unavailable

## Organism Scope

This skill is primarily for:

- `Escherichia coli`
- `Pseudomonas aeruginosa PAO1`

## Mandatory Source Priority

Use this source priority in strict order:

1. `Primary literature with experimental promoter or TSS mapping`
   Prefer papers with:
   - transcription start site mapping
   - primer extension
   - `5' RACE`
   - `dRNA-seq`
   - `cappable-seq`
   - promoter deletion or reporter mapping
   - experimentally defined sigma-factor promoter annotations

2. `Curated organism databases`
   Use when literature is missing or insufficient:
   - `EcoCyc` for `E. coli`
   - `Pseudomonas Genome Database` / `pseudomonas.com` for `PAO1`
   - other relevant curated biological databases when needed

3. `Sequence-based prediction`
   Use only as a last fallback:
   - retrieve up to `500 bp` upstream of the annotated start codon unless the intergenic region is shorter
   - analyze promoter motifs or promoter predictions
   - for `Pseudomonas`, prefer `SAPPHIRE`
   - never treat motif prediction as equal to experimental evidence

## Input Discovery

Read the most recent retained promoter outputs from:

- `skill_2_criss_cross/`
- `skill_3_indirect_response/`

Use the latest dated run folders or archive snapshots tied to the current workflow run. Deduplicate retained inputs so each promoter or gene target is evaluated once per retained biological route.

Promoter-length determination must follow the exact retained promoter anchor from Skills 2 and 3.

- Do not reuse an upstream-length estimate from a neighboring promoter in the same pathway.
- Do not carry a pathway-level label when the retained route has already been narrowed to one exact promoter.
- If the retained route is operon-based, report the full operon name and tie the length call to the exact promoter controlling that operon.

If upstream outputs are missing, stop and state which earlier skill must run first.

## Definitions

For this skill, `promoter upstream length` means:

- the number of nucleotides between the translational start codon of the target coding sequence and the best-supported upstream promoter start or reference boundary

When possible, determine:

- transcription start site (`TSS`)
- `-10` motif
- `-35` motif
- regulator or operator overlap if relevant
- whether the promoter belongs to an operon and is actually upstream of the first gene in that operon

## Critical Reasoning Rules

1. Always verify whether the requested gene has its own promoter or is likely part of an operon.
2. If the promoter is actually upstream of another gene in the same operon, state that clearly.
3. Do not confuse:
   - promoter start
   - transcription start site
   - translation start codon
   - cloning convenience region
4. Do not confuse the best retained promoter anchor with weaker internal, processed, or constitutive transcripts from the same pathway.
5. If the retained Skill 2 or Skill 3 route is corrected from one promoter anchor to another, recompute the upstream-length call for the corrected promoter rather than silently reusing the old value.
6. If multiple promoter boundaries exist in the literature:
   - prefer the one with direct experimental evidence
   - if there are condition-specific promoters, report all clearly and label them
7. Never return a single exact number unless the evidence supports that exact number.
8. If only prediction is available, label the answer as approximate.
9. If evidence conflicts, explain the conflict briefly and rank confidence.

## Required Workflow

For each promoter or gene:

### Step 1 - Normalize target

- identify organism
- identify gene symbol, locus tag, or promoter name
- identify the target coding-sequence start codon position if available
- check whether the promoter name refers to:
  - a gene promoter
  - an operon promoter
  - a sigma-dependent promoter
  - a regulator-controlled promoter region

### Step 2 - Search literature first

Search for experimental evidence using combinations of:

- `[gene] promoter`
- `[gene] transcription start site`
- `[gene] TSS`
- `[gene] primer extension`
- `[gene] 5' RACE`
- `[gene] dRNA-seq`
- `[gene] cappable-seq`
- `[gene] promoter mapping`
- `[organism] [gene] promoter`

Only use article evidence when it provides a real promoter boundary, `TSS`, mapped motif, or a figure or table from which the promoter location can be inferred reliably.

### Step 3 - Use curated database if literature is insufficient

If no solid paper answer exists:

- for `E. coli`, check `EcoCyc`
- for `PAO1`, check `pseudomonas.com`

Extract when available:

- promoter annotation
- `TSS`
- operon context
- relative coordinates
- strand orientation

### Step 4 - Sequence fallback

If literature and curated databases still do not resolve the promoter length:

- retrieve up to `500 bp` upstream of the target start codon, limited by the intergenic region
- use a promoter finder
- for `Pseudomonas`, prefer `SAPPHIRE`
- identify the strongest plausible promoter in the correct orientation
- estimate promoter-region length from predicted `-35/-10/TSS` architecture
- clearly mark the result as prediction-only

### Step 5 - Calculate length

Compute:

- `upstream promoter length = number of nucleotides from the start codon back to the chosen promoter boundary or TSS-associated promoter start reference`

When possible, provide both:

- `TSS-to-start-codon distance`
- promoter-region span used for cloning, such as approximately `-60`, `-100`, or `-150`

### Step 6 - Confidence grading

Assign one of:

- `High confidence` = direct experimental mapping from literature
- `Medium confidence` = curated database annotation or strong indirect literature support
- `Low confidence` = motif prediction only

## Output Storage

Create a dedicated folder for this skill:

- `skill_4_promoter_upstream_length/`

For each run, create a dated run folder:

- `skill_4_promoter_upstream_length/YYYY-MM-DD/`

Also preserve a per-run archive snapshot under:

- `skill_4_promoter_upstream_length/archive/<research_run_folder>/`

Create these files:

- `YYYY-MM-DD_promoter_upstream_lengths.md`
- `YYYY-MM-DD_promoter_upstream_lengths.csv`

The markdown file is the primary human-readable skill output.
The CSV is the compact downstream handoff for Skill 5 and must contain at least:

- `Promoter name`
- `Recommended upstream length from ATG (bp)`
- `Confidence level`

## Required Output Format

For each target, output exactly this structure in the markdown result:

### [Promoter / Gene name]
- Organism:
- Best upstream length (nt):
- What this number refers to:
- Evidence type: Literature / Database / Motif prediction
- Source used:
- TSS distance from start codon (if available):
- Promoter features found:
- Operon check:
- Confidence: High / Medium / Low
- Notes:

### Additional Output Rules

- If multiple promoters exist, list them separately as:
  - `Promoter 1`
  - `Promoter 2`
  - `Condition-specific promoter`
- If the result is only approximate, write:
  - `Approximate predicted promoter region`
- If no reliable answer can be found, write:
  - `No reliable promoter length could be assigned from literature, curated databases, or motif prediction`
- Keep the output minimal and clean. Do not add unnecessary narrative outside the required fields.

## Validation

Before finishing:

- confirm that every retained promoter from Skills 2 and 3 was evaluated
- confirm that every promoter received a reported length or an explicit no-reliable-answer statement
- confirm that every promoter received `High`, `Medium`, or `Low` confidence
- confirm that literature was searched before curated databases, and prediction was used only when stronger evidence was unavailable
- confirm that operon context and strand direction were checked before assigning the final boundary

## Downstream Use

This skill feeds the final detector-ranking stage.

Its output must be carried forward into Skill 5 so the final ranking can consider:

- confidence in upstream length determination
- practicality of the required promoter length
- likelihood that the retained regulatory behavior is preserved

## Forbidden Behaviors

- Do not guess exact promoter lengths without evidence.
- Do not present motif prediction as experimentally proven.
- Do not assume every gene has an independent promoter.
- Do not ignore strand direction.
- Do not ignore operon structure.
