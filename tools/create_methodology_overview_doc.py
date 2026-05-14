import datetime as _dt
import os
import xml.sax.saxutils as _xml
import zipfile


def esc(text: str) -> str:
    return _xml.escape(text, {"'": "&apos;", '"': "&quot;"})


def run_xml(text: str, bold: bool = False, size_half_points: int | None = None) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    preserve = ' xml:space="preserve"' if text.startswith(" ") or text.endswith(" ") else ""
    props = []
    if bold:
        props.append("<w:b/>")
    if size_half_points is not None:
        props.append(f'<w:sz w:val="{size_half_points}"/><w:szCs w:val="{size_half_points}"/>')
    rpr = f"<w:rPr>{''.join(props)}</w:rPr>" if props else ""
    if "\n" not in text:
        return f"<w:r>{rpr}<w:t{preserve}>{esc(text)}</w:t></w:r>"
    pieces = []
    for idx, part in enumerate(text.split("\n")):
        pieces.append(f"<w:r>{rpr}<w:t{preserve}>{esc(part)}</w:t></w:r>")
        if idx != len(text.split("\n")) - 1:
            pieces.append("<w:r><w:br/></w:r>")
    return "".join(pieces)


def paragraph_xml(
    text: str = "",
    *,
    bold: bool = False,
    size_half_points: int | None = None,
    before: int = 120,
    after: int = 120,
    line: int = 276,
    keep_next: bool = False,
) -> str:
    ppr_parts = [f'<w:spacing w:before="{before}" w:after="{after}" w:line="{line}" w:lineRule="auto"/>']
    if keep_next:
        ppr_parts.append("<w:keepNext/>")
    ppr = f"<w:pPr>{''.join(ppr_parts)}</w:pPr>"
    if text == "":
        return f"<w:p>{ppr}</w:p>"
    return f"<w:p>{ppr}{run_xml(text, bold=bold, size_half_points=size_half_points)}</w:p>"


def section_title(text: str) -> str:
    return paragraph_xml(text, bold=True, size_half_points=28, before=240, after=80, keep_next=True)


def subsection_title(text: str) -> str:
    return paragraph_xml(text, bold=True, size_half_points=24, before=180, after=60, keep_next=True)


def bullet(text: str) -> str:
    return paragraph_xml(f"- {text}", before=40, after=40, line=280)


