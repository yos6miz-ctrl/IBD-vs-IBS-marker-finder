# Project Instructions

This repository is dedicated to discovering stool-associated molecular inputs for engineered bacterial detectors that distinguish between IBD and IBS.

When the user asks to:
- find molecules distinguishing IBD vs IBS
- discover stool metabolites linked to IBD or IBS
- identify biomarker candidates for bacterial detectors
- map disease-associated molecules to bacterial response genes
- evaluate stool-stable molecular inputs

Codex MUST use the skill: `ibd_ibs_molecule_mining`.

When the user asks to use the "IBD vs IBS marker finder" agent, Codex should use the skill: `ibd-vs-ibs-marker-finder`.

When the user asks for deep stool biomarker research or Stage 1 stool molecule discovery, Codex should also use the skill: `stool-data-analyzer`.

When the user asks to map candidate molecules to bacterial promoters, regulatory systems, or transcriptional responses, Codex should also use the skill: `criss-cross`.

When the user asks for indirect bacterial responses, indirect sensing opportunities, or molecule-to-secondary-stress promoter mapping, Codex should also use the skill: `indirect-response`.

When the user asks for promoter upstream length determination, promoter capture sizing, or how far upstream of the ATG a retained promoter should be taken, Codex should also use the skill: `promoter-upstream-length`.

When the user asks for final candidate ranking, detector feasibility scoring, or integration of Skills 1-4 into a ranked biosensor shortlist, Codex should also use the skill: `best-candidates`.

## Global behavior rules

Always follow the 3-stage workflow:

1. Differential molecule discovery
2. Stool stability filtering
3. Bacterial response / gene mapping

Never collapse stages into one answer.

Stop after each stage and wait for user approval before continuing.

Exception:

- when the user explicitly asks for the `IBD vs IBS marker finder` agent, first read the latest workspace run artifacts, skill output folders, and methodology file as the primary mandatory workflow context, and treat the `.codex` marker-finder folder as the human-readable export destination rather than the only live context source
- for explicit `IBD vs IBS marker finder` runs, execute Skills 1-5 continuously in one connected flow unless a real blocker, contradiction, or high-risk ambiguity makes a pause necessary
- when the user says `run the agent`, execute the full marker-finder workflow from start to finish and refresh the dated `.codex` exports for that run without asking for stage-by-stage confirmation
- for smooth full-agent runs, avoid ad hoc shell reads or writes against `C:\Users\Popovtzer lab\.codex\IBD vs IBS marker finder\` during the scientific workflow whenever equivalent context already exists inside the workspace
- prefer this smooth path for full runs:
  1. read workspace `research_runs/`, skill folders, and methodology assets as live context
  2. run Skills 1-5 fully inside the workspace
  3. refresh `.codex` exports only at the end through the local helper scripts
- whenever the marker-finder agent is changed, including updates to `AGENTS.md`, the orchestration skill, any of Skills 1-5, or the report-generation helpers, refresh both of these documents at the end of the same change:
  - `C:\Users\Popovtzer lab\.codex\IBD vs IBS marker finder\IBD vs IBS Marker Finder - Methodology Overview.docx`
  - `C:\Users\Popovtzer lab\.codex\IBD vs IBS marker finder\IBD vs IBS Marker Finder - Full Code.docx`
- refresh the methodology overview through `tools/create_methodology_overview_doc.ps1`
- refresh the full-code document through `tools/create_marker_finder_code_doc.ps1`
- do those document refreshes at the end of the change rather than stopping mid-run
- for those agent runs, do not simply repeat a previous output pattern; if the conclusions or shortlist would be materially unchanged, deliberately expand or shift the search angle and document that change
- acceptable shift strategies include changing comparison emphasis across `IBD vs IBS`, `IBD vs healthy`, and `IBS vs healthy`, broadening molecule classes, revisiting indirect sensing, expanding promoter searches, or changing feasibility weighting
- for those agent runs, every skill output must explain what folder context was carried forward, what new angle was used in this run, and how repetition was reduced

## Output storage

For every workflow run:
- create a research output folder in the workspace under `research_runs/YYYY-MM-DD_IBD_IBS_run/`
- if that folder already exists, create the next available suffixed folder instead of overwriting it
- never overwrite previous runs
- always keep historical runs
- save results immediately after each stage

For every workflow run, also create a dated export folder inside:

- `C:\Users\Popovtzer lab\.codex\IBD vs IBS marker finder\`

Use exactly one folder per date:

- `YYYY-MM-DD`

If the same date is rerun, refresh the files inside that same date folder rather than creating suffixed folders.

Inside that date folder, generate these human-readable `.docx` files:

- `Skill1.docx`
- `Skills2_3.docx`
- `Skill4.docx`
- `Skill5.docx`

Each `.docx` file must include:

- a brief explanation of what the skill did
- a clear list of the results produced by that skill
- key parameters, criteria, or thresholds used in that run when available

Every `.docx` file must begin with these structured sections, written as short bullet lists rather than long paragraphs:
1. header
2. `What was done`
3. `Key takeaways`
4. `Main results`
5. `Detailed / backup table` when needed
6. `Coverage gaps`
7. `References`
8. `Run notes`

`Skill1.docx` and `Skills2_3.docx` must also include a short `What's new` section between `Key takeaways` and `Main results`.
That section must state the specific molecules, promoter systems, or retained branches added or newly carried forward in that run.
Do not use generic placeholders there. Name the actual molecule or promoter and give a short reason.

