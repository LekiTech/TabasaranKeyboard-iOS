#!/usr/bin/env python3
"""Build the Tabasaran keyboard dictionary from the v0 data (cleanup version 1).

Deterministic, Python 3 standard library only. Reads (never writes) the five
v0 Tabasaran files from keyboard_data_v0.zip, checked against pinned SHA-256
sums:

    tab_words.sqlite  tab_bigrams.sqlite  tab_words.tsv  tab_bigrams.tsv  tab_stats.json

Writes:

    <out>/tabasaran_words.sqlite    words(word, base_score) + meta   (General Keyboard artifact)
    <out>/tabasaran_bigrams.sqlite  bigrams(prev, word, weight) + meta
    <review>/corrections.csv        every merge the build made
    <review>/flagged.csv            entries kept unchanged but listed for a linguistic review
    <review>/high_priority.csv      the flagged entries frequent enough to show up in everyday use
    <review>/summary.json           counts of the audit, the merges and the flags

Usage, from the repository root (General Keyboard layout: the v0 files sit in
../tabasaran-dictionary/original-v0 next to this repository):

    python3 -I scripts/build_dictionary.py               # build + validate
    python3 -I scripts/build_dictionary.py --validate    # validate the shipped artifacts only
    python3 -I scripts/build_dictionary.py --source DIR --out DIR --review DIR

Set SOURCE_DATE_EPOCH to make meta.generated_at (and so the sqlite bytes)
reproducible; the rows are identical on every run regardless. The build
refuses to replace artifacts that carry a newer cleanup or content version
than this script (an obsolete checkout cannot overwrite approved data).

The rules are documented in docs/DICTIONARY.md. In short:

  * The words are already in the canonical form of General Keyboard's
    dagestanianCyrillicV1 profile (NFC, lowercase, palochka U+04CF); the build
    re-checks it with a mirror of Normalization.swift and refuses anything else.
  * Artifacts of the two digitizations are repaired, each by a rule that
    names the evidence (docs/DICTIONARY.md has the raw-text examples):
    the magazine OCR
      M1  a doubled palochka "ӏӏ" (no Tabasaran letter has two);
      M2  «й» or «г» read for the palochka after к п т ц ч ("варитйан" →
          "варитӏан", "гучг" → "гучӏ"; the raw OCR text has "варитЙан",
          "бицГидар");
      M3  «щ» read for «цӏ» ("бищидар" → "бицӏидар"); щ is not a letter of
          native Tabasaran words, only of Russian loans;
      M4  two signs in a row ("хьъ"), which no Tabasaran spelling has;
      M5  «ь» after a vowel other than а, у ("мектебдиь" → "мектебдиъ"):
          Tabasaran writes ь after a vowel only in аь and уь;
      M6  «ш» read for «пӏ» in the forms of апӏуб "to do" and ипӏуб "to eat"
          ("ашуз" → "апӏуз"; the raw OCR text has "аШуз");
    and the digitized dictionary (headwords and examples)
      D1  «й» for a stressed «и» between or after consonants ("ляхйн" →
          "ляхин"), a position where the magazine text never has й.
    M1–M5 need an OCR-only source row (M2 also accepts the dictionary
    examples, which print Г for the palochka), exactly one attested repaired
    form, and that form at least as frequent. M6 instead needs the repaired
    form in a word list or the dictionary examples, because there the
    misreading is the majority. D1 merges into the attested form and, when
    the form is not attested and the position is unambiguous, respells the
    row. Counts and bigram weights are added; nothing else moves.
  * Nothing is deleted and nothing else is respelled. Every other doubtful
    entry stays as it is and is written to flagged.csv for a Tabasaran speaker.
"""

import argparse
import csv
import hashlib
import json
import os
import re
import sqlite3
import sys
import unicodedata
from collections import Counter, defaultdict
from datetime import datetime, timezone

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SOURCE = os.path.join(os.path.dirname(REPO), "tabasaran-dictionary", "original-v0")
DEFAULT_OUT = os.path.join(REPO, "TabasaranKeyboard", "TabasaranKeyboardExtension")
DEFAULT_REVIEW = os.path.join(REPO, "docs", "dictionary", "review")

# keyboard_data_v0.zip (sha256 8cec9c22b314373386dbcbbbe1680d765b4f212de655162197af019402b8ac31),
# folder keyboard_data/, built 2026-10-11.
V0_SHA256 = {
    "tab_words.sqlite": "ffd07f867f0b4d648bfa9ceeb1fcbd623fa98c55e82ceb6860cbecafa52fd76e",
    "tab_bigrams.sqlite": "53951eca3a158b0624cf6681ea208ad7b125b8d35d446c9fe616f5ffb137c035",
    "tab_words.tsv": "52dbd8bddaa1a63770c86ce2efc17331f1fd0b57e5668ba82ed711b2c377e357",
    "tab_bigrams.tsv": "43d05e8b068354150a562b6f6c4ded18aa7086573c0e59a871c04131472b31cb",
    "tab_stats.json": "d2b6877ab44d7475d72d200adac18a6d1260b88720a39dea32382ca4e9802d9b",
}

