//
//  TypingAndLearningTests.swift
//  TabasaranCoreTests
//
//  The keyboard model built exactly as the extension builds it (its own
//  UserDefaults, its own learned store), fed through a mock host: the keys
//  and the long-press options insert Tabasaran letters and digraphs with
//  the palochka Ӏ U+04C0 in lowercase, title case and uppercase, typed and
//  picked words are learned under the lookup form and come back in the
//  visible one, the apostrophe ends a word, settings persist. The bundled
//  artifacts are not in the test bundle, so the model's dictionary tier is
//  empty here; the dictionary itself is covered by DictionaryTests. Every
//  word is a real word of the Tabasaran dictionary.
//

import XCTest
import UIKit
@testable import TabasaranCore
@testable import GeneralKeyboard

final class TypingAndLearningTests: TabasaranTestCase {

    private static let persistedKeys = [
        "layoutStyle", "recentEmojis",
        "set_wordSuggestions", "set_nextWordSuggestions", "set_autoSpaceAfterSuggestion",
        "set_doubleSpacePeriod", "set_spaceCursor", "set_spaceLabel",
        "set_learnSpeed", "set_calloutDelay", "set_theme",
    ]

    override func setUp() {
        super.setUp()
        for key in Self.persistedKeys { UserDefaults.standard.removeObject(forKey: key) }
        // Empty the learned store IN PLACE; never delete learned.sqlite
        // while a model may still hold it open.
        LearnedWords()?.reset()
        // These tests follow a word from its first use, so they run with
        // Fast selected, the way a user picks it in the settings panel.
        // The default (Normal, three uses) has its own tests under
        // "Learning speed", which start without a stored choice.
        UserDefaults.standard.set("fast", forKey: "set_learnSpeed")
    }

    @MainActor
    private func type(_ text: String, into model: KeyboardModel, proxy: MockTextDocumentProxy) {
        for ch in text {
            model.handleKey(ch == " " ? .space : .character(String(ch)), proxy: proxy)
            model.updateSuggestions(proxy: proxy)
        }
    }

    /// What the keyboard does when a suggestion is tapped: the typed
    /// prefix is replaced by the word and a space, and the model is told.
    @MainActor
    private func pick(_ word: String, in model: KeyboardModel, proxy: MockTextDocumentProxy) {
        let previous = model.previousWord(proxy: proxy)
        for _ in 0..<model.wordPrefix(proxy: proxy).count { proxy.deleteBackward() }
        proxy.insertText(word + " ")
        model.recordPickedSuggestion(word, previous: previous, insertedSpace: true)
        model.updateSuggestions(proxy: proxy)
    }

    private func scalars(_ text: String) -> [UInt32] { text.unicodeScalars.map(\.value) }

    // MARK: - Rows

