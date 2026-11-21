//
//  DictionaryTests.swift
//  TabasaranCoreTests
//
//  The SHIPPED artifacts (TabasaranKeyboardExtension/tabasaran_words.sqlite
//  and tabasaran_bigrams.sqlite, built by scripts/build_dictionary.py)
//  through the engine's readers: metadata, counts, the canonical form of
//  every lookup key, prefix suggestions ranked by frequency, next words
//  from real bigrams, and the cleanup rules. The figures are those of
//  cleanup version 1 (docs/DICTIONARY.md).
//

import XCTest
import SQLite3
@testable import TabasaranCore
@testable import GeneralKeyboard

final class DictionaryTests: TabasaranTestCase {

    private var words: WordSuggestions!
    private var bigrams: StaticBigrams!

    override func setUpWithError() throws {
        try super.setUpWithError()
        words = try XCTUnwrap(WordSuggestions(databaseURL: RepoPaths.wordsArtifact))
        bigrams = try XCTUnwrap(StaticBigrams(databaseURL: RepoPaths.bigramsArtifact))
    }

    private func meta(_ url: URL) throws -> [String: String] {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT key, value FROM meta", -1, &stmt, nil), SQLITE_OK)
        defer { sqlite3_finalize(stmt) }
        var values: [String: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            values[String(cString: sqlite3_column_text(stmt, 0))] = String(cString: sqlite3_column_text(stmt, 1))
        }
        return values
    }

    func testArtifactMetadata() throws {
        let w = try XCTUnwrap(words.metadata)
        XCTAssertEqual(w.artifact, "tabasaran_words")
        XCTAssertEqual(w.schemaVersion, 1)
        XCTAssertEqual(w.contentVersion, 1)
        XCTAssertEqual(w.normalizationVersion, Normalization.version)
        XCTAssertEqual(w.minReaderSchema, 1)
        XCTAssertEqual(w.rowCount, 28698)
        let b = try XCTUnwrap(bigrams.metadata)
        XCTAssertEqual(b.artifact, "tabasaran_bigrams")
        XCTAssertEqual(b.rowCount, 38479)
        XCTAssertEqual(b.normalizationVersion, Normalization.version)
        XCTAssertFalse(bigrams.isEmpty)
        // Both artifacts name the profile they are canonical under
        for url in [RepoPaths.wordsArtifact, RepoPaths.bigramsArtifact] {
            let values = try meta(url)
            XCTAssertEqual(values["normalization_profile"], KeyboardDefinition.current.normalization.id)
            XCTAssertEqual(values["language"], "tab")
            XCTAssertEqual(values["cleanup_version"], "1")
        }
    }

