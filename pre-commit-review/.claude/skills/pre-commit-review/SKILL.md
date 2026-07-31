---
name: pre-commit-review
description: Reviews uncommitted local code changes or GitHub Pull Requests for quality, missing tests, type safety, and PatternFly standards. Use when the user asks to review changes, pre-review, check code before committing, review a PR, or review a GitHub pull request by URL.
---

# Pre-Commit Review

Review uncommitted changes, present findings with urgency and improvement suggestions, then fix what the user asks.

**If the user says "help", show them this:**

```
PRE-COMMIT REVIEWER — Help

LOCAL MODE
  "review my changes"                     Full review of unstaged + staged code
  "review my changes for RHOAIENG-1234"   With Jira ticket context
  "review my changes with screenshot"     With visual comparison
  "review my changes as hotfix"           Light review — must-fix only
  "review my changes as refactor"         Architecture-focused depth
  "fix 1, 3, 5"                           Fix findings by number
  "fix all must-fix"                      Fix all Must fix findings
  "fix all should-fix"                    Fix all Should fix findings
  "generate tests for <file|finding#>"    Generate unit tests
  "revert 3"                              Undo fix for finding #3
  "re-review"                             Re-run after fixes
  "skip"                                  Keep review as info, no fixes

PR MODE
  "review PR <url>"                       Review a GitHub Pull Request
  "review PR <url> for RHOAIENG-1234"     With Jira ticket context
  "review PR <url> as hotfix"             Light review — must-fix only
  "review PR <url> as refactor"           Architecture-focused depth
  "re-review PR"                          Re-check after new commits — resolved / still-open / new
  "re-review PR since <sha>"              Scope new-finding scan to commits after SHA
  "evaluate PR comment"                   Is an existing thread worth acting on?
  "assess PR comment"                     Same as evaluate PR comment
  "post review"                           Post full review as PR comment
  "request changes"                       Post findings and request changes
  "post inline 1,3,5"                     Post selected findings as inline comments
  "post all must-fix inline"              Post all Must fix as inline comments
  "post all should-fix inline"            Post all Should fix as inline comments
  "preview comments"                      Show what would be posted before sending

BOTH MODES
  "reviewer questions"                    3-5 questions a careful reviewer would ask
  "deep review"                           Judgment-only deep dive, no checklist
  "deep review <file>"                    Deep dive on a specific file
  "help"                                  Show this help

WHAT I CHECK
  Pre-flight: tsc + lint before review (local mode)
  Tests: unit (utils/hooks), Cypress mock (page components), contract (BFF routes)
  Cypress: convention compliance, flakiness patterns
  Hygiene: console.log, eslint-disable, @ts-ignore, any, as casts
  Quality: error handling, type safety, performance, component architecture
  Standards: PatternFly (raw HTML, inline styles), security (secrets, XSS)
  Context: impact analysis, Jira AC match, visual screenshot comparison

URGENCY LABELS
  [Must fix]   — definitely wrong, will break or violate standards
  [Should fix] — very likely a problem, verify context
  [Consider]   — improvement opportunity, not wrong
  [Nitpick]    — style only, totally optional
  [FYI]        — awareness only, not actionable

INTEGRATIONS (all optional)
  Jira (Atlassian MCP) — ticket summary + acceptance criteria
  Context7 MCP         — up-to-date React + PatternFly docs
  gh CLI (primary)     — PR diff, existing comments, post reviews (PR mode)
  GitHub MCP           — fallback if gh CLI unavailable
```

---

## How you work

You operate in three phases: **Review → Present → Act.** Never skip phases. Never auto-fix without the user's approval.

---

## Phase 1: REVIEW

### Step 0: Determine review mode

Check the user's message for a GitHub PR URL matching the pattern `https://github.com/<owner>/<repo>/pull/<number>`.

- **PR URL detected → PR Review Mode:** Parse `owner`, `repo`, and `pull_number` from the URL. Skip **Step 1** (local gather changes) only; go to **Step 1 (PR mode)**, then **Step 1d**, then **Step 1b** and **Step 1c** as usual.
- **No PR URL → Local Review Mode:** Continue with Step 1 (Gather changes) as normal. Skip **Step 1d** entirely (no PR thread to read).

**Review depth override (both modes):** Check if the user's message ends with `as hotfix` or `as refactor`:
- `as hotfix` → **Light review**: report Must fix findings only; skip test coverage checks and Context7; open with "Light review — blocker findings only."
- `as refactor` → **Architecture focus**: prioritize DRY violations, impact analysis, type changes, and component responsibility; skip the new-test requirement; open with "Refactor review — architecture focus."
- **Default (no suffix):** Full depth always.

---

### Step 0.5: Pre-flight checks *(Local Review Mode only)*

Before gathering changes, run these two commands:

```bash
npx tsc --noEmit 2>&1 | head -20
npm run lint 2>&1 | head -20
```

**Behaviour:**
- If either fails: surface the failures at the top of the review output under a `⚠️ PRE-FLIGHT FAILURES` heading, then continue the review normally. Pre-flight failures are shown as context — they are not numbered findings.
- If both pass: one line — `✅ Pre-flight: tsc + lint clean` — then proceed.
- If neither command exists (non-JS repo, commands not found): skip silently and proceed.

---

### Step 1: Gather changes *(Local Review Mode only)*

> **If you are in PR Review Mode** (Step 0 detected a GitHub PR URL), **skip this entire step** and go directly to **Step 1 (PR mode)** below. Do not run any git commands.

Run these commands to understand what changed:

```bash
git diff
git diff --cached
git status
```

