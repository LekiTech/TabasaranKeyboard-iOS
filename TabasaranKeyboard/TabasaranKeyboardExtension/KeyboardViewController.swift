//
//  KeyboardViewController.swift
//  TabasaranKeyboardExtension
//
//  The extension's principal class (Info.plist NSExtensionPrincipalClass).
//  Everything a keyboard does lives in the General Keyboard engine; this
//  class only installs the Tabasaran definition before the engine starts. iOS
//  creates a new controller each time the keyboard is shown again, and a
//  repeated install of the same definition is a no-op.
//

import Foundation
import GeneralKeyboard

final class KeyboardViewController: GeneralKeyboardViewController {

    override init(nibName: String?, bundle: Bundle?) {
        KeyboardDefinition.install(TabasaranDefinition.definition)
        super.init(nibName: nibName, bundle: bundle)
    }

    required init?(coder: NSCoder) {
        KeyboardDefinition.install(TabasaranDefinition.definition)
        super.init(coder: coder)
    }
}
