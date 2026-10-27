#!/bin/bash
# ========================================================================
# Report the result of the nightly workflow (.github/workflows/nightly.yaml)
#
# SPDX-FileCopyrightText: 2026 Harald Pretl
# Johannes Kepler University, Department for Integrated Circuits
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0
# ========================================================================
#
# Red night: comment on the open issue labelled nightly-failure (or open one)
# and turn the nightly PR into a draft. Green night with tests: close that
# issue, and open or refresh the PR nightly -> BASE_REF when nightly carries
# bumps. The PR is never merged here.
#
# Environment: NEEDS_JSON (toJSON(needs) of the report job), BASE_REF,
# CHANGED, ARTIFACT_DIR, RUN_URL, GH_TOKEN, GITHUB_REPOSITORY.

set -e

: "${NEEDS_JSON:?}" "${BASE_REF:?}" "${ARTIFACT_DIR:?}" "${RUN_URL:?}"

LABEL="nightly-failure"
DATE=$(date -u +%Y-%m-%d)
OWNER=$(tr '[:upper:]' '[:lower:]' <<< "${GITHUB_REPOSITORY%%/*}")
IMAGE="ghcr.io/${OWNER}/iic-osic-tools:nightly"
# GitHub rejects issue and PR bodies above 65536 characters
MAX_BODY=60000

# Jobs in pipeline order, so the first failed one is the stage that broke
JOBS="bump plan base base-dev tools-1 tools-2 tools-3 tools-4 image-full publish test"
FAILED=()
for job in $JOBS; do
    result=$(jq -r --arg j "$job" '.[$j].result // "missing"' <<< "$NEEDS_JSON")
    case "$result" in
        failure|cancelled) FAILED+=("$job") ;;
    esac
done
TEST_RESULT=$(jq -r '.test.result // "missing"' <<< "$NEEDS_JSON")

BUMPS="$ARTIFACT_DIR/bump-summary.md"
[ -s "$BUMPS" ] || { mkdir -p "$ARTIFACT_DIR"; echo "No bump summary was produced." > "$BUMPS"; }

PR=$(gh pr list --head nightly --base "$BASE_REF" --state open --json number --jq '.[0].number // empty')
ISSUE=$(gh issue list --label "$LABEL" --state open --json number --jq '.[0].number // empty')
BODY=$(mktemp)

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "[INFO] Nightly ${DATE} failed in: ${FAILED[*]}"
    {
        echo "## Nightly ${DATE} failed"
        echo
        echo "Run: ${RUN_URL}"
        echo
        echo "Failed jobs (first one is where it broke): \`${FAILED[*]}\`"
        echo
        found=0
        for f in "$ARTIFACT_DIR"/failures/failure-*.md; do
            [ -f "$f" ] || continue
            found=1
            cat "$f"
            echo
        done
        [ $found -eq 1 ] || echo "No failure summary was uploaded, see the run log."
        echo
        echo "## Version bumps of this night"
        echo
        cat "$BUMPS"
    } | head -c "$MAX_BODY" > "$BODY"

    gh label create "$LABEL" --color B60205 \
        --description "The nightly build or its regression tests failed" > /dev/null 2>&1 || true
    if [ -n "$ISSUE" ]; then
        gh issue comment "$ISSUE" --body-file "$BODY"
        ISSUE_URL=$(gh issue view "$ISSUE" --json url --jq .url)
        echo "[INFO] Commented on issue #${ISSUE}."
    else
        ISSUE_URL=$(gh issue create --title "Nightly build failed" --label "$LABEL" --body-file "$BODY")
        echo "[INFO] Opened ${ISSUE_URL}."
    fi

    if [ -n "$PR" ]; then
        gh pr ready "$PR" --undo > /dev/null 2>&1 || true
        gh pr comment "$PR" --body "Nightly ${DATE} failed, see ${ISSUE_URL}. This PR stays a draft until a night is green again."
        echo "[INFO] PR #${PR} set to draft."
    fi
    exit 0
fi

if [ "$TEST_RESULT" != "success" ]; then
    echo "[INFO] Nightly ${DATE} built, but the tests did not run (${TEST_RESULT}). Issue and PR left as they are."
    exit 0
fi

echo "[INFO] Nightly ${DATE} is green."
if [ -n "$ISSUE" ]; then
    gh issue close "$ISSUE" --comment "Nightly ${DATE} is green again: ${RUN_URL}"
    echo "[INFO] Closed issue #${ISSUE}."
fi

if [ "$CHANGED" != "true" ]; then
    echo "[INFO] nightly carries no change over ${BASE_REF}, no PR needed."
    exit 0
fi

{
    echo "Version bumps of the nightly ${DATE}. The image was built for amd64 and arm64 and passed the regression tests on both."
    echo
    echo "- Run: ${RUN_URL}"
    echo "- Image: \`${IMAGE}\`"
    echo
    echo "Review and merge this PR by hand, the nightly workflow never merges. The branch \`nightly\` is reset from \`${BASE_REF}\` every night, so commit fixes to \`${BASE_REF}\` and not to \`nightly\`."
    echo
    cat "$BUMPS"
} | head -c "$MAX_BODY" > "$BODY"

if [ -n "$PR" ]; then
    gh pr edit "$PR" --body-file "$BODY" > /dev/null
    gh pr ready "$PR" > /dev/null 2>&1 || true
    echo "[INFO] Refreshed PR #${PR}."
else
    url=$(gh pr create --base "$BASE_REF" --head nightly --title "Nightly version bumps" --body-file "$BODY")
    echo "[INFO] Opened ${url}."
fi
