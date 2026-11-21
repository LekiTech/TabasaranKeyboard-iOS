//
//  TabasaranDefinition.swift
//  TabasaranKeyboardExtension
//
//  The Tabasaran keyboard as a KeyboardDefinition: everything
//  Tabasaran-specific the General Keyboard engine uses, assembled in one
//  value. The layout lives in TabasaranLayout.swift, strings and key names
//  in TabasaranStrings.swift.
//

import Foundation
import GeneralKeyboard

enum TabasaranDefinition {

    /// The apostrophe of Tabasaran spelling («дюн’я», «яратмиш’вал»,
    /// «йишв’ин») in the forms a text may carry: ’ U+2019 (what the «ъ»
    /// key's long press inserts and what the press prints), ‘ U+2018,
    /// ʼ U+02BC and the grave accent. The ASCII ' is a separator already.
    ///
    /// They end the word being typed, like the ASCII apostrophe does in
    /// every General Keyboard product. That is the tokenization of the
    /// bundled dictionary (its builder cut words at the apostrophe, so it
    /// holds «дюн» and «яйин», with the pair «дюн → яйин»): after «дюн’»
    /// the letters «яй» are completed to «яйин», and what is learned has
    /// the same shape. docs/DICTIONARY.md, "The apostrophe".
    static let apostrophes = "\u{2019}\u{2018}\u{02BC}`"

    static let definition = KeyboardDefinition(
        // Stable identity: the extension's App Store bundle identifier.
        // Never reused for a different definition.
        id: "org.lekitech.tabasarankeyboard.TabasaranKeyboardExtension",
        data: LanguageData(
            appGroupID: TabasaranIdentity.appGroupID,
            // TabasaranKeyboardExtension/tabasaran_words.sqlite and
            // tabasaran_bigrams.sqlite, built by scripts/build_dictionary.py
            wordsArtifact: "tabasaran_words",
            bigramsArtifact: "tabasaran_bigrams",
            diagnosticsSubsystem: "TabasaranKeyboardExtension"
        ),
        layout: TabasaranLayout.capabilities,
        keys: TabasaranStrings.keys,
        text: TextConventions(
            // Everything the user sees and types carries the palochka
            // Ӏ (U+04C0); lookup keys and stored rows keep ӏ (U+04CF).
            visiblePalochka: "\u{04C0}",
            // Ӏ is category Lu but caseless by convention: «КӀ» is a
            // capitalized digraph, not an ALL-CAPS prefix.
            caseNeutral: ["\u{04C0}", "\u{04CF}"],
            wordSeparators: TextConventions.defaultWordSeparators
                .union(CharacterSet(charactersIn: apostrophes))
        ),
        // Tabasaran is written in Dagestanian Cyrillic: the palochka ӏ and
        // the digraph tails ӏ ь ъ (аь гъ гь къ кь кӏ пӏ тӏ уь хъ хь цӏ чӏ)
        // are exactly the built-in profile's rules, so no profile of its
        // own is needed.
        normalization: .dagestanianCyrillicV1,
        strings: TabasaranStrings.strings,
        emojiCategoryTitles: TabasaranStrings.emojiCategoryTitles
    )
}
