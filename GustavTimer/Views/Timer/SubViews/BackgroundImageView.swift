//
//  BGImageView.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 22.10.2023.
//

import SwiftUI
import SwiftData

struct BackgroundImageView: View {
    @AppStorage(AppPreferences.Key.backgroundIndex) var bgIndex: Int = 0
    @Query var customImage: [CustomImageModel]
    
    var body: some View {
        GeometryReader(content: { geometry in
            getImage()
                .resizable()
                .scaledToFill()
                .overlay {
                    Color.black.opacity(0.3)
                }
                .grayscale(1.0)
                .ignoresSafeArea()
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        })
    }
    
    func getImage() -> Image {
        if AppConfig.backgroundImages.indices.contains(bgIndex) {
            return AppConfig.backgroundImages[bgIndex].getImage()
        } else {
            if let lastImageData = customImage.last?.image, let uiImage = UIImage(data: lastImageData) {
                return Image(uiImage: uiImage)
            }
            return AppConfig.backgroundImages[0].getImage()
        }
    }
}
