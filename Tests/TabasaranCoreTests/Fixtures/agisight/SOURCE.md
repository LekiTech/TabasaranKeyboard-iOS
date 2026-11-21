# Pinned upstream files

Unmodified copies, used by `TabasaranLayoutTests` and
`scripts/analyze_layout.py`, and kept for attribution.

| File | Repository | Path | Commit |
|---|---|---|---|
| `rus-3-rows.yaml` | https://github.com/Agisight/ios-system-keyboard | `layout/rus/rus-3-rows.yaml` | `86e000a966d5d5aa5282617d5f6d90c69890e8db` (2026-11-11) |
| `rus-longpress.yaml` | https://github.com/Agisight/ios-system-keyboard | `layout/rus/rus-longpress.yaml` | same |
| `tab_key_mapping_ext.json` | https://github.com/Agisight/rf-keyboard-corpora | `data/tab/Ali_Kuzhuget/mapping/tab_key_mapping_ext.json` | `cd7a94ee8318b1abb7690b93755242fd73aaf1b5` (2026-11-11) |
| `tab_key_mapping.json` | same | `data/tab/Ali_Kuzhuget/mapping/tab_key_mapping.json` | same |
| `tab_monocorpus_freq.csv` | same | `data/tab/Ali_Kuzhuget/frequencies/tab_monocorpus_freq.csv` | same |

Both repositories are MIT licensed: `LICENSE-ios-system-keyboard`
(Copyright (c) 2025 Agisight) and `LICENSE-rf-keyboard-corpora`
(Copyright (c) 2025 Agisight (Ali Kuzhuget)).

What the Tabasaran keyboard takes from them:

- `rus-3-rows.yaml`, `rus-longpress.yaml`: a transcription of the Russian
  iOS keyboard (letter rows, number and symbol pages, symbol alternates),
  the baseline the Tabasaran layout departs from by two keys.
- `tab_key_mapping_ext.json`: which Russian key carries each Tabasaran
  digraph on a long press (А: АЬ · Г: ГЪ, ГЬ · К: КЪ, КЬ, КӀ · П: ПӀ ·
  Т: ТӀ · У: УЬ · Х: ХЪ, ХЬ · Ц: ЦӀ · Ч: ЧӀ). The keyboard keeps the
  assignment and orders the options of one key by frequency. Its last
  entry, «Ь: I» (a Latin I for the palochka), is not taken: the palochka
  has its own key and is always Ӏ U+04C0.
- `tab_monocorpus_freq.csv`: letter counts of Tabasaran web text
  (FineWeb-2, collected 2025-08-03), an independent check of the
  frequencies measured from the keyboard's own dictionary.

Not available upstream: a Tabasaran layout. At the commits above
`ios-system-keyboard` has no `layout/tab`, and
`rf-keyboard-corpora/data/tab/Ali_Kuzhuget/keyboard/tab_key_default.json`
is an empty stub (`"keys": []`). `tab_key_mapping.json` (the basic mapping,
Ь: Ӏ) is the "A0" candidate of `docs/LAYOUT.md`.
