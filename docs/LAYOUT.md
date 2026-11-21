# The Tabasaran layout

This is the **proposed LekiTech Tabasaran layout**. No community or
official Tabasaran iOS layout existed to copy (see
[What exists upstream](#what-exists-upstream)); it was designed here from
corpus data. It is not an Apple keyboard and has no Apple approval. A
review by Tabasaran speakers is open ([open questions](#open-questions)).

## Rows (iPhone)

```
й ц у к е н г ш ъ з х        11 keys
ф Ӏ в а п р о л д ж э        11 keys
⇧ я ч с м и т ь б ю ⌫        9 letters
123 ⚙︎ 😀 🌐  space  ⏎
```

The Russian iOS layout with **two keys changed**: the hard sign **ъ** is
where the Russian keyboard has **щ**, and the palochka **Ӏ** is where it
has **ы**. **щ** is a long press on ш, **ы** a long press on Ӏ. Every other
letter is in its Russian place. Key sizes are those of the Russian keyboard
(11 keys per row, 29.9 pt on a 402 pt iPhone, 27.5 pt on a 375 pt one); the
engine draws the grid with `KeyboardGridModel.nativeCells`.

The number and symbol pages are the Russian iOS pages, unchanged:
`1 2 3 4 5 6 7 8 9 0` / `- / : ; ( ) ₽ & @ "` / `#+= . , ? ! ' ⌫` and
`[ ] { } # % ^ * + =` / `_ \ | ~ < > $ € ¥ •` / `123 . , ? ! ' ⌫`.

## Long press (complete)

| Key | Options (in order) | |
|---|---|---|
| а | аь | digraph letter |
| г | гъ гь | digraph letters; гъ first (2.18 % of letters vs 1.42 %) |
| к | кь кӀ къ | digraph letters by frequency (0.57 %, 0.33 %, 0.17 %) |
| п | пӀ | digraph letter |
| т | тӀ | digraph letter |
| у | уь | digraph letter |
| х | хь хъ | digraph letters; хь first (0.92 % vs 0.68 %) |
| ц | цӀ | digraph letter |
| ч | чӀ | digraph letter |
| е | ё | no key of its own, as on the Russian keyboard |
| ш | щ | no key of its own |
| Ӏ | ы | no key of its own; on the key that took its place |
| ъ | ’ | the apostrophe of «дюн’я», «яратмиш’вал» (U+2019) |
| 0 | ° | |
| ₽ | $ € £ ¥ ￦ | |
| # | № | |
| . | … | |
| % | ‰ ∞ | |
| = | ≠ ≈ | |
| - | • – — | |
| / | \ | |
| & | § | |
| ? | ¿ | |
| ! | ¡ | |
| ' | ’ ‘ ` | |
| " | ” “ „ » « | |

A digraph option inserts both characters at once (`кӀ` = к U+043A + Ӏ
U+04C0) and is the same string as typing its two keys. With Shift the first
letter is capitalized (`КӀ`, `Гъ`), with Caps Lock all of it (`КӀ`, `ГЪ`);
the palochka has one form. The assignment of the thirteen digraphs to keys
is that of `tab_key_mapping_ext.json` (Agisight/rf-keyboard-corpora); the
order on г, к and х follows the measured frequency, and the independent
letter count of that repository gives the same order.

Not on a long press, on purpose: the doubled consonants **кк пп тт цц чч**
(tapping the key twice is faster than any popup) and the labialized
**жв чв шв ччв чӀв** (two plain keys; a long press with its 0.3 s delay
would be slower than tapping в).

## Tabasaran orthography, as verified

Sources: the alphabet of the 2007 primer (Ханмягьмадов, Къурбанов,
«Букварь») as given in the Russian Wikipedia article «Табасаранская
письменность» (read 2026-11-21); Evertype, *The Alphabets of Europe:
Tabasaran* (2001, based on sources of 1964–1992); and the keyboard's own
corpus.

- **Alphabet (2007):** the 33 Russian letters, thirteen digraphs
  **аь гъ гь къ кь кӀ пӀ тӀ уь хъ хь цӀ чӀ**, the palochka **Ӏ** and the
  apostrophe **’**.
- **The palochka** follows only к, п, т, ц, ч (99.3 % of its occurrences in
  the corpus; the rest are scanning errors). Tabasaran has no гӀ or хӀ.
- **ъ** is the 8th most frequent character: in гъ, хъ, къ and as a letter
  of its own after vowels (the locative «мектебдиъ», «ваъ»). **ь** after a
  vowel occurs only in аь and уь, which are written at the start of a word
  or syllable (after a consonant the same vowels are я and ю).
- **The apostrophe** separates a consonant from a following в, и, я, а at a
  morpheme boundary, so that шв, жв and so on are not read as one letter:
  «яратмиш’вал», «уж’вал», «дюн’я», «йишв’ин». 0.44 % of words in the
  magazine text have one; 179 headwords of the Khanmagomedov–Shalbuzov
  dictionary do.
- **Doubled consonants** кк пп тт цц чч are written by doubling the letter
  (кк alone: 1.8 per 100 words).
- **Labialized consonants** жв чв шв ччв чӀв: letters of the 1950s
  alphabet, dropped in the 1970s, and graphemes of the alphabet again by
  the decision of 27 January 2026 (Wikipedia, citing «Зори Табасарана»).
  They were written throughout and are common in the corpus (шв 0.9, чв
  0.6 per 100 words).
- **Not current:** жъ, чъ (letters of the 1950s alphabet, in Evertype's
  list) and чь: 3, 0 and 0 tokens in the corpus. ГӀ, джв, уӀ, чӀв of the
  1938 alphabet: гӀ and хӀ survive in four dictionary headwords only.

## Measurements

From the shipped dictionary (`scripts/analyze_layout.py`, results in
[`layout/analysis.json`](layout/analysis.json)): 22,879 words with a corpus
count, 434,735 tokens, 2.65 million characters, token-weighted.

| | % of characters | per 100 words | |
|---|---|---|---|
| ъ | 3.46 | 21.1 | rank 8, ahead of л, к, в; 58 % after г, 18 % after х, 17 % after а, и |
| ь | 3.34 | 20.4 | 40 % after г, 26 % after х, 16 % after к, 16 % in аь, уь |
| Ӏ | 1.09 | 6.7 | after п 33 %, к 28 %, ч 15 %, ц 14 %, т 9 %; undercounted, the OCR drops many |
| э | 0.11 | 0.69 | |
| ы | 0.03 | 0.19 | Russian loans only |
| щ | 0.03 | 0.19 | Russian loans only |
| ё | 0.01 | 0.08 | |

40.5 % of all words contain ъ, ь or Ӏ. The thirteen digraphs are 7.7 % of
all letters: гъ 2.18, гь 1.42, хь 0.92, хъ 0.68, кь 0.57, аь 0.40, пӀ 0.39,
кӀ 0.33, чӀ 0.17, цӀ 0.17, къ 0.17, уь 0.16, тӀ 0.11.

An independent count, `tab_monocorpus_freq.csv` of
Agisight/rf-keyboard-corpora (web text): ъ 3.18 %, ь 2.90 %, palochka in
digraphs 1.29 %, ы 0.15 %, щ 0.04 %, ё 0.01 %. Same picture, with more
palochkas, as expected of text that was typed and not scanned.

## Candidates compared

Model estimates (`analysis.json`), **not measured typing speed**: every
word typed letter by letter, a letter without a key costs one long press
(0.3 s delay), two thumbs.

| | A0 | A | **B** | B2 | C |
|---|---|---|---|---|---|
| | Russian layout, Ӏ and ъ under ь | Russian layout, digraphs on long press | **ъ on щ's key, Ӏ on ы's key** | Ӏ on щ's key, ъ on ы's key | 12-key rows with ъ and Ӏ added |
| Keys per row | 11 · 11 · 9 | 11 · 11 · 9 | 11 · 11 · 9 | 11 · 11 · 9 | 12 · 12 · 9 |
| Narrowest key, 402 / 375 pt screen | 29.9 / 27.5 pt | 29.9 / 27.5 | 29.9 / 27.5 | 29.9 / 27.5 | 26.9 / 24.7 |
| Long presses per 100 words | 27.9 | 27.9 | **0.9** | 0.9 | 0.5 |
| Words needing a long press | 25.1 % | 25.1 % | 0.5 % | 0.5 % | 0.1 % |
| Key presses per word | 6.10 | 5.87 | 6.10 | 6.10 | 6.10 |
| Seconds per 100 words (0.25 / 0.18 s per tap) | 161 / 118 | 155 / 114 | 153 / 110 | 153 / 110 | 153 / 110 |
| Thumb travel per character | 57.3 pt | 53.3 | 56.5 | 56.6 | 58.9 |
| Same-thumb transitions | 46.5 % | 45.7 % | 47.9 % | 44.7 % | 50.4 % |
| Letters moved from the Russian layout | 0 | 0 | 2 (щ, ы) | 2 (щ, ы) | 22 |
| Letters without a key | ъ ё Ӏ | ъ ё Ӏ | щ ы ё | щ ы ё | ё |

The long presses of B include the apostrophe (0.44 per 100 words, measured
in the raw magazine text; A0 and A reach it on the number page).

**Why B.**

- A0 and A keep every Russian key but cost a long press in every fourth
  word, because ъ and Ӏ, 4.5 % of all characters together, have no key.
- B and B2 give both a key by moving the two rarest letters of Tabasaran
  text, щ and ы (0.03 % each, Russian loans), under a long press where a
  Russian typist looks for them. Nothing else moves and no key gets
  narrower.
- C needs no long press for a Russian loan either, but narrows every key
  of the two upper rows by 3 pt (to 24.7 pt on the smallest iPhones) and
  shifts 22 letters off their Russian positions, for a gain of 0.4 long
  presses per 100 words.
- B over B2: the model separates them only by thumb alternation (B2 puts
  гъ and most palochka digraphs on alternating thumbs, B on one thumb with
  short rolls; travel is the same). B was chosen for what the model does
  not measure: it is the arrangement LekiTech's Dargwa keyboard uses
  (the Agisight community layout: ъ on щ's key, Ӏ on ы's key) and ъ is
  where the Kumyk keyboard has it, so the family's keyboards agree. This
  is the first thing to revisit with testers.

## What exists upstream

- [Agisight/ios-system-keyboard](https://github.com/Agisight/ios-system-keyboard)
  at `86e000a966d5d5aa5282617d5f6d90c69890e8db` (2026-11-11): **no
  `layout/tab`**.
- [Agisight/rf-keyboard-corpora](https://github.com/Agisight/rf-keyboard-corpora)
  at `cd7a94ee8318b1abb7690b93755242fd73aaf1b5` (2026-11-11), `data/tab/`:
  a long-press mapping (`tab_key_mapping.json`: Ь → Ӏ;
  `tab_key_mapping_ext.json`: the digraphs under their first letters, and
  Ь → I), a letter count, and `tab_key_default.json`, an empty stub. Its
  monocorpus file is a link, not text.

The mapping is used (digraphs under their first letter); the layout itself
is LekiTech's. Pinned copies:
`Tests/TabasaranCoreTests/Fixtures/agisight/` (`SOURCE.md` there).

## Open questions

1. **B or B2**: ъ in the top row and Ӏ under ц (shipped), or the other way
   round?
2. **The apostrophe**: is a long press on ъ the right place, and is ’
   (U+2019) the right character, or should it be the plain ' ? Should it
   get a key of its own (for example right of the space bar)?
3. **Order of the long-press options** on к (кь кӀ къ) and х (хь хъ): by
   frequency, as shipped, or alphabetical (къ кь кӀ)?
4. Should **жв, чв, шв** be offered on a long press after all, now that
   they are graphemes of the alphabet again?
5. Is **ы under Ӏ** found where expected, or should it be under и?