def build_document_xml() -> str:
    blocks: list[str] = []

    blocks.append(
        paragraph_xml(
            "IBD vs IBS Marker Finder - Methodology Overview",
            bold=True,
            size_half_points=36,
            before=120,
            after=220,
            keep_next=True,
        )
    )

    blocks.append(section_title("Introduction"))
    blocks.append(
        paragraph_xml(
            "The goal of the IBD vs IBS Marker Finder is to identify stool-associated biological signals that can distinguish inflammatory bowel disease from irritable bowel syndrome and connect those signals to bacterial detector routes. "
            "The workflow is organized into five skills. Each skill handles one layer of the pipeline, from biomarker discovery to promoter mapping, promoter sizing, and final detector ranking."
        )
    )

    blocks.append(section_title("Skill 1 - Marker Identification"))
    blocks.append(
        paragraph_xml(
            "Skill 1 is the discovery stage. It gathers stool biomarker evidence and builds the candidate marker set that is strong enough to move into downstream bacterial-sensing analysis."
        )
    )
    blocks.append(subsection_title("What input data is used"))
    blocks.extend([
        bullet("Human stool biomarker studies, with direct IBD vs IBS evidence preferred whenever available."),
        bullet("Adjacent comparisons such as IBD vs healthy or IBS vs healthy when direct head-to-head studies are limited."),
        bullet("Protein markers, metabolites, blood-related stool signals, mucosal-damage markers, immune markers, and dysbiosis-associated chemistry."),
    ])
    blocks.append(subsection_title("How candidate biomarkers are identified"))
    blocks.extend([
        bullet("Markers are retained only if they are stool-detectable and show a clear disease-linked pattern."),
        bullet("The search favors signals that are biologically interpretable and plausibly usable as bacterial detector inputs."),
        bullet("Established controls such as calprotectin and lactoferrin are used as internal checks so the search remains anchored to known benchmark markers."),
    ])
    blocks.append(subsection_title("How markers are included or excluded"))
    blocks.extend([
        bullet("Markers are favored when the literature shows a consistent increase or decrease linked to IBD, IBS, or a strong adjacent comparator."),
        bullet("Markers are held back when the signal is weak, poorly replicated, not clearly measurable in stool, or too disconnected from later sensing design."),
        bullet("The output is filtered into advance, hold, or drop decisions so only the strongest candidates move forward."),
    ])
    blocks.append(subsection_title("Output of Skill 1"))
    blocks.append(
        paragraph_xml(
            "The output is a ranked stool-marker list with explicit disease patterns, evidence strength, and a clear handoff status for the next stage."
        )
    )

    blocks.append(section_title("Skill 2 - Promoter Mapping"))
    blocks.append(
        paragraph_xml(
            "Skill 2 translates each retained biomarker into direct bacterial sensing options. The goal is to identify promoters or regulatory systems that respond to the original molecule itself whenever such a route is biologically supported."
        )
    )
    blocks.append(subsection_title("How biomarkers are translated into sensing options"))
    blocks.extend([
        bullet("Each marker from Skill 1 is searched against bacterial regulatory literature and curated organism biology resources."),
        bullet("The search asks whether bacteria have a promoter, operon, or regulator that changes expression in response to that molecule."),
        bullet("The scan is done across relevant laboratory strains such as K12, PAO1, KT2440, and B. subtilis when the biology supports it."),
    ])
    blocks.append(subsection_title("How promoters are selected"))
    blocks.extend([
        bullet("For direct sensing, only the single best promoter per species is retained."),
        bullet("The best promoter is chosen by response strength, sensitivity, specificity, and evidence quality."),
        bullet("Weaker same-species alternatives are dropped from the retained set so the output stays focused and buildable."),
    ])
    blocks.append(subsection_title("How results are organized"))
    blocks.append(
        paragraph_xml(
            "The output is a structured direct-sensing map. Each retained marker is linked to the best-supported direct promoter option per species, with ranked alternatives kept only in the detailed backup mapping."
        )
    )

    blocks.append(section_title("Skill 3 - Indirect Response Mapping"))
    blocks.append(
        paragraph_xml(
            "Skill 3 handles molecules that are not sensed directly but create a secondary physiological state that bacteria can detect. This stage expands the pipeline from direct sensing to mechanistically supported proxy sensing."
        )
    )
    blocks.append(subsection_title("How indirect sensing is identified"))
    blocks.extend([
        bullet("Each retained host marker is checked for biologically supported downstream consequences such as zinc starvation, iron limitation, manganese starvation, oxidative stress, bile stress, or nitrosative stress."),
        bullet("Only consequences that are defensible from literature or curated biology are kept."),
        bullet("Broad unrelated stress responses are not accepted simply because they are easy to find."),
    ])
    blocks.append(subsection_title("How promoters are selected"))
    blocks.extend([
        bullet("All distinct downstream consequences are kept when they are biologically meaningful."),
        bullet("Within each consequence and species, only the single best promoter is retained."),
        bullet("This keeps the indirect stage complete without allowing weaker same-branch duplicates to crowd the results."),
    ])
    blocks.append(subsection_title("What defines a good indirect route"))
    blocks.append(
        paragraph_xml(
            "A good indirect route is one where the host marker, the downstream consequence, and the bacterial readout form a clear mechanistic chain rather than a vague inflammation-associated proxy."
        )
    )

    blocks.append(section_title("Skill 4 - Promoter Upstream Length Determination"))
    blocks.append(
        paragraph_xml(
            "Skill 4 determines how much upstream sequence should be taken for each retained promoter so the relevant regulatory behavior is preserved in a construct."
        )
    )
    blocks.append(subsection_title("How the upstream boundary is determined"))
    blocks.extend([
        bullet("Primary literature with promoter or transcription-start mapping is used first whenever available."),
        bullet("If literature is insufficient, curated databases such as EcoCyc for E. coli and the Pseudomonas Genome Database for PAO1 are used next."),
        bullet("Sequence-based promoter prediction is used only as a last fallback when stronger evidence is not available."),
    ])
    blocks.append(subsection_title("What is checked before assigning a length"))
    blocks.extend([
        bullet("The target gene, locus tag, strain, and coding start are normalized first."),
        bullet("Operon structure is checked so a downstream gene is not mistakenly assigned a promoter that actually sits upstream of another gene."),
        bullet("Promoter start, transcription start site, and translation start codon are kept separate during the calculation."),
    ])
    blocks.append(subsection_title("Output of Skill 4"))
    blocks.append(
        paragraph_xml(
            "The output is one promoter-sizing recommendation per retained route, together with a confidence label and the evidence basis used to justify that boundary."
        )
    )

    blocks.append(section_title("Skill 5 - Final Ranking and Selection"))
    blocks.append(
        paragraph_xml(
            "Skill 5 integrates the full pipeline and produces the final ranked detector panel. This is the decision stage: it asks which marker-promoter systems are strongest overall once evidence, biology, promoter behavior, and promoter-length practicality are considered together."
        )
    )
    blocks.append(subsection_title("How final candidates are ranked"))
    blocks.extend([
        bullet("First, human biomarker evidence strength is scored. This captures how strongly the original stool marker is supported for separating IBD and IBS or a strong adjacent comparator."),
        bullet("Second, marker-to-signal biological linkage is scored. This asks how directly the bacterial readout reflects the host marker or a tight first-order consequence."),
        bullet("Third, detector quality is scored. This includes specificity, stability, exposure window, promoter behavior, exact-strain evidence, and promoter-length practicality from Skill 4."),
    ])
    blocks.append(subsection_title("How trade-offs are handled"))
    blocks.extend([
        bullet("Strong clinical markers remain important even when the sensing route is indirect, but unstable or weakly specific detector routes are penalized."),
        bullet("Same-strain redundancy is reduced so two promoters that mainly report the same biology do not both occupy top ranks without a clear reason."),
        bullet("Species identity alone is not treated as a ranking advantage or penalty; differences must come from evidence or biology."),
    ])
    blocks.append(subsection_title("What the final panel provides"))
    blocks.append(
        paragraph_xml(
            "The final output is a ranked detector shortlist with a practical explanation of why each candidate sits where it does and what still weakens it."
        )
    )

    blocks.append(section_title("Summary"))
    blocks.append(
        paragraph_xml(
            "Together, the five skills form one connected pipeline: Skill 1 finds the right stool markers, Skill 2 maps direct sensing routes, Skill 3 adds mechanistically supported indirect routes, Skill 4 sizes the retained promoters, and Skill 5 ranks the final detector systems. "
            "This layered structure is robust because it combines human biomarker evidence, mechanistic bacterial biology, promoter design constraints, and practical detector reasoning in one workflow."
        )
    )

    body = "".join(blocks)
    sect = (
        "<w:sectPr>"
        '<w:pgSz w:w="12240" w:h="15840"/>'
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>'
        "</w:sectPr>"
    )
    return (
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas" '
        'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" '
        'xmlns:o="urn:schemas-microsoft-com:office:office" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" '
        'xmlns:v="urn:schemas-microsoft-com:vml" '
        'xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:w10="urn:schemas-microsoft-com:office:word" '
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" '
        'xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup" '
        'xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk" '
        'xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml" '
        'xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape" '
        'mc:Ignorable="w14 wp14">'
        f"<w:body>{body}{sect}</w:body></w:document>"
    )


