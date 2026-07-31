#!/usr/bin/env python3
"""
verify-cypress.py — Run a Cypress test spec N times to detect flakiness.

Usage:
  python3 verify-cypress.py <spec-file> [--runs N] [--browser chrome]

Example:
  python3 verify-cypress.py packages/cypress/cypress/tests/mocked/projects/notebook.cy.ts
  python3 verify-cypress.py packages/cypress/cypress/tests/mocked/projects/notebook.cy.ts --runs 5

Exit codes:
  0 — all runs passed (stable)
  1 — one or more runs failed (flaky or genuinely broken)
  2 — usage error / spec file not found
"""

import argparse
import subprocess
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a Cypress spec multiple times to detect flakiness."
    )
    parser.add_argument("spec", help="Path to the Cypress spec file")
    parser.add_argument(
        "--runs",
        type=int,
        default=3,
        help="Number of times to run the spec (default: 3)",
    )
    parser.add_argument(
        "--browser",
        default="chrome",
        help="Browser to use (default: chrome)",
    )
    parser.add_argument(
        "--headless",
        action="store_true",
        default=True,
        help="Run in headless mode (default: true)",
    )
    return parser.parse_args()


def find_cypress_bin() -> str:
    """Locate the Cypress binary in node_modules."""
    candidates = [
        Path("node_modules/.bin/cypress"),
        Path("packages/cypress/node_modules/.bin/cypress"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    return "npx cypress"


def run_spec(cypress_bin: str, spec: str, browser: str, run_index: int) -> bool:
    """Run the spec once. Returns True if the run passed."""
    cmd = [
        *cypress_bin.split(),
        "run",
        "--spec", spec,
        "--browser", browser,
        "--headless",
        "--reporter", "min",
    ]
    print(f"\n{'='*60}")
    print(f"  Run {run_index} — {spec}")
    print(f"{'='*60}")

    result = subprocess.run(cmd, capture_output=False)
    return result.returncode == 0


def main() -> int:
    args = parse_args()

    spec_path = Path(args.spec)
    if not spec_path.exists():
        print(f"ERROR: Spec file not found: {args.spec}", file=sys.stderr)
        return 2

    cypress_bin = find_cypress_bin()
    passes = 0
    failures = 0
    failed_runs: list[int] = []

    for i in range(1, args.runs + 1):
        ok = run_spec(cypress_bin, str(spec_path), args.browser, i)
        if ok:
            passes += 1
            print(f"\n✅ Run {i} PASSED")
        else:
            failures += 1
            failed_runs.append(i)
            print(f"\n❌ Run {i} FAILED")

    print(f"\n{'='*60}")
    print(f"  Results: {passes}/{args.runs} passed")
    if failures == 0:
        print(f"  ✅ STABLE — spec passed all {args.runs} runs")
    elif failures == args.runs:
        print(f"  ❌ BROKEN — spec failed all {args.runs} runs (not flaky, just broken)")
    else:
        print(f"  ⚠️  FLAKY — failed on runs: {failed_runs}")
        print(f"     Review test for: hardcoded waits, missing intercepts, shared state,")
        print(f"     index-based selectors, or Date.now() without cy.clock().")
    print(f"{'='*60}\n")

    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
