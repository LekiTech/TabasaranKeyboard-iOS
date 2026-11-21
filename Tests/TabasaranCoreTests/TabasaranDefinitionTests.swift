//
//  TabasaranDefinitionTests.swift
//  TabasaranCoreTests
//
//  The Tabasaran KeyboardDefinition: its own identity (never another
//  product's), the persisted contract, the Dagestanian Cyrillic profile
//  with the palochka convention (Ӏ U+04C0 shown and typed, ӏ U+04CF as the
//  lookup key), the apostrophe as a word separator, and the project's
//  two-target, two-identity setup (Debug for the developer's team, Release
//  for distribution).
//

import XCTest
import UIKit
@testable import TabasaranCore
@testable import GeneralKeyboard

final class TabasaranDefinitionTests: TabasaranTestCase {

    private var d: KeyboardDefinition { KeyboardDefinition.current }

    func testIdentityAndArtifacts() {
        XCTAssertEqual(d.validationErrors(), [])
        XCTAssertEqual(d.id, "org.lekitech.tabasarankeyboard.TabasaranKeyboardExtension")
        XCTAssertEqual(TabasaranIdentity.releaseAppGroupID, "group.org.lekitech.tabasarankeyboard")
        XCTAssertEqual(TabasaranIdentity.debugAppGroupID, "group.org.lekitech.tabasarankeyboard.dev")
        // Tests build in Debug
        XCTAssertEqual(d.data.appGroupID, TabasaranIdentity.debugAppGroupID)
        XCTAssertEqual(WordSuggestions.artifactName, "tabasaran_words")
        XCTAssertEqual(StaticBigrams.artifactName, "tabasaran_bigrams")
        XCTAssertEqual(d.data.diagnosticsSubsystem, "TabasaranKeyboardExtension")
    }

    func testNeverReusesAnotherProductsIdentity() {
        let taken = ["lezgi", "avar", "dargwa", "kumyk", "vadivian", "generalkeyboard", "reference"]
        for value in [d.id, d.data.appGroupID, TabasaranIdentity.releaseAppGroupID,
                      d.data.wordsArtifact, d.data.bigramsArtifact] {
            for other in taken {
                XCTAssertFalse(value.lowercased().contains(other), "\(value) contains \(other)")
            }
        }
    }

    // MARK: - Normalization and the palochka

    /// Tabasaran needs no profile of its own: the built-in Dagestanian
    /// Cyrillic rules are its rules.
    func testUsesTheBuiltInDagestanianProfile() {
        XCTAssertEqual(d.normalization, .dagestanianCyrillicV1)
        XCTAssertEqual(d.normalization.id, "dagestanian-cyrillic")
        XCTAssertEqual(Normalization.version, 1)
        XCTAssertEqual(Normalization.palochka, Tabasaran.lookup)
        XCTAssertEqual(d.normalization.digraphTails, [Tabasaran.lookup, "ь", "ъ"])
        XCTAssertEqual(d.text.visiblePalochka, Tabasaran.visible)
        XCTAssertEqual(d.text.caseNeutral, [Tabasaran.visible, Tabasaran.lookup])
    }

    /// One lookup key however the palochka was written: Ӏ U+04C0, ӏ U+04CF,
    /// or the Latin I, l and Ukrainian І that other keyboards produce.
    func testCanonicalFormOfTabasaranWords() {
        XCTAssertEqual(Normalization.canonical("ЧӀал"), "ч\u{04CF}ал")
        XCTAssertEqual(Normalization.canonical("чIал"), "ч\u{04CF}ал")
        XCTAssertEqual(Normalization.canonical("чlал"), "ч\u{04CF}ал")
        XCTAssertEqual(Normalization.canonical("ч\u{0406}ал"), "ч\u{04CF}ал")
        XCTAssertEqual(Normalization.canonical("  АПӀУЗ\n"), "ап\u{04CF}уз")
        XCTAssertEqual(Normalization.canonical("Гъахьну"), "гъахьну")
        // NFC: «й» typed as и plus a combining breve
        XCTAssertEqual(Normalization.canonical("йи\u{0306}из"), "ййиз")
        // Latin twins inside a Cyrillic word are repaired (а, у here)
        XCTAssertEqual(Normalization.canonical("xъa"), Normalization.canonical("хъа"))
        // The digit 1 is not a palochka: such a token is refused, not repaired
        XCTAssertFalse(Normalization.isValidToken(Normalization.canonical("ч1ал")))
        for word in ["чӏал", "апӏуз", "гъахьну", "аьхю", "уьмур", "ккунду", "жвуван", "кми-кмиди"] {
            XCTAssertTrue(Normalization.isCanonical(word), word)
            XCTAssertTrue(Normalization.isValidToken(word), word)
        }
        // What the user sees again carries U+04C0
        XCTAssertEqual(d.text.visibleForm("ч\u{04CF}ал", canonicalPalochka: Normalization.palochka), "ч\u{04C0}ал")
    }

