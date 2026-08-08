# Releasing

How to cut a new SELFshell release.

Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
with `v`-prefixed git tags (`v0.1.0`). The canonical version lives in
`quickshell/VERSION` (no `v` prefix); the tag must always match it
exactly — the release workflow refuses to publish otherwise.

## Version rules

| Component | Bump when |
|---|---|
| MAJOR | Breaking changes: config format breaks, features removed |
| MINOR | New features (new widgets, popups, commands) |
| PATCH | Bug fixes, refactors without user-visible changes |

## Procedure

1. In `CHANGELOG.md`, rename `## [Unreleased]` to
   `## [X.Y.Z] - YYYY-MM-DD` and open a fresh empty `## [Unreleased]`
   section above it.
2. Update `quickshell/VERSION` to `X.Y.Z` (hexadecimal-pure, no `v`).
3. Commit: `chore(release): X.Y.Z`.
4. Push to `main`, let CI validate (`VERSION` format check included).
5. Tag and push the tag:

   ```sh
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```

6. `.github/workflows/release.yml` runs and:
   - fails if `quickshell/VERSION` != the tag version;
   - fails if `CHANGELOG.md` has no `## [X.Y.Z]` section;
   - extracts that section as the release notes;
   - builds `selfshell-X.Y.Z.tar.gz` (tag archive);
   - publishes the GitHub Release with the notes and the archive
     attached.
7. Verify on https://github.com/TripShuti/selfshell/releases.

## Notes

- Never force-push, move or delete an already-published tag.
- `selfshell update` in a plain-copy install downloads a fresh archive of
  `main`, so a release archive is an archival snapshot, not a strict
  requirement for updates.
- Every PR that changes user-visible behavior must also update the
  `## [Unreleased]` section of `CHANGELOG.md` (see CONTRIBUTING.md).