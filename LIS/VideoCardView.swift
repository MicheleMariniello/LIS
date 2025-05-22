//
//  VideoCardView.swift
//  LIS
//
//  Created by Michele Mariniello on 23/05/25.
//

import SwiftUI
import AVKit

// Vista per le card dei video
struct VideoCardView: View {
    let video: Video
    @State private var isShowingPlayer = false
    
    var body: some View {
        Button(action: {
            isShowingPlayer = true
        }) {
            VStack(alignment: .leading) {
                // Preview placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fit)
                    
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
                
                // Titolo
                Text(video.fields.Title ?? "Senza titolo")
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
            }
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $isShowingPlayer) {
            if let attachment = video.fields.Segno?.first, let url = URL(string: attachment.url) {
                VideoPlayer(player: AVPlayer(url: url))
                    .edgesIgnoringSafeArea(.all)
            } else {
                Text("Video non disponibile")
                    .padding()
            }
        }
    }
}

struct VideoCardView_Previews: PreviewProvider {
    static var previews: some View {
        // Crea un singolo oggetto Video di esempio (mock)
        let mockVideo = Video(
            id: "mockVideo123",
            fields: VideoFields(
                Title: "Titolo Video di Prova",
                Tags: ["Prova", "Tutorial"],
                Segno: [
                    Attachment(
                        id: "att_mock123",
                        url: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4", // URL di un video di prova pubblico
                        filename: "sample_video.mp4",
                        type: "video/mp4"
                    )
                ]
            )
        )

        VideoCardView(video: mockVideo)
            .previewLayout(.fixed(width: 200, height: 200)) // Dimensioni fisse per una singola card
            .padding() // Aggiungi un po' di padding per visualizzare meglio
            .previewDisplayName("Video Card") // Nome più descrittivo per la preview
    }
}
