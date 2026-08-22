# Awful Screenshot Matrix — How It Works

Regenerate everything with the scripts in `bin/` (all gitignored along with the
images). Set `IDB_BIN` to the `idb` client before running anything.

## Layout

`ScreenshotMatrix/<ios>-<device>/<theme>/<ios>_<device>_<theme>_<NN>-<view>.png`

The `NN` prefix keeps views in a stable order, which makes an ffmpeg slideshow
trivial later. Each PNG has a label strip **spliced below** the screenshot
rather than drawn over it, so the app pixels stay untouched for regression
diffing — crop the strip off before comparing.

## Coverage

| Pass | Devices | Themes | Views |
|---|---|---|---|
| A | iPhone 17 Pro (26.5), iPhone 16 Pro (18.5) | all 15 | 12 |
| B | 17 Pro Max, 16 Pro Max, iPad Pro 11"/13" on both OSes | default + classic-dark | 6 |

## Views

| NN | View | Reached by |
|----|------|-----------|
| 01 | Forums list | `awful://forums` |
| 02 | Thread list | `awful://forums/261` (Apps In Developmental States) — titles/tags/names synthetic¹ |
| 03 | Posts view | `awful://threads/3532200/pages/last` |
| 04 | Bookmarks | `awful://bookmarks` — titles/tags/names synthetic¹ |
| 05 | PM list | `awful://messages` — subjects/senders synthetic¹ |
| 07 | Settings | `awful://settings` |
| 09 | Leper's Colony | `awful://banlist` |
| 10 | Profile | `awful://users/224355` |
| 11 | Rap sheet | `awful://banlist/224355` |
| 13 | Post compose | posts view → compose button (pass A only) |
| 15 | Post preview | compose → Preview (pass A only) |
| 19 | Poll thread | `awful://threads/4115578` |

¹ `scrub-lists.sh` rewrites list-view titles, tags, subjects, and usernames in
the Core Data cache to deterministic fakes from `scrub-data/*.txt` before each
theme cycle (see README, "List scrubbing"). Detail views 03/19 keep real
content. `SCRUB=0` disables.

## Safety rules (enforced in `capture-interactive.sh`)

* Composing happens **only** in forum 261, "Apps In Developmental States".
* Any PM compose is addressed **only** to "Commie kong".
* Post / Send is **never** tapped. Compose exits via Cancel → Delete Draft,
  both located by accessibility label rather than fixed coordinates, so a
  shifted layout cannot become a stray tap on Post.

## Gotchas discovered while building this

* **App preferences live in the app's sandboxed container.**
  `simctl spawn <udid> defaults write` writes to the simulator's *global*
  domain, which the app never reads — theme changes silently did nothing.
  `set-theme.sh` edits the container plist directly, with the app terminated
  and the simulator's `cfprefsd` stopped so it cannot flush a stale cached
  copy back over the write.
* **Custom URL schemes prompt.** Both `simctl openurl` and `idb open` raise a
  SpringBoard "Open in AwfulDebug?" alert every time. `nav.sh` finds the Open
  button in the accessibility tree and taps it.
* **Modal sheets swallow the next deep link.** The profile sheet made the rap
  sheet capture a duplicate of the profile, so `nav.sh` dismisses any open
  sheet before navigating.
* **iPad screenshots come out sideways.** `simctl` grabs the portrait-native
  framebuffer, so a landscape iPad needs `ROTATE=90` (verify per device — the
  correct angle depends on which way the simulator is currently rotated).
* **The app's accessibility tree is nearly empty** in web-backed views (3
  elements), so in-app controls are tapped by coordinate; only UIKit alerts
  and action sheets expose usable labels.
* **Dead framebuffers.** Three iOS 18.5 simulators ran the app but drew
  nothing (screenshots had zero variance) and did not recover from a
  CoreSimulator restart. Replacements were created as `Shot-*` devices rather
  than erasing the originals. A fresh simulator needs a manual login — copying
  the keychain and app container across does **not** transfer the session.

## Devices used

| Slug | Simulator |
|---|---|
| ios26.5-iphone-17-pro | iPhone 17 Pro · E23798C0 |
| ios26.5-iphone-17-pro-max | iPhone 17 Pro Max · 49B749F9 |
| ios26.5-ipad-pro-11 | iPad Pro 11" (M5) · CA5087B6 |
| ios26.5-ipad-pro-13 | iPad Pro 13" (M5) · 9F57B12D |
| ios18.5-iphone-16-pro | iPhone 16 Pro · E8733BA4 |
| ios18.5-iphone-16-pro-max | Shot-16ProMax-185 (replacement) |
| ios18.5-ipad-pro-11 | Shot-iPad11-185 (replacement) |
| ios18.5-ipad-pro-13 | Shot-iPad13-185 (replacement) |
