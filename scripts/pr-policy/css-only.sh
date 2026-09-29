#!/usr/bin/env bash
# CSS-only PR auto-approval policy: pure validation of collected evidence. No network.
#
# A PR is approvable only if ALL rules pass:
#   - open, not draft, not from a fork
#   - every changed file is .css/.scss/.sass/.less, only ADDED/MODIFIED (no delete/rename)
#   - diff size <= MAX_LINES (default 300)
#   - check "$REQUIRED_CHECK" (default "required", the PR Update gate) succeeded, and no check failed
#
# Usage: css-only.sh [evidence.json]   (reads stdin if no file; evidence from collect-evidence.sh)
# Output: verdict JSON {ok, cssOnly, ciDone, sha, collectedAt, rules, report}.
# Exit:   0 = approvable, 1 = not approvable.
set -euo pipefail

MAX_LINES="${MAX_LINES:-300}"
REQUIRED_CHECK="${REQUIRED_CHECK:-required}"

verdict=$(jq --argjson max "$MAX_LINES" --arg req "$REQUIRED_CHECK" '
  def result: if (.conclusion // "") != "" then .conclusion else (.state // .status // "PENDING") end;
  def failed: result | IN("FAILURE", "ERROR", "CANCELLED", "TIMED_OUT", "ACTION_REQUIRED", "STARTUP_FAILURE", "STALE");
  (.statusCheckRollup // []) as $checks
  | ([$checks[] | select((.name // .context) == $req)] | first) as $gate
  | (.additions + .deletions) as $lines
  | ((.files | length) == .changedFiles and .changedFiles > 0
      and all(.files[]; .path | test("\\.(css|scss|sass|less)$"))) as $cssOnly
  | [
      {rule: "PR is open and not a draft", ok: (.state == "OPEN" and (.isDraft | not))},
      {rule: "PR is not from a fork", ok: (.isCrossRepository | not)},
      {rule: "Only .css/.scss/.sass/.less files (\(.files | length) of \(.changedFiles) listed)", ok: $cssOnly},
      {rule: "Only added/modified files (no delete/rename)", ok: all(.files[]; .changeType | IN("ADDED", "MODIFIED"))},
      {rule: "Diff has at most \($max) lines (has \($lines))", ok: ($lines <= $max)},
      {rule: "Check `\($req)` succeeded (\($gate | if . then result else "missing" end))", ok: ($gate != null and ($gate | result) == "SUCCESS")},
      {rule: "No failed checks", ok: all($checks[]; failed | not)}
    ] as $rules
  | all($rules[]; .ok) as $ok
  | {
      ok: $ok,
      cssOnly: $cssOnly,
      ciDone: ($gate != null and ($gate | result | IN("PENDING", "QUEUED", "IN_PROGRESS", "EXPECTED", "WAITING") | not)),
      sha: .headRefOid,
      collectedAt: .collectedAt,
      rules: $rules,
      report: ([
        "<!-- css-only-pr-policy -->",
        "### CSS-only auto-approval: \(if $ok then "APPROVE" else "NOT APPROVED" end)",
        "",
        "Evaluated commit: `\(.headRefOid)` (evidence collected \(.collectedAt // "at unknown time"))",
        "",
        "| Rule | Result |",
        "| --- | --- |",
        ($rules[] | "| \(.rule) | \(if .ok then "pass" else "FAIL" end) |"),
        "",
        "<details><summary>Changed files</summary>",
        "",
        (.files[] | "- `\(.path)` \(.changeType) +\(.additions)/-\(.deletions)"),
        "",
        "</details>",
        "",
        "<details><summary>Checks</summary>",
        "",
        ($checks[] | "- \(.name // .context): \(result)"),
        "",
        "</details>"
      ] | join("\n"))
    }
' "${1:--}")
echo "$verdict"
[[ $(jq -r .ok <<<"$verdict") == true ]]
