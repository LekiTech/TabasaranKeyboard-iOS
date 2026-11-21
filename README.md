# Tabasaran Keyboard for iOS

A native iOS keyboard for the Tabasaran language (Табасаран чӀал),
developed by [LekiTech](https://github.com/LekiTech) on the shared
**General Keyboard** engine, next to the Avar, Lezgi, Dargwa and Kumyk
keyboards.

## The keyboard

- **The LekiTech Tabasaran layout** (a proposal, designed from corpus
  data; not an Apple layout): the Russian iOS layout with two keys changed.
  The hard sign **ъ** (3.5 % of all Tabasaran characters) and the palochka
  **Ӏ** have their own keys, where Russian has щ and ы.

  ```
  й ц у к е н г ш ъ з х
  ф Ӏ в а п р о л д ж э
  ⇧ я ч с м и т ь б ю ⌫
  ```

- Long press: г → гъ гь · к → кь кӀ къ · х → хь хъ · п → пӀ · т → тӀ ·
  ц → цӀ · ч → чӀ · а → аь · у → уь · е → ё · ш → щ · Ӏ → ы · ъ → ’ (the
  apostrophe of «дюн’я»). The thirteen digraph letters are ordinary
  Cyrillic sequences and can also be typed key by key. Why this layout,
  the numbers and the alternatives: [docs/LAYOUT.md](docs/LAYOUT.md).
- The palochka is always **Ӏ U+04C0** in what you see and type; lookups use
  ӏ U+04CF internally, so words typed with a Latin I elsewhere still match.
- Word suggestions from an offline dictionary of 28,698 Tabasaran words
  and 38,479 word pairs, plus the words and word pairs it learns from your
  own typing, including next-word suggestions. The dictionary comes from
  scanned text. Its cleanup was done from the evidence in the data and
  **has not been verified by a native speaker**: 2,081 «й» → «и»
  corrections of the digitized dictionary and 88 merged forms of the verb
  апӀуб need a linguistic review first, and 683 entries are flagged (58 of
  them high priority). See [docs/DICTIONARY.md](docs/DICTIONARY.md).
- Matches the native iOS keyboard (Apple's measured iPhone grid, key
  previews, callout menus with swipe selection, caps lock,
  auto-capitalization, spacebar cursor control, hold-to-repeat delete),
  light and dark mode, the emoji page, an in-keyboard settings panel.
- Private by design: never asks for Full Access and sends nothing anywhere.
  Learned words live in the keyboard's own storage and can be managed and
  reset from the keyboard's gear key.

Status: **development version, not released on the App Store.** Open for
review by Tabasaran speakers: the layout's open questions
([docs/LAYOUT.md](docs/LAYOUT.md#open-questions)), the dictionary's review
lists ([docs/dictionary/review/](docs/dictionary/review/)), and a
Tabasaran translation of the key names and settings panel, which use
Russian text for now ([docs/LOCALIZATION.md](docs/LOCALIZATION.md)).

## Building

The keyboard engine is the shared **General Keyboard** Swift Package
([LekiTech/GeneralKeyboard-iOS](https://github.com/LekiTech/GeneralKeyboard-iOS)),
linked as a local package found next to this checkout. Clone both
repositories side by side, under any parent directory, on their `main`
branches:

```bash
git clone https://github.com/LekiTech/GeneralKeyboard-iOS.git
git clone https://github.com/LekiTech/TabasaranKeyboard-iOS.git
```

```
<workspace>/
  GeneralKeyboard-iOS/     the engine package
  TabasaranKeyboard-iOS/   this repository
```

`GeneralKeyboard-iOS` is a private repository; cloning it needs read access.

The Xcode project references the package as `../../GeneralKeyboard-iOS`
(relative to `TabasaranKeyboard/TabasaranKeyboard.xcodeproj`) and the test
package as `../GeneralKeyboard-iOS`; nothing else is required (no tokens,
no package registry). Open
**`TabasaranKeyboard/TabasaranKeyboard.xcodeproj`** in Xcode 27, pick the
**`TabasaranKeyboard`** scheme (it builds and embeds the
`TabasaranKeyboardExtension` target) and run on a simulator or an iPhone.

```bash
xcodebuild build -project TabasaranKeyboard/TabasaranKeyboard.xcodeproj -scheme TabasaranKeyboard \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
xcodebuild test -scheme TabasaranCoreTests-Package \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
```

Installing on an iPhone, step by step: [docs/BUILDING.md](docs/BUILDING.md).

## Identity

Provisional until the first release.

| | Debug (development) | Release (App Store) |
|---|---|---|
| App bundle ID | `org.lekitech.tabasarankeyboard.dev` | `org.lekitech.tabasarankeyboard` |
| Keyboard extension bundle ID | `org.lekitech.tabasarankeyboard.dev.TabasaranKeyboardExtension` | `org.lekitech.tabasarankeyboard.TabasaranKeyboardExtension` |
| App Group (both targets) | `group.org.lekitech.tabasarankeyboard.dev` | `group.org.lekitech.tabasarankeyboard` |
| Signing | automatic, the developer's own team | manual: the distribution team adds its team and App Store profiles |

Both targets carry the App Groups entitlement; the group's identifier is
the `TABASARAN_APP_GROUP_ID` build setting of each configuration. Learned
words, settings and recent emojis live in the extension's own container,
so nothing is shared with the Avar, Lezgi, Dargwa or Kumyk keyboards.

The keyboard's language is `tab` (ISO 639-3, `PrimaryLanguage` in the
extension's `Info.plist`) and must stay so. iOS has no display name for
`tab`, so the globe menu lists the keyboard by its own name without a
language line under it; that is a limitation of iOS's language data, not a
setting of this project ([docs/LOCALIZATION.md](docs/LOCALIZATION.md#the-language-code)).

## Release and App Store handoff

Debug builds run as they are under the developer's team. The Release
configuration is prepared but deliberately unsigned: it carries the App
Store identifiers, manual signing with `Apple Distribution`, and an empty
team and empty profile names. To archive for the App Store, the
distribution team:

1. Registers the App IDs `org.lekitech.tabasarankeyboard` and
   `org.lekitech.tabasarankeyboard.TabasaranKeyboardExtension`, creates the
   App Group `group.org.lekitech.tabasarankeyboard`, and enables the App
   Groups capability with that group on both App IDs.
2. Creates an App Store provisioning profile for each of the two App IDs.
3. In the **Release** configuration of both targets (`TabasaranKeyboard`
   and `TabasaranKeyboardExtension`) sets `DEVELOPMENT_TEAM` and
   `PROVISIONING_PROFILE_SPECIFIER`. Debug stays as it is.
4. Sets the version in both targets, the same values in each:
   `MARKETING_VERSION` (now 1.0.0) and `CURRENT_PROJECT_VERSION` (now 1).
5. Archives the `TabasaranKeyboard` scheme (Product → Archive) and uploads
   the archive to App Store Connect.

Before signing is set up, this checks that Release compiles:

```bash
xcodebuild build -project TabasaranKeyboard/TabasaranKeyboard.xcodeproj -scheme TabasaranKeyboard \
  -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

The keyboard does not request Full Access (`RequestsOpenAccess` is false)
and sends nothing anywhere, and `ITSAppUsesNonExemptEncryption` is NO. The
bundle identifiers and the App Group are provisional until the first
upload and must not change after it.

## Repository

```
TabasaranKeyboard/
  TabasaranKeyboard.xcodeproj        two targets: the app and the keyboard extension
  TabasaranKeyboard/                 containing app (SwiftUI): install steps, layout,
                                     long-press guide, settings and dictionary info
  TabasaranKeyboardExtension/        the keyboard: TabasaranDefinition, TabasaranLayout,
                                     TabasaranStrings, TabasaranIdentity,
                                     KeyboardViewController, Info.plist,
                                     tabasaran_words.sqlite, tabasaran_bigrams.sqlite
Package.swift, Tests/TabasaranCoreTests/  product-layer tests through the real engine
  Fixtures/agisight/                 pinned upstream files (MIT) the tests read
scripts/build_dictionary.py          reproducible dictionary build from the v0 data
scripts/analyze_layout.py            letter statistics and the layout comparison
scripts/make_icon.py                 checks and installs the app icon from docs/branding/
docs/                                LAYOUT (+ layout/analysis.json), DICTIONARY
                                     (+ dictionary/review/), LOCALIZATION, BUILDING,
                                     branding/ (the icon artwork as delivered)
```

The engine itself (model, views, storage, normalization pipeline,
settings, emoji) is not in this repository; see `GeneralKeyboard-iOS/docs/`.
No engine change was needed for Tabasaran.

## Organization

Developed by [LekiTech](https://github.com/LekiTech), a team building
digital tools for the languages of Dagestan.

## License

All rights reserved, see [LICENSE](LICENSE). Third-party material and its
licenses are listed there.
