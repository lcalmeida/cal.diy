#!/usr/bin/env bash
# Collect evidence for the PR policy. No judgment here: this only snapshots PR state.
#
# Usage: collect-evidence.sh <pr> > evidence.json
#
# Output is the raw `gh pr view` JSON plus `collectedAt`, so a verdict can be
# re-checked later against exactly what was seen. Read-only; never runs PR code.
set -euo pipefail

[[ $# -eq 1 ]] || { echo "usage: $0 <pr>" >&2; exit 2; }

gh pr view "$1" \
  --json number,state,isDraft,headRefOid,isCrossRepository,changedFiles,additions,deletions,files,statusCheckRollup |
  jq --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '. + {collectedAt: $at}'
