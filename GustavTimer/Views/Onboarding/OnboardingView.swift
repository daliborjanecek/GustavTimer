//
//  OnboardingView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 25.12.2025.
//

import SwiftUI
import GustavUICore

struct OnboardingView: View {
    
    let onboardingItems: [GustavOnboardingItem] = [
        GustavOnboardingItem(title: "OB_TIMER_TITLE".localized, description: "OB_TIMER_DESCRIPTION".localized, mediaFileName: "ob_timer", buttonLabel: nil),
        GustavOnboardingItem(title: "OB_FAVOURITES_TITLE".localized, description: "OB_FAVOURITES_DESCRIPTION".localized, mediaFileName: "ob_favourites", buttonLabel: nil),
        GustavOnboardingItem(title: "OB_GUSTAV_TITLE".localized, description: "OB_GUSTAV_DESCRIPTION".localized, mediaFileName: "ob_fristensky", buttonLabel: "OB_FINISH".localized)
    ]
    
    var body: some View {
        GustavOnboardingView(onboardingItems: onboardingItems)
    }
}

#Preview {
    OnboardingView()
}
