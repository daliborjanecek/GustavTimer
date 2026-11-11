//
//  BGView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 08.09.2024.
//

import SwiftUI
import PhotosUI
import SwiftData

struct BackgroundSelectorView: View {
    private let flexibleColumn = [
        GridItem(.adaptive(minimum: 120))
    ]
        
    @AppStorage(AppPreferences.Key.backgroundIndex) var bgIndex: Int = 0
    @AppStorage(AppPreferences.Key.remoteBackgroundID) var remoteBackgroundID: String = ""
    @ObservedObject private var remoteContent = RemoteContentManager.shared
    
    @Environment(\.modelContext) var context
    @Query var customImage: [CustomImageModel]
    
    @State private var selectedPhoto: PhotosPickerItem?
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: flexibleColumn, spacing: 15) {
                // Stažená pozadí jsou před vestavěnými, v pořadí z API.
                ForEach(remoteContent.backgrounds) { item in
                    BackgroundThumbnail(
                        image: Image(uiImage: item.image),
                        isSelected: remoteBackgroundID == item.id
                    ) {
                        setRemoteBG(id: item.id)
                    }
                }
                ForEach(0..<AppConfig.backgroundImages.count, id: \.self) { index in
                    BackgroundThumbnail(
                        image: AppConfig.backgroundImages[index].getImage(),
                        isSelected: bgIndex == index && remoteBackgroundID.isEmpty
                    ) {
                        setBG(index: index)
                    }
                }
                // Vlastní fotka má index -1.
                ForEach(customImage, id: \.id) { imageData in
                    if let uiImage = UIImage(data: imageData.image) {
                        BackgroundThumbnail(
                            image: Image(uiImage: uiImage),
                            isSelected: bgIndex == -1 && remoteBackgroundID.isEmpty
                        ) {
                            setBG(index: -1)
                        }
                    }
                }
                PhotosPicker(selection: $selectedPhoto) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gustavNeutral)
                        .aspectRatio(1, contentMode: .fill)
                        .overlay(alignment: .center) {
                            Image(systemName: "photo")
                                .foregroundStyle(Color.gustavVolt)
                                .font(.title)
                                .padding()
                        }
                }
            }
            .padding()
            .task(id: selectedPhoto) {
                if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                    for image in customImage {
                                context.delete(image)
                            }
                    let customPhoto = CustomImageModel(image: data)
                    context.insert(customPhoto)
                    setBG(index: -1)
                }
            }
        }
        .settingsTitle("BACKGROUND_TAB")
    }
    
    func setBG(index: Int) {
        self.remoteBackgroundID = ""
        self.bgIndex = index
        Analytics.settingChanged("background", value: index == -1 ? "custom" : String(index))
    }

    /// Vzdálené pozadí se pamatuje podle ID. Index se nastaví na výchozí
    /// vestavěné pozadí – na to se přepne, až vzdálené přestane platit.
    func setRemoteBG(id: String) {
        self.bgIndex = AppConfig.defaultBackgroundIndex
        self.remoteBackgroundID = id
        Analytics.settingChanged("background", value: "remote")
    }
}

/// Čtvercový náhled pozadí. Vybraný má rámeček.
private struct BackgroundThumbnail: View {
    let image: Image
    let isSelected: Bool
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 10)

    var body: some View {
        // Čtverec určuje podklad, obrázek ho jen vyplní – fotka s jiným
        // poměrem stran by jinak buňku mřížky roztáhla.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                image.backgroundThumbnail()
            }
            .clipShape(shape)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .overlay {
                shape
                    .stroke(Color.gustavVolt, lineWidth: isSelected ? 4 : 0)
                    .animation(.easeInOut, value: isSelected)
            }
            .padding(1)
    }
}

#Preview {
    NavigationStack {
        BackgroundSelectorView()
    }
    .modelContainer(PreviewData.container)
}
