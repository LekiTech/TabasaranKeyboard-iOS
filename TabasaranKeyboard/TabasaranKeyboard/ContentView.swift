//
//  ContentView.swift
//  TabasaranKeyboard
//
//  The containing app's only screen: how to turn the keyboard on, the
//  layout at a glance, the long-press guide, where the keyboard's settings
//  and learned words live, what the dictionary is. Interface text is
//  English with Russian translations (Localizable.xcstrings); Tabasaran
//  letters are shown verbatim, the palochka always as Ӏ U+04C0.
//

import SwiftUI

struct ContentView: View {

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                installCard
                layoutCard
                longPressCard
                features
                settingsCard
                dictionaryCard
                footer
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                .accessibilityHidden(true)
            Text("Tabasaran Keyboard")
                .font(.title.weight(.bold))
            Text(verbatim: "Табасаран ч\u{04C0}ал")
                .font(.headline)
                .foregroundStyle(Color("BrandTint"))
            Text("Type in your native language")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Installation

    private var installCard: some View {
        Card {
            Text("How to install")
                .font(.title3.weight(.semibold))

            StepRow(number: "1", text: "Tap **Open Settings** below")
            StepRow(number: "2", text: "Tap **Keyboards**")
            StepRow(number: "3", text: "Turn on **Tabasaran**")
            StepRow(number: "4", text: "Switch languages using the 🌐 key on the keyboard")

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)

            Text("Tip: you can also add the keyboard via **Settings → General → Keyboard → Keyboards**")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Layout

    /// Ӏ U+04C0 CYRILLIC LETTER PALOCHKA, as the keyboard shows and inserts it.
    private static let palochka = "\u{04C0}"

    /// The letter rows of TabasaranLayout.swift, for display only.
    private static let rows: [[String]] = [
        ["й","ц","у","к","е","н","г","ш","ъ","з","х"],
        ["ф",palochka,"в","а","п","р","о","л","д","ж","э"],
        ["я","ч","с","м","и","т","ь","б","ю"],
    ]

    /// Long-press options of TabasaranLayout.swift, for display only.
    private static let longPresses: [(String, String)] = [
        ("г", "гъ  гь"),
        ("х", "хь  хъ"),
        ("к", "кь  к\(palochka)  къ"),
        ("п", "п\(palochka)"),
        ("т", "т\(palochka)"),
        ("ц", "ц\(palochka)"),
        ("ч", "ч\(palochka)"),
        ("а", "аь"),
        ("у", "уь"),
        ("е", "ё"),
        ("ш", "щ"),
        (palochka, "ы"),
        ("ъ", "\u{2019}"),
    ]

    private var layoutCard: some View {
        Card {
            Text("Layout")
                .font(.title3.weight(.semibold))
            Text("The Russian layout with two changes: the hard sign (ъ) and the palochka (Ӏ) have their own keys, where щ and ы are on the Russian keyboard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            KeyRowsPreview(rows: Self.rows, highlighted: ["ъ", Self.palochka])
                .padding(.vertical, 4)
        }
    }

    private var longPressCard: some View {
        Card {
            Text("Long press")
                .font(.title3.weight(.semibold))
            Text("Hold a key to see more letters, then slide to the one you need.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(Array(Self.longPresses.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text(verbatim: item.0)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .frame(width: 28, alignment: .leading)
                        Image(systemName: "hand.tap")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(verbatim: item.1)
                            .font(.body)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    if index < Self.longPresses.count - 1 { Divider() }
                }
            }

            Text("Every one of them can also be typed key by key: г, then ъ; к, then Ӏ. Doubled letters (кк, чч) and жв, чв, шв are typed as two letters.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("The apostrophe of words like дюн’я is under ъ.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Feature cards

    private var features: some View {
        VStack(spacing: 12) {
            FeatureCard(icon: "textformat.abc", tint: Color("BrandTint"),
                        title: "Full Tabasaran alphabet",
                        subtitle: "ъ and Ӏ on their own keys; аь, гъ, гь, къ, кь, кӀ, пӀ, тӀ, уь, хъ, хь, цӀ, чӀ key by key or with one long press")
            FeatureCard(icon: "text.book.closed.fill", tint: .orange,
                        title: "Word suggestions",
                        subtitle: "About 28,700 Tabasaran words and 38,500 word pairs, fully offline")
            FeatureCard(icon: "keyboard.fill", tint: .accentColor,
                        title: "Feels native",
                        subtitle: "Matches the iOS keyboard down to the details, in light and dark mode")
            FeatureCard(icon: "lock.shield.fill", tint: .purple,
                        title: "Private by design",
                        subtitle: "Never asks for Full Access and sends nothing anywhere — word learning stays on this device and can be reset from the keyboard")
        }
    }

    // MARK: - Settings

    private var settingsCard: some View {
        Card {
            Label {
                Text("Keyboard settings")
                    .font(.title3.weight(.semibold))
            } icon: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(Color.accentColor)
            }
            Text("Tap the ⚙︎ key on the keyboard to change word suggestions, next-word suggestions, learning speed, the long-press delay and the theme. Settings are saved on this device.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Text("The keyboard learns the words you type. Its **Dictionary** page lists them; you can delete one word or all of them there.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Dictionary

    private var dictionaryCard: some View {
        Card {
            Label {
                Text("Dictionary")
                    .font(.title3.weight(.semibold))
            } icon: {
                Image(systemName: "text.book.closed.fill")
                    .foregroundStyle(Color.orange)
            }
            Text("The built-in dictionary has about 28,700 Tabasaran words and 38,500 word pairs. It works offline and is the same for everyone; your own words are kept separately.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Text("It is drawn from scanned issues of a Tabasaran magazine and from a Tabasaran–Russian dictionary. Scanning errors were corrected where the evidence was clear, and the dictionary is still being reviewed: suggestions may contain misspellings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        Text("Developed by LekiTech")
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .padding(.bottom, 8)
    }
}

// MARK: - Card

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Layout preview

private struct KeyRowsPreview: View {
    let rows: [[String]]
    let highlighted: Set<String>

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                        let isHighlighted = highlighted.contains(key)
                        Text(verbatim: key)
                            .font(.system(size: 16, weight: isHighlighted ? .semibold : .regular))
                            .frame(maxWidth: 30, minHeight: 34)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(isHighlighted ? Color.white : Color.primary)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(isHighlighted ? Color("BrandTint") : Color(.tertiarySystemFill))
                            )
                    }
                }
                .padding(.horizontal, row.count < 11 ? 22 : 0)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Feature card

private struct FeatureCard: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Installation step

private struct StepRow: View {
    let number: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(verbatim: number)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .clipShape(Circle())
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    ContentView()
}
