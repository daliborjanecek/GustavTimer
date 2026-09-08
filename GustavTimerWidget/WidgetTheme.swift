//
//  WidgetTheme.swift
//  GustavTimerWidget
//
//  Barvy a fonty widgetu bez závislosti na balíčku GustavUI.
//
//  Extension je vlastní proces a každý jeho pád znamená, že na zamykací obrazovce
//  zůstane viset poslední vykreslený snímek – systém další render nevyžádá.
//  `Bundle.module` z SwiftPM balíčku přitom při chybějícím resource bundlu končí
//  tvrdým `fatalError`. Widget si proto veze vlastní kopii fontů (`UIAppFonts`
//  v Info.plist) a barvy má jako konstanty. Hodnoty odpovídají GustavUI.
//

import SwiftUI

extension Color {
    /// StartColor z GustavUI – hlavní akcent.
    static let gustavVolt = Color(.displayP3, red: 203 / 255, green: 255 / 255, blue: 115 / 255)
    /// ResetColor z GustavUI – neutrální stav.
    static let gustavNeutral = Color(.displayP3, red: 97 / 255, green: 110 / 255, blue: 121 / 255)
}

extension Font {
    /// Nadpis dlaždice.
    static func gustavLabel(_ size: CGFloat) -> Font { .custom("MartianGrotesk-StdMd", size: size) }
    /// Podřádek.
    static func gustavCaption(_ size: CGFloat) -> Font { .custom("MartianGrotesk-CnRg", size: size) }
}
