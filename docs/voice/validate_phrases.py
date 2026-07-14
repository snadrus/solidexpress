#!/usr/bin/env python3
"""Validate SolidExpress voice phrase corpus and (re)generate commands.gbnf.

Usage:
  python3 docs/voice/validate_phrases.py
  python3 docs/voice/validate_phrases.py --write-gbnf
  python3 docs/voice/validate_phrases.py --sync-kernel-copy

Exit 0 if phrases.json has >= 100 entries and passes schema checks.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PHRASES_PATH = Path(__file__).resolve().parent / "phrases.json"
GBNF_PATH = Path(__file__).resolve().parent / "commands.gbnf"
KERNEL_COPY = ROOT / "sxkernel" / "tests" / "data" / "voice_phrases.json"

KINDS = frozenset(
    {"constraint", "model", "view", "app", "variable", "query", "unmatched"}
)
UNITS = frozenset({"mm", "in", "deg", None})
REQUIRED = ("phrase", "kind", "verb")


def load_phrases(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise SystemExit(f"{path}: expected JSON array")
    return data


def validate(phrases: list[dict]) -> list[str]:
    errors: list[str] = []
    seen: set[str] = set()
    for i, row in enumerate(phrases):
        for key in REQUIRED:
            if key not in row or row[key] in ("", None):
                errors.append(f"[{i}] missing {key}")
        kind = row.get("kind")
        if kind not in KINDS:
            errors.append(f"[{i}] bad kind: {kind!r}")
        unit = row.get("unit", None)
        if unit not in UNITS:
            errors.append(f"[{i}] bad unit: {unit!r}")
        phrase = row.get("phrase")
        if isinstance(phrase, str):
            if phrase != phrase.lower():
                errors.append(f"[{i}] phrase not lowercase: {phrase!r}")
            if "  " in phrase or phrase != phrase.strip():
                errors.append(f"[{i}] phrase has extra whitespace: {phrase!r}")
            if phrase in seen:
                errors.append(f"[{i}] duplicate phrase: {phrase!r}")
            seen.add(phrase)
        value = row.get("value", None)
        if value is not None and not isinstance(value, (int, float)):
            errors.append(f"[{i}] value must be number or null")
    return errors


def gbnf_escape(s: str) -> str:
    """Escape a phrase for a GBNF double-quoted string literal."""
    return s.replace("\\", "\\\\").replace('"', '\\"')


def render_gbnf(phrases: list[dict]) -> str:
    """Union of literal phrases — practical for whisper.cpp constrained decoding."""
    header = [
        "# SolidExpress voice commands — GBNF for whisper.cpp constrained decoding.",
        "# Auto-synced from phrases.json via validate_phrases.py --write-gbnf",
        "# Each alternative is a full lowercase transcript (space-separated tokens).",
        "",
    ]
    body = ["root ::= command", "command ::="]
    for i, phrase in enumerate(p["phrase"] for p in phrases):
        alt = gbnf_escape(phrase)
        if i == 0:
            body.append(f'  "{alt}"')
        else:
            body.append(f'  | "{alt}"')
    return "\n".join(header + body) + "\n"


def coverage(phrases: list[dict]) -> tuple[Counter[str], Counter[tuple[str, str]]]:
    by_kind: Counter[str] = Counter()
    by_verb: Counter[tuple[str, str]] = Counter()
    for p in phrases:
        by_kind[p["kind"]] += 1
        by_verb[(p["kind"], p["verb"])] += 1
    return by_kind, by_verb


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--write-gbnf",
        action="store_true",
        help=f"Write {GBNF_PATH.relative_to(ROOT)} from phrases",
    )
    ap.add_argument(
        "--sync-kernel-copy",
        action="store_true",
        help=f"Copy phrases.json → {KERNEL_COPY.relative_to(ROOT)}",
    )
    ap.add_argument(
        "--check-gbnf",
        action="store_true",
        help="Fail if commands.gbnf is out of sync with phrases.json",
    )
    args = ap.parse_args()

    phrases = load_phrases(PHRASES_PATH)
    errors = validate(phrases)
    count = len(phrases)

    print(f"phrases: {count}")
    if count < 100:
        errors.append(f"need >= 100 phrases, have {count}")

    by_kind, by_verb = coverage(phrases)
    print("\nkind coverage:")
    for kind in sorted(by_kind):
        print(f"  {kind:12s} {by_kind[kind]:3d}")

    print("\nverb coverage:")
    for (kind, verb), n in sorted(by_verb.items()):
        print(f"  {kind:12s} {verb:18s} {n:3d}")

    expected_gbnf = render_gbnf(phrases)
    if args.write_gbnf:
        GBNF_PATH.write_text(expected_gbnf, encoding="utf-8")
        print(f"\nwrote {GBNF_PATH.relative_to(ROOT)}")

    if args.check_gbnf:
        if not GBNF_PATH.exists():
            errors.append(f"missing {GBNF_PATH}")
        else:
            actual = GBNF_PATH.read_text(encoding="utf-8")
            if actual != expected_gbnf:
                errors.append("commands.gbnf out of sync (run with --write-gbnf)")

    if args.sync_kernel_copy:
        KERNEL_COPY.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(PHRASES_PATH, KERNEL_COPY)
        print(f"copied → {KERNEL_COPY.relative_to(ROOT)}")

    if errors:
        print("\nERRORS:", file=sys.stderr)
        for e in errors:
            print(f"  {e}", file=sys.stderr)
        return 1

    print("\nOK (>= 100 phrases, schema valid)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