def styles_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Calibri" w:cs="Calibri"/>
        <w:sz w:val="22"/>
        <w:szCs w:val="22"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault/>
  </w:docDefaults>
</w:styles>
"""


def content_types_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
"""


def root_rels_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
"""


def document_rels_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
"""


def core_xml() -> str:
    now = _dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    return f"""<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:dcmitype="http://purl.org/dc/dcmitype/"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>IBD vs IBS Marker Finder - Methodology Overview</dc:title>
  <dc:creator>Codex</dc:creator>
  <cp:lastModifiedBy>Codex</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">{now}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">{now}</dcterms:modified>
</cp:coreProperties>
"""


def app_xml() -> str:
    return """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"
  xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>Codex</Application>
</Properties>
"""


def write_docx(output_path: str) -> None:
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with zipfile.ZipFile(output_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", content_types_xml())
        zf.writestr("_rels/.rels", root_rels_xml())
        zf.writestr("word/document.xml", build_document_xml())
        zf.writestr("word/styles.xml", styles_xml())
        zf.writestr("word/_rels/document.xml.rels", document_rels_xml())
        zf.writestr("docProps/core.xml", core_xml())
        zf.writestr("docProps/app.xml", app_xml())


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 2:
        raise SystemExit("Usage: python create_methodology_overview_doc.py <output_docx_path>")
    write_docx(sys.argv[1])
