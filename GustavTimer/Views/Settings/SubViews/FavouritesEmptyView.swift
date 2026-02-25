//
//  EmptyFavouritesView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 06.09.2025.
//

import SwiftUI
import GustavUICore

struct FavouritesEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("FAVOURITES_EMPTY_LABEL")
                .multilineTextAlignment(.center)
                .font(.emptyLabel)
                .foregroundStyle(Color.gustavLight)
            Text("FAVOURITES_EMPTY_SUBTITLE")
                .multilineTextAlignment(.center)
                .font(.emptySubtitle)
                .foregroundStyle(Color.gustavLight)
        }
        .padding()
        .frame(height: 150)
        .frame(maxWidth: .infinity, minHeight: 44)
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
}

#Preview {
    List {
        FavouritesEmptyView()
    }
}
