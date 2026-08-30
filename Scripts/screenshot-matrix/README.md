# Awful Screenshot Matrix — solution description

Captures every major view of the Awful app across themes, iOS versions and
device sizes, as demo material and as loose (non-pixel-perfect) regression
images. Built 2026-08-16.

Read this first if you are picking the work up cold; `shotlist.md` has the
per-view detail and `INDEX.md` is the generated inventory of what exists.

---

## What it produces

432 PNGs under `ScreenshotMatrix/<ios>-<device>/<theme>/`, named
`<ios>_<device>_<theme>_<NN>-<view>.png`.

| Pass | Devices | Themes | Views each |
|---|---|---|---|
| A | iPhone 17 Pro (26.5), iPhone 16 Pro (18.5) | all 15 | 12 |
| B | 17 Pro Max, 16 Pro Max, iPad Pro 11"/13", both OSes | default + classic-dark | 6 |

Every image gets a label strip (iOS · device · theme · view) **spliced below**
the screenshot, never drawn over it, so the app pixels stay pristine. Crop the
strip off before any diffing. The `NN` prefix fixes view order, which makes an
ffmpeg slideshow straightforward.

## Where things live

Scripts are tracked in `Scripts/screenshot-matrix/`; the images they generate
land in `ScreenshotMatrix/` at the repo root, which is gitignored (PNGs and the
generated `INDEX.md` only). Override the destination with `OUT_ROOT`.

## How to run it

```bash
export IDB_BIN=/path/to/idb          # see Dependencies
./Scripts/screenshot-matrix/run-all.sh              # full matrix, ~2h
./Scripts/screenshot-matrix/run-all.sh -l quick     # one phone + one iPad
```

`run-all.sh` walks a runlist, boots each simulator in turn, skips any device
that is not installed or not logged in (loudly), runs the right pass, shuts the
device down, then verifies and regenerates `INDEX.md`. `run-all.sh --help`
lists every option; `-n` prints the plan and an image-count estimate without
booting anything, which is the cheap way to sanity-check a long run.

Three axes narrow a run — devices (`-l`, `-d`), screens (`-s`), and themes
(`-p`, indirectly). Output goes wherever `-o` says.

### Recipes

Ordered smallest to largest. Times are rough; the estimate from `-n` is
authoritative for counts.

| Goal | Command | Images |
|---|---|---|
| Minimum useful check: one screen, one device, both key themes | `run-all.sh -l quick -d iphone-17-pro -s bookmarks` | 2 |
| One screen everywhere it can be captured | `run-all.sh -p B -s bookmarks` | 16 |
| A few screens, one phone + one iPad | `run-all.sh -l quick -s bookmarks,settings,posts-view` | 12 |
| Minimum devices, maximum screens + themes: everything on one phone | `run-all.sh -l quick -d iphone-17-pro -p A` | 180 |
| Maximum devices, minimum screens/themes: all 8, key subset | `run-all.sh -p B` | 96 |
| Every device, every screen, every theme it supports (the full matrix) | `run-all.sh` | 456 |
| The full matrix, two devices at a time | `run-all.sh -j 2` | 456 |
| Same, into a scratch directory so a good set stays pristine | `run-all.sh -o /tmp/matrix` | 432 |

Notes on the extremes: `-p A` forces all 15 themes and all 12 screens onto
whatever devices are selected, which is the most exhaustive thing you can ask
for per device (~45min each). `-p B` is the opposite — 2 themes, 6 screens —
and is the fastest way to touch every device. Themes have no flag of their own;
they follow the pass, so `-p` is the theme dial.

`-d` matches slugs as substrings, so `-d iphone-17-pro` also selects
`iphone-17-pro-max` — 360 images, not 180. Narrow it with a runlist that holds
only the device you want (as above), or pass the exact udid, which is matched
whole. `-n` will tell you which devices you actually selected; use it before
committing to a long run.

### Running devices in parallel

`-j N` captures up to N devices at once:

```bash
./Scripts/screenshot-matrix/run-all.sh -j 2
```

Devices whose `rotate` column is non-zero are **excluded from the overlap** and
captured serially first. `orient.sh` fronts a device's own window before
sending the rotate shortcut, but fronting and keystroke are two steps: run two
rotations at once and one can front its window between the other's front and
its keystroke, so the wrong device turns. Serialising the rotating devices
removes that race. Everything else then runs N wide.

