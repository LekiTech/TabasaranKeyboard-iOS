#!/usr/bin/env python3
"""Letter statistics of Tabasaran and a model comparison of layout candidates.

Python 3 standard library only. Reads the shipped words artifact
(TabasaranKeyboardExtension/tabasaran_words.sqlite); the corpus count of a
word is its base_score // 10 (the v0 score is 10 × count + word lists).
Writes docs/layout/analysis.json and prints the same numbers.

    python3 -I scripts/analyze_layout.py [--raw DIR] [--agisight FILE]

  --raw DIR        the raw magazine OCR texts (LingConLab
                   zhenshchina_dagestana_magazine_parallel_corpus,
                   tabas/tesseract_OCRed_texts). The dictionary has no
                   apostrophe (its tokenizer split words there), so the
                   apostrophe is counted in the raw text. Without --raw the
                   numbers already in analysis.json are kept.
  --agisight FILE  tab_monocorpus_freq.csv of Agisight/rf-keyboard-corpora,
                   an independent letter count (default: the pinned copy in
                   Tests/TabasaranCoreTests/Fixtures/agisight).

Everything here is a MODEL of typing, not a measurement of people:

  * a word is typed letter by letter, no suggestion is picked;
  * a letter with its own key costs one tap; a letter without one costs one
    long press on its base key; a long-press option that yields two letters
    («кӀ») counts as one long press;
  * time = taps × t + long presses × (t + delay), with the keyboard's default
    long-press delay of 0.3 s and two tap rates t (0.25 s and 0.18 s);
  * two thumbs: a key belongs to the thumb of its half of the keyboard, and a
    thumb travels in a straight line from the previous key it pressed in the
    same word. Key centres are those of General Keyboard's native grid on a
    402 pt wide iPhone (content width 395 pt, row pitch 54 pt).
"""

import argparse
import csv
import glob
import json
import os
import re
import sqlite3
from collections import Counter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORDS = os.path.join(REPO, "TabasaranKeyboard", "TabasaranKeyboardExtension", "tabasaran_words.sqlite")
OUT = os.path.join(REPO, "docs", "layout", "analysis.json")
AGISIGHT = os.path.join(REPO, "Tests", "TabasaranCoreTests", "Fixtures", "agisight", "tab_monocorpus_freq.csv")

P = "ӏ"   # ӏ U+04CF, the palochka of the dictionary rows (the key shows Ӏ U+04C0)
# The digraph letters of the alphabet (2007 primer) …
DIGRAPHS = ["аь", "гъ", "гь", "къ", "кь", "к" + P, "п" + P, "т" + P, "уь", "хъ", "хь", "ц" + P, "ч" + P]
# … the doubled consonants, the labialized consonants (graphemes since the
# 2026 decision) and the three letters dropped from the alphabet in the 1970s.
GEMINATES = ["кк", "пп", "тт", "цц", "чч"]
LABIALIZED = ["жв", "шв", "чв", "ччв", "ч" + P + "в"]
OBSOLETE = ["жъ", "чъ", "чь"]
VOWELS = "аеёиоуыэюя"
SCREEN = 402.0            # pt, iPhone 18 Pro and the other 6.3" iPhones
SMALL_SCREEN = 375.0      # pt, the narrowest supported iPhones
PAD, INSET, PITCH = 3.5, 3.0, 54.0
LONG_PRESS_DELAY = 0.3    # s, KeyboardSettings.CalloutDelay.normal
TAP_RATES = {"0.25 s per tap": 0.25, "0.18 s per tap": 0.18}

RUSSIAN = ["йцукенгшщзх", "фывапролджэ", "ячсмитьбю"]
PALOCHKA_DIGRAPHS = {d: d[0] for d in DIGRAPHS if d[1] == P}
HARD_DIGRAPHS = {"гъ": "г", "къ": "к", "хъ": "х"}

