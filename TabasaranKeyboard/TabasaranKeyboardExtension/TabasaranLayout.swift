//
//  TabasaranLayout.swift
//  TabasaranKeyboardExtension
//
//  The LekiTech Tabasaran layout (proposed; not an Apple or otherwise
//  official layout). It is the Russian iOS keyboard with two keys changed:
//  the hard sign «ъ» takes the place of «щ», and the palochka «Ӏ» takes the
//  place of «ы». «щ» moves under a long press on «ш», «ы» under «Ӏ».
//
//  Why: in Tabasaran text «ъ» is 3.5 % of all characters (the 8th most
//  frequent, 21 per 100 words, because of «гъ», «хъ», «къ» and the
//  locative -ъ) and the palochka about 1.1–1.3 % (7 per 100 words: «пӀ»,
//  «кӀ», «чӀ», «цӀ», «тӀ»), while «ы» and «щ» are 0.03 % each and occur only
//  in Russian loans. On the Russian layout «ъ» and «Ӏ» need a long press,
//  which the model puts at 28 long presses per 100 words; here it is 0.9.
//  The numbers, the alternatives that were compared and the open questions
//  are in docs/LAYOUT.md, computed by scripts/analyze_layout.py.
//
//  No community Tabasaran layout exists: Agisight/ios-system-keyboard has
//  no layout/tab, and Agisight/rf-keyboard-corpora has only a long-press
//  mapping (data/tab/Ali_Kuzhuget/mapping/tab_key_mapping_ext.json at
//  commit cd7a94e), which the digraph callouts below follow.
//
//  The thirteen digraph letters of the alphabet are typed with the plain
//  keys (г + ъ, к + Ӏ, а + ь …) and are also offered as long-press options
//  that insert both characters at once. Rows are written once, in
//  lowercase; the engine derives the shift layer (first letter: «кӀ» →
//  «КӀ», «гъ» → «Гъ») and Caps Lock (all letters: «ГЪ»).
//
//  Product data: the engine reads it only through
//  `KeyboardDefinition.current.layout` (see TabasaranDefinition.swift).
//

import Foundation
import GeneralKeyboard

extension LayoutStyle {
    /// The one Tabasaran layout. Persisted raw value; never rename.
    static let standard = LayoutStyle(rawValue: "standard")
}

enum TabasaranLayout {

    /// Ӏ U+04C0 CYRILLIC LETTER PALOCHKA: what the key shows and inserts.
    /// Never Latin I, the digit 1 or lowercase l.
    static let palochka = "\u{04C0}"
    /// ’ U+2019: the apostrophe of «дюн’я», under a long press on «ъ».
    static let apostrophe = "\u{2019}"

    static let capabilities = LayoutCapabilities(
        styles: [standard],
        defaultStyle: .standard,
        // One style: the engine hides the selector and the quick menu.
        showsStyleSelector: false,
        persistenceKey: "layoutStyle",
        quickSwitchOnSettingsLongPress: false,
        // iPhone portrait on Apple's native keyboard grid (pixel-snapped
        // cells, native bottom-row proportions, native panel height), as
        // approved for Lezgi, Dargwa and Kumyk
        gridModel: .nativeCells
    )

    static let standard = LayoutStyleSpec(
        id: .standard,
        letterRows: letterRows,
        numberRows: numberRows,
        symbolRows: symbolRows,
        callouts: callouts,
        metrics: metrics,
        settingsTitle: "Стандартная",
        settingsSubtitle: "Русская раскладка, ъ на месте щ, Ӏ на месте ы"
    )

    /// Three letter rows and the geometry Lezgi, Dargwa and Kumyk ship with.
    static let metrics = KeyboardLayout.Metrics(totalHeight: 250, keyHeight: 43, rowSpacing: 11,
                                                emojiRows: 5, emojiCellHeight: 33)

    // MARK: - Letter rows

    static let letterRows: [[KeyCap]] = [
        ["й","ц","у","к","е","н","г","ш","ъ","з","х"].map { .character($0) },        // 11 keys, ъ on щ's key
        ["ф",palochka,"в","а","п","р","о","л","д","ж","э"].map { .character($0) },   // 11 keys, Ӏ on ы's key
        [.shift]
            + ["я","ч","с","м","и","т","ь","б","ю"].map { KeyCap.character($0) }     // 9 keys, as Russian
            + [.backspace],
    ]

    // MARK: - Number page (the standard Russian iOS set)

    static let numberRows: [[KeyCap]] = [
        ["1","2","3","4","5","6","7","8","9","0"].map { .character($0) },
        ["-","/",":",";","(",")","₽","&","@","\""].map { .character($0) },
        [.symbols] + [".",",","?","!","'"].map { KeyCap.character($0) } + [.backspace],
    ]

    // MARK: - Symbol page (the standard Russian iOS set)

    static let symbolRows: [[KeyCap]] = [
        ["[","]","{","}","#","%","^","*","+","="].map { .character($0) },
        ["_","\\","|","~","<",">","$","€","¥","•"].map { .character($0) },
        [.numbers] + [".",",","?","!","'"].map { KeyCap.character($0) } + [.backspace],
    ]

    // MARK: - Long-press callouts
    // Keys are lowercase; the popup puts the base key first and the shift
    // state is applied to every option. An option is inserted as a whole
    // string («кӀ» = к + palochka U+04C0, two Cyrillic characters).

    /// The thirteen digraph letters of the Tabasaran alphabet under their
    /// first letter: the assignment of Agisight/rf-keyboard-corpora
    /// (tab_key_mapping_ext.json). Where a key has several, they are in the
    /// order of their frequency in the corpus (гъ 2.2 % of letters, гь 1.4 %;
    /// кь 0.57 %, кӀ 0.33 %, къ 0.17 %; хь 0.92 %, хъ 0.68 %); the
    /// independent letter count of rf-keyboard-corpora gives the same order.
    static let digraphCallouts: [String: [String]] = [
        "а": ["аь"],
        "г": ["гъ", "гь"],
        "к": ["кь", "к" + palochka, "къ"],
        "п": ["п" + palochka],
        "т": ["т" + palochka],
        "у": ["уь"],
        "х": ["хь", "хъ"],
        "ц": ["ц" + palochka],
        "ч": ["ч" + palochka],
    ]

    /// The three Russian letters without a key, each where a Russian typist
    /// looks for it (ё under е and щ under ш as on the Russian keyboard, ы
    /// on the key that took its place), and the apostrophe under «ъ».
    static let letterCallouts: [String: [String]] = [
        "е": ["ё"],
        "ш": ["щ"],
        palochka: ["ы"],
        "ъ": [apostrophe],
    ]

    /// The symbol alternates of the Russian iOS keyboard (as the sibling
    /// keyboards; the quote alternates sit on this layout's ' and " keys).
    static let symbolCallouts: [String: [String]] = [
        "0": ["°"],
        "₽": ["$", "€", "£", "¥", "￦"],
        "#": ["№"],
        ".": ["…"],
        "%": ["‰", "∞"],
        "=": ["≠", "≈"],
        "-": ["•", "–", "—"],
        "/": ["\\"],
        "&": ["§"],
        "?": ["¿"],
        "!": ["¡"],
        "'": ["’", "‘", "`"],
        "\"": ["”", "“", "„", "»", "«"],
    ]

    static let callouts: [String: [String]] = digraphCallouts
        .merging(letterCallouts) { first, _ in first }
        .merging(symbolCallouts) { first, _ in first }
}