That exclusion costs little, because the expensive devices are the two pass A
phones (180 images each, most of a full run) and both are `rotate 0`.

Each device's output is written to its own file and replayed in order when the
run finishes; live interleaved output from several devices is unreadable.

Measured on four phones capturing two screens each, `-j 2` took 4m09 against
5m27 serial — only 1.3x, because a short pass B run is mostly fixed per-device
boot cost. The gain should be larger on pass A devices, where per-device work
dominates, but that has not been measured. Simulators are memory-hungry; 2-3
is a sensible ceiling on most machines.

### Screens

`-s` takes comma-separated ids or fragments, matched as substrings, so
`-s bookmarks` and `-s 04-bookmarks` are the same request and `-s post` selects
both compose and preview. An unrecognised fragment fails immediately with the
list rather than silently capturing nothing. `run-all.sh --list-screens` prints
the vocabulary, which lives in `screens.txt`:

| Id | Pass | Captured by |
|---|---|---|
| `01-forums-list` | B | theme |
| `02-thread-list` | B | theme |
| `03-posts-view` | B | theme |
| `04-bookmarks` | B | theme |
| `05-pm-list` | B | theme |
| `07-settings` | B | theme |
| `09-lepers-colony` | A | theme |
| `10-profile` | A | theme |
| `11-rap-sheet` | A | both |
| `13-post-compose` | A | interactive |
| `15-post-preview` | A | interactive |
| `19-poll-thread` | A | theme |

Pass B devices only ever capture the six key-subset screens, so a selection
made entirely of pass A screens skips those devices with a warning instead of
booting them for nothing. Selecting only interactive screens skips the theme
pass entirely, and vice versa — the compose flow is most of the interactive
runtime, so `-s` genuinely saves time rather than just discarding screenshots.

`11-rap-sheet` is captured twice on pass A, deep-linked and then again
interactively; the interactive grab wins because the profile sheet can swallow
the deep link (trap 3 below). That double capture is why pass A is 12 files per
theme and not 13.

### Runlists

`-l NAME` selects `devices-NAME.txt`; `full` (the default) means `devices.txt`.
A name with a slash in it is taken as a literal path, and `RUNLIST=NAME` in the
environment sets the default. An unknown name lists what is available.

| Runlist | Devices | Images | Rough time |
|---|---|---|---|
| `full` | all 10 | 456 | ~2h |
| `quick` | iPhone 17 Pro + iPad Pro 11" (26.5) | ~24 | a few minutes |

The two iPad minis were added after the rest and have since been logged in
by hand (both confirmed 2026-08-30), so `full` should yield all 456 images.
Login still cannot be scripted: if a device skips as logged-out, someone has
to sign in on it manually.

The cost is almost entirely pass A — 15 themes × 12 views per device — so
`quick` puts both of its devices on pass B. Flip a `B` to an `A` in
`devices-quick.txt` when you want full theme coverage on one device and can
spare ~45min for it. Copy either file to `devices-<something>.txt` to add a
runlist; no script change is needed.

Runs of different runlists share output paths, so a `quick` run overwrites
those devices' images in a comprehensive set. Set `OUT_ROOT` to keep a full set
pristine.

## Comparison sheets

`collage.sh` builds comparison sheets in either direction — hold the theme
still and compare devices, or hold the device still and compare themes:

```bash
./Scripts/screenshot-matrix/collage.sh                     # devices, default theme
./Scripts/screenshot-matrix/collage.sh -t default,classic-dark
./Scripts/screenshot-matrix/collage.sh -b device           # themes, every device
./Scripts/screenshot-matrix/collage.sh -b device -d 17-pro # ...one device
./Scripts/screenshot-matrix/collage.sh -b family           # devices x themes grid
./Scripts/screenshot-matrix/collage.sh -s bookmarks -S 75  # one view, bigger
```

| Mode | Sheet | Tiles | Path |
|---|---|---|---|
| `--by theme` (default) | one per view per theme | devices | `collages/by-theme/<theme>/<view>-{iphones,ipads}.png` |
| `--by device` | one per view per device | themes | `collages/by-device/<ios>-<device>/<view>-themes.png` |
| `--by family` | one per view per family | devices **x** themes | `collages/by-family/<family>/<view>-grid.png` |

The first two each hold one axis still, so neither shows a fault that depends
on both — a layout that only breaks on the small iPad in a dark theme. `--by
family` is the grid of both: scan a column for size-specific problems, a row
for theme-specific ones. Absent device/theme combinations are padded so a
column stays aligned to one device.

