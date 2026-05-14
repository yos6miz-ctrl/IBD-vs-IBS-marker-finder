import html
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent
README_PATH = REPO_ROOT / "README.md"


def load_readme() -> str:
    if README_PATH.exists():
        return README_PATH.read_text(encoding="utf-8")
    return "# IBD vs IBS Marker Finder\n\nREADME.md not found."


def markdown_to_html(markdown_text: str) -> str:
    lines = markdown_text.splitlines()
    html_parts: list[str] = []
    in_list = False

    def close_list() -> None:
        nonlocal in_list
        if in_list:
            html_parts.append("</ul>")
            in_list = False

    for raw_line in lines:
        line = raw_line.rstrip()
        stripped = line.strip()

        if not stripped:
            close_list()
            continue

        if stripped.startswith("# "):
            close_list()
            html_parts.append(f"<h1>{html.escape(stripped[2:])}</h1>")
            continue
        if stripped.startswith("## "):
            close_list()
            html_parts.append(f"<h2>{html.escape(stripped[3:])}</h2>")
            continue
        if stripped.startswith("### "):
            close_list()
            html_parts.append(f"<h3>{html.escape(stripped[4:])}</h3>")
            continue

        if stripped.startswith("- "):
            if not in_list:
                html_parts.append("<ul>")
                in_list = True
            html_parts.append(f"<li>{html.escape(stripped[2:])}</li>")
            continue

        close_list()
        html_parts.append(f"<p>{html.escape(stripped)}</p>")

    close_list()
    return "\n".join(html_parts)


def render_home_page() -> bytes:
    readme_html = markdown_to_html(load_readme())
    page = f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>IBD vs IBS Marker Finder</title>
    <style>
      :root {{
        color-scheme: light;
        --bg: #f5f7fb;
        --card: #ffffff;
        --text: #1f2937;
        --muted: #526070;
        --line: #d9e2ec;
        --accent: #155eef;
      }}
      body {{
        margin: 0;
        font-family: Aptos, Calibri, Arial, sans-serif;
        background: linear-gradient(180deg, #eef4ff 0%, var(--bg) 100%);
        color: var(--text);
      }}
      main {{
        max-width: 920px;
        margin: 0 auto;
        padding: 32px 20px 56px;
      }}
      .hero, .card {{
        background: var(--card);
        border: 1px solid var(--line);
        border-radius: 18px;
        box-shadow: 0 10px 30px rgba(21, 31, 56, 0.06);
      }}
      .hero {{
        padding: 28px 28px 20px;
        margin-bottom: 18px;
      }}
      .hero h1 {{
        margin: 0 0 10px;
        font-size: 2rem;
      }}
      .hero p {{
        margin: 0 0 14px;
        color: var(--muted);
        line-height: 1.55;
      }}
      .badges {{
        display: flex;
        flex-wrap: wrap;
        gap: 10px;
      }}
      .badge {{
        display: inline-block;
        padding: 8px 12px;
        border-radius: 999px;
        background: #eef4ff;
        color: var(--accent);
        font-size: 0.92rem;
        font-weight: 600;
      }}
      .card {{
        padding: 24px 28px;
      }}
      .card h2 {{
        margin-top: 0;
      }}
      .card p, .card li {{
        line-height: 1.6;
        color: var(--text);
      }}
      .muted {{
        color: var(--muted);
      }}
      a {{
        color: var(--accent);
      }}
      code {{
        background: #eef2f7;
        padding: 2px 6px;
        border-radius: 6px;
      }}
    </style>
  </head>
  <body>
    <main>
      <section class="hero">
        <h1>IBD vs IBS Marker Finder</h1>
        <p>
          Lightweight Render service for this repository. It exposes a health endpoint and a readable project overview
          while the actual scientific workflow remains in the Codex skills and helper scripts tracked in Git.
        </p>
        <div class="badges">
          <span class="badge">/healthz</span>
          <span class="badge">/metadata</span>
          <span class="badge">Render-ready</span>
        </div>
      </section>
      <section class="card">
        {readme_html}
        <p class="muted">
          This web service is intentionally minimal. It is designed to provide a clean deploy target for Render and a
          simple status surface for the repository.
        </p>
      </section>
    </main>
  </body>
</html>
"""
    return page.encode("utf-8")


class AppHandler(BaseHTTPRequestHandler):
    server_version = "IBDIBSMarkerFinderHTTP/1.0"

    def do_GET(self) -> None:
        if self.path in ("/", ""):
            body = render_home_page()
            self._send_response(200, "text/html; charset=utf-8", body)
            return

        if self.path == "/healthz":
            body = json.dumps({"status": "ok"}).encode("utf-8")
            self._send_response(200, "application/json; charset=utf-8", body)
            return

        if self.path == "/metadata":
            payload = {
                "service": "IBD vs IBS Marker Finder",
                "repo": "yos6miz-ctrl/IBD-vs-IBS-marker-finder",
                "skills": [
                    "stool-data-analyzer",
                    "criss-cross",
                    "indirect-response",
                    "promoter-upstream-length",
                    "best-candidates",
                ],
            }
            body = json.dumps(payload, indent=2).encode("utf-8")
            self._send_response(200, "application/json; charset=utf-8", body)
            return

        body = json.dumps({"error": "Not found"}).encode("utf-8")
        self._send_response(404, "application/json; charset=utf-8", body)

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        return

    def _send_response(self, status: int, content_type: str, body: bytes) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    port = int(os.environ.get("PORT", "10000"))
    server = ThreadingHTTPServer(("0.0.0.0", port), AppHandler)
    print(f"Serving on http://0.0.0.0:{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