WORDS_ARTIFACT = "tabasaran_words"
BIGRAMS_ARTIFACT = "tabasaran_bigrams"
SCHEMA_VERSION = 1
CONTENT_VERSION = 1
NORMALIZATION_PROFILE = "dagestanian-cyrillic"   # NormalizationProfile.dagestanianCyrillicV1
NORMALIZATION_VERSION = 1
MIN_READER_SCHEMA = 1
CLEANUP_VERSION = 1

# The CREATE statements of the v0 files, which are the General Keyboard
# artifact shape (docs/engine/ARTIFACT_CONTRACT.md §1). The build checks that
# the v0 files carry exactly these and writes them unchanged.
WORDS_SQL = "CREATE TABLE words(word TEXT PRIMARY KEY, base_score INTEGER NOT NULL DEFAULT 0) WITHOUT ROWID"
BIGRAMS_SQL = ("CREATE TABLE bigrams(prev TEXT NOT NULL, word TEXT NOT NULL, weight INTEGER NOT NULL, "
               "PRIMARY KEY(prev, word)) WITHOUT ROWID")
META_SQL = "CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)"

# v0 recorded only the two corpora in meta.sources although its builder also
# counted two word lists (build_kb_data.py, build_lang("tab")); all four are
# named here.
SOURCES = {
    "zhd_ocr_tabas": "Женщина Дагестана 2016–2023, Tabasaran edition, OCR (LingConLab parallel corpus, "
                     "tabas/tesseract_OCRed_texts); 486,909 tokens, the bulk of the running text",
    "hanmagomedov_examples": "Ханмагомедов, Шалбузов, Табасаранско-русский словарь (2001), example sentences "
                             "(LekiTech data-sources v2.1); 17,599 tokens",
    "hanmagomedov_headwords": "the same dictionary, headwords (word list)",
    "ids": "Intercontinental Dictionary Series, CLDF, Language_ID 67 and 68 (word list)",
}

PALOCHKA = "ӏ"               # ӏ U+04CF, the lookup form (TextConventions shows Ӏ U+04C0)
VOWELS = "аеёиоуыэюя"
CONSONANTS = "бвгджзйклмнпрстфхцчшщ"
SIGNS = "ъь"
PALOCHKA_BASES = "кптцч"     # кӏ пӏ тӏ цӏ чӏ: the only letters a Tabasaran palochka follows
GEMINATES = "кптцч"          # кк пп тт цц чч
ALPHABET_RE = re.compile(rf"[а-яё{PALOCHKA}]+(?:-[а-яё{PALOCHKA}]+)*")
HIGH_PRIORITY_COUNT = 20     # a flagged word this frequent shows up in everyday suggestions
SUSPECT_RATIO = 10           # flags: the attested alternative is this many times as frequent

# ----------------------------------------------------------------- the GK contract
# Mirror of GeneralKeyboard's Normalization.swift with the dagestanianCyrillicV1
# profile (NormalizationProfile.swift). Used only to CHECK the rows.
_SWIFT_WHITESPACE = "\t\n\x0b\x0c\r\x85" + "".join(
    chr(cp) for cp in range(0x110000) if unicodedata.category(chr(cp)) in ("Zs", "Zl", "Zp"))
_LOOKALIKES = {"I", "l", "i", "І", "і", "Ӏ"}
_HOMOGLYPHS = {"a": "а", "c": "с", "e": "е", "o": "о", "p": "р", "x": "х",
               "y": "у", "k": "к", "m": "м", "t": "т", "b": "ь", "h": "н"}
_TAILS = {PALOCHKA, "ь", "ъ"}


def canonical(token):
    t = unicodedata.normalize("NFC", token).strip(_SWIFT_WHITESPACE).lower()
    if any(0x0400 <= ord(ch) <= 0x04FF for ch in t):
        t = "".join(PALOCHKA if ch in _LOOKALIKES else _HOMOGLYPHS.get(ch, ch) for ch in t)
    return unicodedata.normalize("NFC", t)


def letter_count(token):
    return sum(0 if ch in _TAILS else 1 for ch in token)


def is_valid_token(token):
    """Normalization.isValidToken for a canonical token."""
    if not token or len(token) > 64:
        return False
    if any(ch.isspace() or ch.isdigit() for ch in token) or any(ch in token for ch in "@/."):
        return False
    if any(ch.isascii() and ch.isalpha() for ch in token):
        return False
    if any(unicodedata.category(ch) in ("Cc", "Cf") for ch in token):
        return False
    return letter_count(token) >= 2


# ----------------------------------------------------------------- input
def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def ro(path):
    return sqlite3.connect(f"file:{path}?mode=ro", uri=True)


def table_sql(con):
    return {name: sql for name, sql in con.execute("SELECT name, sql FROM sqlite_master WHERE type='table'")}


class Fail(Exception):
    pass


