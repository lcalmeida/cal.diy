---
name: css-only-pr-approval
description: Collect evidence for and run the CSS-only PR auto-approval control. Use when the user asks to auto-approve a PR, check whether a PR qualifies for CSS-only approval, or gather approval evidence for a style-only PR.
---

# CSS-only PR approval

Runs the CSS-only auto-approval control for one PR and reports the evidence.
The policy lives in `scripts/pr-policy/css-only.sh` (single source of truth);
the approval itself is always performed by the
`.github/workflows/css-only-auto-approve.yml` Action as `github-actions[bot]`.

## Rules (enforced by the script, do not re-implement)

- PR open, not draft, not from a fork
- Every changed file is `.css`/`.scss`/`.sass`/`.less`, only added or modified
- Diff has at most 300 lines
- Check `required` (PR Update gate) succeeded, and no check failed

## Hard limits

- Never approve with the user's own account or any token other than the
  Action's. GitHub blocks self-approval anyway; do not look for workarounds.
- Never edit thresholds, rules, the script or the workflow to make a PR pass.
  A policy change is its own PR, reviewed by a human.
- If a rule fails, the answer is "needs human review". Do not retry in a loop.

## Steps

1. **Find the PR.** Use the number the user gave, or
   `gh pr view --json number -q .number` for the current branch.
2. **Collect evidence (dry run).**
   ```bash
   scripts/pr-policy/css-only.sh <pr>
   ```
   Exit 0 = approvable, 1 = not. The output is the evidence table.
3. **Inspect the CSS itself.** The policy checks *which* files changed, not
   *what* they do. Read `gh pr diff <pr>` and flag, in the report, any added
   line with `@import`, `url(` pointing to an external host, `expression(`,
   or `behavior:`. These do not block the Action, but they must be surfaced to
   the user as a reason to review by hand.
4. **Run the control** (only if step 2 exited 0):
   ```bash
   gh workflow run css-only-auto-approve.yml -f pr=<pr>
   sleep 5
   gh run watch "$(gh run list --workflow css-only-auto-approve.yml --limit 1 --json databaseId -q '.[0].databaseId')" --exit-status
   ```
   The Action also runs by itself on every push; triggering it here just
   avoids waiting.
5. **Verify the result.**
   ```bash
   gh api "repos/{owner}/{repo}/pulls/<pr>/reviews" \
     --jq '.[] | select(.user.login == "github-actions[bot]") | {state, commit_id, submitted_at}'
   ```
   The approval counts only if `commit_id` equals the PR's current
   `headRefOid`.
6. **Report** to the user: verdict, evaluated commit, the rule table from
   step 2, any flags from step 3, and a link to the Action run and PR comment.

## If the Action fails to approve

`GitHub Actions is not permitted to approve pull requests` means the repo
setting is off: Settings > Actions > General > "Allow GitHub Actions to create
and approve pull requests". Tell the user; do not change repo settings
yourself.
