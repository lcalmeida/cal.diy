#!/usr/bin/env bash
# CSS-only PR auto-approval policy.
#
# A PR is auto-approved only if ALL rules pass:
#   - open, not draft, not from a fork
#   - every changed file is .css/.scss/.sass/.less, only ADDED/MODIFIED (no delete/rename)
#   - diff size <= MAX_LINES (default 300)
#   - check "$REQUIRED_CHECK" (default "required", the PR Update gate) succeeded, and no check failed
#
# Usage:
#   css-only.sh <pr>            dry run: print evidence, exit 0 if approvable, 1 if not
#   css-only.sh <pr> --enforce  CI mode: wait for CI on CSS-only PRs, comment evidence, then
#                               approve, or dismiss stale bot approvals. Always exits 0 on a verdict.
#   css-only.sh --stdin         evaluate PR JSON from stdin (used by css-only.test.sh)
#
# Security: only reads PR metadata through the GitHub API; never checks out or runs PR code.
set -euo pipefail

MAX_LINES="${MAX_LINES:-300}"
REQUIRED_CHECK="${REQUIRED_CHECK:-required}"
BOT_LOGIN="${BOT_LOGIN:-github-actions[bot]}"
WAIT_MINUTES="${WAIT_MINUTES:-60}"
FIELDS="number,state,isDraft,headRefOid,isCrossRepository,changedFiles,additions,deletions,files,statusCheckRollup"

# stdin: `gh pr view --json $FIELDS` output. stdout: {ok, cssOnly, ciDone, sha, report}.
evaluate() {
  jq --argjson max "$MAX_LINES" --arg req "$REQUIRED_CHECK" '
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
        report: ([
          "<!-- css-only-pr-policy -->",
          "### CSS-only auto-approval: \(if $ok then "APPROVE" else "NOT APPROVED" end)",
          "",
          "Evaluated commit: `\(.headRefOid)`",
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
      }'
}

fetch() { gh pr view "$1" --json "$FIELDS" | evaluate; }

bot_approvals() {
  gh api "repos/{owner}/{repo}/pulls/$1/reviews" --paginate \
    --jq ".[] | select(.user.login == \"$BOT_LOGIN\" and .state == \"APPROVED\") | .id"
}

enforce() {
  local pr="$1" result
  result=$(fetch "$pr")

  # Only CSS-only PRs are worth waiting on; everything else gets a verdict right away.
  local deadline=$((SECONDS + WAIT_MINUTES * 60))
  while [[ $(jq -r '.cssOnly and (.ciDone | not)' <<<"$result") == true && $SECONDS -lt $deadline ]]; do
    sleep 60
    result=$(fetch "$pr")
  done

  local ok css sha approvals
  ok=$(jq -r .ok <<<"$result")
  css=$(jq -r .cssOnly <<<"$result")
  sha=$(jq -r .sha <<<"$result")
  approvals=$(bot_approvals "$pr")

  # Stay silent on ordinary (non-CSS) PRs that never had a bot approval.
  if [[ $ok != true && $css != true && -z $approvals ]]; then
    echo "PR #$pr is not CSS-only; nothing to do."
    return 0
  fi

  jq -r .report <<<"$result" | gh pr comment "$pr" --body-file -

  if [[ $ok == true ]]; then
    # Approve exactly the commit that was evaluated; bail if the PR moved underneath us.
    [[ $(gh pr view "$pr" --json headRefOid -q .headRefOid) == "$sha" ]] || {
      echo "Head moved after evaluation; not approving."
      return 0
    }
    gh api -X POST "repos/{owner}/{repo}/pulls/$pr/reviews" \
      -f commit_id="$sha" -f event=APPROVE \
      -f body="Auto-approved by the CSS-only PR policy (commit $sha)." >/dev/null
    echo "PR #$pr approved at $sha."
  else
    for id in $approvals; do
      gh api -X PUT "repos/{owner}/{repo}/pulls/$pr/reviews/$id/dismissals" \
        -f event=DISMISS -f message="CSS-only PR policy no longer satisfied at $sha." >/dev/null
    done
    echo "PR #$pr not approved; dismissed ${approvals:+stale }bot approvals: ${approvals:-none}."
  fi
}

case "${1:-}" in
  --stdin) evaluate ;;
  "") echo "usage: $0 <pr> [--enforce] | --stdin" >&2; exit 2 ;;
  *)
    if [[ "${2:-}" == --enforce ]]; then
      enforce "$1"
    else
      result=$(fetch "$1")
      jq -r .report <<<"$result"
      [[ $(jq -r .ok <<<"$result") == true ]]
    fi
    ;;
esac
