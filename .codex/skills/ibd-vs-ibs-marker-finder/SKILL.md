---
name: ibd-vs-ibs-marker-finder
description: Coordinate available project skills to discover stool-associated biological and chemical markers that distinguish IBD from IBS and can be sensed by bacteria. Use when the user wants a dedicated IBD vs IBS marker-finder agent or a multi-skill workflow for detector-input discovery.
---

# IBD vs IBS Marker Finder

Coordinate the project's scientific discovery workflow across the most relevant available skills.

## Mission

Identify stool-associated biological and chemical signals that:

- help distinguish IBD from IBS
- remain plausible detector inputs in stool
- can be linked to bacterial sensing, transport, metabolism, or transcriptional response systems

## Operating Rules

- Use the most specific available skill for each subtask instead of duplicating its workflow.
- Treat this skill as the orchestrator and router for the project, not as a replacement for specialized scientific skills.
- Reuse the existing project output structure and preserve historical runs.
- Before any scientific work, read the latest workspace run artifacts, skill output folders, and methodology assets as the primary mandatory workflow context.
- Treat `C:\Users\Popovtzer lab\.codex\IBD vs IBS marker finder\` as the human-readable export destination and as secondary context when needed, not as the only live source of project memory.
- Extract and carry forward prior notes, molecule lists, assumptions, ranking logic, missing options, tested dead ends, formatting preferences, and user corrections from the workspace history and the export set together.
- Run Skills 1-5 continuously in one connected workflow unless a true blocker or contradiction makes a pause necessary.
- If the user says `run the agent`, complete the full marker-finder workflow and refresh the dated `.codex` exports without asking for stage-by-stage confirmation.
- For smooth complete runs, avoid ad hoc shell reads or writes against the `.codex` export folder during the scientific workflow whenever equivalent context already exists inside the workspace.
- Prefer this sequence: read workspace history, run Skills 1-5 fully in the workspace, then refresh `.codex` reports and the methodology overview only at the end through the local helper scripts.
- Whenever the marker-finder agent is changed, including updates to the orchestration skill, any of Skills 1-5, `AGENTS.md`, or the local report-generation helpers, refresh both of these documents at the end of the same change:
  - `C:\Users\Popovtzer lab\.codex\IBD vs IBS marker finder\IBD vs IBS Marker Finder - Methodology Overview.docx`
  - `C:\Users\Popovtzer lab\.codex\IBD vs IBS marker finder\IBD vs IBS Marker Finder - Full Code.docx`
- Refresh the methodology overview through `tools/create_methodology_overview_doc.ps1`.
- Refresh the full-code document through `tools/create_marker_finder_code_doc.ps1`.
- If a rerun would otherwise reproduce essentially the same shortlist or conclusions, deliberately change the analysis angle and widen the search space instead of cosmetically repeating the prior result.
- Valid anti-repetition shifts include changing comparison emphasis, broadening molecule classes, expanding ROS or redox-related signals, revisiting fecal blood or mucosal-damage layers, deepening direct promoter searches, or prioritizing indirect sensing routes more strongly.
- Before calling any bacterial response `Direct` or `Indirect`, read the cited source and extract what is sensed, the mechanism, and the pathway.
- Only laboratory wild-type strains are allowed in this project. Exclude isolate-derived, probiotic, pathogenic, and clinical strains from retained outputs.
- The previously trialed probiotic chassis and its discarded zinc-starvation calprotectin route are globally excluded from this project.
- If a cited sensing route exists only in a disallowed strain and no supported lab-strain replacement is found, remove it from the retained set.
- Never retain the discarded legacy zinc-starvation calprotectin route in project outputs.
- If mechanism certainty is weak, prefer `indirect/proxy` or `mechanism unresolved` over a confident direct label.
- Never invent literature evidence, genes, regulators, or sensing systems.

## Current Skill Routing

### Core discovery workflow

- If `stool-data-analyzer` is available, use it for deep Stage 1 stool evidence discovery and ranked candidate generation.
- If `criss-cross` is available, use it for promoter and regulatory-system mapping once candidate molecules are chosen.
- If `indirect-response` is available, use it for indirect sensing opportunities where molecules create secondary physiological states that bacteria can detect.
- If `promoter-upstream-length` is available, use it to determine the upstream capture length required to preserve promoter regulation before final ranking.
- If `best-candidates` is available, use it for final integration and feasibility ranking across the outputs of Skills 1-4.
- If `ibd_ibs_molecule_mining` is available, use it for the end-to-end three-stage discovery process:
  1. differential molecule discovery
  2. stool stability filtering
  3. bacterial response or gene mapping

When both skills are available:

1. use `stool-data-analyzer` for the deep Stage 1 discovery pass
2. use `criss-cross` for molecule-to-promoter mapping after candidate selection
3. use `indirect-response` for secondary-condition sensing logic when direct sensing is weak or missing
4. use `promoter-upstream-length` to estimate the required upstream promoter region length for retained detector routes
5. use `best-candidates` for final feasibility scoring and detector ranking
6. use `ibd_ibs_molecule_mining` as the broader end-to-end workflow scaffold and fallback for uncovered stages until more specialized skills are added

### Future extension workflow

- When new project skills are added, prefer them for the narrow subproblems they cover.
- Integrate future skills only where they improve specificity, reproducibility, or speed.
- If multiple relevant skills exist, use the minimal set that covers the task and state the order briefly.
- If a needed skill is missing, say so briefly and continue with the best supported fallback.

## Expected Behaviors

- For discovery requests, coordinate the full Skill 1-5 workflow and use folder-derived context to shape every stage.
- For planning requests, propose which future skills would improve the pipeline and where they plug in.
- For evaluation requests, rank candidate stool signals for biosensor engineering decisions.
- Prioritize signals with direct stool evidence and known or mappable bacterial response systems.
- In every skill output, replace long `What was done` / `How it was done` prose with these bullet-list sections:
  - `Data sources used`
  - `Strategy applied`
  - `What was NEW in this run`
  - `What was FIXED or corrected`
  - `Filtering / ranking logic`
  - `Anti-repetition action`
- Keep tables compact. Put long explanations outside tables.

## Suggested Future Skill Areas

Create future skills around narrow capabilities such as:

- literature harvesting and evidence extraction
- biomarker normalization and synonym resolution
- stool chemistry and stability assessment
- output report generation and comparison across runs
