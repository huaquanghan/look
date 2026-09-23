---
name: look-repo-workflow
description: "Build, install, verify, and sync the `look` launcher repo (kunkka19xx/look and its forks) on macOS — covers confirming the right source branch before building, the ffi-unstale stale-Rust-lib gotcha, dev vs release install paths, replacing a Homebrew cask install, verification commands, the lookapp/lookdev CLI grammar, and fork↔upstream sync."
---

# look launcher — build, install, verify, sync (macOS)

## Guardrail: build the branch that actually has the feature

Before any build or install, confirm **which branch** carries the change you were asked to ship, and build from that one. In a fork, `upstream/main` does **not** contain the fork's feature work — a PR that was closed unmerged leaves the commits only on the feature branch.

```bash
git status -sb                               # branch, tracking, ahead/behind
git log --oneline upstream/main..HEAD        # what this branch adds on top of upstream
git log --oneline upstream/main..origin/main # what the fork's main adds
grep -rn "<feature marker>" <paths>          # feature really present in the working tree
```

Then run the feature's own tests before building — `cd apps/macos/LauncherApp && swift test --filter <FeatureTests>` — and build from that branch. Re-run both checks after any rebase. Getting this wrong produces a build that compiles, installs, and launches — while silently missing the feature.

## Repo shape

- `apps/macos/LauncherApp/` — SwiftUI app. Xcode project `look-app.xcodeproj`, scheme `Look`, configs `Debug`/`Release`.
  - `Package.swift` — SwiftPM package `LauncherLogic` + test target `LauncherLogicTests` (logic-only, no app host).
- `core/` — Rust workspace (engine, storage, matching, …). `bridge/ffi/` — Rust FFI crate the macOS app links.
- `apps/linows/` — Tauri app (Linux/Windows only).
- Top-level `Makefile` dispatches to `scripts/Makefile.mac` / `scripts/Makefile.win`. `make help` lists targets.

## Critical: the Rust static lib goes stale silently

The Xcode phase **Build Rust FFI** declares `apps/macos/LauncherApp/RustBuild/liblook_ffi.a` as an output and declares **no inputs**, so Xcode skips the phase whenever that file exists. A Rust change then ships as a stale lib with no warning.

Always run this before any build:

```bash
make ffi-unstale XCODE_CONFIG=Debug      # or Release
```

It deletes the `.a` when the build identity changes — identity covers the configuration, the manifests, and the source set, so a Debug↔Release switch also drops it. `scripts/release-macos-app.sh` does **not** do this for you.

## Build + install

Dev, side-by-side (Debug, own config + DB, bundle id `noah-code.Look.Dev`):

```bash
make app-install-dev     # build + install /Applications/Look Dev.app + the lookdev CLI
make app-run-dev         # same, then stops production Look and launches the dev app
make app-uninstall-dev
```

Release (what users run):

```bash
make ffi-unstale XCODE_CONFIG=Release
./scripts/release-macos-app.sh [version]     # default version = date (YYYY.MM.DD)
LOOK_DOWNLOAD_URL="file://$PWD/dist/Look-<version>-macOS.zip" ./scripts/install-look.sh
```

`install-look.sh` installs to `/Applications/Look.app`, strips the quarantine attribute, and recreates the `lookapp` CLI symlink (`/opt/homebrew/bin/lookapp` → the app binary). It also accepts `--url`, `--version`, `--repo`.

Replacing a Homebrew install:

```bash
brew uninstall --cask look      # NEVER --zap: it wipes ~/.look/config and the DB
```

Locally built apps are ad-hoc signed (`codesign -dv` → `Signature=adhoc`), so expect to re-grant Accessibility / Full Disk Access / Apple Events after replacing a notarized build.

## Verify

```bash
cd apps/macos/LauncherApp && swift test          # LauncherLogicTests (SwiftPM, ~209 tests)
strings -a /Applications/Look.app/Contents/MacOS/Look | grep -i <NewSymbol>   # new code really in the bundle
log show --predicate 'subsystem == "noah-code.Look" AND category == "hotkey"' --last 2m --style compact
```

The launcher hides itself whenever it is not the frontmost app, so a window screenshot is unreliable — prefer tests + binary symbols + process/log checks, and say so when visual verification was not possible.

## CLI grammar

- `lookapp --list-modes`, `lookapp --query "<text>"`, `lookapp --toggle`, `lookapp --mode <name>`, `lookapp --version`.
- A bare argument is a mode **only when it resolves to a known mode** (`clipboard`, `files`, `calc`, …). A bare unknown word like `empty` is not a query — it falls through to a normal launch and starts a second instance. Queries must go through `--query`.
- Invoking through the `lookapp` symlink can spawn a second instance rather than delivering to the running one; for a cold start use `open -a /Applications/Look.app --args --query "..."`.
- Dev build: `lookdev` (same grammar), honours `LOOK_DEV_APP` / `LOOK_DEV_CONFIG`.

## Fork ↔ upstream sync

```bash
git remote add upstream git@github.com:kunkka19xx/look.git
git fetch upstream
git checkout main && git merge --ff-only upstream/main
git branch --set-upstream-to=upstream/main main     # otherwise `git pull` targets the fork
```

Feature branch on top of the latest upstream:

```bash
git checkout feat/<name> && git rebase upstream/main
git push --force-with-lease origin feat/<name>
```

PRs to upstream target `kunkka19xx/look:main`; a PR inside a fork uses base `main`, head the feature branch.

## Version + update check

- Xcode default `MARKETING_VERSION = 1.0`; `release-macos-app.sh` overrides it (default = build date).
- `UpdateChecker` compares `CFBundleShortVersionString` against `api.github.com/repos/kunkka19xx/look/releases/latest` (numeric dotted compare; non-numeric components count as 0) and offers `brew upgrade --cask kunkka19xx/tap/look`.