    /// Every stored key is already canonical (lowercase, NFC, palochka
    /// U+04CF), valid under the token contract and written with Tabasaran
    /// letters only, and every bigram word is a row of the words artifact,
    /// so a lookup never misses by representation.
    func testEveryRowIsCanonicalAndValid() throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(RepoPaths.wordsArtifact.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT word, base_score FROM words", -1, &stmt, nil), SQLITE_OK)
        var all = Set<String>()
        var minScore = Int.max
        var withPalochka = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            let word = String(cString: sqlite3_column_text(stmt, 0))
            minScore = min(minScore, Int(sqlite3_column_int64(stmt, 1)))
            XCTAssertTrue(Normalization.isCanonical(word), word)
            XCTAssertTrue(Normalization.isValidToken(word), word)
            XCTAssertFalse(word.contains(Tabasaran.visible), "\(word) stores the visible palochka U+04C0")
            XCTAssertFalse(word.contains("\u{2019}") || word.contains("'"), word)
            XCTAssertFalse(word.contains("\u{04CF}\u{04CF}"), "\(word) has a doubled palochka")
            let letters = word.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "\u{04CF}", with: "")
            XCTAssertTrue(Tabasaran.isTabasaranText(letters), word)
            withPalochka += word.contains(Tabasaran.lookup) ? 1 : 0
            all.insert(word)
        }
        sqlite3_finalize(stmt)
        XCTAssertEqual(all.count, 28698)
        XCTAssertEqual(withPalochka, 2112)
        XCTAssertGreaterThanOrEqual(minScore, 1)

        var bdb: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(RepoPaths.bigramsArtifact.path, &bdb, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(bdb) }
        XCTAssertEqual(sqlite3_prepare_v2(bdb, "SELECT prev, word, weight FROM bigrams", -1, &stmt, nil), SQLITE_OK)
        var pairs = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            let prev = String(cString: sqlite3_column_text(stmt, 0))
            let word = String(cString: sqlite3_column_text(stmt, 1))
            XCTAssertTrue(all.contains(prev), prev)
            XCTAssertTrue(all.contains(word), word)
            XCTAssertGreaterThanOrEqual(sqlite3_column_int64(stmt, 2), 2)
            pairs += 1
        }
        sqlite3_finalize(stmt)
        XCTAssertEqual(pairs, 38479)
    }

    /// Frequency ranks the prefix candidates, for prefixes that end inside
    /// or right after a digraph.
    func testPrefixSuggestionsAreRankedByFrequency() {
        XCTAssertEqual(words.suggestions(for: "таб"), ["табасаран", "табиаьтдин", "табиаьт"])
        XCTAssertEqual(words.suggestions(for: "гъ"), ["гъахьну", "гъабхьну", "гъавриъ"])
        XCTAssertEqual(words.suggestions(for: "гь"), ["гьаци", "гьадму", "гьарган"])
        XCTAssertEqual(words.suggestions(for: "кӏ"), ["кӏуру", "кӏури", "кӏваин"])
        XCTAssertEqual(words.suggestions(for: "цӏ"), ["цӏийи", "цӏиб", "цӏа"])
        XCTAssertEqual(words.suggestions(for: "чӏ"), ["чӏал", "чӏалниинди", "чӏалнан"])
        XCTAssertEqual(words.suggestions(for: "аь"), ["аьхю", "аьгью", "аьхир"])
        XCTAssertEqual(words.suggestions(for: "уь"), ["уьмур", "уьмриъ", "уьмрин"])
        XCTAssertEqual(words.suggestions(for: "хъ"), ["хъа", "хъасин", "хъайи"])
        XCTAssertEqual(words.suggestions(for: "кь"), ["кьяляхъ", "кьабул", "кьюб"])
        XCTAssertEqual(words.suggestions(for: "ккун"), ["ккунду", "ккун", "ккуни"])
        XCTAssertEqual(words.suggestions(for: "жв"), ["жвуван", "жвув", "жвуву"])
        XCTAssertEqual(words.suggestions(for: "э"), ["эгер", "эсерар", "эвленмиш"])
        XCTAssertEqual(words.suggestions(for: "ъъъ"), [])
    }

    /// A prefix typed with the keyboard's Ӏ (U+04C0), in capitals, with the
    /// Latin I that other keyboards produce or in decomposed Unicode
    /// reaches the same rows.
    func testPrefixLookupNormalizesThePalochka() {
        let canonical = words.suggestions(for: "чӏал")
        XCTAssertEqual(canonical, ["чӏал", "чӏалниинди", "чӏалнан"])
        XCTAssertEqual(words.suggestions(for: "чӀал"), canonical)       // U+04C0
        XCTAssertEqual(words.suggestions(for: "ЧӀАЛ"), canonical)
        XCTAssertEqual(words.suggestions(for: "чIал"), canonical)       // Latin I
        XCTAssertEqual(words.suggestions(for: "чlaл"), canonical)       // Latin l and a
        XCTAssertTrue(words.contains("АпӀуз"))
        XCTAssertTrue(words.contains("БИЦӀИДАР"))
        XCTAssertTrue(words.contains("гъахьну"))
        XCTAssertEqual(words.suggestions(for: "и\u{0306}ишв"), words.suggestions(for: "йишв"))
    }

    /// The cleanup merged the digitization artifacts into the words they
    /// stand for (docs/DICTIONARY.md, rules M1–M6 and D1).
    func testCleanupRulesAreApplied() {
        // M1: a doubled palochka
        XCTAssertFalse(words.contains("кӏӏуру"));        XCTAssertTrue(words.contains("кӏуру"))
        // M2: «й» or «г» read for the palochka
        XCTAssertFalse(words.contains("варитйан"));      XCTAssertTrue(words.contains("варитӏан"))
        XCTAssertFalse(words.contains("гучг"));          XCTAssertTrue(words.contains("гучӏ"))
        // M3: «щ» read for «цӏ»
        XCTAssertFalse(words.contains("бищидар"));       XCTAssertTrue(words.contains("бицӏидар"))
        XCTAssertFalse(words.contains("щийи"));          XCTAssertTrue(words.contains("цӏийи"))
        // M5: «ь» for «ъ» after и
        XCTAssertFalse(words.contains("мектебдиь"));     XCTAssertTrue(words.contains("мектебдиъ"))
        // M6: «аш» read for «апӏ» in the forms of апӏуб "to do"
        for (misread, word) in [("ашуз", "апӏуз"), ("ашури", "апӏури"), ("гъашну", "гъапӏну"),
                                ("дашну", "дапӏну"), ("ашин", "апӏин")] {
            XCTAssertFalse(words.contains(misread), misread)
            XCTAssertTrue(words.contains(word), word)
        }
        XCTAssertEqual(words.suggestions(for: "ап"), ["апӏуз", "апӏуб", "апӏури"])
        // D1: «й» for a stressed «и» of the digitized dictionary, merged
        // into the attested word or respelled
        XCTAssertFalse(words.contains("ляхйн"));         XCTAssertTrue(words.contains("ляхин"))
        XCTAssertFalse(words.contains("гъурмйш"));       XCTAssertTrue(words.contains("гъурмиш"))
        XCTAssertFalse(words.contains("халачййр"));      XCTAssertTrue(words.contains("халачйир"))
    }

    /// What the rules deliberately leave alone.
    func testNothingElseWasRespelledOrRemoved() {
        // Real words with ш, щ and «чй» are untouched
        XCTAssertTrue(words.contains("ашкар"))
        XCTAssertTrue(words.contains("ишри"))            // a form of хьуб, not of ипӏуб
        XCTAssertTrue(words.contains("училище"))         // Russian loan with щ
        XCTAssertTrue(words.contains("халачйир"))        // plural -йир after ч
        // Two attested readings: not merged, flagged for review
        XCTAssertTrue(words.contains("хьъа"))
        XCTAssertTrue(words.contains("хъа"))
        XCTAssertTrue(words.contains("хьа"))
        // «йй»: either one could be the stressed и, nothing attested
        XCTAssertTrue(words.contains("арфанййр"))
        XCTAssertFalse(words.contains("арфанйир"))
        // A lost palochka is a question, never a repair
        XCTAssertTrue(words.contains("кваин"))
        XCTAssertTrue(words.contains("кӏваин"))
    }

    func testNextWordsComeFromRealBigrams() {
        XCTAssertEqual(bigrams.nextWords(after: "табасаран"), ["райондин", "чӏалнан", "чӏал"])
        XCTAssertEqual(bigrams.nextWords(after: "хъа"), ["гьацира", "узу", "думу"])
        XCTAssertEqual(bigrams.nextWords(after: "яшамиш"), ["шулайи", "хьуз", "шула"])
        XCTAssertEqual(bigrams.nextWords(after: "саб"), ["вахтнара", "ражну", "вахтна"])
        XCTAssertEqual(bigrams.nextWords(after: "ляхин"), ["ву", "дар", "апӏуз"])
        XCTAssertEqual(bigrams.nextWords(after: "ВаритӀан"), ["аьхю", "асасуб", "заан"])
        XCTAssertEqual(bigrams.nextWords(after: "ъъъ"), [])
        // Static context reorders dictionary candidates among themselves
        let weights = bigrams.weights(after: "табасаран", candidates: ["чӏал", "райондин", "ъъъ"])
        XCTAssertEqual(weights, ["райондин": 57, "чӏал": 16])
    }

    /// The dictionary's builder cut words at the apostrophe, and the
    /// keyboard treats the apostrophe the same way: after «дюн’» the bar
    /// offers the second halves the corpus has.
    func testHalvesOfApostropheWordsPredictEachOther() {
        XCTAssertTrue(words.contains("дюн"))
        XCTAssertEqual(words.suggestions(for: "яй"), ["яйин", "яйиъ", "яйиз"])
        XCTAssertEqual(bigrams.nextWords(after: "дюн"), ["яйин", "яйиъ", "яйиз"])
        XCTAssertEqual(bigrams.nextWords(after: "яратмиш").first, "валин")
        for word in ["дюн’я", "дюн'яйин"] { XCTAssertFalse(words.contains(word), word) }
    }

    func testRandomIdleWordsComeFromTheDictionary() {
        let idle = words.randomWords(3)
        XCTAssertEqual(idle.count, 3)
        for word in idle { XCTAssertTrue(words.contains(word), word) }
    }
}