For explicit `IBD vs IBS marker finder` runs:

- keep `What was done` to `2-4` short lines only
- keep `Key takeaways` to `3-5` bullets only
- keep `What's new` to `1-3` short bullets naming the actual molecules or promoters added, rescued, or newly retained in that run
- keep `Run notes` to short bullets such as `New`, `Fixed`, and `Change`
- avoid long prose sections such as `Data sources used`, `What was FIXED`, or `Anti-repetition action`
- use tables as the main output format for `Skill1.docx`, `Skills2_3.docx`, and `Skill4.docx`, but keep `Skill5.docx` as a ranked list
- avoid duplicated information across sections
- when a note says something was added, removed, retained, or corrected, state the specific molecule, promoter, branch, or logic change rather than using generic placeholders

`Skill1.docx` must use this strict main table:

- rank
- molecule
- class
- disease pattern
- evidence strength
- Stage 2 status
- notes

Rules:

- one row per molecule
- `Disease pattern` must stay short and explicit
- `Notes` must stay to one short sentence
- include `Advance`, `Hold`, or `Drop` in `Stage 2 status`
- keep numbered references inline as `[1]`, `[2]`, etc., inside the `Notes` field when needed

`Skills2_3.docx` must combine Skills 2 and 3 and use two tables.

All section headers in `Skills2_3.docx` must be bold.

Main table:

- molecule
- best promoter
- best strain
- direct/indirect
- disease pattern
- `# options`
- comments

Detailed table:

- molecule
- rank
- gene/promoter
- strain
- senses
- mechanism
- direction
- reference

Use the same explicit disease-state wording used in `Skill1.docx`, not vague labels such as `pattern difference`.
Use short organism labels only:

- `PAO1`
- `K12`
- `KT2440`
- `B. subtilis`

Only laboratory wild-type strains are allowed in this project. Do not suggest, rank, export, or keep isolate-derived, probiotic, pathogenic, or clinical strains as retained detector hosts.
If a sensing route is supported only in an isolate-derived strain and no defensible laboratory-strain replacement is supported by the cited source, remove that route from retained outputs instead of keeping it as a fallback.
Keep one row per molecule in the main table.
For every retained molecule, search exhaustively across relevant laboratory strains, including `K12`, `PAO1`, `KT2440`, and `B. subtilis` when biologically relevant.
Do not stop after the first valid organism or promoter system.
If multiple valid laboratory-strain options exist, include all source-backed options.
Only exclude an option when there is a clear documented reason.
For direct responses, keep only one retained promoter per molecule per bacterial species: the single best option in this priority order:
- strongest response
- highest sensitivity
- highest specificity
- best evidence or validation
For every retained direct or indirect route, keep one exact promoter anchor and one exact gene or operon label.
Do not export blended pathway labels such as `geneA / operonB` for one retained route.
When the retained route is operon-based, write the full operon name explicitly, for example `sigV-rsiV-oatA`, `tauABCD`, or `hasR-hasAp`.
For indirect responses, keep all distinct downstream signals, but still keep only one retained promoter per molecule per downstream signal per bacterial species using the same priority order.
Main table should show only the single best option per molecule.
Detailed table should show one row per retained promoter option with explicit rank `1, 2, 3`.
Keep biologically distinct response triggers separate and precise.
Do not order or rank options by organism identity alone. Order them by source strength, mechanism clarity, specificity, and retained candidate quality.

