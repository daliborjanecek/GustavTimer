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
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(uiImage: item.image)
                                .backgroundThumbnail()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .contentShape(Rectangle())
                        .onTapGesture { setRemoteBG(id: item.id) }
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(style: .init(lineWidth: (remoteBackgroundID == item.id) ? 4 : 0))
                                .fill(Color.gustavVolt)
                                .animation(.easeInOut, value: remoteBackgroundID)
                        }
                        .padding(1)
                }
                ForEach(0..<AppConfig.backgroundImages.count, id: \.self) { index in
                    AppConfig.backgroundImages[index].getImage()
                        .backgroundThumbnail()
                        .onTapGesture { setBG(index: index) }
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(style: .init(lineWidth: (bgIndex == index && remoteBackgroundID.isEmpty) ? 4 : 0))
                                .fill(Color.gustavVolt)
                                .animation(.easeInOut, value: bgIndex)
                        }
                        .padding(1)
                }
                if !customImage.isEmpty {
                    ForEach(customImage, id: \.id) { imageData in
                        if let uiImage = UIImage(data: imageData.image) {
                            GeometryReader { geometry in
                                            Image(uiImage: uiImage)
                                    .backgroundThumbnail()
                                                .aspectRatio(contentMode: .fill) // Vyplní celý čtverec
                                                .frame(width: geometry.size.width, height: geometry.size.width) // Zajistí čtvercovou velikost
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .onTapGesture { setBG(index: -1) }
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(style: .init(lineWidth: (bgIndex == -1 && remoteBackgroundID.isEmpty) ? 4 : 0))
                                                        .fill(Color.gustavVolt)
                                                        .animation(.easeInOut, value: bgIndex)
                                                }
                                        }
                                        .aspectRatio(1, contentMode: .fit) // Zachová poměr 1:1, takže bude čtverec
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
        .toolbar {toolbar}
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if #available(iOS 26, *){
            ToolbarItem(placement: .title) {
                HStack {
                    Text("BACKGROUND_TAB")
                        .font(.settingsNavbarTitle)
                }
                .padding(.vertical)
            }
        } else {
            // Fallback to earlier versions
            ToolbarItem(placement: .title) {
                HStack {
                    Text("BACKGROUND_TAB")
                        .font(.settingsNavbarTitle)
                }
                .padding(.vertical)
            }
        }
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
