from __future__ import annotations

import argparse
import csv
import re
import zipfile
from pathlib import Path
from typing import Iterable
from xml.sax.saxutils import escape


WORKSPACE = Path(__file__).resolve().parents[1]


def extract_run_date(run_name: str) -> str:
    match = re.match(r"(\d{4}-\d{2}-\d{2})", run_name)
    if not match:
        raise ValueError(f"Could not extract run date from {run_name}")
    return match.group(1)


def next_output_dir(output_root: Path, run_date: str) -> Path:
    candidate = output_root / run_date
    if not candidate.exists():
        return candidate
    index = 2
    while True:
        candidate = output_root / f"{run_date}_{index}"
        if not candidate.exists():
            return candidate
        index += 1


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_markdown_table_rows(text: str, heading: str) -> list[list[str]]:
    lines = text.splitlines()
    rows: list[list[str]] = []
    in_section = False
    in_table = False
    for line in lines:
        if line.startswith("## "):
            if in_section and rows:
                break
            in_section = line.strip() == heading
            in_table = False
            continue
        if not in_section:
            continue
        if line.startswith("|"):
            in_table = True
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if all(set(cell) <= {"-"} for cell in cells):
                continue
            rows.append(cells)
        elif in_table and rows:
            break
    if rows and rows[0]:
        header_tokens = {"rank", "molecule", "signal", "candidate from uploaded panel"}
        if rows[0][0].strip().lower() in header_tokens:
            rows = rows[1:]
    return rows


def extract_bullets(text: str, heading: str) -> list[str]:
    lines = text.splitlines()
    bullets: list[str] = []
    in_section = False
    for line in lines:
        if line.startswith("## "):
            if in_section and bullets:
                break
            in_section = line.strip() == heading
            continue
        if not in_section:
            continue
        stripped = line.strip()
        if stripped.startswith("- "):
            bullets.append(stripped[2:].strip())
        elif bullets and stripped and not stripped.startswith("|"):
            break
    return bullets


def parse_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader)


def build_paragraph_xml(text: str) -> str:
    safe = escape(text)
    return (
        "<w:p>"
        "<w:r>"
        f"<w:t xml:space=\"preserve\">{safe}</w:t>"
        "</w:r>"
        "</w:p>"
    )


