#!/usr/bin/env python3
"""Checks a language's file against the words Medalluin's code looks up
(locale/locale.lua): every Tr["..."] key the code uses, beside the
L["..."] = "..." entries of locale/<lang>.lua.

    python3 tools/locale.py [ruRU]     (default ruRU)

Prints the keys the file has no entry for, the entries no code uses, and
the entries whose formats differ from their key's (the same %s/%d, in the
same order, unless the translation numbers them: %2$s). Exits 1 on a
missing key or a format that differs, 0 otherwise (unused entries only
warn)."""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(ROOT, "WoW", "Interface", "AddOns", "Medalluin")
STR = r'"((?:[^"\\]|\\.)*)"'
KEY = re.compile(r'\bTr\[' + STR + r'\]')
ENTRY = re.compile(r'^\s*L\[' + STR + r'\]\s*=\s*' + STR, re.M)
FMT = re.compile(r'%(?:(\d+)\$)?[-+ #0]*\d*(?:\.\d+)?([sdifgxXqc])')


def formats(s):
    """The conversions in order, each by the argument it reads."""
    out, n = [], 0
    for m in FMT.finditer(s.replace("%%", "")):
        n += 1
        pos = int(m.group(1)) if m.group(1) else n
        kind = "d" if m.group(2) in "di" else m.group(2)
        out.append((pos, kind))
    return sorted(out)


def keys():
    found = {}
    for base, _, files in os.walk(ADDON):
        if os.path.basename(base) == "locale":
            continue
        for f in files:
            if f.endswith(".lua"):
                path = os.path.join(base, f)
                with open(path, encoding="utf-8") as fh:
                    for i, line in enumerate(fh, 1):
                        for m in KEY.finditer(line):
                            found.setdefault(m.group(1), f"{os.path.relpath(path, ADDON)}:{i}")
    return found


def main():
    lang = sys.argv[1] if len(sys.argv) > 1 else "ruRU"
    with open(os.path.join(ADDON, "locale", lang + ".lua"), encoding="utf-8") as fh:
        text = fh.read()
    entries = {m.group(1): m.group(2) for m in ENTRY.finditer(text)}
    used = keys()
    missing = sorted(k for k in used if k not in entries)
    unused = sorted(k for k in entries if k not in used)
    bad = sorted(k for k, v in entries.items() if k in used and formats(k) != formats(v))
    for k in missing:
        print(f"missing  {used[k]}  {k}")
    for k in bad:
        print(f"format   {used[k]}  {k}  ->  {entries[k]}")
    for k in unused:
        print(f"unused   {k}")
    print(f"{lang}: {len(used)} keys, {len(entries)} entries, {len(missing)} missing, "
          f"{len(bad)} formats differ, {len(unused)} unused")
    sys.exit(1 if missing or bad else 0)


if __name__ == "__main__":
    main()
