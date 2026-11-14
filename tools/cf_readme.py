#!/usr/bin/env python3
"""CurseForge's description from the GitHub README.

    python3 tools/cf_readme.py            write cf-readme.md beside README.md
    python3 tools/cf_readme.py --check    exit 1 if cf-readme.md is out of date
    python3 tools/cf_readme.py --ref TAG  point at a tag or commit, not main

cf-readme.md is README.md exactly, except that the paths CurseForge cannot
follow become full GitHub URLs: an image's (Markdown or <img src>) the raw
file, so it shows; a link's the file's page on GitHub, so it opens.
Absolute URLs, mail links and #anchors are left as they are.
"""
import argparse
import re
import sys
from pathlib import Path

REPO = "ahrymx/ahrymx.medalluin"
ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "README.md"
TARGET = ROOT / "cf-readme.md"

# ![alt](path "title") and [text](path "title"); the path ends at a space or ")"
MD_TARGET = re.compile(r'(!?)\[((?:[^\[\]]|\[[^\]]*\])*)\]\(\s*<?([^)\s>]+)>?((?:\s+"[^"]*")?)\s*\)')
IMG_SRC = re.compile(r'(<img\b[^>]*?\bsrc=)(["\'])([^"\']+)\2', re.IGNORECASE)


def relative(path):
    return not re.match(r"^(?:[a-z][a-z0-9+.-]*:|//|#)", path, re.IGNORECASE)


def resolve(text, ref):
    raw = f"https://raw.githubusercontent.com/{REPO}/{ref}/"
    page = f"https://github.com/{REPO}/blob/{ref}/"

    def clean(path):
        return path[2:] if path.startswith("./") else path

    def md(m):
        bang, label, path, title = m.groups()
        if not relative(path):
            return m.group(0)
        base = raw if bang else page
        return f"{bang}[{label}]({base}{clean(path)}{title})"

    def img(m):
        head, quote, path = m.groups()
        if not relative(path):
            return m.group(0)
        return f"{head}{quote}{raw}{clean(path)}{quote}"

    return IMG_SRC.sub(img, MD_TARGET.sub(md, text))


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="fail if cf-readme.md is out of date")
    ap.add_argument("--ref", default="main", help="branch, tag or commit the URLs point at")
    args = ap.parse_args()

    text = SOURCE.read_text(encoding="utf-8")
    out = resolve(text, args.ref)
    if args.check:
        now = TARGET.read_text(encoding="utf-8") if TARGET.exists() else None
        if now != out:
            print(f"{TARGET.name} is out of date: run python3 tools/cf_readme.py", file=sys.stderr)
            return 1
        return 0
    TARGET.write_text(out, encoding="utf-8")
    print(f"wrote {TARGET.name} (ref {args.ref})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