Its layout follows tile shape rather than being fixed. Portrait phones sit side
by side, so devices run across and themes down. Six landscape iPads across
would be 8400px wide and have to shrink to about 25% to fit, too small to read
— so for landscape tiles the grid transposes, themes across and devices down,
and tiles stay at 50%. Scale is likewise chosen per family to keep sheets under
`MAX_SHEET_W` (4400px); `-S` overrides both defaults. `--by family` defaults to
the themes every device has, since a grid where only two columns have most of
their rows filled is mostly padding.

In `--by theme`, phones and iPads are separate images because a landscape iPad
beside a portrait phone wastes most of the canvas: 4 phones in one row
(2736x1601), 6 iPads as 3 x 2 (4200x2328), and 2 phones for the pass A views
iPads never capture. In `--by device`, tiles are laid out 5 wide in
`themes.txt` order rather than alphabetically, so light themes group ahead of
dark — a pass A phone gives all 15 themes at 3135x4191, a pass B device 2.

Tiles default to 50% of capture size — smaller than the device, still readable
— and keep the caption strip `label.sh` spliced on, so each sheet labels
itself. Options: `-b` mode, `-t` themes, `-d` devices (`--by device` only),
`-s` screens, `-S` scale percent, `-c` columns, `-o` output directory. `-d`
matches slug fragments, so `-d iphone-17-pro` also selects the Pro Max, same as
`run-all.sh`.

Only `default` and `classic-dark` cover every device, which is why `--by theme`
defaults to `default`; `--by device` defaults to every theme a device has.

Two details worth keeping if this is ever rewritten: tiles are bottom-aligned
(`-gravity south`) so the captions line up despite differing device heights,
and the device directories are iterated rather than the files globbed, because
sorting whole paths compares "-pro-max/" against "-pro/" and puts Pro Max first.

`collages/` sits outside the `ios*/` directories that `verify.sh` and
`make-index.sh` scan, so the sheets are never mistaken for captures.

## Scripts

| Script | Role |
|---|---|
| `run-all.sh` | Entry point and CLI; resolves options, iterates the runlist |
| `run-device.sh` | One device, every theme in `themes.txt` (or `themes-key.txt`) |
| `run-interactive.sh` | One device, the tap-driven screens per theme |
| `capture-theme.sh` | One device+theme: the deep-linkable views |
| `capture-interactive.sh` | One device+theme: rap sheet, compose, preview |
| `set-theme.sh` | Switches theme via the app's container plist; runs the scrub |
| `scrub-lists.sh` | Rewrites list-view titles/tags/names in the Core Data cache to deterministic fakes and bumps refresh timestamps; `release` mode undoes the timestamps |
| `orient.sh` | Forces a booted device into landscape/portrait and verifies it |
| `nav.sh` | Opens a deep link, dismissing prompts and stale sheets |
| `tap-label.sh` | Taps an element by accessibility label |
| `label.sh` | Splices the caption strip onto an image |
| `collage.sh` | Builds per-view comparison sheets, by theme or by device |
| `verify.sh` | Fails if any capture is a blank frame, or if a device was captured sideways |
| `make-index.sh` | Regenerates `INDEX.md` |
| `common.sh` | Sourced by the rest; resolves `OUT_ROOT`, the test-forum ids, and `want` (the `--screens` filter) |

Config: `devices.txt` / `devices-*.txt` (device tables — see Runlists),
`screens.txt` (screen id vocabulary — see Screens), `themes.txt` /
`themes-key.txt` (theme lists with their light/dark mode flags),
`scrub-data/*.txt` (fake titles, usernames, PM subjects, announcement titles,
preferred tags).

`screens.txt` is metadata only: `run-all.sh` validates `-s` against it and uses
it to decide which sub-scripts to run, but the actual captures are still the
`shot`/`grab` calls in `capture-theme.sh` and `capture-interactive.sh`, which
carry each view's URL and settle time. Adding a screen means editing both — an
id listed here that no capture script emits will simply capture nothing.

## Dependencies

* **ImageMagick** (`magick`) for rotation and labels.
* **Simulator.app, plus Accessibility permission** for the app running the
  scripts — `orient.sh` needs both to rotate devices. See trap 5.