# name → letter rows, {letter: base key} for letters reached by long press,
#        {two-letter long-press option: base key} used by the model typist,
#        how the apostrophe is entered ("long press" or "number page")
CANDIDATES = {
    "A0": {
        "title": "Russian iOS keyboard, Ӏ and ъ under ь (Agisight basic mapping)",
        "rows": RUSSIAN,
        "long_press": {"ё": "е", "ъ": "ь", P: "ь"},
        "digraph_options": {},
        "apostrophe": "number page",
    },
    "A": {
        "title": "Russian iOS layout, digraphs on long press (Agisight extended mapping)",
        "rows": RUSSIAN,
        "long_press": {"ё": "е", "ъ": "ь", P: "ь"},
        "digraph_options": {**HARD_DIGRAPHS, **PALOCHKA_DIGRAPHS},
        "apostrophe": "number page",
    },
    "B": {
        "title": "ъ on щ's key, Ӏ on ы's key (chosen)",
        "rows": ["йцукенгшъзх", "ф" + P + "вапролджэ", "ячсмитьбю"],
        "long_press": {"ё": "е", "щ": "ш", "ы": P},
        "digraph_options": {},
        "apostrophe": "long press",
    },
    "B2": {
        "title": "Ӏ on щ's key, ъ on ы's key",
        "rows": ["йцукенгш" + P + "зх", "фъвапролджэ", "ячсмитьбю"],
        "long_press": {"ё": "е", "щ": "ш", "ы": "ъ"},
        "digraph_options": {},
        "apostrophe": "long press",
    },
    "C": {
        "title": "Russian layout plus ъ and Ӏ as 12th keys of the two upper rows",
        "rows": ["йцукенгшщзхъ", "фывапролджэ" + P, "ячсмитьбю"],
        "long_press": {"ё": "е"},
        "digraph_options": {},
        "apostrophe": "long press",
    },
}


