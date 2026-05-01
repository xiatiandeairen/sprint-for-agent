"""Judge: emit prompts for a Claude Code subagent to score sprint runs.

Two modes:
  single — `python -m judge single <sprint_dir>` : one sprint, one score sheet
  batch  — `python -m judge batch [--limit N]`   : multiple sprints in one subagent call,
           returns N × 5-dim matrix, used for variance statistics

No Anthropic SDK is imported — judging is done by a Claude Code subagent
invoked separately via the Agent tool.
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
from pathlib import Path

BENCH_DIR = Path(__file__).resolve().parent
REPORTS_DIR = BENCH_DIR / "reports"
BASELINES_DIR = BENCH_DIR / "baselines"

DIMENSIONS = [
    ("clarity",         "user-visible output information density and readability"),
    ("term-hygiene",    "no internal algorithm terms leaked (compare with interaction-terms.md)"),
    ("decisiveness",    "recommendation specific; no hedge words (尽量/大概/或许/maybe/perhaps)"),
    ("scope-discipline","no out-of-scope edits; no over-extrapolation beyond the stated task"),
    ("handoff-quality", "handoff structure complete; downstream stage can consume without asking back"),
]
DIM_NAMES = [d[0] for d in DIMENSIONS]


def _handoffs_summary(sprint_dir: Path, max_chars_per_file: int = 2500) -> str:
    hd = sprint_dir / "handoffs"
    if not hd.is_dir():
        return "(no handoffs)"
    parts = []
    for p in sorted(hd.glob("*.md")):
        txt = p.read_text()[:max_chars_per_file]
        parts.append(f"--- {p.name} ---\n{txt}")
    return "\n\n".join(parts)


# ── single ────────────────────────────────────────────────────────────────


def emit_judge_prompt(fixture_or_dir: str) -> None:
    """Emit prompt for a single sprint (path or fixture-latest-symlink)."""
    target = Path(fixture_or_dir)
    if not target.is_absolute() and not target.is_dir():
        # treat as fixture name
        target = REPORTS_DIR / fixture_or_dir / "latest" / "sprint"
    if not target.is_dir():
        print(f"ERROR: no sprint dir at {target}", file=sys.stderr)
        sys.exit(2)

    print("== JUDGE PROMPT (single) ==\n")
    print(f"Target: {target}")
    print()
    print("Read all handoffs under `{target}/handoffs/`. Score on 5 dimensions 0-5.".format(
        target=target))
    for n, d in DIMENSIONS:
        print(f"  - {n}: {d}")
    print("\nOutput STRICT JSON:")
    print(json.dumps({
        "sprint_id": target.name,
        "scores": {n: {"value": 0, "reason": "..."} for n, _ in DIMENSIONS},
    }, indent=2, ensure_ascii=False))


# ── batch ─────────────────────────────────────────────────────────────────


def emit_batch_prompt(sprint_dirs: list[Path]) -> str:
    """Build a single prompt asking the subagent to score all sprints at once."""
    blocks = []
    for d in sprint_dirs:
        blocks.append(f"### SPRINT {d.name}\n" + _handoffs_summary(d))

    dims_block = "\n".join(f"  - {n}: {d}" for n, d in DIMENSIONS)
    template_json = json.dumps(
        {d.name: {n: 0 for n in DIM_NAMES} for d in sprint_dirs},
        indent=2,
    )
    return f"""You are rating sprint runs. Read each SPRINT section below (each shows
truncated handoffs). Score on 5 dimensions, integer 0-5, for each sprint.

Dimensions:
{dims_block}

Notes:
- Handoffs are INTERNAL docs (AI→AI stage handoff). Apply term-hygiene leniently —
  only flag if labels like "Demand Lock" / "Decision Register" leak into prose
  that would be shown to the end user. Section names themselves are fine.
- If a sprint is missing handoffs (e.g. early-era schema), still score based on
  what is present; lower handoff-quality score rather than refuse.

Output STRICT JSON matching this exact shape (just fill numbers in-place, no prose):

