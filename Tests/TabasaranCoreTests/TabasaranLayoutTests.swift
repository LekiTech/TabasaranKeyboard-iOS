//
//  TabasaranLayoutTests.swift
//  TabasaranCoreTests
//
//  TabasaranLayout.swift: the three letter rows, the two departures from
//  the Russian iOS layout (checked against the pinned transcription of
//  that layout, Fixtures/agisight/rus-3-rows.yaml), every long-press
//  mapping, the digraph assignment of the pinned Tabasaran mapping
//  (tab_key_mapping_ext.json), the alphabet, and the evidence the design
//  rests on, measured again from the shipped dictionary.
//

import XCTest
import SQLite3
import UIKit
@testable import TabasaranCore
@testable import GeneralKeyboard

final class TabasaranLayoutTests: TabasaranTestCase {

    private var spec: LayoutStyleSpec { KeyboardDefinition.current.layout.spec(for: .standard) }
    private let palochka = String(Tabasaran.visible)

    private func characters(_ row: [KeyCap]) -> [String] {
        row.compactMap { if case .character(let c) = $0 { return c } else { return nil } }
    }

    private var letterKeys: [String] { spec.letterRows.flatMap(characters) }

    // MARK: - Minimal readers for the pinned files

    private func file(_ name: String) throws -> String {
        try RepoPaths.text(RepoPaths.upstream.appendingPathComponent(name))
    }

    /// Rows of one layer of `iOS: primary:` as key tokens; `\s{…}`
    /// specials (shift, backspace, spacers) are dropped.
    private func russianLayer(_ name: String) throws -> [[String]] {
        let lines = try file("rus-3-rows.yaml").components(separatedBy: "\n")
        guard let primary = lines.firstIndex(of: "  primary:"),
              let start = lines[primary...].firstIndex(where: {
                  $0.trimmingCharacters(in: .whitespaces) == "\(name): |" }) else {
            XCTFail("layer \(name) not found"); return []
        }
        let indent = lines[start].prefix(while: { $0 == " " }).count
        var rows: [[String]] = []
        for line in lines[(start + 1)...] {
            let lineIndent = line.prefix(while: { $0 == " " }).count
            if line.trimmingCharacters(in: .whitespaces).isEmpty || lineIndent <= indent { break }
            rows.append(line.split(separator: " ").map(String.init).filter { !$0.hasPrefix("\\s{") })
        }
        return rows
    }

    // MARK: - Letter rows

    func testLetterRows() {
        XCTAssertEqual(spec.letterRows.map(characters), [
            ["й", "ц", "у", "к", "е", "н", "г", "ш", "ъ", "з", "х"],
            ["ф", "\u{04C0}", "в", "а", "п", "р", "о", "л", "д", "ж", "э"],
            ["я", "ч", "с", "м", "и", "т", "ь", "б", "ю"],
        ])
        XCTAssertEqual(spec.letterRows.count, 3)
        // Shift and backspace frame the third row
        XCTAssertEqual(spec.letterRows[2].first, .shift)
        XCTAssertEqual(spec.letterRows[2].last, .backspace)
        // No letter twice, no row wider than the Russian keyboard's 11 keys
        XCTAssertEqual(Set(letterKeys).count, letterKeys.count)
        XCTAssertEqual(spec.letterRows.map { characters($0).count }, [11, 11, 9])
        // Every key is one Cyrillic character; the palochka is U+04C0
        for key in letterKeys {
            XCTAssertEqual(key.unicodeScalars.count, 1, key)
            XCTAssertTrue(Tabasaran.isTabasaranText(key), key)
        }
        XCTAssertEqual(letterKeys.filter { $0 == palochka }.count, 1)
        XCTAssertEqual(Array(palochka.unicodeScalars).map(\.value), [0x04C0])
        XCTAssertFalse(letterKeys.contains("\u{04CF}"))
        XCTAssertFalse(letterKeys.contains("I"))
        XCTAssertFalse(letterKeys.contains("l"))
    }

    /// The layout is the Russian iOS layout with exactly two keys changed:
    /// «ъ» where the Russian keyboard has «щ», «Ӏ» where it has «ы».
    func testOnlyTwoKeysDifferFromTheRussianLayout() throws {
        let russian = try russianLayer("default")
        XCTAssertEqual(russian.map(\.count), [11, 11, 9])
        let tabasaran = spec.letterRows.map(characters)
        var differences: [String: String] = [:]
        for (r, row) in russian.enumerated() {
            for (i, key) in row.enumerated() where tabasaran[r][i] != key {
                differences[key] = tabasaran[r][i]
            }
        }
        XCTAssertEqual(differences, ["щ": "ъ", "ы": palochka])
        // «ъ» sits in the top row two keys right of «г» and two left of «х»
        XCTAssertEqual(tabasaran[0].firstIndex(of: "ъ"), 8)
        XCTAssertEqual(tabasaran[0].firstIndex(of: "г"), 6)
        XCTAssertEqual(tabasaran[0].firstIndex(of: "х"), 10)
        // «Ӏ» sits under «ц», next to «ф»
        XCTAssertEqual(tabasaran[1].firstIndex(of: palochka), 1)
        XCTAssertEqual(tabasaran[0].firstIndex(of: "ц"), 1)
    }

