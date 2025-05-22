//
//  CategoryDetailView.swift
//  LIS
//
//  Created by Michele Mariniello on 23/05/25.
//

import SwiftUI

// Vista dettaglio di una categoria
struct CategoryDetailView: View {
    let letter: String
    let videos: [Video]
    let onBack: () -> Void
    
    // Definiamo il numero di colonne per la griglia
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(action: onBack) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Indietro")
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("Categoria \(letter)")
                    .font(.headline)
                
                Spacer()
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(videos) { video in
                        VideoCardView(video: video)
                    }
                }
                .padding()
            }
        }
    }
}

struct CategoryDetailView_Previews: PreviewProvider {
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
            ])),
            Video(id: "4", fields: VideoFields(Title: "Anatra", Tags: ["Animale"], Segno: [
                Attachment(id: "att4", url: "https://example.com/video4.mp4", filename: "video4.mp4", type: "video/mp4")
            ])),
            Video(id: "5", fields: VideoFields(Title: "Aereo", Tags: ["Trasporto"], Segno: [
                Attachment(id: "att5", url: "https://example.com/video5.mp4", filename: "video5.mp4", type: "video/mp4")
            ]))
        ]

        CategoryDetailView(
            letter: "A", // Lettera di esempio
            videos: mockVideos, // Passa i video mock
            onBack: {
                print("Azione 'Indietro' eseguita")
                // Qui puoi simulare la chiusura della vista, se necessario
            }
        )
        // Puoi avvolgerla in una NavigationView per simulare la barra di navigazione
        // .previewLayout(.sizeThatFits) // Adatta la preview al contenuto
        // .padding() // Aggiungi un po' di padding per visualizzare meglio
    }
}
