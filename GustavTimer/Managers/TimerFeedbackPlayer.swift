//
//  TimerFeedbackPlayer.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 11.11.2026.
//
//  Převádí události enginu (`TimerFeedback`) na vibrace a zvuky podle
//  nastavení timeru. Dřív to dělal `TimerViewModel` sám a sahal přitom přímo
//  na UIKit a `SoundManager`.
//
//  Co se má stát, rozhoduje čistá funkce `effects(for:settings:isRunning:)`,
//  kterou testuje `TimerFeedbackPlayerTests`. `play` ji jen provede.
//
//      engine.onFeedback = { feedback in
//          player.play(feedback, settings: settings, isRunning: engine.isRunning)
//      }
//

import UIKit

struct TimerFeedbackPlayer {

    /// Jedna vibrace nebo zvuk.
    enum Effect: Equatable {
        /// Lehký dotek – přechod intervalu a tik úvodního odpočtu.
        case lightHaptic
        /// Výraznější vibrace – konec kola a konec úvodního odpočtu.
        case successHaptic
        /// Nejsilnější vibrace – konec celého timeru.
        case endHaptic
        case sound(SoundModel)
        case tick
    }

    /// Co má zařízení udělat při dané události.
    ///
    /// - Parameter isRunning: vibrace přechodů se pouští jen za běhu. Konec
    ///   timeru vibruje vždy – engine se v tu chvíli už zastavil.
    static func effects(for feedback: TimerFeedback, settings: TimerSettings, isRunning: Bool) -> [Effect] {
        let vibrates = settings.isVibrating && isRunning

        switch feedback {
        case .intervalTransition:
            return (vibrates ? [.lightHaptic] : []) + transitionSound(settings)
        case .roundComplete:
            return (vibrates ? [.successHaptic] : []) + transitionSound(settings)
        case .timerEnd:
            return (settings.isVibrating ? [.endHaptic] : []) + transitionSound(settings)
        case .countdownTick:
            return vibrates ? [.lightHaptic] : []
        case .countdownEnd:
            return vibrates ? [.successHaptic] : []
        case .secondTick(let remainingSeconds):
            return tick(settings, remainingSeconds: remainingSeconds)
        }
    }

    /// Zvuk přechodu. Poslední sekunda intervalu nedostane `.secondTick` –
    /// engine místo ní pošle přechod – takže při ztlumeném zvuku se tik
    /// doplňuje tady. Přechod je „nultá“ sekunda, tiká v obou režimech tikání.
    private static func transitionSound(_ settings: TimerSettings) -> [Effect] {
        if let sound = settings.sound {
            return [.sound(sound)]
        }
        return tick(settings, remainingSeconds: 0)
    }

    /// Tik, pokud ho režim tikání pro danou sekundu chce.
    ///
    ///     .everySecond  → tiká vždy
    ///     .finalSeconds → tiká jen při 3, 2, 1 (a na přechodu při ztlumeném zvuku)
    private static func tick(_ settings: TimerSettings, remainingSeconds: Int) -> [Effect] {
        settings.ticking.shouldTick(remainingSeconds: remainingSeconds) ? [.tick] : []
    }

    func play(_ feedback: TimerFeedback, settings: TimerSettings, isRunning: Bool) {
        for effect in Self.effects(for: feedback, settings: settings, isRunning: isRunning) {
            perform(effect)
        }
    }

    private func perform(_ effect: Effect) {
        switch effect {
        case .lightHaptic:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .successHaptic:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .endHaptic:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .sound(let sound):
            SoundManager.instance.playSound(soundModel: sound)
        case .tick:
            SoundManager.instance.playTick()
        }
    }
}