    /// The shift layer the engine derives equals the Russian shift layer
    /// with the same two changes; the palochka has no other case.
    func testShiftLayer() throws {
        let upstream = try russianLayer("shift")
        let shifted = spec.letterRows.map { row in
            characters(row).map { KeyboardLayout.label(for: .character($0), shifted: true, capsLock: false) }
        }
        XCTAssertEqual(shifted, upstream.map { $0.map { $0 == "Щ" ? "Ъ" : $0 == "Ы" ? palochka : $0 } })
        for capsLock in [false, true] {
            XCTAssertEqual(KeyboardLayout.label(for: .character(palochka), shifted: true, capsLock: capsLock), palochka)
        }
    }

    // MARK: - Number and symbol pages

    /// The pages of the Russian iOS keyboard, unchanged. The transcription
    /// writes the typographic “ and ’; the keyboard types the plain " and '
    /// like the sibling keyboards and offers the typographic ones on a
    /// long press.
    func testNumberAndSymbolPagesAreTheRussianOnes() throws {
        func plain(_ rows: [[String]]) -> [[String]] {
            rows.map { $0.map { $0 == "“" ? "\"" : $0 == "’" ? "'" : $0 } }
        }
        XCTAssertEqual(spec.numberRows.map(characters), plain(try russianLayer("symbols-1")))
        XCTAssertEqual(spec.symbolRows.map(characters), plain(try russianLayer("symbols-2")))
        XCTAssertEqual(spec.numberRows[2].first, .symbols)
        XCTAssertEqual(spec.symbolRows[2].first, .numbers)
        XCTAssertEqual(spec.numberRows[2].last, .backspace)
    }

    // MARK: - Long press

    func testLongPressMappings() {
        let letters: [String: [String]] = [
            "а": ["аь"],
            "г": ["гъ", "гь"],
            "к": ["кь", "кӀ", "къ"],
            "п": ["пӀ"],
            "т": ["тӀ"],
            "у": ["уь"],
            "х": ["хь", "хъ"],
            "ц": ["цӀ"],
            "ч": ["чӀ"],
            "е": ["ё"],
            "ш": ["щ"],
            "\u{04C0}": ["ы"],
            "ъ": ["\u{2019}"],
        ]
        for (key, alternates) in letters {
            XCTAssertEqual(spec.callouts[key], alternates, key)
        }
        // No other letter key has a long press
        let letterCalloutKeys = spec.callouts.keys.filter { $0.first!.isLetter }
        XCTAssertEqual(Set(letterCalloutKeys), Set(letters.keys))
        // Every long-press base is a key of the layout, and no option
        // repeats its base key or another option
        let allKeys = Set((spec.letterRows + spec.numberRows + spec.symbolRows).flatMap(characters))
        for (key, alternates) in spec.callouts {
            XCTAssertTrue(allKeys.contains(key), "\(key) is not a key")
            XCTAssertFalse(alternates.contains(key), key)
            XCTAssertEqual(Set(alternates).count, alternates.count, key)
        }
        // No popup is wider than the base key and three options
        XCTAssertLessThanOrEqual(letters.values.map(\.count).max()!, 3)
    }

    /// Each digraph option is exactly two Cyrillic characters that start
    /// with its base key: a sequence, never a single code point, a Latin
    /// lookalike or the lookup palochka.
    func testDigraphOptionsInsertTheIntendedUnicodeSequences() {
        var offered: [String] = []
        for (key, alternates) in TabasaranLayout.digraphCallouts {
            for option in alternates {
                XCTAssertEqual(option.unicodeScalars.count, 2, option)
                XCTAssertEqual(option.count, 2, option)
                XCTAssertTrue(option.hasPrefix(key), option)
                XCTAssertTrue(Tabasaran.isTabasaranText(option), option)
                XCTAssertEqual(option, option.precomposedStringWithCanonicalMapping, option)
                offered.append(option)
            }
        }
        XCTAssertEqual(offered.sorted(), Tabasaran.digraphs.sorted())
        let expected: [String: [UInt32]] = [
            "аь": [0x0430, 0x044C], "гъ": [0x0433, 0x044A], "гь": [0x0433, 0x044C],
            "къ": [0x043A, 0x044A], "кь": [0x043A, 0x044C], "кӀ": [0x043A, 0x04C0],
            "пӀ": [0x043F, 0x04C0], "тӀ": [0x0442, 0x04C0], "уь": [0x0443, 0x044C],
            "хъ": [0x0445, 0x044A], "хь": [0x0445, 0x044C], "цӀ": [0x0446, 0x04C0],
            "чӀ": [0x0447, 0x04C0],
        ]
        XCTAssertEqual(expected.count, 13)
        for option in offered {
            XCTAssertEqual(Array(option.unicodeScalars).map(\.value), expected[option], option)
        }
        XCTAssertEqual(Array(spec.callouts["ъ"]![0].unicodeScalars).map(\.value), [0x2019])
    }

