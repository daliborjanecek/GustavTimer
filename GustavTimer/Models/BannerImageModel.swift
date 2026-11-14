//
//  BannerImageModel.swift
//  GustavTimer
//
//  Created by Dalibor Janeček on 13.12.2025.
//

import SwiftUI

struct BannerImageModel: Identifiable {
    let id = UUID()
    let imageResource: ImageResource
    let urlString: String
    
    func getImage() -> Image {
        return Image(imageResource)
    }
    
    func getURL() -> URL? {
        return URL(string: urlString)
    }
}