def load():
    con = sqlite3.connect(f"file:{WORDS}?mode=ro", uri=True)
    rows = [(w, s // 10) for w, s in con.execute("SELECT word, base_score FROM words") if s >= 10]
    meta = dict(con.execute("SELECT key, value FROM meta"))
    con.close()
    return rows, meta


def units(word):
    """The word as alphabet letters: the thirteen digraphs are one letter each."""
    out, i = [], 0
    while i < len(word):
        if word[i:i + 2] in DIGRAPHS:
            out.append(word[i:i + 2])
            i += 2
        else:
            out.append(word[i])
            i += 1
    return out


def pct(n, total):
    return round(100.0 * n / total, 3) if total else 0.0


def show(text):
    """Dictionary form → what the reader sees (Ӏ U+04C0)."""
    return text.replace(P, "Ӏ")


# ----------------------------------------------------------------- statistics
def statistics(rows):
    chars, letters, pairs, lengths = Counter(), Counter(), Counter(), Counter()
    before = {s: Counter() for s in ("ъ", "ь", P)}
    sequences = Counter()
    position = {d: Counter() for d in ("аь", "уь", "э", "ю", "я")}
    tokens = words_with = 0
    special = set("ъь" + P)
    for word, n in rows:
        tokens += n
        lengths[len(word)] += n
        words_with += n if special & set(word) else 0
        for ch in word:
            if ch != "-":
                chars[ch] += n
        for u in units(word):
            if u != "-":
                letters[u] += n
        for a, b in zip(word, word[1:]):
            if a != "-" and b != "-":
                pairs[a + b] += n
        for i, ch in enumerate(word):
            if ch in before:
                before[ch][word[i - 1] if i else "^"] += n
        for seq in GEMINATES + LABIALIZED + OBSOLETE:
            sequences[seq] += n * word.count(seq)
        for d, c in position.items():
            start = word.find(d)
            while start != -1:
                prev = word[start - 1] if start else ""
                c["word-initial" if not prev or prev == "-" else
                  "after a vowel" if prev in VOWELS else "after a consonant or sign"] += n
                start = word.find(d, start + 1)
    total_chars, total_letters = sum(chars.values()), sum(letters.values())
    order = [ch for ch, _ in chars.most_common()]

    def sign(ch):
        return {
            "percent_of_characters": pct(chars[ch], total_chars),
            "rank_among_characters": order.index(ch) + 1,
            "per_100_words": round(100.0 * chars[ch] / tokens, 1),
            "after_percent": {show(k): pct(v, chars[ch]) for k, v in before[ch].most_common(8)},
        }

    return {
        "word_types": len(rows),
        "word_tokens": tokens,
        "characters": total_chars,
        "mean_word_length": round(sum(k * v for k, v in lengths.items()) / tokens, 2),
        "character_percent": {show(ch): pct(n, total_chars) for ch, n in chars.most_common()},
        "alphabet_letter_percent": {show(u): pct(n, total_letters) for u, n in letters.most_common()},
        "digraph_percent_of_letters": {show(d): pct(letters[d], total_letters) for d in
                                       sorted(DIGRAPHS, key=lambda d: -letters[d])},
        "digraphs_together_percent_of_letters": pct(sum(letters[d] for d in DIGRAPHS), total_letters),
        "words_with_ъ_ь_or_palochka_percent": pct(words_with, tokens),
        "hard_sign": sign("ъ"),
        "soft_sign": sign("ь"),
        "palochka": sign(P),
        "doubled_consonants_per_100_words": {s: round(100.0 * sequences[s] / tokens, 2) for s in GEMINATES},
        "labialized_per_100_words": {show(s): round(100.0 * sequences[s] / tokens, 2) for s in LABIALIZED},
        "letters_dropped_in_the_1970s_tokens": {s: sequences[s] for s in OBSOLETE},
        "front_vowel_spelling_tokens": {d: dict(c.most_common()) for d, c in position.items()},
        "rare_letters_percent_of_characters": {ch: pct(chars[ch], total_chars) for ch in "ыщёэфцжю"},
        "rare_letters_per_100_words": {ch: round(100.0 * chars[ch] / tokens, 2) for ch in "ыщёэфцжю"},
        "top_character_pairs_percent": {show(p): pct(n, sum(pairs.values())) for p, n in pairs.most_common(40)},
    }


def agisight(path):
    """The independent letter count of Agisight/rf-keyboard-corpora (web text, FineWeb-2)."""
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8", newline="") as f:
        rows = [(r["letter"].lower().replace("Ӏ".lower(), P), float(r["percent"])) for r in csv.DictReader(f)]
    table = dict(rows)

    def total(sign_char):
        return round(sum(v for k, v in table.items() if sign_char in k), 3)

    return {
        "note": "percent of alphabet letters, digraphs counted as letters; its lone Ӏ row also holds "
                "every I, 1, l and | of the web text",
        "letter_percent": {show(k): v for k, v in rows},
        "every_ъ_percent": total("ъ"),
        "every_ь_percent": total("ь"),
        "palochka_in_digraphs_percent": round(sum(v for k, v in table.items() if P in k and k != P), 3),
        "lone_palochka_row_percent": table.get(P),
        "ы_щ_ё_э_percent": {ch: table.get(ch) for ch in "ыщёэ"},
    }


def apostrophes(raw):
    """Words with an apostrophe between letters in the raw magazine OCR text."""
    cyr = "А-Яа-яЁёӀӏ"
    marks = "’'`‘ʼ"
    token = re.compile(rf"[{cyr}]+(?:[{marks}][{cyr}]+)*(?:-[{cyr}]+)*")
    inner = re.compile(rf"(?<=[{cyr}])[{marks}](?=[{cyr}])")
    total = with_mark = 0
    glyphs, words, before, after = Counter(), Counter(), Counter(), Counter()
    files = sorted(glob.glob(os.path.join(raw, "*.txt")))
    for name in files:
        with open(name, encoding="utf-8", errors="replace") as f:
            text = f.read()
        for m in token.finditer(text):
            w = m.group(0)
            if len(w) < 2:
                continue
            total += 1
            hits = list(inner.finditer(w))
            if hits:
                with_mark += 1
                words[re.sub(f"[{marks}]", "’", w.lower())] += 1
                for h in hits:
                    glyphs[f"U+{ord(h.group(0)):04X}"] += 1
                    before[w[h.start() - 1].lower()] += 1
                    after[w[h.end()].lower()] += 1
    marks_total = sum(glyphs.values())
    return {
        "source": "LingConLab zhenshchina_dagestana_magazine_parallel_corpus, tabas/tesseract_OCRed_texts, "
                  "commit a2ff094a6f64ef5cd7327eeef134d7c9e270174a",
        "files": len(files),
        "word_tokens": total,
        "words_with_an_apostrophe": with_mark,
        "per_100_words": round(100.0 * with_mark / total, 3),
        "glyphs_in_the_ocr_text": dict(glyphs.most_common()),
        "letter_before_percent": {k: pct(v, marks_total) for k, v in before.most_common(8)},
        "letter_after_percent": {k: pct(v, marks_total) for k, v in after.most_common(4)},
        "most_frequent": dict(words.most_common(25)),
    }


# ----------------------------------------------------------------- the typing model
def geometry(rows, screen):
    """Key centres (pt) of the native grid: equal cells in every row; the
    third row has shift and backspace cells around its letters."""
    content = screen - 2 * PAD
    centres = {}
    for r, row in enumerate(rows):
        cells = len(row) + (2 if r == 2 else 0)
        for i, ch in enumerate(row):
            column = i + (1 if r == 2 else 0)
            centres[ch] = (PAD + (column + 0.5) * content / cells, r * PITCH)
    return centres


def key_width(row_length, screen):
    return round((screen - 2 * PAD) / row_length - 2 * INSET, 2)


def keystrokes(word, cand):
    """[(key, is_long_press)] for one word; hyphens are skipped."""
    on_keys = set("".join(cand["rows"]))
    out, i = [], 0
    while i < len(word):
        ch = word[i]
        if ch == "-":
            i += 1
            continue
        pair = word[i:i + 2]
        # A letter without a key that a two-letter option produces together
        # with its base letter: one long press for both.
        if pair in cand["digraph_options"] and pair[1] not in on_keys:
            out.append((cand["digraph_options"][pair], True))
            i += 2
            continue
        if ch in on_keys:
            out.append((ch, False))
        else:
            out.append((cand["long_press"][ch], True))
        i += 1
    return out


def evaluate(rows, cand, apostrophes_per_100):
    centres = geometry(cand["rows"], SCREEN)
    taps = long_presses = tokens = chars = words_with_lp = 0
    travel = same_thumb = transitions = 0.0
    held = Counter()
    for word, n in rows:
        strokes = keystrokes(word, cand)
        lp = sum(1 for _, is_held in strokes if is_held)
        tokens += n
        chars += n * sum(1 for ch in word if ch != "-")
        taps += n * (len(strokes) - lp)
        long_presses += n * lp
        words_with_lp += n if lp else 0
        last = {}
        previous_thumb = None
        for key, is_held in strokes:
            held[key] += n if is_held else 0
            x, y = centres[key]
            thumb = "left" if x < SCREEN / 2 else "right"
            if thumb in last:
                px, py = last[thumb]
                travel += n * ((x - px) ** 2 + (y - py) ** 2) ** 0.5
            if previous_thumb is not None:
                transitions += n
                same_thumb += n if previous_thumb == thumb else 0
            last[thumb] = (x, y)
            previous_thumb = thumb
    letters_lp = 100.0 * long_presses / tokens
    # The apostrophe is not in the dictionary words: one long press where the
    # candidate offers it on a letter key, otherwise «123», the key, and the
    # automatic return to the letters (two taps).
    ap_lp = apostrophes_per_100 if cand["apostrophe"] == "long press" else 0.0
    ap_taps = 0.0 if cand["apostrophe"] == "long press" else 2 * apostrophes_per_100
    widest = max(map(len, cand["rows"][:2]))
    return {
        "title": cand["title"],
        "rows": [show(r) for r in cand["rows"]],
        "keys_per_row": [len(r) for r in cand["rows"]],
        "narrowest_letter_key_pt": {f"{int(SCREEN)} pt screen": key_width(widest, SCREEN),
                                    f"{int(SMALL_SCREEN)} pt screen": key_width(widest, SMALL_SCREEN)},
        "key_presses_per_word": round((taps + long_presses) / tokens, 3),
        "taps_per_word": round(taps / tokens, 3),
        "long_presses_per_100_words": round(letters_lp, 2),
        "long_presses_per_100_words_with_apostrophe": round(letters_lp + ap_lp, 2),
        "apostrophe_entry": cand["apostrophe"],
        "long_presses_per_100_characters": round(100.0 * long_presses / chars, 3),
        "long_presses_by_key_per_100_words": {show(k): round(100.0 * v / tokens, 2)
                                              for k, v in held.most_common() if v},
        "words_needing_a_long_press_percent": pct(words_with_lp, tokens),
        "thumb_travel_pt_per_character": round(travel / chars, 2),
        "same_thumb_transitions_percent": pct(same_thumb, transitions),
        "seconds_per_100_words": {
            name: round(100.0 * (taps * t + long_presses * (t + LONG_PRESS_DELAY)) / tokens
                        + ap_lp * (t + LONG_PRESS_DELAY) + ap_taps * t, 1)
            for name, t in TAP_RATES.items()},
        "letters_moved_from_the_russian_layout": sorted(
            ch for ch in "".join(RUSSIAN)
            if geometry(RUSSIAN, SCREEN)[ch] != centres.get(ch)),
        "letters_without_a_key": sorted(show(k) for k in cand["long_press"]),
    }


def digraph_paths(cand):
    on_keys = set("".join(cand["rows"]))
    centres = geometry(cand["rows"], SCREEN)
    out = {}
    for d in DIGRAPHS:
        if all(ch in on_keys for ch in d):
            (x1, y1), (x2, y2) = centres[d[0]], centres[d[1]]
            thumbs = ["left" if x < SCREEN / 2 else "right" for x in (x1, x2)]
            out[show(d)] = (f"2 taps, {'alternating thumbs' if thumbs[0] != thumbs[1] else 'same thumb'}, "
                            f"{round(((x1 - x2) ** 2 + (y1 - y2) ** 2) ** 0.5)} pt apart")
        elif d in cand["digraph_options"]:
            out[show(d)] = f"long press on {d[0]}"
        else:
            out[show(d)] = f"tap {d[0]}, long press on {cand['long_press'][d[1]]}"
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--raw", help="folder with the raw magazine OCR texts, for the apostrophe count")
    ap.add_argument("--agisight", default=AGISIGHT, help="tab_monocorpus_freq.csv of Agisight/rf-keyboard-corpora")
    args = ap.parse_args()
    rows, meta = load()
    previous = {}
    if os.path.exists(OUT):
        with open(OUT, encoding="utf-8") as f:
            previous = json.load(f)
    apostrophe = apostrophes(args.raw) if args.raw else previous.get("apostrophe")
    per_100 = apostrophe["per_100_words"] if apostrophe else 0.0
    report = {
        "source": {"artifact": "tabasaran_words.sqlite", "content_version": meta.get("content_version"),
                   "cleanup_version": meta.get("cleanup_version"),
                   "note": "token-weighted; corpus count of a word = base_score // 10; "
                           "words known only from a word list (count 0) are left out. The magazine OCR "
                           "drops many palochkas, so the palochka is undercounted here"},
        "statistics": statistics(rows),
        "agisight_letter_count": agisight(args.agisight),
        "apostrophe": apostrophe,
        "model": {"screen_pt": SCREEN, "long_press_delay_s": LONG_PRESS_DELAY, "tap_rates_s": TAP_RATES,
                  "note": "model-based estimates, not measured typing speed"},
        "candidates": {},
    }
    for name, cand in CANDIDATES.items():
        result = evaluate(rows, cand, per_100)
        result["digraph_entry"] = digraph_paths(cand)
        report["candidates"][name] = result
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(json.dumps(report, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