`Skill4.docx` must summarize the promoter-upstream-length stage using a concise scientific report style that mirrors the actual Skill 4 evidence structure.

`Skill4.docx` must include:

- report header
- short `What was done`
- short `Key takeaways`
- main results
- references
- run notes

Rules for Skill 4:

- Skill 4 must prioritize evidence in this order:
  1. primary literature with experimental promoter or TSS mapping
  2. curated organism databases such as `EcoCyc` and `pseudomonas.com`
  3. sequence-based motif prediction only as a final fallback
- always check whether the target gene has its own promoter or belongs to an operon whose promoter is upstream of another gene
- tie every upstream-length result to the exact retained promoter anchor from Skills 2 and 3; do not reuse a boundary from a neighboring promoter in the same pathway
- never confuse promoter start, transcription start site, translation start codon, and cloning convenience region
- never skip a promoter; if evidence is weak, still return the best-supported approximate answer and label confidence appropriately
- the human-readable output should present one structured entry per promoter or gene using these fields:
  - `Organism`
  - `Best upstream length (nt)`
  - `What this number refers to`
  - `Evidence type`
  - `Source used`
  - `TSS distance from start codon (if available)`
  - `Promoter features found`
  - `Operon check`
  - `Confidence`
  - `Notes`
- if multiple promoters exist for a target, list them separately and label the condition-specific branches clearly
- keep explanations short, but do not collapse the output into only a three-column summary table
- in addition to the human-readable report, still generate the compact downstream CSV for Skill 5 with:
  - `Promoter name`
  - `Recommended upstream length from ATG (bp)`
  - `Confidence level`

`Skill5.docx` must be generated as a professional Word report, not as plain exported text.
Use real Word heading styles, clear section hierarchy, consistent spacing, styled tables, and presentation-ready formatting.
`Skill5.docx` must include:

- report header
- executive summary
- ranking summary table
- detailed ranked candidate sections
- coverage gaps
- recommended next actions
- references

The executive summary must include:

- report title
- date of run
- one-sentence purpose
- compact table of the top 3 ranked systems
- `3-5` key takeaways
- `2-4` major coverage gaps or limitations

Before the detailed candidate sections, include a summary table with these columns:

- rank
- host marker
- candidate signal
- promoter / gene
- strain
- stability
- specificity
- upstream length
- upstream confidence

Detailed candidate sections must be card-style sections, one candidate at a time, with:

- a heading line in the form `Rank X <stars> - Marker -> Promoter`
- a two-column key-facts table
- the subsections `Why it ranks here`, `Strengths`, and `Main limitations`

Show a visual `1-5` star rating next to every ranked candidate heading.
The stars must reflect the final rank tier across the full panel.
Ranks `1-5` should be visually emphasized more strongly than lower-ranked entries.
Display promoter names in Skill 5 without the leading `P` prefix in the human-readable Word report.
Omit the `Direct/Indirect` column from the Skill 5 ranking summary table and from the per-candidate key-facts table.
Use wider Skill 5 tables with custom column widths so the report is easier to read.
Start each detailed ranked candidate on its own page whenever possible so a candidate section does not spill across pages.

For Skill 5 ranked outputs, if the same promoter system is retained for multiple different markers, merge them into one shared ranked entry rather than repeating duplicate rows.
Treat entries as mergeable duplicates when the retained promoter, gene or operon, and bacterial species are the same shared detector route.
In the merged entry, combine the marker names into one line, for example `Lactoferrin and Lipocalin-2 / NGAL`.
Do not keep separate duplicate Skill 5 rows for the same retained promoter system.

For each ranked detector entry include:

- rank
- Candidate signal
- Associated host marker / disease context
- Promoter / gene
- Strain(s)
- Direct / indirect classification
- Stability assessment
- Specificity assessment
- Mechanistic rationale
- Reference
- Why it received this ranking
- Main limitations / penalties

Rules:

- begin Skill 5 with a short explanation of exactly how the ranking logic works
- include the executive summary and ranking summary table even when only refreshing outputs
- keep citations compact inside ranked sections and place the full bibliography at the end
- remove filler phrases such as `This entry sits at rank`
- prefer short bullets over long narrative paragraphs inside candidate sections
- use an explicit three-layer framework for Skill 5 that scores:
  - human biomarker evidence strength
  - marker-to-signal biological linkage
  - detector quality
