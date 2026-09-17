---
name: prepare-image-release
description: Use when preparing a monthly IIC-OSIC-TOOLS image release (tag YYYY.MM), or when asked to update RELEASE_NOTES.md, prune KNOWN_ISSUES.md, or check which local workarounds, patches and fixups are resolved upstream and can be dropped.
---

# Prepare an Image Release

## Overview

Three passes before tagging: release notes, known issues, workarounds. All
three are judged against **what the image actually builds**, never against
what an issue tracker says.

## 1. Establish the range

```bash
git tag --sort=-creatordate | head -3          # previous release, e.g. 2026.08
git log --format='%h %ad %an | %s' --date=short <prev>..next_release
curl -s 'https://hub.docker.com/v2/repositories/hpretl/iic-osic-tools/tags?page_size=6' \
  | python3 -c 'import sys,json;[print(t["name"],t["last_updated"]) for t in json.load(sys.stdin)["results"]]'
```

The Docker Hub push time of the previous tag is the real cut-off. Commits merged
after it (even on the same day, even on `main`) are **not** in that image. Entries
for them that were added to the previous section of `RELEASE_NOTES.md` belong in
the new section — move them and tell Harald.

## 2. RELEASE_NOTES.md

Sources: commit messages in the range, plus
`git diff <prev> next_release -- _build/tool_metadata.yml _build/images/*/Dockerfile _build/images/iic-osic-tools/skel/headless/scripts/install_eda.sh`
for version bumps.

Shape of every entry: **one short line**, `* [Tag] what changed for the user`.
No mechanism, no root-cause story, no issue narrative — that lives in the commit.
Tags in this order: `[Adding]`, `[Update]`, `[Changing]`, `[Remove]`, `[Fix]`,
`[Build]`, `[Docs]`. Routine bumps collapse into
`* [Update] various tool and Python package version bumps`; name a tool only when
the bump changes what users can do. Leave out fixes to things that were never
released (a bug in a feature new in this same release) and pure build-plumbing
(retry windows, CI harness fixes) unless users notice.

## 3. KNOWN_ISSUES.md

Per section: KEEP / REMOVE / REWORD, with evidence.
- Referenced issues: `gh issue view N -R owner/repo` — then confirm the fix is in
  the pinned revision (step 4), a closed issue alone is not enough.
- Claims about scripts, env vars, paths, image tags: grep the repo; stale
  version numbers and symptom lists are the common rot.
- Scan `gh issue list -R iic-jku/IIC-OSIC-TOOLS --state open` for confirmed,
  user-facing problems not yet listed.
- Anything only a running container can settle (GUI crashes, platform-specific
  behaviour) stays KEEP and is reported as "needs runtime check".

## 4. Workarounds and local fixups

Inventory: `_build/images/open_pdks/{patches,scripts}` (install-time PDK fixups,
often several per script), `_build/images/*/patches`, `sed -i`/python edits in
`_build/images/*/scripts/install.sh`, `skel/headless/scripts/{install_eda.sh,patches}`,
runtime wrappers and `base/scripts`. Grep: `workaround|upstream|Drop once|remove once|FIXME|patch|sed -i`.

For each, the pinned revision decides:

| Pin source | Where |
|---|---|
| Git tools | `_build/tool_metadata.yml`, `ARG *_REPO_COMMIT` in the Dockerfile |
| Python/cargo | versions in `install_eda.sh` |
| IHP PDKs | **tip of `dev`** of `iic-jku/IHP-Open-PDK` (unpinned) |
| sky130/gf180 | ciel / open_pdks version in `open_pdks` |

Evidence = the upstream file **at that revision**
(`gh api repos/O/R/contents/PATH?ref=SHA -q .content | base64 -d`) or
`gh api repos/O/R/compare/FIX...PIN` showing the fix is an ancestor.
Verdicts: REMOVABLE, REMOVABLE AFTER BUMP, STILL NEEDED, UNCLEAR.

Run the inventory with parallel read-only subagents (PDK fixups / tool builds /
known issues) while writing the notes.

## 5. Apply and report

- Remove only REMOVABLE items; each removal is its own commit, and the matching
  regression test (e.g. `_tests/27`, `_tests/34`) must still guard the behaviour.
  A removal is not verified until an image build and the affected tests pass —
  say so rather than implying it.
- Update KNOWN_ISSUES text alongside any removal that it describes.
- Commit named paths only (`git commit -o <paths>`); never push.

## Common Mistakes

| Mistake | Reality |
|---|---|
| Using the tag date as the cut-off | The Docker Hub push time is; the tag can precede later merges |
| "Issue closed, drop the patch" | Fix must be in the pinned revision the image builds |
| Long explanatory release-note entries | One line each; details belong in the commit message |
| Treating a skip-on-no-match fixup as proof of an upstream fix | It only means the pattern moved; read the upstream file |
| Dropping a silent `sed` because the upstream *source repo* is fixed | ciel/open_pdks assemble the installed tree from several repos and post-process it; without the built tree or a build log, report it and keep it |
| Rewriting build steps when only the reason went away | If the code works either way (e.g. a build order), fix the stale comment and leave the steps; a step change needs a rebuild |
| Deleting a fixup but leaving references to it | grep for the script name and issue number in other scripts, `_tests/` and `KNOWN_ISSUES.md` |
| Keeping a KNOWN_ISSUES workaround whose premise is gone | Check the advice against today's scripts (e.g. an X server recommendation after `start_x.bat` went WSLg-only) |