* **idb** — the client, for taps and the accessibility tree. `idb_companion`
  is on this machine via Homebrew but the Python client is not; it was
  installed into a throwaway venv, and **it needs Python ≤3.13** (it calls
  `asyncio.get_event_loop()`, removed in 3.14):

  ```bash
  /usr/bin/python3 -m venv ~/.venvs/idb && ~/.venvs/idb/bin/pip install fb-idb
  export IDB_BIN=~/.venvs/idb/bin/idb
  ```

* A Debug simulator build installed on each device
  (`xcodebuild -scheme Awful -configuration Debug -destination 'generic/platform=iOS Simulator'`,
  then `simctl install`). Bundle id `com.awfulapp.Awful.debug`.

## Safety rules — do not relax

Compose flows touch a live forum account, so:

* Composing happens **only** in forum 261, "Apps In Developmental States".
* Any PM compose is addressed **only** to "Commie kong".
* **Post / Send is never tapped.** Compose exits via Cancel → Delete Draft,
  both found by accessibility label rather than fixed coordinates, so a
  shifted layout cannot become a stray tap on Post.

Nothing was submitted during the build of this set.

## List scrubbing

The account is real, so list views would otherwise leak real bookmark titles,
thread titles from the (non-public) test forum, PM subjects, and usernames.
`scrub-lists.sh` runs inside `set-theme.sh`'s terminated window each theme
cycle and rewrites the app's Core Data cache
(`<container>/Library/Application Support/CachedForumData/AwfulCache.sqlite`):

* **Faked:** bookmark + forum-261 thread titles, thread tags (repointed at
  other tag rows already cached in that store), "Killed by" last-post author
  names, thread-author usernames (unseen rows show "Posted by <author>"),
  PM subjects and sender names, announcement titles.
