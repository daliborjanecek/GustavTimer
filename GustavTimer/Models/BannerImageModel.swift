//
//  BannerImageModel.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 13.12.2025.
//

import SwiftUI

struct BannerImageModel: Identifiable {
    let id = UUID()
    /// Čitelný název pro analytiku (v aplikaci se nezobrazuje).
    let name: String
    let imageResource: ImageResource
    let urlString: String
    
    func getImage() -> Image {
        return Image(imageResource)
    }
    
    func getURL() -> URL? {
        return URL(string: urlString)
    }
}