    /// The thirteen digraph letters are one letter each for the engine, so
    /// a lone digraph is never learned as a word.
    func testLetterCountOfDigraphs() {
        for digraph in Tabasaran.digraphs {
            let canonical = Normalization.canonical(digraph)
            XCTAssertEqual(Normalization.letterCount(canonical), 1, digraph)
            XCTAssertFalse(Normalization.isValidToken(canonical), digraph)
        }
        XCTAssertEqual(Normalization.letterCount("чӏал"), 3)       // чӏ а л
        XCTAssertEqual(Normalization.letterCount("гъахьну"), 5)    // гъ а хь н у
        XCTAssertEqual(Normalization.letterCount("кку"), 3)        // a doubled consonant is two letters
        XCTAssertTrue(Normalization.isValidToken("цӏа"))
    }

    // MARK: - The apostrophe

    /// «дюн’я», «яратмиш’вал»: the apostrophe ends the word being typed,
    /// in every form a text may carry it, like the ASCII apostrophe does
    /// in the engine's default set.
    func testApostrophesAreWordSeparators() {
        let separators = d.text.wordSeparators
        for mark in ["\u{2019}", "\u{2018}", "\u{02BC}", "`", "'"] {
            XCTAssertTrue(separators.contains(mark.unicodeScalars.first!), mark)
        }
        // Nothing else changed: the default separators are all there, and
        // letters, the palochka and the signs are not separators
        for scalar in " \n.,!?;:\"'()[]{}—–-".unicodeScalars {
            XCTAssertTrue(separators.contains(scalar))
        }
        for scalar in "аяъь\u{04C0}\u{04CF}".unicodeScalars {
            XCTAssertFalse(separators.contains(scalar))
        }
        XCTAssertEqual(TabasaranLayout.apostrophe, Tabasaran.apostrophe)
    }

    // MARK: - Layout capabilities and strings

    func testLayoutCapabilities() {
        XCTAssertEqual(d.layout.styles.map(\.id.rawValue), ["standard"])
        XCTAssertEqual(d.layout.defaultStyle.rawValue, "standard")
        XCTAssertEqual(d.layout.persistenceKey, "layoutStyle")
        XCTAssertFalse(d.layout.showsSelector)
        XCTAssertFalse(d.layout.showsQuickSwitch)
        XCTAssertEqual(d.layout.gridModel, .nativeCells)
        XCTAssertEqual(d.layout.resolve(nil).rawValue, "standard")
        XCTAssertEqual(d.layout.resolve("classic").rawValue, "standard")
        XCTAssertEqual(d.layout.spec(for: .standard).bottomRowAfterSpace, [])
    }

    /// Everything the user reads or types carries Ӏ U+04C0, never the
    /// lookup form ӏ U+04CF and never a Latin I or l standing in for it.
    func testUserFacingTextUsesTheVisiblePalochka() {
        let s = d.strings
        var texts: [String] = [
            s.deleteWordQuestion("чӀал"), s.no, s.delete, s.emojiRecents, s.back, s.close,
            s.settingsCaption, s.settingsTitle, s.pageInput, s.pageTheme, s.pageDictionary,
            s.pageAbout, s.sectionLayout, s.sectionSuggestions, s.sectionKeys, s.sectionLearning,
            s.sectionLongPress, s.sectionTheme, s.wordSuggestions, s.nextWordSuggestion,
            s.autoSpace, s.doubleSpacePeriod, s.spaceCursor, s.spaceCornerToggle,
            s.spaceCornerToggleSubtitle, s.learnFast, s.learnNormal, s.learnSlow, s.learnUses(3),
            s.calloutShort, s.calloutNormal, s.calloutLong, s.calloutDuration(0.3), s.themeSystem,
            s.themeLight, s.themeDark, s.learnedWordsCaption, s.noWordsYet, s.deleteAll,
            s.deleteAllQuestion, s.aboutInitial, s.aboutTitle, s.aboutByline("1.0.0"),
            d.keys.space, d.keys.spaceCornerLabel, d.keys.keyboardName, d.keys.lettersKey,
            d.keys.lettersKeyShifted, d.keys.emojiPageLettersKey,
        ]
        texts += d.keys.returnLabels.values
        texts += d.emojiCategoryTitles.values
        let spec = d.layout.spec(for: .standard)
        texts += [spec.settingsTitle, spec.settingsSubtitle]
        var letterTexts: [String] = []
        for row in spec.letterRows {
            for case .character(let c) in row { letterTexts.append(c) }
        }
        for (key, alternates) in spec.callouts where key.first!.isLetter { letterTexts += [key] + alternates }
        for text in texts + letterTexts {
            XCTAssertFalse(text.contains(Tabasaran.lookup), "\(text) shows the lookup palochka U+04CF")
        }
        // No Latin letter on a letter key or in a letter's long press
        for text in letterTexts {
            XCTAssertFalse(text.contains(where: { $0.isASCII && $0.isLetter }), "\(text) has a Latin letter")
        }
        XCTAssertEqual(d.keys.keyboardName, "Табасаран ч\u{04C0}ал")
        XCTAssertEqual(d.keys.spaceCornerLabel, "ТАБ")
        XCTAssertEqual(s.sectionLongPress, "Долгое нажатие (гъ, к\u{04C0}, ё…)")
        // The palochka key itself
        XCTAssertEqual(spec.letterRows[1][1], .character(String(Tabasaran.visible)))
    }

