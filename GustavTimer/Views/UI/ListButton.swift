//
//  ListButton.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 22.09.2024.
//

import SwiftUI
import GustavUICore

struct ListButton: View {
    var name: LocalizedStringKey
    var value: LocalizedStringKey?

    var body: some View {
        HStack {
            Text(name)
            Spacer()
            if let value {
                Text(value)
                    .foregroundColor(Color.gustavNeutral)
            }
        }
        .font(.gustavBody)
    }
}

#Preview {
    List {
        NavigationLink {
            Text("Destination")
        } label: {
            ListButton(name: "Hello", value: "World")
        }
    }
}
