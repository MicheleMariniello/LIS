//
//  VideoPlayerView.swift
//  LIS
//
//  Created by Michele Mariniello on 23/05/25.
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoAttachment: Attachment?
    
    var body: some View {
        if let attachment = videoAttachment, let url = URL(string: attachment.url) {
            VideoPlayer(player: AVPlayer(url: url))
                .edgesIgnoringSafeArea(.all)
        } else {
            Text("Video non disponibile")
        }
    }
}


//struct VideoPlayerView_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            // Caso 1: Video disponibile
//            VideoPlayerView(videoAttachment: Attachment(
//                id: "att_mock123",
//                url: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4", // URL di un video di prova pubblico
//                filename: "sample_video.mp4",
//                type: "video/mp4"
//            ))
//            .previewDisplayName("Video Disponibile")
//
//            // Caso 2: Video non disponibile (Attachment è nil)
//            VideoPlayerView(videoAttachment: nil)
//                .previewDisplayName("Video Non Disponibile (nil)")
//
//            // Caso 3: Video non disponibile (URL non valido)
//            VideoPlayerView(videoAttachment: Attachment(
//                id: "att_invalid",
//                url: "invalid-url", // URL non valido
//                filename: "invalid.mp4",
//                type: "video/mp4"
//            ))
//            .previewDisplayName("Video Non Disponibile (URL non valido)")
//        }
//    }
//}