def write_docx(path: Path, paragraphs: Iterable[str]) -> None:
    document_body = "".join(build_paragraph_xml(paragraph) for paragraph in paragraphs)
    document_xml = (
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
        "<w:body>"
        f"{document_body}"
        "<w:sectPr>"
        "<w:pgSz w:w=\"12240\" w:h=\"15840\"/>"
        "<w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\" "
        "w:header=\"708\" w:footer=\"708\" w:gutter=\"0\"/>"
        "</w:sectPr>"
        "</w:body>"
        "</w:document>"
    )
    content_types = (
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
        "<Default Extension=\"rels\" "
        "ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
        "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
        "<Override PartName=\"/word/document.xml\" "
        "ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>"
        "</Types>"
    )
    relationships = (
        "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"
        "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        "<Relationship Id=\"rId1\" "
        "Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" "
        "Target=\"word/document.xml\"/>"
        "</Relationships>"
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", content_types)
        archive.writestr("_rels/.rels", relationships)
        archive.writestr("word/document.xml", document_xml)


def skill1_paragraphs(run_dir: Path) -> list[str]:
    summary_path = run_dir / "stage1_summary.md"
    candidates_path = run_dir / "stage1_candidates.md"
    summary_text = read_text(summary_path)
    candidates_text = read_text(candidates_path)
    candidate_rows = extract_markdown_table_rows(candidates_text, "## Ranked Candidate Pool")
    shortlist_rows = extract_markdown_table_rows(candidates_text, "## Recommended Signals for Stage 2")
    top_signals = ", ".join(row[1] for row in candidate_rows[:5] if len(row) > 1)
    paragraphs = [
        "Skill 1",
        "",
        "What this skill did",
        "Stage 1 searched stool literature for candidate molecules that could help distinguish IBD from IBS. The search emphasized inflammatory biomarkers and metabolomics, while also scanning fecal blood signals, mucosal-damage signals, immune-system signals, and dysbiosis-linked stool chemistry.",
        "",
        "Results produced",
        f"- Source files: {summary_path.name}, {candidates_path.name}",
        f"- Candidate pool size: {len(candidate_rows)}",
        f"- Stage 2 handoff size: {len(shortlist_rows)}",
        f"- Top candidate examples: {top_signals or 'Not parsed'}",
        "",
        "Key parameters and thresholds used",
        "- Direct IBD vs IBS stool evidence is preferred.",
        "- Strong one-disease-vs-healthy stool signals may enter provisionally if they remain biologically coherent and detector-relevant.",
        "- Signals must be stool-detectable and suitable for later sensing work.",
    ]
    return paragraphs


def skill2_paragraphs(run_dir: Path) -> list[str]:
    archive_dir = WORKSPACE / "skill_2_criss_cross" / "archive" / run_dir.name
    summary_path = archive_dir / "2026-03-16_criss_cross_summary.md"
    csv_path = archive_dir / "2026-03-16_promoter_molecule_mapping.csv"
    derived = False
    if not csv_path.exists():
        latest_dir = WORKSPACE / "skill_2_criss_cross" / "2026-03-16_criss_cross"
        summary_path = latest_dir / "2026-03-16_criss_cross_summary.md"
        csv_path = latest_dir / "2026-03-16_promoter_molecule_mapping.csv"
        derived = True
    rows = parse_csv_rows(csv_path)
    positive_rows = [
        row
        for row in rows
        if row.get("Gene / Operon", "").strip()
        not in {"NO KNOWN BACTERIAL RESPONSE FOUND", "USER-EXCLUDED DIRECT MODULE"}
    ]
    unsupported_rows = [
        row for row in rows if row.get("Gene / Operon", "").strip() == "NO KNOWN BACTERIAL RESPONSE FOUND"
    ]
    examples = ", ".join(
        f"{row.get('Molecule', '').strip()} -> {row.get('Promoter', '').strip()}"
        for row in positive_rows[:4]
    )
    paragraphs = [
        "Skill 2",
        "",
        "What this skill did",
        "Skill 2 mapped stool-associated molecules to direct bacterial promoters or transcriptional systems that respond to those molecules in tractable bacteria.",
        "",
        "Results produced",
        f"- Source files: {summary_path.name}, {csv_path.name}",
        f"- Direct mappings supported: {len(positive_rows)}",
        f"- Molecules with no known direct bacterial response: {len(unsupported_rows)}",
        f"- Example retained systems: {examples or 'No direct systems found'}",
    ]
    if derived:
        paragraphs.append("- Note: this export used the latest dated Skill 2 files because a per-run archive snapshot was not available for this run.")
    paragraphs.extend(
        [
            "",
        "Key parameters and thresholds used",
        "- Only direct activation or repression logic was retained.",
        "- Tractable bacteria were prioritized, especially E. coli and P. aeruginosa PAO1.",
        "- Project-specific engineering caveats were respected when present.",
    ]
    )
    return paragraphs


def skill3_paragraphs(run_dir: Path) -> list[str]:
    archive_dir = WORKSPACE / "skill_3_indirect_response" / "archive" / run_dir.name
    summary_path = archive_dir / "2026-03-16_indirect_response_summary.md"
    csv_path = archive_dir / "2026-03-16_indirect_response_mapping.csv"
    derived = False
    if not csv_path.exists():
        latest_dir = WORKSPACE / "skill_3_indirect_response" / "2026-03-16"
        summary_path = latest_dir / "2026-03-16_indirect_response_summary.md"
        csv_path = latest_dir / "2026-03-16_indirect_response_mapping.csv"
        derived = True
    rows = parse_csv_rows(csv_path)
    positive_rows = [
        row
        for row in rows
        if row.get("Gene / Operon", "").strip() != "NO STRONG INDIRECT BACTERIAL RESPONSE FOUND"
    ]
    unsupported_rows = [
        row
        for row in rows
        if row.get("Gene / Operon", "").strip() == "NO STRONG INDIRECT BACTERIAL RESPONSE FOUND"
    ]
    examples = ", ".join(
        f"{row.get('Molecule', '').strip()} -> {row.get('Promoter', '').strip()}"
        for row in positive_rows[:4]
    )
    paragraphs = [
        "Skill 3",
        "",
        "What this skill did",
        "Skill 3 searched for indirect bacterial sensing opportunities, where a stool molecule changes a secondary physiological condition such as metal starvation, oxidative stress, or envelope stress and bacteria respond to that consequence.",
        "",
        "Results produced",
        f"- Source files: {summary_path.name}, {csv_path.name}",
        f"- Supported indirect mappings: {len(positive_rows)}",
        f"- Molecules with no strong indirect mapping: {len(unsupported_rows)}",
        f"- Example retained systems: {examples or 'No indirect systems found'}",
    ]
    if derived:
        paragraphs.append("- Note: this export used the latest dated Skill 3 files because a per-run archive snapshot was not available for this run.")
    paragraphs.extend(
        [
            "",
            "Key parameters and thresholds used",
            "- Only true indirect consequence chains were retained.",
            "- Direct sensing systems were not relabeled as indirect.",
            "- Tractable bacteria and well-characterized regulators were prioritized.",
        ]
    )
    return paragraphs


def skill4_paragraphs(run_dir: Path) -> list[str] | None:
    archive_dir = WORKSPACE / "skill_4_detector_ranking" / "archive" / run_dir.name
    report_path = archive_dir / "2026-03-16_detector_analysis_report.md"
    csv_path = archive_dir / "2026-03-16_detector_candidates_ranked.csv"
    if not csv_path.exists():
        return None
    rows = parse_csv_rows(csv_path)
    top_rows = rows[:5]
    examples = ", ".join(
        f"{row.get('Rank', '').strip()}: {row.get('Molecule', '').strip()} -> {row.get('Promoter', '').strip()}"
        for row in top_rows
    )
    return [
        "Skill 4",
        "",
        "What this skill did",
        "Skill 4 integrated the upstream discovery and mapping outputs, then ranked the best detector systems for feasibility and biosensor engineering.",
        "",
        "Results produced",
        f"- Source files: {report_path.name}, {csv_path.name}",
        f"- Ranked detector candidates: {len(rows)}",
        f"- Top ranked systems: {examples or 'Not parsed'}",
        "",
        "Key parameters and thresholds used",
        "- Total score combined disease signal, stool stability, response strength, specificity, and engineering feasibility.",
        "- Direct and indirect systems were scored together, with direct sensing preferred when other factors were similar.",
    ]


def export_run(run_dir: Path, output_root: Path) -> Path:
    run_date = extract_run_date(run_dir.name)
    output_dir = next_output_dir(output_root, run_date)
    output_dir.mkdir(parents=True, exist_ok=False)
    write_docx(output_dir / "Skill1.docx", skill1_paragraphs(run_dir))
    write_docx(output_dir / "Skill2.docx", skill2_paragraphs(run_dir))
    write_docx(output_dir / "Skill3.docx", skill3_paragraphs(run_dir))
    skill4 = skill4_paragraphs(run_dir)
    if skill4 is not None:
        write_docx(output_dir / "Skill4.docx", skill4)
    return output_dir


def main() -> None:
    parser = argparse.ArgumentParser(description="Export skill run summaries to .docx files.")
    parser.add_argument("--run-dir", required=True, help="Path to the research run folder.")
    parser.add_argument("--output-root", required=True, help="Path to the root export folder, usually C:\\Users\\<user>\\.codex")
    args = parser.parse_args()
    run_dir = Path(args.run_dir).resolve()
    output_root = Path(args.output_root).resolve()
    output_dir = export_run(run_dir, output_root)
    print(output_dir)


if __name__ == "__main__":
    main()