    /// Every two-letter long-press option is one letter for the engine
    /// (its tail is a digraph tail of the normalization profile).
    func testDigraphTailsCoverEveryTwoCharacterCallout() {
        for (_, alternates) in d.layout.spec(for: .standard).callouts {
            for alt in alternates where alt.count == 2 && alt.first!.isLetter {
                let canonical = Normalization.canonical(alt)
                XCTAssertTrue(d.normalization.digraphTails.contains(canonical.last!), alt)
                XCTAssertEqual(Normalization.letterCount(canonical), 1, alt)
            }
        }
    }

    func testRussianFallbackFormatting() {
        let s = d.strings
        XCTAssertEqual(s.learnUses(1), "1 раз")
        XCTAssertEqual(s.learnUses(3), "3 раза")
        XCTAssertEqual(s.learnUses(5), "5 раз")
        XCTAssertEqual(s.learnUses(12), "12 раз")
        XCTAssertEqual(s.learnUses(22), "22 раза")
        XCTAssertEqual(s.calloutDuration(0.2), "0,2 с")
        XCTAssertEqual(s.calloutDuration(0.45), "0,45 с")
        XCTAssertEqual(s.aboutByline("1.0.0"), "Версия 1.0.0 · LekiTech")
    }

    // MARK: - Project

    /// Two targets, no sticker or messenger targets; Debug signs with the
    /// developer's team under `.dev` identifiers, Release carries the App
    /// Store identifiers and no team (the distribution team adds its own).
    func testProjectTargetsAndSigning() throws {
        let pbx = try RepoPaths.text(RepoPaths.project)
        XCTAssertEqual(pbx.components(separatedBy: "isa = PBXNativeTarget;").count - 1, 2)
        XCTAssertEqual(pbx.components(separatedBy: "com.apple.product-type.application\"").count - 1, 1)
        XCTAssertEqual(pbx.components(separatedBy: "com.apple.product-type.app-extension\"").count - 1, 1)
        for banned in ["sticker", "Sticker", "messages", "telegram", "whatsapp", "instagram",
                       "Lezgi", "lezgi", "Avar", "avar", "Dargwa", "dargwa", "Kumyk", "kumyk", "vadivian"] {
            XCTAssertFalse(pbx.contains(banned), "project mentions \(banned)")
        }
        let bundleIDs = Set(pbx.matches(of: /PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/).map { String($0.1) })
        XCTAssertEqual(bundleIDs, [
            "org.lekitech.tabasarankeyboard.dev", "org.lekitech.tabasarankeyboard.dev.TabasaranKeyboardExtension",
            "org.lekitech.tabasarankeyboard", "org.lekitech.tabasarankeyboard.TabasaranKeyboardExtension",
        ])
        let groups = Set(pbx.matches(of: /TABASARAN_APP_GROUP_ID = ([^;]+);/).map { String($0.1) })
        XCTAssertEqual(groups, [TabasaranIdentity.debugAppGroupID, TabasaranIdentity.releaseAppGroupID])
        let teams = pbx.matches(of: /\bDEVELOPMENT_TEAM = ([^;]+);/).map { String($0.1) }
        XCTAssertEqual(teams.sorted(), ["\"\"", "\"\"", "RC94H8KQYA", "RC94H8KQYA"])
        XCTAssertTrue(pbx.contains("relativePath = \"../../GeneralKeyboard-iOS\";"))

        for file in ["TabasaranKeyboard/TabasaranKeyboard/TabasaranKeyboard.entitlements",
                     "TabasaranKeyboard/TabasaranKeyboardExtension/TabasaranKeyboardExtension.entitlements"] {
            let plist = try RepoPaths.text(RepoPaths.root.appendingPathComponent(file))
            XCTAssertTrue(plist.contains("<string>$(TABASARAN_APP_GROUP_ID)</string>"), file)
        }
        let info = try RepoPaths.text(RepoPaths.extensionFolder.appendingPathComponent("Info.plist"))
        XCTAssertTrue(info.contains("<string>tab</string>"))
        XCTAssertTrue(info.contains("<key>RequestsOpenAccess</key>\n\t\t\t<false/>"))
    }
}
