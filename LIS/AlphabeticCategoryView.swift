//
//  AlphabeticCategoryView.swift
//  LIS
//
//  Created by Michele Mariniello on 23/05/25.
//

import SwiftUI

// Vista per la sezione di una lettera specifica
struct AlphabeticCategoryView: View {
    let letter: String
    let videos: [Video]
    let onSeeAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(letter)
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: onSeeAll) {
                    Text("Vedi tutti")
                        .foregroundColor(.blue)
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(videos) { video in
                        VideoCardView(video: video)
                            .frame(width: 180)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
}


struct AlphabeticCategoryView_Previews: PreviewProvider {
    static var previews: some View {
        // Crea alcuni dati di esempio (mock) per i video
        let mockVideos: [Video] = [
            Video(id: "1", fields: VideoFields(Title: "Ape", Tags: ["Animale"], Segno: [
                Attachment(id: "att1", url: "https://example.com/video1.mp4", filename: "video1.mp4", type: "video/mp4")
            ])),
            Video(id: "2", fields: VideoFields(Title: "Albero", Tags: ["Natura"], Segno: [
                Attachment(id: "att2", url: "https://example.com/video2.mp4", filename: "video2.mp4", type: "video/mp4")
            ])),
            Video(id: "3", fields: VideoFields(Title: "Acqua", Tags: ["Fluido"], Segno: [
                Attachment(id: "att3", url: "https://example.com/video3.mp4", filename: "video3.mp4", type: "video/mp4")
            ]))
        ]

        AlphabeticCategoryView(
            letter: "A", // Lettera di esempio
            videos: mockVideos, // Passa i video mock
            onSeeAll: {
                print("Azione 'Vedi tutti' eseguita per la lettera A")
                // Qui puoi simulare un cambio di stato nel tuo ViewModel per la preview, se necessario
            }
        )
        .previewLayout(.sizeThatFits) // Adatta la preview al contenuto
        .padding() // Aggiungi un po' di padding per visualizzare meglio
    }
}