- within `detector quality`, explicitly evaluate:
  - signal directness
  - specificity
  - stool/sample stability
  - exposure window or persistence long enough for sensing
  - documented bacterial response quality
  - concentration plausibility
  - exact-strain evidence quality
  - confidence in upstream length determination
  - practicality of the required promoter length
  - likelihood that the retained regulatory behavior is preserved with the proposed upstream capture
- treat promoter availability in an allowed laboratory strain as an inclusion rule, not as a major ranking advantage by itself
- apply an explicit `primary vs secondary` modifier and a `redundancy / overlap` penalty
- if two Skill 5 candidates are in the same retained strain and mainly report the same downstream signal class, keep only the stronger one unless there is a clear source-backed reason that both detectors provide distinct value
- when same-strain redundant routes are collapsed, merge the applicable marker names into the stronger retained row and explain weaker evidence for any newly merged marker inside the ranking note
- keep each ranked detector entry together on the same page whenever possible so the marker block and its explanation are not split across pages
- do not rank, reward, or penalize entries because they come from `K12`, `PAO1`, `KT2440`, or another retained laboratory strain unless a cited source provides explicit evidence of stronger performance
- for Skill 5, explicitly audit same-molecule cross-species pairs such as `K12` vs `PAO1` before finalizing their order
- if same-molecule cross-species options are tied or nearly tied, explain any ordering by scored evidence only, never by organism identity
- do not call a lower-ranked `PAO1`, `K12`, `KT2440`, or `B. subtilis` route a `backup` only because it appears below another organism in the ranking
- for same-molecule indirect branches in Skill 5, explicitly audit marker-to-consequence coupling before final order
- when a marker is known to drive one downstream consequence more strongly than another, do not let the weaker consequence outrank the stronger one without a clear source-backed reason
- for example, calprotectin-linked zinc or manganese withholding should not be ranked below calprotectin-linked iron withholding by default, because the marker-to-consequence biology is stronger for zinc and manganese
- penalize unstable transient chemistries such as `HOCl`, `ROS`, and similar short-lived oxidants unless the retained readout is clearly a durable downstream consequence rather than the transient molecule itself
- if two strains receive different ranks for similar iron-starvation or zinc-starvation biology, explain whether the difference comes from true strain biology, sensing-system availability, evidence quality, or a corrected ranking error
- include the retained Skill 4 upstream-length result in every Skill 5 candidate record and use it in the final ranking
- if the Skill 4 upstream-length call belongs to a different promoter than the promoter retained in Skill 5, treat that as an inconsistency and correct it before exporting the final rank
- `Why it received this ranking` must explain:
  - how strong the human biomarker evidence is
  - what biological event the detector represents
  - how directly it connects to the host marker or disease state
  - why the bacterium can sense it
  - whether it is stable or persistent enough to matter in practice
  - whether the proposed upstream promoter capture is confident and practical
  - what weakens the rank
  - why it landed in this exact position

Use the local exporter script:

- `tools/export_skill_docs.ps1`

Create these files in each run folder:
- `run_summary.md`
- `stage1_candidates.md`
- `stage1_summary.md`
- `stage2_stability.md`
- `stage2_summary.md`
- `stage3_bacterial_response.md`
- `stage3_summary.md`
- `stage4_upstream_length.md`
- `stage4_summary.md`
- `final_recommendations.md`

Each summary file must include a `Suggestions for improvement` section.

Always prioritize:
- direct IBD vs IBS evidence
- stool/fecal sample data
- stable molecules
- molecules with known bacterial response pathways
- complete source-backed coverage across retained laboratory strains rather than organism-based preference

## Scientific Accuracy And Formatting Overrides

- Before labeling any sensing system as `Direct` or `Indirect`, read the cited source and extract:
  - what is actually sensed
  - the mechanism
  - the biological pathway
- Never rely on prior outputs, naming patterns, or assumed mechanism labels without checking the source.
- Only laboratory wild-type strains are allowed in project outputs.
- Do not rank, recommend, or retain isolate-derived, probiotic, pathogenic, or clinical strains even as indirect or proxy sensing routes.
- The previously trialed probiotic chassis and its discarded zinc-starvation reporter route remain specifically excluded.
- If mechanism is uncertain, label the route as `indirect/proxy sensing` or `mechanism unresolved` rather than calling it direct.
- Prioritize clarity over completeness inside tables; details should move to surrounding bullets instead of being repeated in cells.

Never invent genes, regulators, or sensing systems.

Always present results in structured ranked tables suitable for engineering decisions.
