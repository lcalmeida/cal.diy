#!/usr/bin/env bash
# Offline checks for css-only.sh's rules. Run: scripts/pr-policy/css-only.test.sh
set -uo pipefail
cd "$(dirname "$0")"

base='{
  "number": 1, "state": "OPEN", "isDraft": false, "headRefOid": "abc123",
  "isCrossRepository": false, "changedFiles": 1, "additions": 10, "deletions": 2,
  "files": [{"path": "packages/ui/styles/globals.css", "changeType": "MODIFIED", "additions": 10, "deletions": 2}],
  "statusCheckRollup": [
    {"name": "required", "status": "COMPLETED", "conclusion": "SUCCESS"},
    {"name": "Linters", "status": "COMPLETED", "conclusion": "SKIPPED"}
  ]
}'

fails=0
expect() { # expect <ok|cssOnly> <true|false> <description> <jq patch>
  local got
  got=$( (jq "$4" <<<"$base" | ./css-only.sh || true) | jq -r ".$1")
  if [[ $got == "$2" ]]; then echo "ok   $3"; else echo "FAIL $3 ($1=$got, want $2)"; fails=1; fi
}

expect ok true  "approves a CSS-only PR with green CI" '.'
expect ok true  "approves scss/sass/less too" '.files = [{"path":"a.scss","changeType":"ADDED","additions":1,"deletions":0},{"path":"b.sass","changeType":"MODIFIED","additions":1,"deletions":0},{"path":"c.less","changeType":"MODIFIED","additions":1,"deletions":0}] | .changedFiles = 3'
expect ok false "rejects a non-CSS file" '.files += [{"path":"a.tsx","changeType":"MODIFIED","additions":1,"deletions":0}] | .changedFiles = 2'
expect cssOnly false "flags a .css.ts file as not CSS-only" '.files[0].path = "theme.css.ts"'
expect ok false "rejects a deleted CSS file" '.files[0].changeType = "DELETED"'
expect ok false "rejects a renamed CSS file" '.files[0].changeType = "RENAMED"'
expect ok false "rejects a diff over the size limit" '.additions = 299 | .deletions = 2'
expect ok false "rejects a PR from a fork" '.isCrossRepository = true'
expect ok false "rejects a draft PR" '.isDraft = true'
expect ok false "rejects when the required check failed" '.statusCheckRollup[0].conclusion = "FAILURE"'
expect ok false "rejects when the required check is missing" '.statusCheckRollup = []'
expect ok false "rejects when the required check is still running" '.statusCheckRollup[0] = {"name":"required","status":"IN_PROGRESS","conclusion":""}'
expect ok false "rejects when another check failed" '.statusCheckRollup += [{"context":"legacy/status","state":"ERROR"}]'
expect ok false "rejects a truncated file list" '.changedFiles = 150'

# Exit code contract used by enforce.sh: 0 approvable, 1 not approvable.
./css-only.sh <<<"$base" >/dev/null && echo "ok   exits 0 when approvable" || { echo "FAIL exit code on approve"; fails=1; }
jq '.isDraft = true' <<<"$base" | ./css-only.sh >/dev/null; [[ $? -eq 1 ]] && echo "ok   exits 1 when not approvable" || { echo "FAIL exit code on reject"; fails=1; }

exit $fails