* **Synthesized variety:** ratings spread 0-5 stars, and unread states mixed
  across buckets — completely unread, fully read (gray 0 badge), and unread
  counts of 1 / 6 / 12 / 99 / 1206 (clamped to the thread's reply count).
  The username list deliberately mixes very short, very long, and spaced
  names to exercise cell layout.
* **Kept real:** thread 3532200 and poll thread 4115578 (deliberately shown),
  the forum's own name, and the account's own username.

Fake strings live in `scrub-data/*.txt` — edit them to test specific titles/
names/tags. Assignment is deterministic (rank % line count), so every theme
and device shows the same fakes until a file changes.

It is cache-only and self-healing: any network refresh restores real data.
That is also why it must run **every** theme cycle — the app re-scrapes
bookmarks/PMs after 10 minutes and forum thread lists after 15, and a full
run is longer than that — so the scrub also stamps those refresh timestamps
to "just now" (four prefs-plist date keys plus `ZFORUM.ZLASTREFRESH`).
`run-all.sh` ends each device with `scrub-lists.sh <udid> release`, which
drops the stamps so the next manual launch un-fakes itself promptly.

`SCRUB=0 ./run-all.sh` disables the whole mechanism. Known limits:

* Tag choice is deterministic per store but can differ across devices whose
  caches hold different tag inventories.
* A fresh, never-refreshed container has nothing to scrub and would fetch
  real titles on launch — the scrub fails the theme loudly instead.
* A manual pull-to-refresh during a run restores real data for that list.

## The four traps this works around

Each of these fails silently or looks like an app bug:

1. **App prefs live in the app's sandboxed container.**
   `simctl spawn <udid> defaults write <bundle> …` writes to the simulator's
   *global* domain, which the app never reads — theme changes appear to do
   nothing while `defaults read` happily echoes them back. `set-theme.sh`
   edits `<container>/Library/Preferences/<bundle>.plist` directly, with the
   app terminated **and** the simulator's `cfprefsd` stopped so its cached
   copy cannot overwrite the change.
2. **Custom URL schemes always prompt.** `simctl openurl` and `idb open` both
   raise a SpringBoard "Open in AwfulDebug?" alert on every navigation, with
   no suppress flag. `nav.sh` finds the Open button in the accessibility tree.
3. **Modal sheets swallow the next deep link.** The profile sheet silently ate
   the rap-sheet navigation, so that shot was a duplicate of the profile until
   `nav.sh` learned to dismiss any open sheet first.
4. **iPad captures come out sideways.** `simctl` grabs the portrait-native
   framebuffer, so a landscape iPad needs rotation before labelling — hence
   the `rotate` column in `devices.txt`.
5. **A headless boot is always portrait, whatever the saved orientation says.**
   `SimulatorWindowOrientation` in `com.apple.iphonesimulator.plist` is applied
   when Simulator.app opens a window, not when `simctl` boots a device. Watch
   the simulators and the iPads are landscape; run them hidden and the same
   devices come up portrait. That breaks iPads twice over: `rotate 90` turns an
   already-upright capture sideways, **and** iPadOS only shows the split-view
   sidebar alongside in landscape, so the forums and thread lists photograph as
   an empty detail pane. `orient.sh` rotates each device after boot and
   verifies it, which fixes both — no sidebar tapping is needed, because
   landscape reveals the sidebar on its own.

## Related: iPad alignment UI test

Nav-bar title/button *alignment* on iPad (both orientations) is measured by an
XCUITest, not by this toolkit — `App/UITests/SidebarAlignmentTests.swift`,
run via the `UITests` test plan. The comfortable way to run it is the wrapper,
which handles multiple devices, exports the annotated screenshots and
measurement reports to `ScreenshotMatrix/alignment/`, and stacks per-screen
cross-device comparison sheets:

```bash
./Scripts/run-alignment-test.sh <udid> [<udid> ...]   # or no args: booted sims
```

It needs the same manual login this matrix does, prints a measurement table to
the log, and attaches per-screen screenshots to the xcresult. It is not in the
default test plan, so `⌘U` and CI stay unit-test-only. This matrix remains the
tool for themes and device coverage.

## Known limits — likely places to want changes

* **Login cannot be scripted.** A fresh simulator must be logged in by hand;
  copying the keychain and app container across devices does **not** transfer
  the session. `run-all.sh` detects and skips logged-out devices.
* **Interactive coordinates are phone-sized.** `capture-interactive.sh`
  hardcodes nav-bar hit points for a 402×874pt screen (16 Pro / 17 Pro). Other
  sizes need their own constants — the app's accessibility tree exposes only
  about three elements in web-backed views, so in-app controls cannot be
  found by label. Only UIKit alerts and action sheets can.
* **Rotation is a stored constant, not detected.** `orient.sh` now forces each
  device into the orientation its `rotate` column assumes, so the two cannot
  drift apart mid-run — but the column is still the thing that decides which
  orientation that is. Change one and you must change the other.
* **Rotating needs Accessibility permission.** Neither `simctl` nor `idb` can
  set orientation, so `orient.sh` drives Simulator's own Rotate Right shortcut
  via System Events. The app running the script must be enabled in System
  Settings > Privacy & Security > Accessibility, or it fails with "not allowed
  to send keystrokes". It also briefly steals keyboard focus.
* **The rotate shortcut hits the frontmost window.** `orient.sh` therefore
  fronts the target first through Simulator's Window menu, whose entries read
  "<device name> – iOS <version>" and stay unique across runtimes. This matters
  whenever another simulator is booted — one opened by hand to log in, say.
  Without the fronting step that stray device silently absorbs the keystroke:
  the target stays portrait and the bystander rotates. `orient.sh` verifies the
  target afterwards and fails loudly rather than capturing a sideways set.
* **The sideways check is per device, not per image.** A few screens are close
  to structurally neutral — a dark-theme thread list is a column of thread tags
  and scores about 0.76 upright, about 1.3 rotated — so no per-image threshold
  classifies them both ways. Whole devices are never half-rotated, so
  `verify.sh` takes the median over each device directory instead, which
  separated cleanly on this matrix (upright 2.5-6, sideways ~0.3, and zero
  false positives across a known-good 433-image set). A single wrong image in
  an otherwise correct device would slip through; a wrong device will not.
* **Uncaptured screens:** PM compose, search, theme picker, glossary, smilie
  picker, image viewer. Each needs hand-calibrated coordinates.
* **Rap sheet is empty** ("Nothing to see here…") — the account has no bans.
* **Pass B is iPhone-Pro-only for compose/preview**; iPads and Pro Maxes get
  the six deep-linkable views only.
* **Three original simulators have dead framebuffers** (iPhone 16 Pro Max
  `73DE4B4E`, iPad Pro 11 M4 `43AA39FC`, iPad Pro 13 M4 `1FA97B5A`): the app
  runs but never draws, and it survives a CoreSimulator restart. They were
  replaced by the `Shot-*` devices in `devices.txt` rather than erased. Erase
  the originals if you want them back.
* **Runtime** is roughly 2 hours for the full matrix, mostly fixed sleeps in
  `nav.sh`/`capture-theme.sh` waiting for content to settle.
