//
//  GustavTimerWidgetBundle.swift
//  GustavTimerWidget
//
//  Vstupní bod widget extension. Zatím obsahuje jedinou položku – Live Activity
//  s odpočtem, který drží běh timeru na zamykací obrazovce a v Dynamic Islandu.
//

import SwiftUI
import WidgetKit

@main
struct GustavTimerWidgetBundle: WidgetBundle {

    // Fonty si widget veze vlastní a registruje je přes `UIAppFonts` v Info.plist,
    // takže tu není co inicializovat. Na balíčku GustavUI záměrně nezávisí:
    // pád extension by znamenal, že na zamykací obrazovce zůstane viset poslední
    // vykreslený snímek a systém další render nevyžádá.

    var body: some Widget {
        TimerLiveActivity()
    }
}