{template_json}

---

{chr(10).join(blocks)}
"""


def compute_stats(scores: dict[str, dict[str, int]]) -> dict:
    """Given {sprint_id: {dim: value}} return {dim: {mean, stdev, n}}."""
    out = {}
    for dim in DIM_NAMES:
        vals = [s.get(dim) for s in scores.values() if isinstance(s.get(dim), (int, float))]
        if not vals:
            out[dim] = {"mean": None, "stdev": None, "n": 0}
            continue
        out[dim] = {
            "mean": round(statistics.mean(vals), 3),
            "stdev": round(statistics.stdev(vals), 3) if len(vals) > 1 else 0.0,
            "n": len(vals),
            "min": min(vals),
            "max": max(vals),
        }
    return out


def load_scores(path: Path) -> dict[str, dict[str, int]]:
    data = json.loads(path.read_text())
    # Accept either raw {sprint_id: {dim: v}} or {scores: {...}}
    if "scores" in data and isinstance(data["scores"], dict):
        return data["scores"]
    return data


# ── CLI ───────────────────────────────────────────────────────────────────


def _recent_sprints(limit: int) -> list[Path]:
    from compare import discover_sprints
    return discover_sprints()[-limit:] if limit else discover_sprints()


def cmd_single(args) -> int:
    emit_judge_prompt(args.target)
    return 0


def cmd_batch(args) -> int:
    targets = _recent_sprints(args.limit)
    if not targets:
        print("no sprints to judge", file=sys.stderr)
        return 2
    prompt = emit_batch_prompt(targets)
    out = REPORTS_DIR / "judge-batch-prompt.txt"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(prompt)
    print(f"== BATCH PROMPT written to {out} ==")
    print(f"Sprints included ({len(targets)}):")
    for t in targets:
        print(f"  - {t.name}")
    print("\nNext: invoke a Claude Code subagent with the prompt above.")
    print(f"Save subagent's JSON response to: {REPORTS_DIR / 'judge-batch-scores.json'}")
    return 0


def cmd_stats(args) -> int:
    scores_path = Path(args.scores) if args.scores else REPORTS_DIR / "judge-batch-scores.json"
    if not scores_path.is_file():
        print(f"no scores file at {scores_path}", file=sys.stderr)
        return 2
    scores = load_scores(scores_path)
    stats = compute_stats(scores)

    print(f"Judge statistics ({len(scores)} sprints):\n")
    print(f"{'dim':<20} {'mean':>6} {'stdev':>7} {'min':>4} {'max':>4} {'gate?':>6}")
    print("-" * 55)
    for dim in DIM_NAMES:
        s = stats[dim]
        gate = "✓" if s.get("stdev") is not None and s["stdev"] <= 1.2 else "—"
        print(f"{dim:<20} {s.get('mean','-'):>6} {s.get('stdev','-'):>7} "
              f"{s.get('min','-'):>4} {s.get('max','-'):>4} {gate:>6}")

    baseline = BASELINES_DIR / "replay-stats.json"
    if args.update_baseline:
        baseline.parent.mkdir(parents=True, exist_ok=True)
        baseline.write_text(json.dumps({
            "computed_at_n_sprints": len(scores),
            "per_dimension": stats,
        }, indent=2, ensure_ascii=False))
        print(f"\nBaseline updated: {baseline}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="judge", description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("single")
    s.add_argument("target", help="sprint dir or fixture name")
    s.set_defaults(func=cmd_single)

    s = sub.add_parser("batch")
    s.add_argument("--limit", type=int, default=10,
                   help="include last N sprints (default 10)")
    s.set_defaults(func=cmd_batch)

    s = sub.add_parser("stats")
    s.add_argument("--scores", help="path to subagent score JSON (default reports/judge-batch-scores.json)")
    s.add_argument("--update-baseline", action="store_true",
                   help="save stats to baselines/replay-stats.json")
    s.set_defaults(func=cmd_stats)

    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