From the output, build a list of:
- **Modified files** (with their package: frontend, backend, packages/*)
- **New files** (untracked)
- **Deleted files**

If there are no changes, tell the user and stop.

### Step 1b: Jira ticket context

Resolve Jira context before asking follow-up questions. Use ticket key pattern matching (e.g. `RHOAIENG-1234`) across these signals in order:
1. **User message** (highest confidence)
2. **PR title/body** *(PR Review Mode only)*
3. **Branch name** via `git branch --show-current` *(Local Review Mode only)*

Inference rules:
- If exactly one unique key is found, **use it automatically**. Do not ask the generic Jira question.
- If multiple different keys are found, ask a targeted clarifying question naming the conflicting keys.
- If no key is found, ask: "Is there a Jira ticket for this work? (e.g. RHOAIENG-1234, or 'skip')"
- If the user says "skip", "none", or otherwise declines Jira context, continue the review without ticket lookup.

When a key is resolved (either inferred or confirmed), state what you are using and pull the ticket using the Atlassian MCP when configured:

```
CallMcpTool: user-atlassian / jira_get_issue
  issue_key: "RHOAIENG-1234"
  fields: "summary,description,status,labels,priority"
```

If Atlassian MCP is not available, ask the user to paste the ticket description (summary + acceptance criteria).

From the ticket, extract:
- **Summary** — what the work is supposed to accomplish
- **Description / Acceptance Criteria** — specific requirements, bullet points of what is expected
- **Labels** — whether it's a bug, enhancement, tech-debt, needs-ux, etc.

Use this context throughout the review:
- In **structural checks**: if the ticket's acceptance criteria mention "add/update Cypress mocked tests" or "add/update unit tests," escalate missing tests to **Must fix** instead of Should fix.
- In **quality review**: check whether the diff actually addresses what the ticket describes. If the ticket says "handle timeout case" but the diff has no timeout handling, flag it.
- In **present**: add a section before the findings:
  ```
  ### Jira Context: RHOAIENG-1234
  **Summary:** [ticket summary]
  **Acceptance Criteria match:** [which ACs are addressed / which are missing in the diff]
  ```
- If acceptance criteria are clearly unmet by the diff, report them as **Should fix** with category `missing-requirement`.

### Step 1c: Screenshot comparison (if provided)

If the user attached a screenshot (or multiple), compare the visible UI against:

1. **Code changes:** Does the screenshot reflect what the diff implements? Look for components added/removed in the diff and verify they appear in the screenshot.
2. **Jira ACs (if available):** Does the screenshot satisfy the acceptance criteria? For example, if the AC says "show a danger icon when status is Failed," check if the screenshot shows that icon.
3. **PatternFly standards:** Are there visible issues — wrong colors, broken layout, non-PF-looking elements (custom styled buttons, raw HTML tables), missing spacing?
4. **Obvious bugs:** Empty states with no message, overlapping elements, truncated text, missing loading indicators.

Report visual findings using category `**[VISUAL]**` with urgency:
- **Must fix** — screenshot clearly contradicts a Jira AC or shows a runtime error/crash
- **Should fix** — visible PF violation, broken layout, missing UI element that the code should produce
- **Consider** — minor visual polish, spacing that looks off, color that could be a PF variable

If no screenshot is provided, skip this step entirely. Do not ask for screenshots unprompted.

### Step 1 (PR mode): Fetch PR data

Extract `owner`, `repo`, and `pull_number` from the URL (`https://github.com/<owner>/<repo>/pull/<number>`).

**Fetch PR metadata — `gh` CLI (primary):**

```bash
gh pr view <url> --json title,body,labels,baseRefName,headRefName,headRefOid,number,state
```

From the response, extract:
- **Title** — look for Jira ticket keys (e.g. `RHOAIENG-1234`) to pre-populate Step 1b
- **Body** — may contain acceptance criteria, linked issues, test instructions, or reviewer notes
- **Labels** — e.g. `bug`, `enhancement`, `needs-review`, `wip`
- **Base branch / head branch** — context for what this PR targets

**Fetch changed files and diffs:**

```bash
gh pr diff <url>
gh pr view <url> --json files
```

Use the `gh pr diff` output as the unified diff source (same format as `git diff`). Use `gh pr view --json files` to get the list of changed files with `additions`, `deletions`, and `status`.

**If `gh` is unavailable**, fall back to the GitHub MCP:

```
CallMcpTool: user-github / get_pull_request
  owner: "<owner>"
  repo: "<repo>"
  pull_number: <number>

CallMcpTool: user-github / get_pull_request_files
  owner: "<owner>"
  repo: "<repo>"
  pull_number: <number>
```

The MCP `get_pull_request_files` returns each file with `filename`, `status`, `additions`, `deletions`, and `patch` (unified diff) — use `patch` as the diff source.

### Step 1d (PR mode only): Existing PR feedback

After you have `owner`, `repo`, `pull_number`, and file patches, **load existing reviews and comments** on this PR (humans, CodeRabbit, other bots) so your write-up does not mostly repeat what is already on the thread.

**Fetch using `gh` CLI (primary):**

```bash
gh api repos/<owner>/<repo>/pulls/<pull_number>/reviews
gh api repos/<owner>/<repo>/pulls/<pull_number>/comments
gh api repos/<owner>/<repo>/issues/<pull_number>/comments
```

**If `gh` is unavailable**, fall back to the GitHub MCP — use any tools your `user-github` server exposes for listing pull request **reviews**, **inline review comments** (on the diff), and **issue / conversation comments** on the PR.

Build a **short private digest** for yourself (do not dump the whole thread into the final review): bullets for each distinct theme, author when obvious (bot vs human), and `file:line` when the API provides it.

**Dedupe rules (apply in Phase 2 when writing findings):**

- Do **not** emit a numbered finding whose substance is **already well covered** by an existing open comment or review, unless you are **adding material evidence** (e.g. security, Jira AC gap), **correcting wrong or outdated advice**, or the earlier comment no longer applies to the **current** patch.
- If you skip a finding purely for overlap, you may omit it, or add **one line** under optional heading **Existing feedback (PR)** only when it helps the author, e.g. "CodeRabbit already flagged missing tests for `foo.ts` — agree; no extra detail here."
- Never paste long quotations of other reviewers' comments into your review body.

**Then continue with Step 1b (Jira) and Step 1c (screenshot) as normal**, using the PR title and body for Jira key auto-detection instead of the branch name.

### Evaluate a specific PR comment (PR context)

When the user asks whether **one** existing comment is worth acting on (e.g. `"evaluate PR comment"`, `"assess PR comment"`, "is this CodeRabbit comment valid?", with a **paste of the comment**, a **permalink**, or **file + line + excerpt**), and a PR is in scope (PR URL in the message or already in PR Review Mode):

1. Reuse or refresh the same fetches as **Step 1d** so you can match the user's reference to a real thread.
2. Compare the comment to the **current PR diff** (`patch` per file) and to `docs/pr-review-guidelines.md` / `docs/best-practices.md` where relevant.
3. Reply with a compact verdict (no Phase 2 template required unless the user asks for a full review):

**Verdict:** Worth addressing / Partially / Nitpick / Not warranted (one line each for **why**).

**Against the current diff:** Does it apply to changed lines? Is it still true after the latest commits?

**Optional:** One-sentence **suggested reply** for the GitHub thread if the author should push back or ask for clarification.

If the user did not supply a PR URL and you are not already in PR mode, ask once for the PR link.

**PR mode limitations — note these in your review when relevant:**
- You cannot run `git log`, `git blame`, or read files outside the diff. Work only from the `patch` data.
- Impact analysis (Step 2b) is limited to what is visible in the PR diff. When it would require reading a local file, add a note: "Impact analysis limited to PR diff — verify locally that `<file>` still compiles."
- All structural checks (Step 2) still apply — analyse the `patch` for each file as you would a `git diff`.

---

### Step 2: Structural checks

For each changed or new file, run these deterministic checks:

**Missing tests:**
- If a file in `frontend/src/` exports utility functions or custom hooks, check if a corresponding `__tests__/*.spec.ts` file exists. The pattern is: source at `src/foo/bar.ts` → test at `src/foo/bar/__tests__/bar.spec.ts` or `src/foo/__tests__/bar.spec.ts`.
- If a file under `frontend/src/pages/` or `frontend/src/concepts/` is a new or significantly changed component (`.tsx` file), check for cypress mock test coverage:
  1. Identify the feature area from the path (e.g. `pages/projects/notebook/` → area is `projects`)
  2. Search for related cypress specs: look in `packages/cypress/cypress/tests/mocked/` for a directory matching the area (e.g. `mocked/projects/`)
  3. Within that directory, search for test files that reference the component name or its functionality
  4. If no cypress coverage exists for the changed component, flag it as **Should fix** with category `missing-tests`
  5. Also check module-specific cypress directories in `packages/*/frontend/src/__tests__/cypress/` for packages that have their own tests
- If a file is a BFF route in a package with a BFF (gen-ai, maas, model-registry), check if contract tests exist.

**Code hygiene:**
- Scan diffs for added `console.log` statements — flag each one.
- Scan diffs for added `eslint-disable` comments — flag each one.
- Scan diffs for added `@ts-ignore` or `@ts-expect-error` — flag each one.
- Scan diffs for added `any` type annotations — flag each one.
- Scan diffs for added `as` type casts that aren't in test files — flag each one.

**Cypress flakiness patterns:**
If the diff includes new or modified Cypress test files (`.cy.ts`, `.cy.tsx`), scan for patterns that commonly cause flaky tests. Flag each as **Consider** with category `tests`. After flagging, note: "Run `python3 pre-commit-review/verify-cypress.py <spec-file> --runs 3` locally to confirm the test is stable before merging."
- `cy.wait(<number>)` — hardcoded timeout instead of waiting for a condition (`cy.intercept` + `cy.wait('@alias')`)
- Selecting by index, text content, or CSS class instead of `data-testid`
- Network calls without matching `cy.intercept()` — causes race conditions
- Tests that rely on execution order or shared state without proper `beforeEach` cleanup
- `new Date()` or `Date.now()` without clock mocking (`cy.clock`)
- Clicking elements without ensuring they're visible/stable first (missing `.should('be.visible')` before `.click()`)

**Cypress convention check:**
If the diff includes Cypress test files, also verify they follow the project's conventions. Pick the right doc based on the file path:
- Files in `**/tests/mocked/**` or `**/__tests__/cypress/**` → read `docs/agent-rules/cypress-mock.md`
- Files in `**/tests/e2e/**` → read `docs/agent-rules/cypress-e2e.md`

Check the modified test against the doc's key conventions (page objects, interceptor patterns, `data-testid` usage, file structure, naming). Flag deviations as **Consider** with category `tests`.

**Security:**
- Scan diffs for hardcoded secrets: API keys, tokens, passwords, connection strings. Look for patterns like `token = "..."`, `apiKey:`, `password:`, `Authorization: Bearer`, base64-encoded strings that look like credentials.
- Scan for `dangerouslySetInnerHTML` usage — flag as **Should fix**. If the input comes from user data or an API without sanitization, escalate to **Must fix**.
- Scan for URLs constructed from user input without validation — possible XSS or open redirect.
- Scan for `eval()`, `new Function()`, `innerHTML` assignments — flag each one.
- Scan for sensitive data logged (user emails, tokens, k8s secrets) in `console.log` or error messages that surface to UI.
- If `package.json` or `package-lock.json` changed, note new/updated dependencies and suggest the user run `npm audit` to check for known vulnerabilities.

### Step 2b: Impact analysis

After checking individual files, step back and consider what's **missing from the diff**. This catches incomplete changes.

For each changed file, ask:
1. **Types/interfaces changed?** If a type in `types.ts` was modified, search for all importers of that type. If any consuming file wasn't updated, flag it as a warning: "file X imports [type] which changed — verify it still compiles."
2. **Shared utility changed?** If a utility function's signature or behavior changed, search for callers. Flag untouched callers that may break.
3. **Component props changed?** If a component's props interface was modified, search for all usages of that component. Flag any parent that passes the old prop shape.
4. **Route/API changed?** If a BFF route or API call was modified, check the corresponding frontend consumer (or vice versa).
5. **Config/constant changed?** If an enum, constant, or config value was modified, check all references.

How to check: for each changed export, run a search across the codebase for its name. If there are consumers not in the diff, flag them.

Report these as category `impact` with urgency based on likelihood of breakage:
- Type/signature changes with untouched consumers → **Should fix**
- Behavioral changes with untouched consumers → **Consider** (may still work)
- New exports with no consumers → **FYI** (skip unless suspicious)

### Step 3: Quality review

**Before reviewing, read these project docs for the team's standards:**
- `docs/pr-review-guidelines.md` — the team's PR review checklist
- `docs/best-practices.md` — PF-first coding, hook/memoization rules, custom component policy

Read each changed file (not just the diff — read the full file for context). Analyze:

- **Error handling:** Flag async submit handlers missing any of: `try/catch`, loading state (`isSubmitting` or equivalent), error surfacing (`<Alert variant="danger">`), button `isDisabled` during submit. All four must be present in a submit flow. Flag each missing piece as **Should fix** [ERROR-HANDLING]. Also flag data fetches with no loading/error state exposed to the UI.

- **Type safety:**
  - `as` cast outside test files → **Should fix** [TYPES]: suggest a type guard or proper narrowing instead
  - `(x as any)` anywhere → **Must fix** [TYPES]: eliminates all type safety
  - Optional chaining result used directly without `?? fallback` (e.g. `a?.b?.c` assigned to a non-optional) → **Consider** [TYPES]
  - Props marked optional (`prop?:`) that are always passed by all call sites → **Consider** [TYPES]: make required, or use `EitherNotBoth` for mutually exclusive states
  - `// eslint-disable-next-line react-hooks/exhaustive-deps` → **Must fix** [TYPES]: add the missing dep and wrap with `useCallback` if needed to keep stability

- **Edge cases:** Are null/undefined checks present? Empty arrays handled? Loading/error states covered?

- **Performance:**
  - `useCallback` wrapping a function used only locally (not passed as prop, not returned from a hook) → **Consider** [PERF]: plain function is fine, `useCallback` adds overhead not benefit
  - `useEffect` + `useState` where the value can be derived during render → **Should fix** [PERF]: replace with `useMemo` to avoid the extra render cycle
  - `useMemo` for trivial computation (string concatenation, arithmetic, single boolean) → **Consider** [PERF]: compute inline
  - Function or object returned from a custom hook without `useCallback`/`useMemo` → **Should fix** [PERF]: callers get a new reference every render, breaking memoization in consuming components:

  ```tsx
  // BAD: new function reference every render
  const useData = () => {
    const refresh = () => api.fetch().then(setData);
    return { data, refresh };
  };
  // GOOD: stable reference
  const useData = () => {
    const refresh = useCallback(() => api.fetch().then(setData), []);
    return { data, refresh };
  };
  ```

- **Component architecture:** Flag a component that mixes more than one of: data fetching/API calls, form/local state management, validation logic, or >50 lines of JSX — suggest extracting data and state logic into custom hooks. Flag props passing a whole object when the component body only uses one field — suggest passing only the needed value. **Consider** [QUALITY] for both.

- **Patterns:** Does the code follow patterns already established in the codebase? (Check neighboring files for conventions.)

- **Git context (intent, not blame):** For code that looks questionable, check its history to understand intent — NOT to call out individuals. Never mention author names in findings.
  - `git log --oneline -5 -- <file>` — was this area recently refactored? Is the pattern new or long-established?
  - If the surrounding code follows the same pattern you're about to flag, the pattern may be intentional. Downgrade to **Consider** and note: "existing pattern in this file — verify if intentional"
  - If the pattern was introduced recently and differs from the rest of the codebase, it's more likely a mistake. Keep the urgency.
- **PatternFly:** Before running any PF checks, verify at least one of these is true: (a) diff imports from `@patternfly/*`, (b) `docs/best-practices.md` exists and mentions PatternFly, (c) `.claude/rules/css-patternfly.md` exists. If none are true, skip this section and note "No PF context detected."

  When PF context is confirmed, read `docs/best-practices.md` first — it is the authoritative source for PF-first rules in this project. Then apply these checks:

  **Check 1 — Raw HTML where a PF component exists → Should fix [PF]**
  The rule: in a `.tsx` file in a PF project, any native HTML element that has a PF equivalent should not be used. Quick reference for common cases:

  | Instead of | Use |
  |-----------|-----|
  | `<button>`, `<div onClick>` | `<Button>` |
  | `<a href>` | `<Button variant="link">` or PF router link |
  | `<input>`, `<textarea>`, `<select>` | `<TextInput>`, `<TextArea>`, `<Select>` |
  | Raw `<table>`, `<tr>`, `<td>` | PF `<Table>` components |
  | Custom modal / alert / spinner div | `<Modal>`, `<Alert>`, `<Spinner>` |
  | `<h1>`–`<h6>` | `<Title>`, `<Content>` |

  For elements not in this table — search 2–3 neighboring files for how the same pattern is implemented. If the codebase uses PF for it, flag as **Should fix** [PF]. If the codebase also uses raw HTML, downgrade to **Consider** and note "existing pattern — verify if intentional." If no PF equivalent exists (e.g. `<canvas>`, `<video>`), flag as **FYI** [PF]: "If PF can't cover this, add a `// TODO: PF gap` comment above it."

  **Check 2 — Direct `@patternfly/*` import when a project wrapper exists → Should fix [PF]**
  Parse import declarations in the diff. For each `import { X } from '@patternfly/react-core'` (or other `@patternfly/*` packages): check if `frontend/src/components/` or `frontend/src/concepts/dashboard/` contains a wrapper for `X`. If yes, flag: "use project wrapper instead of raw PF component." Skip the wrapper's own implementation file.

  **Check 3 — Inline `style={{}}` → Should fix [PF]**
  Any `style={{}}` prop on a PF component is almost always wrong. Follow the priority order before concluding custom styling is needed:
  1. PF component prop (e.g. `variant`, `isFullWidth`, `isInline`)
  2. PF layout component (`<Flex>`, `<Stack>`, `<Grid>`, `<Gallery>`)
  3. PF CSS variables (`--pf-t--global--color--*`, spacer tokens)
  4. Custom CSS (last resort — if needed, belongs in `frontend/src/concepts/dashboard`, not inline)

  If a genuine PF gap exists (PF truly cannot do it), flag as **FYI** [PF] — not a violation.

  **Check 4 — PF component props correct?** (e.g. `variant`, `size`, `status` values)
  Verify in order: (1) Context7 MCP if available, (2) `patternfly.org`, (3) how the same component is used elsewhere in the repo.

### Step 3b: Context7 best-practice lookups (if MCP available)

If the Context7 MCP is configured, use it to fetch **up-to-date best practices** for patterns found in the diff. This goes beyond the project docs and Step 3 rules — it catches evolving APIs, deprecated patterns, and component-specific nuances.

**Skip this step entirely if Context7 MCP is not available.** Step 3 plus the linked `docs/*` (and `react.md` when present) are sufficient on their own. Context7 is strictly additive.

**Library IDs:**
- React docs: `/websites/react_dev`
- PatternFly React: `/patternfly/patternfly-react`

**When to query:**
- **React hooks** (`useEffect`+`useState`, `useMemo`, `useCallback`, `forwardRef`, `useRef`, `Suspense`, `dangerouslySetInnerHTML`): query `/websites/react_dev` with the pattern name + "best practices pitfalls"
- **Any PF component** in the diff: query `/patternfly/patternfly-react` with the component name + "props variants accessibility"
- **Any other hook or pattern you're uncertain about**: query `/websites/react_dev`

Max **3 calls per review** — prioritize patterns you're least confident about or PF components not seen elsewhere in the codebase.

**How to use the results:**
1. Compare what Context7 returns against what the diff does. If the diff violates documented best practices, include it as a finding.
2. Cite the source in the finding: "Per React docs (react.dev): ..." or "Per PatternFly docs: ..."
3. If Context7 confirms the code is correct, don't report a false positive — skip it.
4. Limit to **3 Context7 calls per review** to avoid slowing down the review. Prioritize: (a) patterns you're most uncertain about, (b) PF components you haven't seen in this codebase before, (c) React hooks used in unusual ways.

---

## Phase 2: PRESENT

Output the review in this exact structure. **Every heading and label must include both the emoji AND the text label** so the output is readable even when emojis don't render (known Cursor issue).

In **PR Review Mode**, apply **Step 1d dedupe rules** when you write findings: do not repeat threads that already exist on the PR unless you add real new signal (see Step 1d).

### Part A: Change Walkthrough

Before findings, output a structured summary of what changed. Group related file changes by feature area. This gives the reader context before they see findings.

```
## Change Walkthrough

| Area | Files | What changed |
|------|-------|-------------|
| Kueue status | `kueue/index.ts`, `kueue/types.ts` | Added new status mapping helper, extended KueueStatus enum |
| Notebook UI | `NotebookStateStatus.tsx` | Integrated kueue status display into status column |
| Notebook modal | `StartNotebookModal.tsx` | Added warning banner for kueue-blocked notebooks |

**Review effort: 3/5** (moderate — touches shared types + 2 UI components, needs manual PF verification)
```

**Review effort scoring:**
- **1/5** — Trivial: typo fix, config change, single-line edit
- **2/5** — Small: one file, straightforward logic, clear intent
- **3/5** — Moderate: multiple files, some type/prop changes, UI work
- **4/5** — Large: cross-cutting changes, new feature, architectural impact
- **5/5** — Complex: many files, new patterns, needs careful review of interactions

### Part A2: What's done well

After the walkthrough table, always include this section — never skip it even if the review has many findings.

```
### ✅ What's done well

- [specific thing done correctly — cite file:line or a named pattern visible in the diff]
- [specific thing — e.g. "Error states handled consistently across all async calls in useKueueStatus.ts:34–67"]
- [specific thing — e.g. "Cypress test uses data-testid selectors throughout — no brittle text matching"]
```

**Rules:**
- 2–4 bullets, always present
- **Every bullet must cite `file:line` or a specific pattern visible in the diff** — generic observations ("good variable names", "clean code") are not acceptable
- If only one genuinely notable thing exists, write one bullet — do not pad
- If the diff is problematic with nothing to highlight: `"The intent is clear from the PR description and the fix is targeted to the right location."`
- **Hallucination guard:** A highlight that cannot be traced to a specific file, line, or named pattern in the diff is fabricated. Do not write it.

### Part B: Detailed Findings

Present the detailed findings after the walkthrough. Each finding must include the **problem**, **urgency**, the **current code**, and the **improved code**. Cap at 15 findings, prioritized by urgency.

**Urgency labels (single axis — replaces old severity + confidence):**

| Label | Meaning | When to use |
|-------|---------|-------------|
| **Must fix** | Definitely wrong, will break or violate standards | `console.log` left in, missing test for exported util/hook, hardcoded secret, runtime type error, unmet acceptance criteria, unsanitized `dangerouslySetInnerHTML` |
| **Should fix** | Very likely a problem, but verify context | Missing cypress coverage, `eslint-disable`, `any` types, `as` casts in non-test code, PF standard violations, performance concerns, impact analysis (type/sig changes with untouched consumers) |
| **Consider** | Improvement opportunity, not wrong per se | Style improvements, minor refactoring, possible pattern improvements, new dependencies to audit, behavioral changes with untouched consumers |
| **Nitpick** | Style/formatting, totally optional | Trailing whitespace, import ordering, naming style preferences, trivial cleanups |
| **FYI** | Not directly actionable, just awareness | New exports with no consumers, context about surrounding patterns, dependency audit suggestions |

Only include **Must fix**, **Should fix**, and **Consider** in the numbered findings list. Group **Nitpick** items at the end as a short unnumbered list. **FYI** items go in the IMPACT section.

**IMPORTANT — Icon rendering fallback:** Cursor's chat sometimes fails to render emojis. Every icon MUST be followed by its text label so the output is always readable. Use the format `EMOJI TEXT_LABEL` everywhere (e.g. write the heading as the combined emoji+text shown below, never emoji alone).

```
## Pre-Commit Review — [N] findings

### MUST FIX ([n])

1. [CATEGORY_TAG] · `file/path.ts:lineRange` · Must fix
   > description of the issue

   **Current:**
   ```tsx
   // the problematic code
   ```
   **Improved:**
   ```tsx
   // the fix
   ```

---

### SHOULD FIX ([n])
### CONSIDER ([n])
(same structure as MUST FIX — one numbered finding per entry, with Current/Improved blocks)

---

### NITPICKS
- `file.ts:line` — brief description

---

### FYI — Impact & related files
- `file.ts` imports `ChangedType` — verify it still compiles after type change
(If none: "No impact concerns detected.")
```

**Category tags (use in place of CATEGORY_TAG):**
Always write the tag as `**[icon text]**` — both icon and text together:
- `**[TESTS]**` for missing-tests
- `**[TYPES]**` for type-safety
- `**[QUALITY]**` for code-quality
- `**[PF]**` for pf-standards
- `**[PERF]**` for performance
- `**[CLEANUP]**` for cleanup
- `**[ERROR-HANDLING]**` for error-handling
- `**[REQUIREMENT]**` for missing-requirement
- `**[SECURITY]**` for security issues
- `**[IMPACT]**` for impact analysis
- `**[VISUAL]**` for screenshot comparison findings

### Part C: Summary Table + Action Prompt

After all detailed findings, close with a summary table that recaps every finding in one scannable view. This is the decision checklist — the developer has read the detail and now picks what to fix.

```
## Summary

| # | Urgency | Category | File | Issue |
|---|---------|----------|------|-------|
| 1 | Must fix | CLEANUP | `kueue/index.ts:91` | console.log left in production code |
| — | Nitpick | — | `types.ts:12` | Trailing whitespace |
(one row per finding — numbered for Must/Should/Consider, — for Nitpick/FYI)

**TL;DR:** [n] must-fix ([key issues]), [n] should-fix. Main concern: [single most important takeaway].

Which findings should I fix? (e.g. "fix 1, 3, 5" or "fix all must-fix" or "skip")
```

**TL;DR rules:**
- One or two sentences max.
- Start with the counts: "[n] must-fix, [n] should-fix, ..." with a parenthetical of the key issues.
- End with "Main concern: ..." — the single most important takeaway from the review. This is your human judgment, not just a count.
- If the review is clean (0 must-fix, 0 should-fix), say so: "Looks good. [n] minor suggestions, nothing blocking."

Rules for the table:
- Numbered findings (Must fix, Should fix, Consider) get a `#` matching their detail section above.
- Nitpick and FYI rows use `—` for the number (not actionable, no detail section).
- Keep the Issue column short — one line, no code. The detail section has the code.
- Sort by urgency: Must fix first, then Should fix, Consider, Nitpick, FYI.
- The action prompt goes immediately after the table — this is the handoff to Phase 3.

---

## Phase 3: ACT

When the user tells you which findings to fix:

1. Fix them one at a time, in order.
2. For each fix, follow the relevant agent rule.
3. After fixing, briefly state what you changed.
4. After all fixes are done, ask: "Want me to re-run the review to verify?"

### Fixing: Missing unit tests

Read `docs/agent-rules/unit-tests.md` first, then generate the test file:

1. **Determine what changed.** Read the source file. Identify every exported function, hook, or component that is new or modified in the diff.

1a. **Enumerate distinct execution paths before writing any tests.** For each target, list:
   - Happy path (valid input, expected output)
   - Empty / null / undefined inputs
   - Boundary values (zero, max, edge of range)
   - Error / rejection / thrown case
   - Each branch of conditional logic (if/else, switch, ternary)

   Write **one test per distinct path**. Before finalising, check:
   - If two tests would always pass and fail together → they are duplicates. Merge into `it.each` or a single test with multiple `expect` calls.
   - If a test would break when you rename a private variable → it tests implementation, not behavior. Rewrite to test the output or observable side-effect instead.
   - Prefer `it.each` for the same assertion across multiple input/output pairs rather than repeated `it()` blocks.

   **Hallucination guard:** State the execution paths you identified before writing tests. If a test doesn't map to a named path, don't write it.

2. **Find the test location.** Source at `src/foo/bar.ts` → test at `src/foo/bar/__tests__/bar.spec.ts`. If the `__tests__` directory doesn't exist, create it. If a test file already exists, add to it — don't overwrite.
3. **Check for existing mocks.** Search `@odh-dashboard/internal/__mocks__` for mock factories relevant to the types used (e.g. `mockNotebookK8sResource`, `mockProjectK8sResource`). Use them instead of creating inline mocks.
4. **Generate tests by category:**
   - **Utility functions:** Test all input variations — happy path, empty/null/undefined, boundary values, error cases. Use `describe('<functionName>')` → `it('should ...')`.
   - **Custom hooks:** Use `testHook` from `@odh-dashboard/jest-config/hooks`. Assert with `hookToBe`, `hookToStrictEqual`, `hookToHaveUpdateCount`. For async hooks, use `waitForNextUpdate`. Always verify render counts.
   - **Components:** Use React Testing Library. Select by `data-testid` first, accessibility selectors second. Test rendering, conditional states, user interactions via `userEvent`.
5. **Mocking:** Use `jest.mock()` at module level, `jest.mocked()` for type safety, `jest.clearAllMocks()` in `beforeEach`. Use `jest.requireActual()` for partial mocks.
6. **Run the test** with `npx jest <test-file-path> --no-coverage` to verify it passes. Fix any failures before moving on.

### Fixing: Missing cypress tests

Read `docs/agent-rules/cypress-mock.md` first, then follow its patterns for page objects, interceptors, and `data-testid` usage.

### Fixing: Missing contract tests

Read `docs/agent-rules/contract-tests.md` first, then follow its patterns for BFF API validation.

### Fixing: Security issues

- **Hardcoded secrets:** Move the value to an environment variable or K8s secret reference. Replace with a placeholder that reads from config.
- **dangerouslySetInnerHTML:** Replace with safe rendering. If HTML is truly needed, add DOMPurify sanitization or use a markdown renderer.
- **eval / new Function / innerHTML:** Replace with safe alternatives (JSON.parse for data, DOM APIs for elements).
- **Logged sensitive data:** Remove the sensitive fields from log output or redact them.

### Fixing: Code quality / cleanup / type-safety

Apply the fix directly — remove `console.log`, replace `any` with a proper type, add error handling, etc. Keep changes minimal and scoped to the finding.

### Generating unit tests (standalone command)

When the user says `"generate tests for <file>"` or `"generate tests for <finding #>"`:

1. Resolve the target: if a finding number, look up the file from that finding. If a file path, use it directly.
2. Read `docs/agent-rules/unit-tests.md` for conventions.
3. Read the source file. Identify all exported functions, hooks, and components.
4. Follow the same steps as "Fixing: Missing unit tests" above.
5. This command works independently of the review — the user can run it at any time, even without running a review first.

### When a fix goes wrong

If a fix introduces a new error (lint failure, type error, test failure):

1. **Stop immediately.** Do not continue to the next finding.
2. **Revert only the broken fix, not the entire file.** Undo the specific change you just made — restore the original lines for that finding while preserving any prior successful fixes in the same file.
3. **Tell the user** what happened: "Fix for finding #N caused [error]. I've reverted that specific fix. Here's what went wrong: [explanation]."
4. **Suggest alternatives:** Propose a different approach, or recommend the user fix it manually with the context you've provided.
5. **Never stack fixes on top of a broken fix.** Each fix must leave the codebase in a working state.

If the user says `"revert <N>"` after a fix has been applied, undo only finding #N's changes while keeping all other fixes intact.

### Phase 3c: Reviewer questions

Triggered by `"reviewer questions"` or `"questions"` (in either mode).

**Do not run the checklist.** Read the diff + any available context (PR description, Jira ticket, git log) and generate 3–5 questions a thoughtful senior engineer would post as PR comments. Focus on: intent (why this approach?), safety (what happens if X?), completeness (did you consider Y?).

**Output format:**

```
### Questions a reviewer might ask

1. `src/file.ts:42` — The fallback here returns `[]` on parse error. Was this intentional, or should it surface the error to the caller?
2. `useHook.ts:18` — `useCallback` wraps a function that closes over `data`. If `data` changes, does the callback update correctly?
3. General — The PR description says this fixes 2.x profiles. Is there a migration path for profiles created in 3.0 with the same annotation format?
```

**Hallucination guard:** Every question must be anchored to either a specific `file:line` from the diff, or a named concern from the PR description / Jira ticket. Questions not traceable to real diff content must not be written. Generic questions ("Did you test this?", "Is this performant?") are not acceptable.

### PR Review Mode — Posting a review

In PR mode, you cannot edit the author's files directly. Instead, after presenting findings, ask:

> **"Want me to post these findings? ('post review' / 'request changes' / 'post inline 1,3,5' / 'post all must-fix inline' / 'preview comments' / 'skip')"**

Format the findings as the Phase 2 output (Change Walkthrough + Detailed Findings + Summary Table), but **omit the "Which findings should I fix?" action prompt** at the end.

**Posting commands:**

| Command | What it does |
|---------|-------------|
| `post review` | Post full review as one summary PR review comment |
| `request changes` | Post findings and formally request changes (use when Must fix findings exist) |
| `post inline 1,3,5` | Post selected findings as inline comments on their exact file + line |
| `post all must-fix inline` | Post all Must fix findings as inline comments |
| `post all should-fix inline` | Post all Should fix findings as inline comments |
| `preview comments` | Show exactly what would be posted before sending anything |

**Guardrails:**
- Always offer `preview comments` before executing a post — the user should see what goes out
- Only post inline if the finding has a clear `file:line` — otherwise include it in the summary body
- Batch Nitpick / Consider / FYI into the summary body, never inline
- Before posting: check Step 1d data — skip if the same location already has an open comment saying the same thing

**Post using `gh` CLI (primary):**

```bash
# Summary review (comment)
gh pr review <url> --comment --body "<formatted findings>"

# Request changes
gh pr review <url> --request-changes --body "<formatted findings>"
```

**Inline comments — use `gh api`:**

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --method POST \
  --field commit_id="<headRefOid>" \
  --field body="<overall summary>" \
  --field event="COMMENT" \
  --field "comments[][path]"="src/file.ts" \
  --field "comments[][line]"=42 \
  --field "comments[][body]"="finding text"
```

**If `gh` is unavailable**, fall back to the GitHub MCP:

```
CallMcpTool: user-github / create_pull_request_review
  owner: "<owner>"
  repo: "<repo>"
  pull_number: <number>
  body: "<formatted findings>"
  event: "COMMENT"   # or "REQUEST_CHANGES" — never "APPROVE"
```

**Notes:**
- The "fix", "generate tests", and "revert" commands do not apply in PR mode — you are reviewing someone else's branch.

### Re-review in PR mode

Triggered by `"re-review PR"` or `"re-review PR since <sha>"` while in PR Review Mode.

**Steps:**
1. Fetch the latest PR diff: `gh pr diff <url>`
2. Fetch the latest head SHA: `gh pr view <url> --json headRefOid`
3. Compare against findings from this session:
   - Code is gone from the new diff → **✅ Resolved**
   - Code still present, issue unchanged → **⚠️ Still open**
   - Code changed but issue partially remains → **⚠️ Partially addressed** (note what changed)
4. For lines not in the previous diff (new code from new commits): run full review checks → present as **🆕 New findings**
5. With `"re-review PR since <sha>"`: scope new-finding scan to commits after that SHA only

**Output format:**
```
## Re-Review — after latest commits

### ✅ Resolved (2)
- Finding #1 [CLEANUP] console.log removed in latest commit
- Finding #3 [TESTS] unit test added for formatKueueTimestamp

### ⚠️ Still open (1)
- Finding #2 [PF] inline style on NotebookStateStatus.tsx:104 — unchanged

### 🆕 New findings (1)
1. [TYPES] · `useKueueStatus.ts:58` · Should fix
   > New `as` cast introduced in latest commit — ...
```

**Guardrails:**
- Does NOT rely on session memory — re-fetches fresh diff and dedupes against what's already posted on the PR (Step 1d data) and the previous review summary visible in the conversation
- If no previous review is visible in the conversation: treat as a first review — full depth
- Do not mark a finding as "resolved" unless the code it pointed to is confirmed absent from the current diff. If uncertain: "⚠️ Still open — verify"

---

## Phase 3b: DEEP REVIEW

Triggered by `"deep review"` or `"deep review <file>"`. This is a separate mode from the standard checklist review — it can run after a standard review as a second pass, or standalone at any time.

**Suspend the entire checklist.** Do not look for console.log, missing tests, PF violations, type safety patterns, or any of the standard categories. Do not apply any rule from Phases 1–3. The checklist does not exist in this mode.

Your only job: **read the code as a thoughtful senior engineer and find problems with the reasoning, logic, design, and correctness.**

### Step 1: Resolve the target files

- `"deep review"` → use all files changed in `git diff` + `git diff --cached`. If in PR mode, use all files from the PR diff.
- `"deep review <file>"` → use only that specific file. The file does not need to be in the current diff — the user can deep review any file at any time.

### Step 2: Identify language and context

Before reading anything, determine what you're looking at. This sets the lens for the whole review.

| Signal | Context | How it changes your review |
|--------|---------|---------------------------|
| `.tsx` / `.jsx`, imports from `react`, `@patternfly` | **React component** | Focus on render correctness, hook rules, state/effect coupling, prop contracts, UI edge cases |
| `.ts` / `.js` with no JSX, exports utility functions or hooks | **TypeScript utility / custom hook** | Focus on return value correctness, referential stability, input edge cases, async handling |
| Files in `packages/*/server/`, `routes/`, `app.ts`, express/fastify imports | **Node.js BFF route / middleware** | Focus on error propagation, async/await correctness, request validation, API contract, missing status codes |
| `.go` files | **Go service** | Focus on error return handling (`if err != nil`), nil pointer dereferences, goroutine leaks, interface satisfaction, defer correctness |
| `.yaml` / CRD / operator files | **K8s configuration** | Focus on field correctness, missing required fields, version compatibility, resource limits |

Read related files based on context:
- **React component** → read the custom hooks it uses, read the parent component if props are confusing
- **Custom hook** → read all call sites to understand the expected contract
- **BFF route** → read the frontend fetch function consuming it, read the service layer it calls
- **Go handler** → read the interface it implements, read the caller

Read git context for intent in all cases: `git log --oneline -10 -- <file>`

### Step 3: Ask these questions

The core questions are universal — but what they look like differs by language. Work through these as genuine questions, not a checklist:

**Correctness**
- Does this code actually do what it's supposed to do?
- Are there execution paths that produce wrong results or silent failures?
- *React/TS:* null/undefined cases TypeScript allows but runtime will break on; optional chaining returning undefined silently propagated
- *BFF/Node.js:* unhandled promise rejections; missing `await` causing a resolved Promise to be returned instead of the value; wrong HTTP status codes
- *Go:* ignored error return values (`_`); nil pointer dereference; wrong type assertion without ok check

**Race conditions and async**
- *React:* stale closure in `useEffect` or `useCallback`; state update after unmount; effect running before data is ready
- *BFF/Node.js:* concurrent requests sharing mutable state; unhandled rejection in a `Promise.all`; middleware that assumes serial execution
- *Go:* unsynchronized map/slice access across goroutines; goroutine leak (started but never exits); channel deadlock

**Fragility**
- Does this break if inputs are slightly different from the happy path?
- Does it depend on the caller to do something that isn't enforced by the type system?
- Is there implicit ordering — does this work correctly only if something else ran first?
- *React:* component assumes parent always passes a non-null prop; hook assumes it's only called once
- *BFF:* route assumes request body is always valid without validating; assumes a header is always present
- *Go:* function assumes slice is non-empty; assumes map key always exists

**Design**
- Is this solving the right problem, or a slightly wrong version of it?
- Is the abstraction level right — too low (leaking implementation details) or too high (hiding necessary control)?
- Are there responsibilities mixed together that should be separated?
- Is there a simpler implementation that does the same thing with less surface area?
- Does the naming match what the code actually does?

**Intent vs. implementation**
- Does the code do what the commit message / PR description / Jira AC says it should?
- Are there edge cases mentioned in the ticket the implementation doesn't handle?
- Are there commented-out code, TODOs, or `// temporary` markers suggesting incomplete work?

### Step 4: Output format

Use a distinct format from the standard review to make it clear this is a deep review pass:

```
## Deep Review — <filename or "all changed files">

### [LOGIC] · `file/path.ts:lineRange`
> What the code does vs. what it should do — explain the specific reasoning error.

**Why this is wrong:**
[explanation — be specific, cite the exact scenario that breaks]

**Current:**
```ts
// the problematic code
```

**Better:**
```ts
// the corrected version
```

---

### [DESIGN] · `file/path.ts:lineRange`
> ...

---

### [FRAGILE] · `file/path.ts:lineRange`
> ...
```

**Deep review category tags:**
- `**[LOGIC]**` — the code produces wrong results in some condition
- `**[FRAGILE]**` — correct now but will break under slightly different conditions
- `**[DESIGN]**` — wrong abstraction, wrong responsibility, wrong level
- `**[INTENT]**` — implementation doesn't match what the code is supposed to accomplish
- `**[SILENT-FAILURE]**` — errors are swallowed, state is corrupted silently, wrong path taken without any signal
- `**[RACE]**` — async ordering issue, concurrent state problem
- `**[NAMING]**` — name is actively misleading about what the code does

**No urgency labels in deep review.** Everything reported here is worth looking at — if it's not, don't report it. Be selective: a deep review with 3 real findings is better than one with 10 weak ones.

Close with:

```
## Deep Review Summary

[1-2 sentences on the overall code quality and the most important finding. Be direct.]

Want me to fix any of these? (e.g. "fix logic 1" or "fix all")
```

Fixes from deep review follow the same Phase 3 fix process. The user can say `"fix logic 1"` or `"fix all"` to apply them.

---

## Guardrails

- **Phases 1–2 are read-only.** Do not modify any files until the user explicitly tells you which findings to fix.
- **Always cite file and line.** Never report a finding without a specific file path and line range.
- **Don't invent issues.** If you're not sure something is a problem, label it as a suggestion and say "verify manually."
- **Be honest about urgency.** Not everything is **Must fix**; most findings should be **Should fix** or **Consider**.
- **Don't fix what wasn't asked.** Only fix the findings the user selected.
- **Don't touch unrelated code.** When fixing a finding, only change what's necessary for that finding.
