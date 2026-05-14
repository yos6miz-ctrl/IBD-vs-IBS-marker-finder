# IBD vs IBS Marker Finder

This repository contains the local Codex agent, skills, and helper scripts used to discover stool-associated molecular signals that differentiate inflammatory bowel disease (IBD) from irritable bowel syndrome (IBS), map them to bacterial sensing systems, estimate promoter capture regions, and rank detector candidates for engineered bacterial biosensors.

## What This Repo Includes

- `AGENTS.md`
  Project-level workflow rules and output requirements.

- `.codex/skills/`
  The marker-finder agent and its scientific workflow skills:
  - `stool-data-analyzer`
  - `criss-cross`
  - `indirect-response`
  - `promoter-upstream-length`
  - `best-candidates`
  - `ibd-vs-ibs-marker-finder`
  - `ibd_ibs_molecule_mining`

- `tools/`
  Local export and documentation helpers, including:
  - Word export generation
  - methodology overview generation
  - full-code document generation

## Workflow Overview

The full marker-finder workflow runs as a 5-skill pipeline:

1. `Skill 1` - Marker identification
   Discover stool-associated molecules that differentiate IBD from IBS.

2. `Skill 2` - Direct promoter mapping
   Map retained molecules to direct bacterial sensing or response systems.

3. `Skill 3` - Indirect response mapping
   Map molecules to secondary physiological consequences and bacterial proxy responses.

4. `Skill 4` - Promoter upstream length determination
   Estimate how much upstream sequence should be retained to preserve promoter regulation.

5. `Skill 5` - Final ranking
   Rank detector candidates using human biomarker evidence, marker-to-signal linkage, and detector quality.

## Main Goal

The goal of this project is to prioritize biologically grounded, practically usable detector inputs for engineered bacterial systems that can help distinguish IBD from IBS using stool-associated signals.

## Notes

- Generated run outputs and exported reports are intentionally not tracked in Git.
- The repository is focused on source logic, workflow structure, and reproducible agent behavior.

## Render Deployment

This repository now includes a minimal deployable service for Render:

- `render.yaml`
  Render Blueprint configuration for a Python web service.

- `app.py`
  Lightweight HTTP service that:
  - serves a project overview page at `/`
  - exposes a health check at `/healthz`
  - exposes simple metadata at `/metadata`

This service is intentionally small. It is meant to give the repository a clean Render deploy target, not to replace the full local Codex workflow.
