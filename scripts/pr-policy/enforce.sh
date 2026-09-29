#!/usr/bin/env bash
# Enforce the CSS-only PR policy: collect evidence -> validate -> act.
#
# Usage: enforce.sh <pr>
#   - waits for CI while the PR is CSS-only and the gate check is still running
#   - saves evidence.json and verdict.json to $EVIDENCE_DIR (default: a temp dir)
#   - comments the verdict, then approves the evaluated commit or dismisses stale bot approvals
#   - stays silent on ordinary (non-CSS) PRs with no bot approval
# Always exits 0 once a verdict is reached; non-zero only on errors.
set -euo pipefail

[[ $# -eq 1 ]] || { echo "usage: $0 <pr>" >&2; exit 2; }
pr="$1"
dir="$(cd "$(dirname "$0")" && pwd)"
out="${EVIDENCE_DIR:-$(mktemp -d)}"
mkdir -p "$out"
BOT_LOGIN="${BOT_LOGIN:-github-actions[bot]}"
WAIT_MINUTES="${WAIT_MINUTES:-60}"

evaluate() {
  "$dir/collect-evidence.sh" "$pr" >"$out/evidence.json"
  # css-only.sh exits 1 for "not approvable"; any other failure is a real error.
  "$dir/css-only.sh" "$out/evidence.json" >"$out/verdict.json" || [[ $? -eq 1 ]]
}

evaluate
deadline=$((SECONDS + WAIT_MINUTES * 60))
while [[ $(jq -r '.cssOnly and (.ciDone | not)' "$out/verdict.json") == true && $SECONDS -lt $deadline ]]; do
  sleep 60
  evaluate
done

ok=$(jq -r .ok "$out/verdict.json")
css=$(jq -r .cssOnly "$out/verdict.json")
sha=$(jq -r .sha "$out/verdict.json")
approvals=$(gh api "repos/{owner}/{repo}/pulls/$pr/reviews" --paginate \
  --jq ".[] | select(.user.login == \"$BOT_LOGIN\" and .state == \"APPROVED\") | .id")
echo "Evidence and verdict saved in $out"

if [[ $ok != true && $css != true && -z $approvals ]]; then
  echo "PR #$pr is not CSS-only; nothing to do."
  exit 0
fi

jq -r .report "$out/verdict.json" | gh pr comment "$pr" --body-file -

if [[ $ok == true ]]; then
  # Approve exactly the commit that was evaluated; bail if the PR moved underneath us.
  [[ $(gh pr view "$pr" --json headRefOid -q .headRefOid) == "$sha" ]] || {
    echo "Head moved after evaluation; not approving."
    exit 0
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
  echo "PR #$pr not approved; dismissed bot approvals: ${approvals:-none}."
fi
