# Localization and strings for review

## What is Tabasaran today

| Where | String | Source |
|---|---|---|
| Keyboard name (flashed on the space bar), app header | Табасаран чӀал | the self-name of the language: the title of the school grammar «Табасаран чӀал» (1992) and of Evertype's alphabet sheet; the corpus has «табасаран чӀал» (16 times as a word pair), «табасаран чӀалнан» (18) |
| Space bar corner label | ТАБ | abbreviation chosen here (also the ISO 639-3 code), like «ЛЕЗГ», «АВАР», «ДАРГ», «КЪУМ» |

The palochka in every string is Ӏ U+04C0. Nothing else is Tabasaran yet.
**No Tabasaran translation was invented.**

## What is temporary Russian (needs a Tabasaran translation)

No verified Tabasaran translation of the key names or of the keyboard's
settings panel exists (Agisight's `ios-system-keyboard` has no Tabasaran
key names), so `TabasaranStrings.swift` uses Russian. Every string below
needs a reviewed Tabasaran version:

| Field | Russian (current) |
|---|---|
| space | Пробел |
| return key: Go / Send / Done / Next / Continue / Join / Route / Search | Перейти / Отправить / Готово / Далее / Продолжить / Подкл. / Маршрут / Найти |
| emergency call | SOS |
| lettersKey | АБВ |
| deleteWordQuestion | Удалить «…»? |
| no / delete | Нет / Удалить |
| emojiRecents | Недавние |
| back / close | Назад / Клавиатура |
| settingsCaption / settingsTitle | ТАБАСАРАНСКАЯ КЛАВИАТУРА / Настройки |
| pageInput / pageTheme / pageDictionary / pageAbout | Ввод / Тема / Словарь / О клавиатуре |
| sectionLayout / sectionSuggestions / sectionKeys / sectionLearning | Раскладка / Подсказки / Клавиши / Обучение |
| sectionLongPress / sectionTheme | Долгое нажатие (гъ, кӀ, ё…) / Тема |
| wordSuggestions / nextWordSuggestion / autoSpace | Подсказки слов / Подсказка следующего слова / Пробел после подсказки |
| doubleSpacePeriod / spaceCursor / spaceCornerToggle | Два пробела — точка / Курсор пробелом / «таб» на пробеле |
| learnFast / learnNormal / learnSlow / learnUses | Быстро / Обычно / Медленно / N раз(а) |
| calloutShort / calloutNormal / calloutLong / calloutDuration | Короткая задержка / Обычная задержка / Длинная задержка / 0,3 с |
| themeSystem / themeLight / themeDark | Системная / Светлая / Тёмная |
| learnedWordsCaption / noWordsYet | выученные слова / Пока нет слов |
| deleteAll / deleteAllQuestion | Удалить все выученные слова / Удалить все выученные слова? |
| aboutInitial / aboutTitle / aboutByline | Т / Табасаранская клавиатура / Версия … · LekiTech |
| settingsTitle / settingsSubtitle of the layout style | Стандартная / Русская раскладка, ъ на месте щ, Ӏ на месте ы |
| emojiCategoryTitles | Смайлики и люди, Животные и природа, Еда и напитки, Активность, Путешествия и места, Предметы, Символы, Флаги |

Also the extension's `Localizable.xcstrings` («Show «таб» on the space
bar», en/ru) and the display name «Tabasaran» / «Табасаранский» in the keyboard
extension's `InfoPlist.xcstrings` (a Tabasaran display name could be added as a `tab`
localization once iOS lists the language).

The engine's own labels (for example the explanatory subtitles under the
toggles) follow the system language (en/ru) and are not Tabasaran's to
translate.

## The language code

`PrimaryLanguage` of the extension is `tab`, the ISO 639-3 code of
Tabasaran and a valid BCP 47 language subtag. Unlike `ava`, `lez`, `dar`
and `kum` (codes of ISO 639-2, which iOS's language data covers), `tab`
has no display name in iOS: `Locale.localizedString(forLanguageCode:)`
returns nothing for it in English and in Russian (checked on iOS 27.0 and
27.2). The effect is cosmetic: the globe menu shows «Tabasaran» /
«Табасаранский» (the extension's own display name) without the language
line that the Kumyk keyboard has under its name. The app cannot supply
that line. The code must not be replaced by another language's to obtain
one; Lak (`lbe`), Agul (`agx`) and Rutul (`rut`) will behave the same.

## The containing app

English with Russian translations
(`TabasaranKeyboard/Localizable.xcstrings`, 30 strings), like the Lezgi,
Dargwa and Kumyk apps: «Tabasaran Keyboard» / «Табасаранская клавиатура».
No Tabasaran text there except letters, the example «дюн’я» and
«Табасаран чӀал». The app shows no contributor credits; attribution of
third-party material is in the repository (`LICENSE`,
`Tests/TabasaranCoreTests/Fixtures/agisight/SOURCE.md`,
`docs/DICTIONARY.md`).