    /// The digraphs sit under the same Russian keys as in the Tabasaran
    /// mapping of Agisight/rf-keyboard-corpora. Its «Ь: I» (a Latin I for
    /// the palochka) is not taken: the palochka has its own key here.
    func testDigraphAssignmentMatchesThePinnedTabasaranMapping() throws {
        let data = try Data(contentsOf: RepoPaths.upstream.appendingPathComponent("tab_key_mapping_ext.json"))
        let upstream = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: [String]])
        XCTAssertEqual(upstream.count, 10)
        XCTAssertEqual(upstream["Ь"], ["I"])
        var lowercased: [String: Set<String>] = [:]
        for (key, values) in upstream where key != "Ь" {
            // Upstream writes the palochka of its digraphs as U+04C0 already
            lowercased[key.lowercased()] = Set(values.map {
                KeyboardDefinition.current.text.visibleLowercased($0, canonicalPalochka: Normalization.palochka)
            })
        }
        XCTAssertEqual(TabasaranLayout.digraphCallouts.mapValues(Set.init), lowercased)
    }

    /// The symbol alternates are those of the Russian iOS keyboard.
    func testSymbolLongPressesAreTheRussianOnes() throws {
        var upstream: [String: [String]] = [:]
        for line in try file("rus-longpress.yaml").components(separatedBy: "\n") {
            guard let colon = line.range(of: ": ") else { continue }
            func unquote(_ s: Substring) -> String {
                let t = s.trimmingCharacters(in: .whitespaces)
                if t.count >= 2, let f = t.first, f == t.last, f == "'" || f == "\"" {
                    return String(t.dropFirst().dropLast())
                }
                return t
            }
            upstream[unquote(line[..<colon.lowerBound])] =
                unquote(line[colon.upperBound...]).split(separator: " ").map(String.init)
        }
        XCTAssertEqual(upstream["е"], spec.callouts["е"])
        for key in ["0", "₽", "#", ".", "%", "=", "-", "/", "&", "?", "!"] {
            XCTAssertEqual(spec.callouts[key], upstream[key], key)
        }
        // The quote alternates sit on this layout's ' and " keys; the
        // popup never repeats its base key
        XCTAssertEqual(spec.callouts["'"], upstream["’"]?.filter { $0 != "'" })
        XCTAssertEqual(spec.callouts["\""], upstream["“"]?.filter { $0 != "\"" })
    }

    // MARK: - Alphabet

    /// Every letter of the Tabasaran alphabet (the 2007 primer: the 33
    /// Russian letters, the thirteen digraphs, the palochka and the
    /// apostrophe) can be typed, and so can the doubled and the labialized
    /// consonants, which are plain letter sequences.
    func testWholeAlphabetIsTypeable() {
        let alphabet = ["а", "аь", "б", "в", "г", "гъ", "гь", "д", "е", "ё", "ж", "з", "и", "й", "к",
                        "къ", "кь", "кӀ", "л", "м", "н", "о", "п", "пӀ", "р", "с", "т", "тӀ", "у", "уь",
                        "ф", "х", "хъ", "хь", "ц", "цӀ", "ч", "чӀ", "ш", "щ", "ъ", "ы", "ь", "э", "ю",
                        "я", "\u{04C0}", "\u{2019}"]
        XCTAssertEqual(alphabet.count, 48)
        let keys = Set(letterKeys)
        let longPress = Set(spec.callouts.filter { keys.contains($0.key) }.flatMap(\.value))
        for letter in alphabet {
            let fromKeys = letter.allSatisfy { keys.contains(String($0)) }
            XCTAssertTrue(fromKeys || longPress.contains(letter), "\(letter) cannot be typed")
        }
        // Every digraph both ways: key by key, and as one long press
        for digraph in Tabasaran.digraphs {
            XCTAssertTrue(digraph.allSatisfy { keys.contains(String($0)) }, digraph)
            XCTAssertTrue(longPress.contains(digraph), digraph)
        }
        // Doubled consonants and the labialized consonants of the 2026
        // decision need no long press: both letters are keys
        for sequence in ["кк", "пп", "тт", "цц", "чч", "жв", "шв", "чв", "ччв", "чӀв"] {
            XCTAssertTrue(sequence.allSatisfy { keys.contains(String($0)) }, sequence)
            XCTAssertFalse(longPress.contains(sequence), sequence)
        }
        // The only Russian letters without a key of their own
        let russian = Set("абвгдеёжзийклмнопрстуфхцчшщъыьэюя".map(String.init))
        XCTAssertEqual(russian.subtracting(keys), ["ё", "щ", "ы"])
        XCTAssertTrue(longPress.isSuperset(of: ["ё", "щ", "ы", "\u{2019}"]))
    }

    // MARK: - The evidence, from the shipped dictionary

    /// The layout rests on measured frequencies (docs/LAYOUT.md). The
    /// claims are checked against the shipped dictionary, so a future
    /// dictionary that no longer supports them fails here.
    func testCorpusFrequenciesSupportTheLayout() throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(RepoPaths.wordsArtifact.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "SELECT word, base_score FROM words", -1, &stmt, nil), SQLITE_OK)
        var characters: [Character: Int] = [:]
        var pairs: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            let word = Array(String(cString: sqlite3_column_text(stmt, 0)))
            let count = Int(sqlite3_column_int64(stmt, 1)) / 10
            guard count > 0 else { continue }
            for (i, ch) in word.enumerated() where ch != "-" {
                characters[ch, default: 0] += count
                if i > 0 { pairs[String([word[i - 1], ch]), default: 0] += count }
            }
        }
        sqlite3_finalize(stmt)
        let total = Double(characters.values.reduce(0, +))
        func share(_ ch: Character) -> Double { 100 * Double(characters[ch] ?? 0) / total }
        func pair(_ p: String) -> Int { pairs[p.replacingOccurrences(of: "Ӏ", with: "\u{04CF}")] ?? 0 }

        // «ъ» is a frequent letter and the palochka a regular one; «щ» and
        // «ы», whose keys they take, are the rarest letters of all
        XCTAssertEqual(share("ъ"), 3.46, accuracy: 0.05)
        XCTAssertEqual(share("ь"), 3.34, accuracy: 0.05)
        XCTAssertEqual(share(Tabasaran.lookup), 1.09, accuracy: 0.05)
        XCTAssertLessThan(share("щ"), 0.05)
        XCTAssertLessThan(share("ы"), 0.05)
        XCTAssertGreaterThan(share("ъ"), share("к"))
        XCTAssertGreaterThan(share(Tabasaran.lookup), 20 * share("ы"))
        for ch in "эфцжю" { XCTAssertGreaterThan(share(ch), 3 * share("ы"), String(ch)) }
        // The palochka follows к п т ц ч and (almost) nothing else
        let palochkaTotal = Double(characters[Tabasaran.lookup]!)
        let afterEjectives = ["кӀ", "пӀ", "тӀ", "цӀ", "чӀ"].map(pair).reduce(0, +)
        XCTAssertGreaterThan(Double(afterEjectives) / palochkaTotal, 0.99)
        // Long-press order on the keys with several digraphs
        XCTAssertGreaterThan(pair("гъ"), pair("гь"))
        XCTAssertGreaterThan(pair("кь"), pair("кӀ"))
        XCTAssertGreaterThan(pair("кӀ"), pair("къ"))
        XCTAssertGreaterThan(pair("хь"), pair("хъ"))
        // The letters dropped from the alphabet in the 1970s are gone from use
        XCTAssertLessThan(pair("жъ") + pair("чъ") + pair("чь"), 10)
    }

    /// The independent letter count of Agisight/rf-keyboard-corpora (web
    /// text) orders the digraphs of «г», «к» and «х» the same way.
    func testAgisightLetterCountAgreesOnTheOrder() throws {
        var percent: [String: Double] = [:]
        for line in try file("tab_monocorpus_freq.csv").components(separatedBy: "\n").dropFirst() {
            let fields = line.split(separator: ",")
            guard fields.count == 3, let value = Double(fields[2]) else { continue }
            percent[String(fields[0])] = value
        }
        XCTAssertEqual(percent.count, 47)
        XCTAssertGreaterThan(percent["ГЪ"]!, percent["ГЬ"]!)
        XCTAssertGreaterThan(percent["КЬ"]!, percent["КӀ"]!)
        XCTAssertGreaterThan(percent["КӀ"]!, percent["КЪ"]!)
        XCTAssertGreaterThan(percent["ХЬ"]!, percent["ХЪ"]!)
        XCTAssertLessThan(percent["Ы"]!, 0.2)
        XCTAssertLessThan(percent["Щ"]!, 0.05)
    }
}
