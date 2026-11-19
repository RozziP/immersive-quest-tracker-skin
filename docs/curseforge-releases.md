# CurseForge releases

The `Publish to CurseForge` workflow uploads the existing stable GitHub release ZIP. It copies the GitHub release notes, derives the WoW Forever game version from the ZIP's TOC, and sets the required dependency in `scripts/curseforge.json`. It does not rebuild the addon or include uncommitted local files.

## One-time setup

Create an upload token in [CurseForge Authors API Tokens](https://authors.curseforge.com/#/settings/api-tokens). Save it in this repository's **Settings > Secrets and variables > Actions** as the repository secret `CF_API_TOKEN`. Never put the token in a source file, release note, or chat message.

The project ID, stable installed folder, release asset prefix, and dependency are already configured in `scripts/curseforge.json`. Verify those values if the project is moved or renamed.

## Publishing

Update the addon's TOC version, commit the release, and push a stable `vMAJOR.MINOR.PATCH` tag pointing to that commit. The release workflow packages the tagged addon, creates a GitHub release with generated notes, and calls the CurseForge uploader. Review the generated notes and the Actions run. The tag and TOC version must match. Human-published stable GitHub releases with the matching ZIP and notes also trigger the uploader.

To upload an existing release, use **Actions > Publish to CurseForge > Run workflow** on `main` and enter its exact tag. Check the CurseForge Files page first so you do not upload a duplicate. After a timeout or failed upload, check the Files page before retrying: CurseForge may have accepted the file before the response was lost. The uploader deliberately does not retry POST requests. Concurrent uploads of the same tag are serialized, but completed uploads are not automatically deduplicated.

A successful run reports the CurseForge file ID. CurseForge approval may still be pending. Prereleases are excluded; missing notes, missing ZIPs, TOC/tag mismatches, unknown Forever versions, and missing credentials fail visibly.

## Verification

Run `pwsh -NoProfile -File tests/Test-CurseForgeUpload.ps1` for offline checks with mocked GitHub and CurseForge calls. With GitHub CLI available, `pwsh -NoProfile -File scripts/publish-curseforge.ps1 -Tag vMAJOR.MINOR.PATCH -DryRun` validates a real published ZIP without contacting CurseForge or uploading anything.

Protocol references: [CurseForge Upload API](https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api), [BigWigs packager version mapping](https://github.com/BigWigsMods/packager/blob/master/release.sh), and [GitHub workflow triggering](https://docs.github.com/en/actions/how-tos/writing-workflows/choosing-when-your-workflow-runs/triggering-a-workflow).