def load(source):
    for name, digest in V0_SHA256.items():
        path = os.path.join(source, name)
        if not os.path.exists(path):
            raise Fail(f"missing v0 file {path}")
        if sha256(path) != digest:
            raise Fail(f"{name}: SHA-256 differs from the pinned v0 file")

    wc, bc = ro(os.path.join(source, "tab_words.sqlite")), ro(os.path.join(source, "tab_bigrams.sqlite"))
    if table_sql(wc) != {"words": WORDS_SQL, "meta": META_SQL}:
        raise Fail("tab_words.sqlite: unexpected schema")
    if table_sql(bc) != {"bigrams": BIGRAMS_SQL, "meta": META_SQL}:
        raise Fail("tab_bigrams.sqlite: unexpected schema")
    sqlite_words = dict(wc.execute("SELECT word, base_score FROM words"))
    sqlite_pairs = {(a, b): w for a, b, w in bc.execute("SELECT prev, word, weight FROM bigrams")}
    v0_meta = dict(wc.execute("SELECT key, value FROM meta"))
    wc.close()
    bc.close()

    words = {}
    with open(os.path.join(source, "tab_words.tsv"), encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            words[r["word"]] = {
                "score": int(r["base_score"]), "count": int(r["count"]), "clean": int(r["clean_count"]),
                "ocr": int(r["ocr_count"]), "extra": int(r["extra_count"]), "lex": int(r["lexicon_sources"]),
            }
    if {w: r["score"] for w, r in words.items()} != sqlite_words:
        raise Fail("tab_words.tsv and tab_words.sqlite disagree")
    with open(os.path.join(source, "tab_bigrams.tsv"), encoding="utf-8", newline="") as f:
        tsv_pairs = {(r["prev"], r["word"]): int(r["weight"]) for r in csv.DictReader(f, delimiter="\t")}
    if tsv_pairs != sqlite_pairs:
        raise Fail("tab_bigrams.tsv and tab_bigrams.sqlite disagree")
    with open(os.path.join(source, "tab_stats.json"), encoding="utf-8") as f:
        stats = json.load(f)
    return words, sqlite_pairs, v0_meta, stats


def v0_score(rec):
    """base_score of the v0 builder: 10 × corpus count + min(9, word lists)."""
    return 10 * rec["count"] + min(9, rec["lex"])


def ocr_only(rec):
    return rec["lex"] == 0 and rec["clean"] == 0 and rec["extra"] == 0


def anchored(rec):
    """Attested independently of the magazine OCR: a word list or the clean examples."""
    return rec["lex"] > 0 or rec["clean"] > 0


# ----------------------------------------------------------------- audit
def audit(words, pairs):
    inventory = Counter()
    for w in words:
        inventory.update(w)
    canon_groups = defaultdict(list)
    for w in words:
        canon_groups[canonical(w)].append(w)
    mix = Counter()
    for r in words.values():
        mix[" + ".join(k for k, on in (("word list", r["lex"]), ("clean examples", r["clean"]), ("ocr", r["ocr"]))
                       if on)] += 1
    after = Counter()
    for w in words:
        for m in re.finditer(PALOCHKA, w):
            after[w[m.start() - 1] if m.start() else "^"] += 1
    return {
        "words": len(words),
        "bigrams": len(pairs),
        "character_inventory": {f"{ch} U+{ord(ch):04X}": n for ch, n in
                                sorted(inventory.items(), key=lambda kv: (-kv[1], kv[0]))},
        "palochka_after": dict(sorted(after.items(), key=lambda kv: (-kv[1], kv[0]))),
        "not_nfc": sorted(w for w in words if unicodedata.normalize("NFC", w) != w),
        "not_lowercase": sorted(w for w in words if w != w.lower()),
        "not_canonical": sorted(w for w in words if canonical(w) != w),
        "canonical_collisions": sorted(ws for ws in canon_groups.values() if len(ws) > 1),
        "contract_invalid": sorted(w for w in words if not is_valid_token(w)),
        "outside_alphabet": sorted(w for w in words if not ALPHABET_RE.fullmatch(w)),
        "latin_letters": sorted(w for w in words if any(ch.isascii() and ch.isalpha() for ch in w)),
        "visible_palochka_u04c0": sorted(w for w in words if "Ӏ" in w),
        "replacement_or_control_chars": sorted(
            w for w in words if any(ch == "�" or unicodedata.category(ch) in ("Cc", "Cf", "Co", "Cs")
                                    for ch in w)),
        "hyphenated": sum(1 for w in words if "-" in w),
        "with_palochka": sum(1 for w in words if PALOCHKA in w),
        "score_formula_mismatch": sorted(w for w, r in words.items() if r["score"] != v0_score(r)),
        "count_mismatch": sorted(w for w, r in words.items()
                                 if r["count"] != r["clean"] + r["ocr"] + r["extra"]),
        "source_mix": dict(sorted(mix.items(), key=lambda kv: -kv[1])),
        "in_word_lists": sum(1 for r in words.values() if r["lex"] > 0),
        "word_lists_only": sum(1 for r in words.values() if r["lex"] > 0 and r["count"] == 0),
        "ocr_only": sum(1 for r in words.values() if ocr_only(r)),
        "ocr_only_count_3_or_4": sum(1 for r in words.values() if ocr_only(r) and 3 <= r["ocr"] <= 4),
        "corpus_tokens": {"ocr": sum(r["ocr"] for r in words.values()),
                          "clean_examples": sum(r["clean"] for r in words.values())},
        "bigram_orphans": sum(1 for a, b in pairs if a not in words or b not in words),
        "bigram_weight_below_2": sum(1 for v in pairs.values() if v < 2),
        "bigram_self_pairs": sorted(f"{a} {b}" for a, b in pairs if a == b),
    }


# ----------------------------------------------------------------- merges
SIGN_RUN = re.compile(f"[{SIGNS}]{{2,}}")
EJECTIVE_MISREAD = re.compile(f"(?<=[{PALOCHKA_BASES}])[йг]")
VOWEL_SOFT = re.compile(r"(?<=[еёиоыэюя])ь")
STRESSED_I = re.compile(f"(?<=[{CONSONANTS}])й(?=[{CONSONANTS}{SIGNS}-]|$)")
DO_VERB_SH = re.compile("(?<=а)ш")       # rule M6: «аш» for the root «апӏ» of апӏуб

M1 = "M1 doubled palochka"
M2 = "M2 «й» or «г» for ӏ after к п т ц ч"
M3 = "M3 «щ» for «цӏ»"
M4 = "M4 two signs in a row"
M5 = "M5 ь after a vowel other than а, у"
M6 = "M6 «аш» for «апӏ» (forms of апӏуб)"
D1 = "D1 «й» for a stressed «и»"

# rule: (source must be, an unattested row is reported, an unattested row is respelled)
#   "ocr"       OCR-only: in no word list and not in the dictionary examples
#   "unlisted"  in no word list
#   "any"       no condition (the word lists carry the artifact themselves)
RULES = {
    M1: ("ocr", True, False),
    M4: ("ocr", True, False),
    M5: ("ocr", True, False),
    D1: ("any", True, True),
    M3: ("ocr", False, False),
    M2: ("unlisted", False, False),
}
IMPOSSIBLE = {M1, M4, M5, D1}   # spellings no Tabasaran word has; M2 and M3 letters also occur legitimately


def one_at_a_time(pattern, replacement, word):
    """Every form with one match replaced, plus the form with all replaced."""
    forms = {word[:m.start()] + replacement + word[m.end():] for m in pattern.finditer(word)}
    forms.add(pattern.sub(replacement, word))
    return sorted(forms)


def artifact(word):
    """(rule, candidate repaired forms) for a pattern artifact, or None.

    One rule per word, in this order. M6 has no pattern of its own («ш» is a
    letter like any other) and is planned separately.
    """
    if PALOCHKA * 2 in word:
        return M1, [re.sub(PALOCHKA + "+", PALOCHKA, word)]
    runs = list(SIGN_RUN.finditer(word))
    if runs:
        if len(runs) > 1:
            return M4, []
        m = runs[0]
        return M4, [word[:m.start()] + s + word[m.end():] for s in SIGNS]
    if VOWEL_SOFT.search(word):
        return M5, [VOWEL_SOFT.sub("ъ", word)]
    if STRESSED_I.search(word):
        return D1, one_at_a_time(STRESSED_I, "и", word)
    if "щ" in word:
        return M3, [re.sub("щ" + PALOCHKA + "?", "ц" + PALOCHKA, word)]
    if EJECTIVE_MISREAD.search(word):
        return M2, one_at_a_time(EJECTIVE_MISREAD, PALOCHKA, word)
    return None


def impossible(word):
    hit = artifact(word)
    return bool(hit) and hit[0] in IMPOSSIBLE


def plan_merges(words):
    """merges: {source: (rule, direct target)}; blocked: {source: (rule, repaired form(s), reason)}.

    A direct target may be the source of another merge («ашйн» → «ашин» by D1,
    «ашин» → «апӏин» by M6); resolve() follows such chains.
    """
    merges, blocked = {}, {}
    for w, r in sorted(words.items()):
        hit = artifact(w)
        if not hit:
            continue
        rule, forms = hit
        source, report, respell = RULES[rule]
        attested = [f for f in forms if f in words and not impossible(f)]
        shown = " / ".join(forms) or "?"
        if source == "ocr" and not ocr_only(r) or source == "unlisted" and r["lex"]:
            if attested or report:
                blocked[w] = (rule, shown, "source is in a word list" if r["lex"] else
                              "source is in the dictionary examples")
        elif len(attested) > 1:
            blocked[w] = (rule, shown, "two attested readings: " + ", ".join(
                f"{f} ({words[f]['count']})" for f in attested))
        elif attested:
            if rule != D1 and words[attested[0]]["count"] < r["count"]:
                blocked[w] = (rule, attested[0], f"repaired form is less frequent ({words[attested[0]]['count']})")
            else:
                merges[w] = (rule, attested[0])
        elif respell:
            # No attested form: respell when every stressed и is unambiguous.
            # In «…Cйй…» one of the two is the real й, and which one is a
            # question for a speaker.
            hits = [m.start() for m in STRESSED_I.finditer(w)]
            target = STRESSED_I.sub("и", w)
            if any(b - a == 1 for a, b in zip(hits, hits[1:])):
                blocked[w] = (rule, shown, "«йй»: either one could be the stressed и, no reading is attested")
            elif impossible(target):
                blocked[w] = (rule, shown, "repaired form still carries an artifact")
            else:
                merges[w] = (rule, target)
        elif report:
            blocked[w] = (rule, shown, "repaired form is not attested in the data")

    # M6: an OCR-only form with «аш» whose «апӏ» form is attested. The magazine
    # OCR reads the pair «пӏ» as «ш» (raw text «аШуз»), and for this verb that
    # is the majority reading, so there is no frequency condition; the scope
    # is the root of апӏуб instead («ишри» is a real form of хьуб).
    # A form that D1 respells into existence («апӏрй» → «апӏри») counts as attested.
    known = set(words) | {target for _, target in merges.values()}
    for w, r in sorted(words.items()):
        if w in merges or w in blocked or artifact(w) or not ocr_only(r):
            continue
        forms = [w[:m.start()] + "п" + PALOCHKA + w[m.end():] for m in DO_VERB_SH.finditer(w)]
        hits = [f for f in forms if f in known and not artifact(f)]
        if len(hits) == 1:
            merges[w] = (M6, hits[0])
        elif len(hits) > 1:
            blocked[w] = (M6, " / ".join(hits), "two attested readings")
    return merges, blocked


def resolve(merges):
    """{source: final target}, following chains of merges."""
    out = {}
    for src in merges:
        seen, t = {src}, merges[src][1]
        while t in merges:
            if t in seen:
                raise Fail(f"merge cycle at {t}")
            seen.add(t)
            t = merges[t][1]
        out[src] = t
    return out


def apply_merges(words, pairs, merges):
    target = resolve(merges)
    final = {w: dict(r) for w, r in words.items() if w not in merges}
    for src, dst in sorted(target.items()):
        s = words[src]
        t = final.setdefault(dst, {"score": 0, "count": 0, "clean": 0, "ocr": 0, "extra": 0, "lex": 0})
        for k in ("count", "clean", "ocr", "extra"):
            t[k] += s[k]
        # The number of word lists that know the word: the same list may hold
        # both spellings, so the larger number, never the sum.
        t["lex"] = max(t["lex"], s["lex"])
    for w in set(target.values()):
        final[w]["score"] = v0_score(final[w])
    out = Counter()
    remapped = 0
    for (a, b), v in pairs.items():
        na, nb = target.get(a, a), target.get(b, b)
        remapped += (na, nb) != (a, b)
        out[(na, nb)] += v
    return final, dict(out), remapped, target


# ----------------------------------------------------------------- flags
def flag_entries(final, blocked):
    """Entries kept unchanged and listed for review: {word: [(category, note)]}."""
    flags = defaultdict(list)

    def count(w):
        return final[w]["count"] if w in final else 0

    def attested(form):
        return f"{form} ({count(form)})"

    def much_more_frequent(alt, w):
        return alt in final and count(alt) >= SUSPECT_RATIO * max(1, count(w))

    for w, r in final.items():
        unlisted = r["lex"] == 0
        if re.search(f"(^|[^{PALOCHKA_BASES}{PALOCHKA}]){PALOCHKA}", w):
            flags[w].append(("palochka after a letter other than к п т ц ч",
                             "Tabasaran writes ӏ only in кӏ пӏ тӏ цӏ чӏ: OCR (a lost consonant, a misread "
                             "letter) or an old spelling"))
        if unlisted:
            # The magazine OCR often drops the palochka (raw text: «сатиди» next
            # to «сатГиди», «сат[иди»). к/кӏ etc. are different sounds, so this
            # is a question, never a repair.
            for i, ch in enumerate(w):
                if ch in PALOCHKA_BASES and (i + 1 == len(w) or w[i + 1] not in PALOCHKA + SIGNS + ch):
                    alt = w[:i + 1] + PALOCHKA + w[i + 1:]
                    if alt in final and anchored(final[alt]) and count(alt) >= count(w) > 0:
                        flags[w].append(("possibly lost palochka", "attested with palochka: " + attested(alt)))
                        break
            # «пӏ» printed close together reads as «ш» (raw text: «аШуз»). Rule
            # M6 merged the forms of апӏуб; outside that verb it is a question.
            if ocr_only(r):
                for m in re.finditer("ш", w):
                    alt = w[:m.start()] + "п" + PALOCHKA + w[m.end():]
                    if alt in final:
                        flags[w].append(("possibly «пӏ» read as «ш»",
                                         f"OCR-only; the «пӏ» form is attested: {attested(alt)}"))
                        break
            for a, b in (("гь", "гъ"), ("гъ", "гь"), ("хь", "хъ"), ("хъ", "хь"), ("кь", "къ"), ("къ", "кь")):
                alts = [w[:m.start()] + b + w[m.end():] for m in re.finditer(a, w)]
                alts = [alt for alt in alts if much_more_frequent(alt, w)]
                if alts:
                    flags[w].append((f"«{a}» where «{b}» is far more frequent",
                                     "possibly ъ and ь confused; attested: " + attested(alts[0])))
                    break
            for i, ch in enumerate(w):
                if ch in GEMINATES:
                    single = i + 1 < len(w) and w[i + 1] == ch
                    alt = w[:i] + w[i + 1:] if single else w[:i + 1] + ch + w[i + 1:]
                    if much_more_frequent(alt, w):
                        flags[w].append(("possibly extra doubled consonant" if single else
                                         "possibly lost doubled consonant", "attested: " + attested(alt)))
                        break
            if "аы" in w:
                alt = w.replace("аы", "аь")
                if alt in final:
                    flags[w].append(("possibly «аь» read as «аы»", "attested: " + attested(alt)))
            if letter_count(w) == 2:
                flags[w].append(("two-letter token outside the word lists",
                                 "a fragment, an abbreviation or noise"))
        if "ё" in w and w.replace("ё", "е") in final:
            # The digitized dictionary prints a stressed е as ё («кюмёк»);
            # Russian loans have a real ё («самолёт»), so this is a question.
            flags[w].append(("ё where the same word is attested with е",
                             "a stressed е of the dictionary read as ё, or a Russian ё: "
                             + attested(w.replace("ё", "е"))))
        if not any(ch in VOWELS for ch in w):
            flags[w].append(("no vowel", "abbreviation or noise"))
        if re.search(r"(.)\1\1", w):
            flags[w].append(("same letter three times", "abbreviation, interjection or noise"))
        if len(w) >= 20:
            flags[w].append(("very long token", "possibly glued words"))
        if "-" in w and any(letter_count(p) < 2 for p in w.split("-")):
            flags[w].append(("hyphen part shorter than 2 letters", "abbreviation or broken hyphenation"))
        if w[0] in SIGNS + PALOCHKA:
            flags[w].append(("word starts with ь, ъ or ӏ", "possibly OCR or a fragment"))
    for w, (rule, repaired, why) in blocked.items():
        if w in final:
            flags[w].append((f"not merged ({rule.split()[0]})", f"{rule}: {why}; repaired form would be {repaired}"))
    return flags


# ----------------------------------------------------------------- output
def generated_at():
    epoch = os.environ.get("SOURCE_DATE_EPOCH")
    t = datetime.fromtimestamp(int(epoch), timezone.utc) if epoch else datetime.now(timezone.utc)
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


def guard_existing(out):
    """Refuse to replace artifacts built by a newer cleanup or content version."""
    for artifact_name in (WORDS_ARTIFACT, BIGRAMS_ARTIFACT):
        path = os.path.join(out, artifact_name + ".sqlite")
        if not os.path.exists(path):
            continue
        con = ro(path)
        try:
            meta = dict(con.execute("SELECT key, value FROM meta"))
        except sqlite3.Error:
            meta = {}
        finally:
            con.close()
        for key, ours in (("cleanup_version", CLEANUP_VERSION), ("content_version", CONTENT_VERSION),
                          ("schema_version", SCHEMA_VERSION)):
            theirs = meta.get(key)
            if theirs is not None and theirs.isdigit() and int(theirs) > ours:
                raise Fail(f"{path} has {key} {theirs}, newer than this script's {ours}: "
                           "refusing to overwrite it with older data")


def write_artifacts(out, final, pairs):
    os.makedirs(out, exist_ok=True)
    common = [
        ("schema_version", str(SCHEMA_VERSION)), ("content_version", str(CONTENT_VERSION)),
        ("normalization_version", str(NORMALIZATION_VERSION)), ("normalization_profile", NORMALIZATION_PROFILE),
        ("min_reader_schema", str(MIN_READER_SCHEMA)), ("cleanup_version", str(CLEANUP_VERSION)),
        ("generated_at", generated_at()), ("language", "tab"),
        ("sources", json.dumps(SOURCES, ensure_ascii=False, sort_keys=True)),
    ]
    specs = [
        (WORDS_ARTIFACT, WORDS_SQL, "INSERT INTO words(word, base_score) VALUES(?, ?)",
         sorted((w, r["score"]) for w, r in final.items()), ["tab_words.sqlite", "tab_words.tsv"]),
        (BIGRAMS_ARTIFACT, BIGRAMS_SQL, "INSERT INTO bigrams(prev, word, weight) VALUES(?, ?, ?)",
         sorted((a, b, v) for (a, b), v in pairs.items()), ["tab_bigrams.sqlite", "tab_bigrams.tsv", "tab_words.tsv"]),
    ]
    for artifact_name, create, insert, rows, inputs in specs:
        path = os.path.join(out, artifact_name + ".sqlite")
        tmp = path + ".tmp"
        if os.path.exists(tmp):
            os.remove(tmp)
        con = sqlite3.connect(tmp)
        con.execute("PRAGMA page_size = 4096")
        con.execute(create)
        con.execute(META_SQL)
        con.executemany(insert, rows)
        derived = json.dumps({n: V0_SHA256[n] for n in inputs}, sort_keys=True)
        meta = [("artifact", artifact_name)] + common + [("row_count", str(len(rows))), ("derived_from", derived)]
        con.executemany("INSERT INTO meta(key, value) VALUES(?, ?)", sorted(meta))
        con.commit()
        con.execute("VACUUM")
        con.close()
        os.replace(tmp, path)


FLAG_HEADER = ["priority", "word", "count", "ocr_count", "clean_count", "word_lists", "base_score",
               "categories", "notes"]


def write_reviews(review, words, final, merges, target, flags, summary):
    os.makedirs(review, exist_ok=True)
    with open(os.path.join(review, "corrections.csv"), "w", encoding="utf-8", newline="") as f:
        wr = csv.writer(f, lineterminator="\n")
        wr.writerow(["source", "target", "rule", "action", "source_count", "source_ocr_count", "source_word_lists",
                     "target_count_before", "target_count_after", "note"])
        for src, (rule, direct) in sorted(merges.items(), key=lambda kv: (kv[1][0], kv[0])):
            dst = target[src]
            wr.writerow([src, dst, rule, "merged" if dst in words else "respelled", words[src]["count"],
                         words[src]["ocr"], words[src]["lex"], words[dst]["count"] if dst in words else "",
                         final[dst]["count"],
                         "" if direct == dst else f"via {direct} ({merges[direct][0].split()[0]})"])
    rows = []
    for w, items in flags.items():
        r = final[w]
        prio = "high" if r["count"] >= HIGH_PRIORITY_COUNT else "normal"
        rows.append((prio != "high", -r["count"], w, [prio, w, r["count"], r["ocr"], r["clean"], r["lex"],
                                                       r["score"], "; ".join(c for c, _ in items),
                                                       "; ".join(n for _, n in items)]))
    rows.sort()
    for name, keep in (("flagged.csv", lambda row: True), ("high_priority.csv", lambda row: row[0] == "high")):
        with open(os.path.join(review, name), "w", encoding="utf-8", newline="") as f:
            wr = csv.writer(f, lineterminator="\n")
            wr.writerow(FLAG_HEADER)
            for *_, row in rows:
                if keep(row):
                    wr.writerow(row)
    with open(os.path.join(review, "summary.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=1, sort_keys=False)
        f.write("\n")


# ----------------------------------------------------------------- validation
# Rows cleanup version 1 leaves in place (flagged.csv, "not merged"), pinned
# so that a rule change cannot slip through unnoticed.
KEPT_WITH_DOUBLED_PALOCHKA = 0
KEPT_WITH_TWO_SIGNS = 42
KEPT_WITH_VOWEL_SOFT_SIGN = 7
KEPT_WITH_STRESSED_I = 47     # й between or after consonants (rule D1)


def validate(out):
    results = []

    def check(name, ok, detail=""):
        results.append((name, bool(ok), detail))

    wp, bp = os.path.join(out, WORDS_ARTIFACT + ".sqlite"), os.path.join(out, BIGRAMS_ARTIFACT + ".sqlite")
    wc, bc = ro(wp), ro(bp)
    for con, table, artifact_name, create in ((wc, "words", WORDS_ARTIFACT, WORDS_SQL),
                                              (bc, "bigrams", BIGRAMS_ARTIFACT, BIGRAMS_SQL)):
        meta = dict(con.execute("SELECT key, value FROM meta"))
        n = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        check(f"{artifact_name}: meta.artifact", meta.get("artifact") == artifact_name, meta.get("artifact"))
        check(f"{artifact_name}: meta.row_count == COUNT(*) ({n})", meta.get("row_count") == str(n),
              meta.get("row_count"))
        for k, v in (("schema_version", SCHEMA_VERSION), ("content_version", CONTENT_VERSION),
                     ("normalization_version", NORMALIZATION_VERSION),
                     ("normalization_profile", NORMALIZATION_PROFILE), ("min_reader_schema", MIN_READER_SCHEMA),
                     ("cleanup_version", CLEANUP_VERSION), ("language", "tab")):
            check(f"{artifact_name}: meta.{k} == {v}", meta.get(k) == str(v), meta.get(k))
        for k in ("generated_at", "sources", "derived_from"):
            check(f"{artifact_name}: meta.{k} present", bool(meta.get(k)))
        check(f"{artifact_name}: schema is the General Keyboard artifact shape",
              table_sql(con) == {table: create, "meta": META_SQL})
        check(f"{artifact_name}: page_size 4096", con.execute("PRAGMA page_size").fetchone()[0] == 4096)
        check(f"{artifact_name}: vacuumed", con.execute("PRAGMA freelist_count").fetchone()[0] == 0)
        check(f"{artifact_name}: integrity_check", con.execute("PRAGMA integrity_check").fetchone()[0] == "ok")
    words = dict(wc.execute("SELECT word, base_score FROM words"))
    pairs = list(bc.execute("SELECT prev, word, weight FROM bigrams"))
    bad = [w for w in words if canonical(w) != w]
    check("every word is canonical under dagestanianCyrillicV1", not bad, ", ".join(bad[:5]))
    bad = [w for w in words if not is_valid_token(w)]
    check("every word passes the token contract", not bad, ", ".join(bad[:5]))
    bad = [w for w in words if not ALPHABET_RE.fullmatch(w)]
    check("every word uses only а–я, ё, ӏ (U+04CF) and inner hyphens", not bad, ", ".join(bad[:5]))
    check("no visible palochka U+04C0 in lookup keys", not any("Ӏ" in w for w in words))
    left = sorted(w for w in words if PALOCHKA * 2 in w)
    check(f"a doubled palochka is left only in the {KEPT_WITH_DOUBLED_PALOCHKA} flagged rows",
          len(left) == KEPT_WITH_DOUBLED_PALOCHKA, ", ".join(left))
    left = sorted(w for w in words if SIGN_RUN.search(w))
    check(f"two signs in a row are left only in the {KEPT_WITH_TWO_SIGNS} flagged rows",
          len(left) == KEPT_WITH_TWO_SIGNS, ", ".join(left))
    left = sorted(w for w in words if VOWEL_SOFT.search(w))
    check(f"ь after a vowel other than а, у is left only in the {KEPT_WITH_VOWEL_SOFT_SIGN} flagged rows",
          len(left) == KEPT_WITH_VOWEL_SOFT_SIGN, ", ".join(left))
    left = sorted(w for w in words if STRESSED_I.search(w))
    check(f"й between or after consonants is left only in the {KEPT_WITH_STRESSED_I} flagged rows",
          len(left) == KEPT_WITH_STRESSED_I, ", ".join(left[:8]))
    check("every base_score >= 1", all(s >= 1 for s in words.values()))
    bad = [(a, b) for a, b, _ in pairs if a not in words or b not in words]
    check("both words of every bigram are rows of the words artifact", not bad, str(bad[:3]))
    check("every bigram weight >= 2", all(v >= 2 for _, _, v in pairs))
    wc.close()
    bc.close()
    return results


# ----------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", default=DEFAULT_SOURCE, help="folder with the five v0 tab_* files")
    ap.add_argument("--out", default=DEFAULT_OUT, help="where the two artifacts are written")
    ap.add_argument("--review", default=DEFAULT_REVIEW, help="where the review files are written")
    ap.add_argument("--validate", action="store_true", help="only validate the artifacts in --out")
    args = ap.parse_args()

    def report(results):
        for name, ok, detail in results:
            print(("PASS " if ok else "FAIL ") + name + (f"  [{detail}]" if detail and not ok else ""))
        return 0 if all(ok for _, ok, _ in results) else 1

    if args.validate:
        return report(validate(args.out))
    try:
        guard_existing(args.out)
        words, pairs, v0_meta, stats = load(args.source)
    except Fail as e:
        print(f"error: {e}", file=sys.stderr)
        return 2

    a = audit(words, pairs)
    hard = {k: a[k] for k in ("not_nfc", "not_lowercase", "not_canonical", "canonical_collisions",
                              "contract_invalid", "outside_alphabet", "latin_letters", "visible_palochka_u04c0",
                              "replacement_or_control_chars", "score_formula_mismatch", "count_mismatch")
            if a[k]}
    if hard or a["bigram_orphans"] or a["bigram_weight_below_2"]:
        print("error: the v0 data breaks an assumption of this build:",
              json.dumps(hard, ensure_ascii=False)[:2000], file=sys.stderr)
        return 2

    try:
        merges, blocked = plan_merges(words)
        final, final_pairs, remapped, target = apply_merges(words, pairs, merges)
    except Fail as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    respells = {s for s, t in target.items() if t not in words}
    flags = flag_entries(final, blocked)

    by_cat = Counter(c for items in flags.values() for c, _ in items)
    by_cat_high = Counter(c for w, items in flags.items() if final[w]["count"] >= HIGH_PRIORITY_COUNT
                          for c, _ in items)
    summary = {
        "input": {"archive": "keyboard_data_v0.zip / keyboard_data/", "files": V0_SHA256,
                  "v0_generated_at": v0_meta.get("generated_at"), "v0_sources": stats.get("sources")},
        "audit": a,
        "merges": {"total": len(merges),
                   "merged_into_an_attested_row": len(merges) - len(respells),
                   "respelled": len(respells),
                   "by_rule": dict(sorted(Counter(r for r, _ in merges.values()).items())),
                   "merged_by_rule": dict(sorted(Counter(r for s, (r, _) in merges.items()
                                                         if s not in respells).items())),
                   "respelled_by_rule": dict(sorted(Counter(merges[s][0] for s in respells).items())),
                   "tokens_by_rule": dict(sorted(Counter({rule: sum(words[s]["count"] for s, (r, _) in merges.items()
                                                                    if r == rule)
                                                          for rule in {r for r, _ in merges.values()}}).items())),
                   "targets": len(set(target.values())),
                   "chained": sum(1 for s, (_, d) in merges.items() if target[s] != d),
                   "tokens_moved": sum(words[s]["count"] for s in merges),
                   "not_merged": len(blocked),
                   "not_merged_by_rule": dict(sorted(Counter(r for r, _, _ in blocked.values()).items()))},
        "removed": 0,
        "flags": {"words": len(flags),
                  "high_priority": sum(1 for w in flags if final[w]["count"] >= HIGH_PRIORITY_COUNT),
                  "by_category": dict(sorted(by_cat.items(), key=lambda kv: (-kv[1], kv[0]))),
                  "high_priority_by_category": dict(sorted(by_cat_high.items(), key=lambda kv: (-kv[1], kv[0])))},
        "output": {"words": len(final), "bigrams": len(final_pairs),
                   "bigram_pairs_remapped": remapped, "bigram_pairs_combined": len(pairs) - len(final_pairs),
                   "words_unchanged_from_v0": sum(1 for w, r in final.items() if words.get(w) == r),
                   "corpus_tokens_kept": sum(r["count"] for r in final.values()),
                   "corpus_tokens_v0": sum(r["count"] for r in words.values()),
                   "bigram_weight_total": sum(final_pairs.values()),
                   "bigram_weight_total_v0": sum(pairs.values())},
    }
    write_artifacts(args.out, final, final_pairs)
    write_reviews(args.review, words, final, merges, target, flags, summary)
    results = validate(args.out)
    print(json.dumps({k: summary[k] for k in ("merges", "flags", "output")}, ensure_ascii=False, indent=1)[:5000])
    return report(results)


if __name__ == "__main__":
    sys.exit(main())