    @MainActor
    func testKeyboardShowsThreeLetterRowsAndTheBottomRow() {
        let model = KeyboardModel()
        let rows = model.rows(needsGlobe: true)
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows[0].count, 11)
        XCTAssertEqual(rows[1].count, 11)
        XCTAssertEqual(rows[2].count, 11)   // shift, nine letters, backspace
        XCTAssertEqual(rows[0][8], .character("ъ"))
        XCTAssertEqual(rows[1][1], .character("\u{04C0}"))
        XCTAssertEqual(rows[3], [.numbers, .settings, .emoji, .globe, .space, .return])
        XCTAssertEqual(model.rows(needsGlobe: false)[3], [.numbers, .settings, .emoji, .space, .return])
        XCTAssertEqual(model.layoutStyle, .standard)
    }

    // MARK: - Keys and digraphs

    @MainActor
    func testEveryLetterKeyInsertsItsLetter() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        let letters = "йцукенгшъзхф\u{04C0}вапролджэячсмитьбю"
        for ch in letters { model.handleKey(.character(String(ch)), proxy: proxy) }
        XCTAssertEqual(proxy.before, letters)
        XCTAssertEqual(proxy.before.unicodeScalars.count, 31)
        XCTAssertTrue(Tabasaran.isTabasaranText(proxy.before))
    }

    /// The palochka key inserts U+04C0 whatever the shift state: the letter
    /// is caseless, and the lookup form U+04CF never reaches the text.
    @MainActor
    func testPalochkaKeyInsertsU04C0() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        model.handleKey(.character("\u{04C0}"), proxy: proxy)
        XCTAssertEqual(scalars(proxy.before), [0x04C0])
        model.shiftState = .once
        model.handleKey(.character("\u{04C0}"), proxy: proxy)
        model.shiftState = .capsLock
        model.handleKey(.character("\u{04C0}"), proxy: proxy)
        XCTAssertEqual(scalars(proxy.before), [0x04C0, 0x04C0, 0x04C0])
        XCTAssertFalse(proxy.before.contains("\u{04CF}"))
        XCTAssertFalse(proxy.before.contains("I"))
        // Even a key that carried the lookup form would insert the visible one
        model.shiftState = .off
        model.handleKey(.character("\u{04CF}"), proxy: proxy)
        XCTAssertEqual(scalars(proxy.before).last, 0x04C0)
        model.shiftState = .off
    }

    /// The thirteen digraphs typed key by key.
    @MainActor
    func testDigraphsTypedKeyByKey() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        let text = Tabasaran.digraphs.joined(separator: " ")
        type(text, into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, text)
        XCTAssertEqual(scalars("кӀ"), [0x043A, 0x04C0])
        XCTAssertTrue(Tabasaran.isTabasaranText(proxy.before.replacingOccurrences(of: " ", with: "")))
    }

    /// A long-press option inserts the complete digraph; the result is the
    /// same string as typing its two keys.
    @MainActor
    func testLongPressOptionsInsertWholeDigraphs() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        let spec = KeyboardDefinition.current.layout.spec(for: .standard)
        var options: [String] = []
        for key in ["а", "г", "к", "п", "т", "у", "х", "ц", "ч", "е", "ш", "\u{04C0}"] {
            options += spec.callouts[key]!
        }
        XCTAssertEqual(options, ["аь", "гъ", "гь", "кь", "кӀ", "къ", "пӀ", "тӀ", "уь", "хь", "хъ", "цӀ", "чӀ",
                                 "ё", "щ", "ы"])
        for option in options { model.handleKey(.character(option), proxy: proxy) }
        XCTAssertEqual(proxy.before, "аьгъгькькӀкъпӀтӀуьхьхъцӀчӀёщы")
        XCTAssertEqual(proxy.before.unicodeScalars.count, 29)
        XCTAssertTrue(Tabasaran.isTabasaranText(proxy.before))
        XCTAssertFalse(proxy.before.contains("\u{04CF}"))

        let typed = MockTextDocumentProxy()
        for ch in "аьгъгькькӀкъпӀтӀуьхьхъцӀчӀ" { model.handleKey(.character(String(ch)), proxy: typed) }
        XCTAssertTrue(proxy.before.hasPrefix(typed.before))
        XCTAssertEqual(Array(typed.before.unicodeScalars), Array(proxy.before.unicodeScalars.prefix(26)))
    }

    /// Shift capitalizes the first letter of a digraph («КӀ», «Гъ», «Аь»),
    /// Caps Lock all of it («КӀ», «ГЪ», «АЬ»), for long-press options and
    /// plain keys alike. The palochka keeps its one form.
    @MainActor
    func testShiftAndCapsLockOnDigraphs() {
        let model = KeyboardModel()
        let titleCase = ["аь": "Аь", "гъ": "Гъ", "гь": "Гь", "къ": "Къ", "кь": "Кь", "кӀ": "КӀ", "пӀ": "ПӀ",
                         "тӀ": "ТӀ", "уь": "Уь", "хъ": "Хъ", "хь": "Хь", "цӀ": "ЦӀ", "чӀ": "ЧӀ",
                         "ё": "Ё", "щ": "Щ", "ы": "Ы"]
        let upperCase = ["аь": "АЬ", "гъ": "ГЪ", "гь": "ГЬ", "къ": "КЪ", "кь": "КЬ", "кӀ": "КӀ", "пӀ": "ПӀ",
                         "тӀ": "ТӀ", "уь": "УЬ", "хъ": "ХЪ", "хь": "ХЬ", "цӀ": "ЦӀ", "чӀ": "ЧӀ",
                         "ё": "Ё", "щ": "Щ", "ы": "Ы"]
        XCTAssertEqual(titleCase.count, 16)
        for (option, expected) in titleCase {
            let proxy = MockTextDocumentProxy()
            model.shiftState = .once
            model.handleKey(.character(option), proxy: proxy)
            XCTAssertEqual(proxy.before, expected)
            XCTAssertEqual(model.shiftState, .off)
            XCTAssertFalse(proxy.before.contains("\u{04CF}"), expected)
            // The key label previews exactly what a tap inserts
            XCTAssertEqual(KeyboardLayout.label(for: .character(option), shifted: true, capsLock: false), expected)
        }
        for (option, expected) in upperCase {
            let proxy = MockTextDocumentProxy()
            model.shiftState = .capsLock
            model.handleKey(.character(option), proxy: proxy)
            XCTAssertEqual(proxy.before, expected)
            XCTAssertEqual(model.shiftState, .capsLock)
            XCTAssertFalse(proxy.before.contains("\u{04CF}"), expected)
            XCTAssertEqual(KeyboardLayout.label(for: .character(option), shifted: true, capsLock: true), expected)
        }
        // Key by key: Shift, ч, Ӏ, а, л → «ЧӀал»; Caps Lock → «ЧӀАЛ»
        let proxy = MockTextDocumentProxy()
        model.shiftState = .once
        type("чӀал", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "ЧӀал")
        proxy.before = ""
        model.shiftState = .capsLock
        type("чӀал", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "ЧӀАЛ")
        XCTAssertEqual(scalars(proxy.before), [0x0427, 0x04C0, 0x0410, 0x041B])
        model.shiftState = .off
    }

    @MainActor
    func testSentenceStartShiftsAndSpaceBehaviour() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        XCTAssertEqual(model.shiftState, .once)   // new field: auto-capitalized
        type("кӀул", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "КӀул")
        model.handleKey(.space, proxy: proxy)
        XCTAssertEqual(proxy.before, "КӀул ")
        XCTAssertEqual(model.composedWord, "")
        // A long-press digraph at the start of a sentence is title case
        let fresh = MockTextDocumentProxy()
        let again = KeyboardModel()
        again.handleKey(.character("гъ"), proxy: fresh)
        type("ахьну", into: again, proxy: fresh)
        XCTAssertEqual(fresh.before, "Гъахьну")
    }

    // MARK: - The apostrophe

    /// «дюн’яйин»: the apostrophe (long press on ъ) ends the word being
    /// typed, so the halves are words of their own, as in the bundled
    /// dictionary, and the second half is completed from its own prefix.
    @MainActor
    func testApostropheEndsTheWordAndPairsItsHalves() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("дюн", into: model, proxy: proxy)
        XCTAssertEqual(model.composedWord, "дюн")
        model.handleKey(.character(Tabasaran.apostrophe), proxy: proxy)
        model.updateSuggestions(proxy: proxy)
        XCTAssertEqual(proxy.before, "дюн\u{2019}")
        XCTAssertEqual(model.composedWord, "")
        XCTAssertEqual(model.wordPrefix(proxy: proxy), "")
        XCTAssertEqual(model.previousWord(proxy: proxy), "дюн")
        // The letters after it are a new prefix
        type("яй", into: model, proxy: proxy)
        XCTAssertEqual(model.composedWord, "яй")
        XCTAssertEqual(model.wordPrefix(proxy: proxy), "яй")
        XCTAssertEqual(model.previousWord(proxy: proxy), "дюн")
        type("ин ", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "дюн\u{2019}яйин ")
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertTrue(store.isRecognized("яйин"))
        XCTAssertFalse(store.isRecognized("дюн\u{2019}яйин"))
        // The second half is learned as the follower of the first. Once the
        // pair has been typed twice, it leads the suggestions for its
        // prefix after «дюн’» …
        type("дюн", into: model, proxy: proxy)
        model.handleKey(.character(Tabasaran.apostrophe), proxy: proxy)
        type("яйин ", into: model, proxy: proxy)
        type("дюн", into: model, proxy: proxy)
        model.handleKey(.character(Tabasaran.apostrophe), proxy: proxy)
        type("я", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions, ["я", "яйин"])
        // … and after a host resync (a cursor move, the field reopened) it is
        // predicted right after the apostrophe. Without a resync the bar
        // keeps the context of the last space-terminated word: the engine
        // moves that context on a space, not on other separators
        // (docs/DICTIONARY.md, "The apostrophe").
        proxy.deleteBackward()
        model.syncComposedWord(proxy: proxy)
        model.updateSuggestions(proxy: proxy)
        XCTAssertEqual(model.suggestions.first, "яйин")
        // The ASCII apostrophe of the number page behaves the same
        XCTAssertEqual(model.wordPrefix(proxy: MockTextDocumentProxy(before: "яратмиш'вал")), "вал")
        XCTAssertEqual(model.previousWord(proxy: MockTextDocumentProxy(before: "яратмиш'вал")), "яратмиш")
    }

    // MARK: - Learning

    /// Typed with the keyboard's Ӏ, stored under the lookup form, shown
    /// again with Ӏ.
    @MainActor
    func testTypedWordIsLearnedCanonicallyAndSuggestedVisibly() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("чӀалнан ", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "чӀалнан ")
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertTrue(store.isRecognized("ч\u{04CF}алнан"))
        XCTAssertTrue(store.isRecognized("чӀалнан"))
        XCTAssertTrue(store.isRecognized("ЧӀАЛНАН"))
        XCTAssertTrue(store.isRecognized("чIалнан"))          // Latin I from another keyboard
        XCTAssertEqual(store.topWords(limit: 5), ["ч\u{04CF}алнан"])
        // Suggested back with the visible palochka while typing its prefix.
        // The bar leads with the typed prefix as a quoted literal (it is not
        // a word of its own), the learned word follows.
        type("чӀа", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions, ["чӀа", "чӀалнан"])
        XCTAssertFalse(model.suggestions.joined().contains("\u{04CF}"))
        XCTAssertTrue(model.isLearnedSuggestion("чӀалнан"))
        XCTAssertEqual(model.savedWords(), ["чӀалнан"])
    }

    /// A capitalized prefix capitalizes the suggestion's first letter only:
    /// «КӀ…» is a title-case digraph, not an all-caps prefix.
    @MainActor
    func testSuggestionFollowsTheCaseOfADigraphPrefix() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("кӀваин гъахьну ", into: model, proxy: proxy)
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .once
        type("кӀ", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "КӀ")
        XCTAssertTrue(model.suggestions.contains("КӀваин"), "\(model.suggestions)")
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .once
        type("гъа", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "Гъа")
        XCTAssertTrue(model.suggestions.contains("Гъахьну"), "\(model.suggestions)")
        proxy.before = ""
        model.syncComposedWord(proxy: proxy)
        model.shiftState = .capsLock
        type("кӀв", into: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "КӀВ")
        XCTAssertTrue(model.suggestions.contains("КӀВАИН"), "\(model.suggestions)")
        model.shiftState = .off
    }

    /// Tapping a suggestion replaces the prefix with the whole word, with
    /// its digraphs intact, and adds the space.
    @MainActor
    func testAcceptedSuggestionInsertsTheWholeWord() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("бицӀидар ", into: model, proxy: proxy)
        type("биц", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions, ["биц", "бицӀидар"])
        pick("бицӀидар", in: model, proxy: proxy)
        XCTAssertEqual(proxy.before, "бицӀидар бицӀидар ")
        XCTAssertEqual(scalars(String(proxy.before.suffix(9))),
                       [0x0431, 0x0438, 0x0446, 0x04C0, 0x0438, 0x0434, 0x0430, 0x0440, 0x0020])
        XCTAssertEqual(model.composedWord, "")
        // The pick itself counts as a stronger use than typing
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertTrue(store.isRecognized("бицӀидар"))
        // Sentence punctuation right after a picked word swallows the
        // automatic space
        model.handleKey(.character("."), proxy: proxy)
        XCTAssertEqual(proxy.before, "бицӀидар бицӀидар.")
    }

    @MainActor
    func testLearnedWordsSurviveANewModel() {
        do {
            let model = KeyboardModel()
            let proxy = MockTextDocumentProxy()
            model.shiftState = .off
            type("уьмриъ апӀуз ", into: model, proxy: proxy)
        }
        // A new keyboard controller (new model, same container)
        let again = KeyboardModel()
        let proxy = MockTextDocumentProxy(before: "уьмриъ ")
        again.shiftState = .off
        again.syncComposedWord(proxy: proxy)
        XCTAssertEqual(again.savedWords().sorted(), ["апӀуз", "уьмриъ"])
        type("ап", into: again, proxy: proxy)
        XCTAssertEqual(again.suggestions, ["ап", "апӀуз"])
    }

    @MainActor
    func testPersonalBigramPredictsTheNextWord() {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        // A pair seen twice is confident enough to predict (minPairUses)
        type("табасаран чӀал ", into: model, proxy: proxy)
        type("табасаран чӀал ", into: model, proxy: proxy)
        // After the first word and a space, its learned follower leads the bar
        type("табасаран ", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions.first, "чӀал")
    }

    @MainActor
    func testDeletingALearnedWordRemovesIt() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("варитӀан аьхю ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords().sorted(), ["аьхю", "варитӀан"])
        // The list shows Ӏ; deleting by that visible form reaches the row
        model.deleteLearnedWord("варитӀан", proxy: proxy)
        XCTAssertEqual(model.savedWords(), ["аьхю"])
        XCTAssertFalse(try XCTUnwrap(LearnedWords()).isRecognized("варитӀан"))
        model.resetLearnedWords(proxy: proxy)
        XCTAssertEqual(model.savedWords(), [])
        XCTAssertFalse(try XCTUnwrap(LearnedWords()).isRecognized("аьхю"))
    }

    /// A lone digraph or a lone letter is not a word; the store refuses it.
    @MainActor
    func testSingleLettersAndLoneDigraphsAreNotLearned() throws {
        let model = KeyboardModel()
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("кӀ гъ аь а \u{04C0} ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords(), [])
        let store = try XCTUnwrap(LearnedWords())
        XCTAssertFalse(store.isRecognized("кӀ"))
    }

    // MARK: - Settings

    @MainActor
    func testSettingsPersistAcrossModels() {
        UserDefaults.standard.removeObject(forKey: "set_learnSpeed")   // a fresh install
        let model = KeyboardModel()
        XCTAssertEqual(model.settings.learnSpeed, .normal)
        XCTAssertEqual(model.settings.theme, .system)
        model.updateSettings {
            $0.theme = .dark
            $0.learnSpeed = .conservative
            $0.calloutDelay = .long
            $0.nextWordSuggestions = false
        }
        let again = KeyboardModel()
        XCTAssertEqual(again.settings.theme, .dark)
        XCTAssertEqual(again.settings.learnSpeed, .conservative)
        XCTAssertEqual(again.settings.calloutDelay, .long)
        XCTAssertFalse(again.settings.nextWordSuggestions)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "set_theme"), "dark")
        XCTAssertEqual(model.layoutStyle, .standard)
    }

    // MARK: - Learning speed

    /// A fresh install has no stored learning speed and follows General
    /// Keyboard's default, Normal: a word is suggested after three uses.
    @MainActor
    func testFreshInstallLearnsAWordAfterThreeUses() {
        UserDefaults.standard.removeObject(forKey: "set_learnSpeed")
        let model = KeyboardModel()
        XCTAssertEqual(model.settings.learnSpeed, .normal)
        XCTAssertEqual(model.settings.learnSpeed.minUses, 3)
        let proxy = MockTextDocumentProxy()
        model.shiftState = .off
        type("чӀалнан ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords(), [], "1 of 3 uses")
        type("чӀалнан ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords(), [], "2 of 3 uses")
        type("чӀалнан ", into: model, proxy: proxy)
        XCTAssertEqual(model.savedWords(), ["чӀалнан"])
        type("чӀа", into: model, proxy: proxy)
        XCTAssertEqual(model.suggestions, ["чӀа", "чӀалнан"])
        // Following the default stores nothing
        XCTAssertNil(UserDefaults.standard.object(forKey: "set_learnSpeed"))
    }

    /// A learning speed the user saved is kept: Fast stays Fast and Slow
    /// stays Slow, and words learned earlier are neither deleted nor reset.
    @MainActor
    func testSavedLearningSpeedAndLearnedWordsAreKept() throws {
        for (raw, speed) in [("fast", KeyboardSettings.LearnSpeed.fast), ("conservative", .conservative)] {
            UserDefaults.standard.set(raw, forKey: "set_learnSpeed")
            XCTAssertEqual(KeyboardModel().settings.learnSpeed, speed, raw)
            XCTAssertEqual(UserDefaults.standard.string(forKey: "set_learnSpeed"), raw)
        }
        // A word used once before the default was Normal, no stored choice
        UserDefaults.standard.removeObject(forKey: "set_learnSpeed")
        try XCTUnwrap(LearnedWords()).learn("чӀалнан", previous: nil, picked: false)
        let model = KeyboardModel()
        XCTAssertEqual(model.savedWords(), [])
        XCTAssertTrue(try XCTUnwrap(LearnedWords()).isRecognized("чӀалнан"), "the row and its count are still stored")
        model.updateSettings { $0.learnSpeed = .fast }
        XCTAssertEqual(model.savedWords(), ["чӀалнан"])
    }
}
