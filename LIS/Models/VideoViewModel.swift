//
//  VideoViewModel.swift
//  LIS
//
//  Created by Michele Mariniello on 23/05/25.
//

import Foundation
import SwiftUI

class VideoViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published var selectedCategory: String? = nil
    
    // Mappa per raggruppare i video per lettera iniziale
    @Published var videosByLetter: [String: [Video]] = [:]
    // Array delle lettere disponibili, ordinate alfabeticamente
    @Published var availableLetters: [String] = []
    
    private let baseID = "appqb5aHMDsKPQZdI"
    private let tableName = "Videos"
    private let apiKey = "patME7YvFXBbm1l1q.6e72c32928ce37e19811a3e630ecce2c39be4671bbe5ab3bd1189087827bad1c"
    
    var filteredVideos: [Video] {
        if searchText.isEmpty {
            return videos
        } else {
            return videos.filter { video in
                // Cerca nel titolo
                let titleMatch = video.fields.Title?.localizedCaseInsensitiveContains(searchText) ?? false
                
                // Cerca nei tag
                let tagMatch = video.fields.Tags?.contains { tag in
                    tag.localizedCaseInsensitiveContains(searchText)
                } ?? false
                
                // Ritorna true se corrisponde al titolo o ai tag
                return titleMatch || tagMatch
            }
        }
    }
    
    // Raggruppa i video per lettera iniziale
    func organizeVideosByLetter() {
        var tempGrouping: [String: [Video]] = [:]
        
        for video in videos {
            if let title = video.fields.Title, !title.isEmpty {
                // Prendi il primo carattere e convertilo in maiuscolo
                let firstChar = String(title.prefix(1)).uppercased()
                
                // Se la chiave non esiste, crea un nuovo array
                if tempGrouping[firstChar] == nil {
                    tempGrouping[firstChar] = [video]
                } else {
                    // Altrimenti, aggiungi il video all'array esistente
                    tempGrouping[firstChar]!.append(video)
                }
            } else {
                // Per i video senza titolo, li mettiamo in una categoria "#"
                let category = "#"
                if tempGrouping[category] == nil {
                    tempGrouping[category] = [video]
                } else {
                    tempGrouping[category]!.append(video)
                }
            }
        }
        
        // Ordina le lettere alfabeticamente, mettendo "#" alla fine se presente
        let sortedKeys = tempGrouping.keys.sorted { key1, key2 in
            if key1 == "#" { return false }
            if key2 == "#" { return true }
            return key1 < key2
        }
        
        self.availableLetters = sortedKeys
        self.videosByLetter = tempGrouping
    }
    
    func performSearch() {
        // Qui possiamo aggiungere logica aggiuntiva per la ricerca se necessario
        isSearching = true
        // Simuliamo un breve ritardo per mostrare l'animazione di ricerca
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isSearching = false
        }
    }
    
    func fetchVideos() {
        guard let url = URL(string: "https://api.airtable.com/v0/\(baseID)/\(tableName)") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                print("Nessun dato ricevuto")
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode(VideoResponse.self, from: data)
                DispatchQueue.main.async {
                    self.videos = decoded.records
                    self.organizeVideosByLetter()
                }
            } catch {
                print("Errore decoding: \(error)")
                
                // Debug: se c'è un errore, prova a capire quale campo non funziona
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    print("Struttura JSON: \(json ?? [:])")
                } catch {
                    print("Errore nel parsare il JSON: \(error)")
                }
            }
        }.resume()
    }
}
