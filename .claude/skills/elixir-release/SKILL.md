---
name: elixir-release
description: Cut a release of this Elixir package and publish it to Hex — bump the version, move the Unreleased changelog section under a dated header, commit, tag, and run mix hex.publish. Use when the user asks to "cut a release", "release a new version", "publish to hex", or similar for this project.
---

# Elixir release + Hex publish

Project-local skill for `ex_check`. Not a general Elixir release guide — follows the
`chore: release X.Y.Z` commit + `vX.Y.Z` tag convention.

## Preconditions

- Working tree clean, on the branch the user wants to release from (usually `master`).
- `CHANGELOG.md` has content under `## [Unreleased]` — if empty, ask the user what to release.
- User has confirmed the target version number (or ask; if previous version was a -rc.x version,
  the desired version might be another prerelease).
- `mix hex.user whoami` succeeds (user is authenticated with Hex). If not, stop and tell
  the user to run `mix hex.user auth` themselves — do not attempt to authenticate for them.

## Steps

1. **Bump version** in `mix.exs`: update the `@version "..."` module attribute.

2. **Update `CHANGELOG.md`**: rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD` (today's
   date), then add a fresh empty `## [Unreleased]` section above it. Keep the existing
   **Added**/**Changed**/**Fixed**/**BREAKING** bullet style.

3. **Run the full check suite** before committing:

   ```
   mix check --format agent
   ```

   Do not proceed if it fails.

4. **Commit** the version bump + changelog as their own commit:

   ```
   git commit -am "chore: release X.Y.Z"
   ```

   (Confirm with the user before committing — this is a durable, user-facing action.)

5. **Tag** the release:

   ```
   git tag vX.Y.Z
   ```

   Confirm with the user before pushing the tag anywhere.

6. **Build + review the Hex package** before publishing:

   ```
   mix hex.build
   ```

   Check the file list matches `package()[:files]` in `mix.exs` (currently `lib`, `priv`,
   `mix.exs`, `README.md`, `CHANGELOG.md`, `LICENSE.md`, `usage-rules.md`, `usage-rules`).

7. **Publish to Hex** — irreversible (Hex does not allow re-publishing the same version),
   so ask the user to do the following by hand:

   ```
   mix hex.publish
   ```

8. **Push** the commit and tag once the user confirms:

   ```
   git push origin master
   git push origin vX.Y.Z
   ```

## Notes

- Steps 4, 5, 7, 8 are hard-to-reverse / publicly visible actions — always pause for
  explicit user confirmation before each, even mid-flow. Do not batch them into one
  unattended sequence.
- Package name on Hex is `ex_check` (see `app:` in `mix.exs`).
