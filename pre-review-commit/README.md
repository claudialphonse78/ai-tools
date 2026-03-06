# Pre-Commit Reviewer

AI-powered code review agent for Cursor IDE and Claude Code. Analyzes uncommitted changes, flags issues with urgency-based scoring, and lets you fix them interactively — all without leaving your editor.

## What's Included

```
pre-review-commit/
├── .cursor/agents/pre-commit-reviewer.md   # Cursor IDE agent
├── .claude/skills/pre-commit-review/SKILL.md  # Claude Code skill
└── README.md                                # This file
```

| File | Platform | How to use |
|------|----------|-----------|
| `.cursor/agents/pre-commit-reviewer.md` | Cursor IDE | Copy to your repo's `.cursor/agents/`. Activates when you say "review my changes" or "pre-review". |
| `.claude/skills/pre-commit-review/SKILL.md` | Claude Code | Copy to your repo's `.claude/skills/pre-commit-review/`. Works identically to the Cursor version. |

## Commands

| Command | What it does |
|---------|-------------|
| `review my changes` | Full review of uncommitted code |
| `review my changes for PROJ-1234` | Review with Jira ticket context |
| `review my changes with screenshot` | Review + visual comparison against attached screenshot |
| `review my changes for PROJ-1234 with screenshot` | All three: code + Jira + visual |
| `fix 1, 3, 5` | Fix specific findings by number |
| `fix all must-fix` | Fix all [Must fix] findings |
| `fix all should-fix` | Fix all [Should fix] findings |
| `generate tests for <file>` | Generate unit tests for a source file |
| `generate tests for 2` | Generate tests for the file in finding #2 |
| `revert 3` | Undo fix for finding #3, keep other fixes |
| `skip` | Skip fixing, keep the review as info |
| `re-review` | Re-run the review after fixes |
| `help` | Show available commands and checks |

## What It Checks

| Category | Details |
|----------|---------|
| **Missing tests** | Unit tests for utilities/hooks, Cypress tests for page components, contract tests for BFF routes |
| **Cypress conventions** | Mock/E2E rule compliance (reads your project's Cypress guidelines if present), flakiness patterns (hardcoded waits, missing intercepts, shared state, etc.) |
| **Code hygiene** | `console.log`, `eslint-disable`, `@ts-ignore`, `any` types, `as` casts |
| **Security** | Hardcoded secrets, `dangerouslySetInnerHTML`, `eval()`, `innerHTML`, XSS vectors, sensitive data logging |
| **Type safety** | `as` casts, optional chaining without fallbacks, optional props misuse, hook dependency issues |
| **Performance** | `useCallback`/`useMemo` misuse, `useEffect` + `useState` anti-pattern, unstable hook returns |
| **Component architecture** | Single responsibility, prop interface width, custom hook extraction |
| **PatternFly standards** | Raw HTML vs PF components, inline styles, PF layout usage, CSS variables |
| **Impact analysis** | Related files not in the diff that may break (type changes, shared utils, component props) |
| **Jira acceptance criteria** | Cross-references ticket ACs against the diff, flags unmet requirements |
| **Visual comparison** | Compares screenshots against code changes, Jira ACs, and PF standards |

## Urgency Labels

| Label | Meaning |
|-------|---------|
| **Must fix** | Definitely wrong — will break or violate standards |
| **Should fix** | Very likely a problem — verify context |
| **Consider** | Improvement opportunity — not wrong per se |
| **Nitpick** | Style/formatting — totally optional |
| **FYI** | Awareness only — not directly actionable |

## Review Output Structure

The review follows a consistent structure:

1. **Change Walkthrough** — What changed, grouped by area, with a review effort score (1-5)
2. **Jira Context** (if ticket provided) — Summary, acceptance criteria match
3. **Detailed Findings** — Numbered, with problem + urgency + current code + improved code
4. **Summary Table** — Scannable checklist of all findings
5. **TL;DR** — One-line human judgment: counts + main concern
6. **Action Prompt** — "Which findings should I fix?"

## Optional Integrations

These enhance the review but are not required:

| Integration | What it adds | Required? |
|------------|-------------|-----------|
| **Atlassian MCP** (Jira) | Pulls ticket summary, description, acceptance criteria for cross-referencing | No — you can skip or paste ticket info manually |
| **Context7 MCP** | Fetches up-to-date React and PatternFly best practices from official docs | No — embedded examples cover the basics |
| **Web search** | Fallback for PF component verification when Context7 is unavailable | No — uses codebase patterns as last resort |

## Adapting to Your Repository

The agent is designed for the ODH Dashboard but can be adapted. Replace these repo-specific references:

| What to change | Current value | Replace with |
|---------------|--------------|-------------|
| Test file pattern | `frontend/src/` → `__tests__/*.spec.ts` | Your test file convention |
| Cypress test paths | `packages/cypress/cypress/tests/mocked/` | Your Cypress directory |
| Agent rule docs | `docs/agent-rules/unit-tests.md`, etc. | Your project's test guidelines (or remove) |
| Review guidelines | `docs/pr-review-guidelines.md`, `docs/best-practices.md` | Your project's review docs (or remove) |
| Mock factories | `@odh-dashboard/internal/__mocks__` | Your mock utilities |
| BFF packages | gen-ai, maas, model-registry | Your BFF packages (or remove) |
| UI library | PatternFly v6 | Your UI library (Material UI, Chakra, Ant Design, etc.) |
| Jira prefix | `RHOAIENG-*` | Your project's Jira prefix |
| Jest config | `@odh-dashboard/jest-config` | Your test config package |
| Type helpers | `EitherNotBoth`, `EitherOrNone` | Your type utilities (or remove) |

## Safety & Guardrails

- **Read-only during review.** No files are modified until you explicitly ask.
- **No auto-fix.** Every fix requires your approval.
- **Targeted revert.** If a fix breaks something, only that fix is reverted — other fixes stay intact.
- **Cite file and line.** Every finding includes a specific location.
- **Honest severity.** Not everything is a "must fix" — most things are suggestions.

## Roadmap

- **v1** (done): Core review — structural checks, code quality, PF standards, urgency labels
- **v1.5** (done): Jira integration, Context7 lookups, impact analysis
- **v2** (done): Screenshots, generate tests command, revert command, Cypress convention/flakiness checks, security checks, rollback guidance
- **v3** (planned): Review persona extraction — mine past PR comments to build area-specific review patterns
