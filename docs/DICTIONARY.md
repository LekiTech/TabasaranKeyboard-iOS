# The Tabasaran dictionary (cleanup version 1)

The keyboard ships two read-only SQLite artifacts in the extension,
`tabasaran_words.sqlite` (28,698 words, 652 KB) and
`tabasaran_bigrams.sqlite` (38,479 word pairs, 1,220 KB), built by
`scripts/build_dictionary.py` from the v0 Tabasaran data. The same files
are bundled in Debug and Release. The schema is General Keyboard's artifact
contract (`GeneralKeyboard-iOS/docs/engine/ARTIFACT_CONTRACT.md`): no extra
columns, no duplicate representations. Lookup keys carry the palochka as
ӏ U+04CF; the keyboard shows and inserts Ӏ U+04C0.

**The source data is scanned text, and it shows.** Cleanup version 1
repairs what the evidence settles and lists the rest for a Tabasaran
speaker. Suggestions will still contain misspellings; see
[Known limitations](#known-limitations).

## Review status

**No correction and no spelling in this dictionary has been verified by a
native speaker.** The rules were derived from the data and the raw
sources, not from a knowledge of the language. In the order a reviewer
should take them:

1. **D1, 2,081 rows** («й» → «и», the stressed и of the digitized
   dictionary). 783 were merged into a word the data already had; **1,298
   were respelled into spellings that are in no source**, on the argument
   that й never stands in that position in the magazine text. A wrong
   respelling is possible wherever that argument fails.
2. **M6, 88 rows** («аш…» → «апӀ…», 7,615 tokens). The merge moves the
   most frequent verb of the corpus; it rests on the OCR evidence below and
   on the dictionary examples, not on a speaker's judgment.
3. **The 683 flagged entries** (58 high priority), which were left as they
   are: [`dictionary/review/`](dictionary/review/).

Every change can be undone row by row: `corrections.csv` lists the source
spelling, the target and the rule, and the build is reproducible.

## Source data

`keyboard_data_v0.zip` (SHA-256
`8cec9c22b314373386dbcbbbe1680d765b4f212de655162197af019402b8ac31`, folder
`keyboard_data/`, built 2026-10-11 by `build_kb_data.py`), language code
`tab`. The five Tabasaran files are kept **outside this repository**,
unmodified and read-only, with checksums, in
`../tabasaran-dictionary/original-v0/` (`SHA256SUMS` there; the same hashes
are pinned in the build script and in each artifact's `meta.derived_from`):

| File | SHA-256 |
|---|---|
| `tab_words.sqlite` | `ffd07f86…d76e` |
| `tab_bigrams.sqlite` | `53951eca…c035` |
| `tab_words.tsv` | `52dbd8bd…7357` |
| `tab_bigrams.tsv` | `43d05e8b…31cb` |
| `tab_stats.json` | `d2b6877a…2d9b` |

v0 sources (`tab_stats.json`; the v0 `meta.sources` named only the first
two, the artifacts here name all four):

- `zhd_ocr_tabas`: the Tabasaran edition of «Женщина Дагестана» 2016–2023,
  **Tesseract OCR** from the LingConLab parallel corpus
  (`tabas/tesseract_OCRed_texts`, 39 issues): 51,692 sentences, 486,909
  tokens, 8,462 sentences dropped as Russian. 96 % of the running text and
  almost every bigram.
- `hanmagomedov_examples`: the example sentences of the Tabasaran–Russian
  dictionary by Khanmagomedov and Shalbuzov (2001) as digitized in
  LekiTech/data-sources (v2.1): 6,782 sentences, 17,599 tokens. v0 treats
  it as clean text; it is a scan too (see D1 below).
- `hanmagomedov_headwords`: the headwords of the same dictionary, 8,866
  words (word list).
- `ids`: Intercontinental Dictionary Series, 2,713 words (word list).

v0 scoring: `base_score = 10 × corpus count + min(9, number of word lists)`;
bigram `weight` = adjacent occurrences in one sentence, kept when ≥ 2 and
both words are rows. A word seen only in the OCR needs ≥ 3 occurrences. v0
normalized with NFC, lowercase, the palochka lookalikes and the twelve
Latin → Cyrillic twins, and repaired some OCR renderings of the palochka
(`Г`, `!`, `[`, `1` between letters).

## Audit of the v0 data

| | |
|---|---|
| Words / bigrams | 29,693 / 38,785 |
| Where a word is attested | OCR only 13,575 · word list only 5,988 · dictionary examples only 3,323 · the rest in two or three sources |
| In a word list | 10,799 |
| OCR-only | 13,575, of which 5,818 seen only 3–4 times |
| Corpus tokens | 434,735: 417,136 from the OCR, 17,599 from the dictionary examples |
| Characters | а–я, ё, ӏ (U+04CF) and the hyphen; no Latin letter, no U+04C0, no control character |
| Canonical form | every row is canonical and valid under General Keyboard's `dagestanianCyrillicV1` profile; no duplicates, no score or count mismatch |
| Words with a palochka | 2,166; after к 614, т 574, ч 549, ц 336, п 205, and 69 times after a letter that never takes one |
| Hyphenated | 499 |
| Bigram orphans / weight < 2 | 0 / 0 |

So the v0 files are sound as data. The problems are in the text they were
counted from. Each finding below was checked in the raw sources (the
LingConLab OCR text at commit `a2ff094a6f64ef5cd7327eeef134d7c9e270174a`
and the dictionary JSON of LekiTech/data-sources at
`1ef51bcef018925065c48a5ffa043ad462399b97`); the build itself reads only
the v0 files.

1. **The magazine's palochka is misread in a dozen ways.** One word in the
   raw OCR text: `сатиди` 100×, `сатГиди` 82×, `сат[иди` 38×, `са[иди` 37×,
   `саШиди` 14×. v0 repaired `Г`, `[`, `!` into ӏ; what remains is a lost
   palochka (`сатиди`), a lost consonant (`саӏиди`), `й` or `г` in its
   place (`варитЙан`), and letters that swallow it: `цӀ` read as `щ`
   (`бищидар` for `бицӀидар`) and `пӀ` read as `ш` (`аШуз` for `апӀуз`).
2. **The most frequent verb is the worst hit.** 88 OCR-only forms with
   `аш` pair one to one with attested forms of апӀуб "to do" in `апӀ`:
   `ашуз` 1,109 / `апӀуз` 254, `ашури` 576 / `апӀури` 76, `гъашну` 463 /
   `гъапӀну` 38 … 7,615 tokens in all, 1.8 % of the corpus. None of the
   `аш` forms occurs in the dictionary examples, where the `апӀ` forms do;
   the dictionary files its own misread headword `АШЙН` among the `АП…`
   entries with the gloss "see апӀуб".
3. **ъ and ь are confused**, both valid after г, х, к (`гьапиш` 78 next to
   `гъапиш` 236), doubled (`хьъа`), and ь after и where only ъ is possible
   (`мектебдиь`).
4. **The digitized dictionary prints a stressed и as й** (`ляхйн` for
   `ляхи́н`, `гъурмйш`, `адмй`) and a stressed е as ё (`кюмёк`): 2,128
   headwords and example words have й between or after consonants. In the
   417,136 tokens of magazine text that position never has й.
5. **Words are cut at the apostrophe.** Tabasaran writes «дюн’я»,
   «яратмиш’вал», «йишв’ин»; the v0 tokenizer split there, so the data
   holds `дюн` + `яйин`, `яратмиш` + `валин` as words and pairs. See
   [The apostrophe](#the-apostrophe).

## What cleanup version 1 does

`python3 -I scripts/build_dictionary.py` reads the five v0 files (refusing
them if a checksum differs), re-checks every assumption above, applies
seven rules and writes the artifacts and the review files.

| Rule | Artifact | Example | Rows | Tokens |
|---|---|---|---|---|
| M1 | a doubled palochka | кӏӏуру → кӏуру | 14 | 59 |
| M2 | й or г read for the palochka after к п т ц ч | варитйан → варитӏан, гучг → гучӏ | 54 | 374 |
| M3 | щ read for цӏ (щ is not a letter of native words) | бищидар → бицӏидар, щийи → цӏийи | 46 | 487 |
| M4 | two signs in a row | хьъа | 0 | 0 |
| M5 | ь after a vowel other than а, у | мектебдиь → мектебдиъ | 10 | 43 |
| M6 | аш read for апӏ in the forms of апӏуб | ашуз → апӏуз, гъашну → гъапӏну | 88 | 7,615 |
| D1 | й for a stressed и of the digitized dictionary | ляхйн → ляхин, гъурмйш → гъурмиш | 2,081 | 2,161 |
| | | | **2,293** | **10,739** |

Conditions, the same for every row of a rule:

- **M1–M5** (magazine OCR): the source row is OCR-only (in no word list
  and not in the dictionary examples; M2 also accepts the examples, which
  print `Г` for the palochka), exactly one repaired form is a row of the
  data, and that row is at least as frequent. M2 and M3 touch letters that
  also occur legitimately (the plural -йир in «халачйир», щ in «училище»):
  without an attested repair nothing happens.
- **M6**: the source row is OCR-only, has `ш` right after `а`, and its
  `апӏ` form is a row of the data (or one that D1 respells into it). There is
  no frequency condition, because
  here the misreading is the majority reading (finding 2); the scope is the
  root of апӏуб instead. `ишри`, a real form of хьуб, is outside it, and
  the three `иш` forms that could belong to ипӏуб "to eat" are only flagged.
- **D1**: й after a consonant and before a consonant, a sign, a hyphen or
  the end of the word becomes и. 783 rows merge into the attested word;
  1,298 rows have no attested form and are **respelled** (the row keeps
  its counts under the corrected spelling). This is the one rule that
  writes spellings v0 does not have. It is applied because the position is
  one where real text never has й, and because a headword spelled
  «гъурмйш» can never be typed. A row with two й in a row («арфанййр»,
  41 rows) is left alone: either one could be the stressed и.
- Merges add counts and bigram weights and recompute `base_score` with the
  v0 formula; the number of word lists of a merged row is the larger of
  the two, never the sum. Chains are followed (`ашйн` → `ашин` → `апӏин`).
  **Nothing is deleted.** Corpus tokens (434,735) and the total bigram
  weight (152,553) are the same before and after.

| | v0 | cleanup 1 |
|---|---|---|
| Words | 29,693 | **28,698** (995 merged away; 1,298 respelled; 26,486 unchanged) |
| Bigrams | 38,785 | **38,479** (1,846 pairs remapped, 306 combined) |

Every change is a row of
[`dictionary/review/corrections.csv`](dictionary/review/corrections.csv)
(source, target, rule, merged or respelled, counts).

### Not merged

105 rows match a rule but fail a condition and stay as they are, flagged:
42 with two signs (M4: both readings are attested, as in `хьъа` → `хъа`
3,648 or `хьа` 258, or none is), 47 of D1 (41 with «йй», 6 others), 7 of
M5, 6 of M3 and 3 of M2 (the source is in a word list, or the repaired
form is rarer).

## Review lists

- [`dictionary/review/flagged.csv`](dictionary/review/flagged.csv): 683
  entries kept unchanged, with the reason and the attested alternative.
- [`dictionary/review/high_priority.csv`](dictionary/review/high_priority.csv):
  the 58 of them seen at least 20 times, the ones a typist will meet.
- [`dictionary/review/summary.json`](dictionary/review/summary.json): the
  audit, the rule counts and the flag counts.

| Flag | Entries | High priority |
|---|---|---|
| possibly lost palochka (`кваин` 338 next to `кӏваин` 427) | 145 | 39 |
| ё where the same word is attested with е (`кюмёк`, but also `самолёт`) | 111 | 0 |
| ъ and ь possibly confused after г, х, к (`дугьу` 58 next to `дугъу` 2,577) | 115 | 4 |
| two-letter token outside the word lists (`пи` 1,199) | 77 | 9 |
| no vowel | 52 | 2 |
| palochka after a letter other than к п т ц ч (`саӏиди`) | 49 | 2 |
| not merged (rules above) | 105 | 1 |
| doubled consonant possibly extra or lost | 14 | 2 |
| hyphen part shorter than 2 letters, same letter three times, starts with a sign, very long | 35 | 2 |
| possibly аь read as аы; possibly пӏ read as ш outside апӏуб | 8 | 1 |

A lost palochka is flagged and never repaired: к and кӏ are different
sounds, and «кул» and «кӏул» may both be words.

## The apostrophe

Tabasaran spelling has an apostrophe (it is in the alphabet of the 2007
primer): 0.44 % of the words of the magazine text have one, most often
after н, ш, л, в and before и, в, я, а («дюн’я», «яратмиш’вал»,
«йишв’ин», «хул’ан»). The v0 tokenizer cut words there, and the
dictionary cannot be repaired from the v0 files alone (a half of one
letter, like the «я» of «дюн’я», was dropped and left no trace).

Cleanup version 1 therefore keeps the halves, and the keyboard is set up
to match: the apostrophe (a long press on ъ, or ' on the number page) ends
the word being typed, as the ASCII apostrophe does in every General
Keyboard product (`TextConventions.wordSeparators`). In practice:

- after «дюн’» the next letters are a new word: «яй» is completed to
  «яйин», «яйиъ», «яйиз»;
- the halves are learned as two words and as a pair;
- the bigram «дюн → яйин» (weight 118) also shows «яйин» as the next word
  after «дюн» and a space, where it does not belong;
- right after the apostrophe the suggestion bar still shows the next-word
  predictions of the previous space-terminated word: the engine moves that
  context on a space, not on other separators (true of the hyphen in every
  General Keyboard product). Typing one letter replaces them.

A dictionary with whole apostrophe words needs a rebuild from the raw
texts with a tokenizer that keeps the apostrophe, and a decision on how
the engine should treat it. Both are future work.

## Known limitations

- **Lost palochkas remain**, 145 flagged pairs and more that have no
  attested partner: `кваин`, `кури`, `цийи`, `апуз` are offered next to
  `кӏваин`, `кӏури`, `цӏийи`, `апӏуз`, usually below them.
- **ъ/ь variants remain** (`гьапиш`, `багьри`).
- **5,818 OCR-only words were seen only 3–4 times**; some are misreadings
  no rule can name.
- **Russian words** of the magazine's Russian passages are in the data
  (`военный`, `художественный`): v0 kept a Russian word seen 10 times.
- **Fragments**: halves of apostrophe words, suffixes written apart
  (`-йин` after an abbreviation), the two-letter tokens of the flag list.
- The counts come from one magazine and one dictionary: 434,735 tokens is
  a small corpus, and its vocabulary is that magazine's.

None of this was hidden by deleting rows: what is doubtful is in the
review lists.

## Rebuilding

```bash
SOURCE_DATE_EPOCH=1795132800 python3 -I scripts/build_dictionary.py
python3 -I scripts/build_dictionary.py --validate
```

Python 3, standard library only. The input is `../tabasaran-dictionary/original-v0`
(or `--source DIR`); the five files must match the pinned SHA-256 sums.
With `SOURCE_DATE_EPOCH` the output is byte-identical on every run
(`tabasaran_words.sqlite` SHA-256 `c0ab7c9d…3aaf`, `tabasaran_bigrams.sqlite`
`8e051104…95fd`). The build validates what it wrote (43 checks: metadata,
schema, canonical form, token contract, the rows each rule leaves, bigram
integrity) and **refuses to overwrite artifacts that carry a newer
`cleanup_version`, `content_version` or `schema_version` than the script**,
so an old checkout cannot replace approved data. The Xcode project bundles
the two files of `TabasaranKeyboardExtension/` as they are; there is no
build phase that regenerates them.

A change of rules means: bump `CLEANUP_VERSION` and `CONTENT_VERSION`,
rebuild, update the pinned counts in `validate()` and in
`Tests/TabasaranCoreTests/DictionaryTests.swift`, and this document.
