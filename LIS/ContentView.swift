//
//  ContentView.swift
//  LIS
//
//  Created by Michele Mariniello on 21/05/25.
//

import SwiftUI
import AVKit
import PhotosUI // Fondamentale per PHPickerViewController (il picker video/foto moderno di iOS)
import UniformTypeIdentifiers // Necessario con PhotosUI per specificare i tipi di media (video)
// Non avrai più bisogno di import MessageUI se non invii email dall'app

struct Video: Identifiable, Decodable {
    let id: String
    let fields: VideoFields
}

// Struttura per gli allegati (attachments) di Airtable
struct Attachment: Decodable {
    let id: String
    let url: String
    let filename: String
    let type: String
}

struct VideoFields: Decodable {
    let Title: String?
    // Aggiungiamo il campo Tags
    let Tags: [String]?
    // Campo Segno che contiene gli allegati video
    let Segno: [Attachment]?
}

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

struct VideoResponse: Decodable {
    let records: [Video]
}

struct ContentView: View {
    @StateObject private var viewModel = VideoViewModel()
    // Definiamo il numero di colonne per la griglia
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    // NUOVI STATI PER LA FUNZIONALITÀ DI UPLOAD
    @State private var showingVideoSourceActionSheet = false // Controlla la visibilità dell'action sheet (registra/scegli)
    @State private var showingImagePicker = false // Controlla la visibilità del picker (fotocamera/galleria)
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary // Determina la sorgente del picker
    @State private var selectedVideoURL: URL? = nil // Contiene l'URL del video selezionato/registrato
    @State private var showingVideoUploadSheet = false // Controlla la visibilità della form di upload
    @State private var isUploading = false // Indica se l'upload è in corso
    @State private var uploadStatusMessage: String? = nil // Messaggio di stato per l'utente (es. "Upload completato!")
    // Fine NUOVI STATI
    
    var body: some View {
        NavigationView {
            VStack {
                // Barra di ricerca
                HStack {
                    TextField("Cerca video...", text: $viewModel.searchText)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.leading)
                        .submitLabel(.search)
                        .onSubmit {
                            viewModel.performSearch()
                        }
                    
                    Button(action: {
                        viewModel.performSearch()
                    }) {
                        Image(systemName: "magnifyingglass")
                            .padding(10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding(.trailing)
                }
                .padding(.vertical, 8)
                
                if viewModel.isSearching {
                    ProgressView()
                        .padding()
                } else if !viewModel.searchText.isEmpty {
                    // Vista di ricerca: mostra i risultati in una griglia
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(viewModel.filteredVideos) { video in
                                VideoCardView(video: video)
                            }
                        }
                        .padding()
                    }
                } else if let selectedCategory = viewModel.selectedCategory {
                    // Vista dettaglio categoria
                    CategoryDetailView(
                        letter: selectedCategory,
                        videos: viewModel.videosByLetter[selectedCategory] ?? [],
                        onBack: { viewModel.selectedCategory = nil }
                    )
                } else {
                    // Vista principale con categorie alfabetiche
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            ForEach(viewModel.availableLetters, id: \.self) { letter in
                                if let videosForLetter = viewModel.videosByLetter[letter], !videosForLetter.isEmpty {
                                    AlphabeticCategoryView(
                                        letter: letter,
                                        videos: videosForLetter,
                                        onSeeAll: {
                                            viewModel.selectedCategory = letter
                                        }
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Video")
            //Tasto Plus
            .navigationBarItems(trailing:
                                    Button(action: {
                showingVideoSourceActionSheet = true // Quando cliccato, mostra l'action sheet
            }) {
                Image(systemName: "plus.circle.fill") // Icona del pulsante "+"
                    .font(.title2) // Dimensione dell'icona
                    .foregroundColor(.blue) // Colore dell'icona
            }
            )
            //ACTION SHEET
            .actionSheet(isPresented: $showingVideoSourceActionSheet) {
                ActionSheet(
                    title: Text("Seleziona Sorgente Video"),
                    buttons: [
                        .default(Text("Registra Video")) {
                            self.sourceType = .camera // Imposta la sorgente a fotocamera
                            self.showingImagePicker = true // Mostra il picker
                        },
                        .default(Text("Scegli dalla Libreria")) {
                            self.sourceType = .photoLibrary // Imposta la sorgente a libreria
                            self.showingImagePicker = true // Mostra il picker
                        },
                        .cancel() // Pulsante per annullare
                    ]
                )
            }
            //PRESENTAZIONE DEL PICKER
            .sheet(isPresented: $showingImagePicker) {
                // Utilizza PHPickerViewController (iOS 14+) o UIImagePickerController (per compatibilità)
                if sourceType == .photoLibrary {
                    if #available(iOS 14, *) {
                        // iOS 14 e successivi: usa PHPickerViewController
                        VideoPicker(selectedVideoURL: $selectedVideoURL, showingSheet: $showingImagePicker)
                    } else {
                        // iOS precedenti al 14: fallback a UIImagePickerController
                        ImagePicker(selectedVideoURL: $selectedVideoURL, showingSheet: $showingImagePicker, sourceType: .photoLibrary)
                    }
                } else { // sourceType == .camera
                    // Sempre UIImagePickerController per la fotocamera
                    ImagePicker(selectedVideoURL: $selectedVideoURL, showingSheet: $showingImagePicker, sourceType: .camera)
                }
            }
            // Fine: NUOVE RIGHE PER LA PRESENTAZIONE DEL PICKER
            
            // Inizio: NUOVE RIGHE PER OSSERVARE IL VIDEO SELEZIONATO E MOSTRARE LA FORM DI UPLOAD
            .onChange(of: selectedVideoURL) { oldURL, newURL in // Ora ha due parametri: oldURL e newURL
                if newURL != nil {
                    showingVideoUploadSheet = true
                }
            }
            // Fine: NUOVE RIGHE PER OSSERVARE IL VIDEO SELEZIONATO
            
            // Inizio: NUOVE RIGHE PER LA PRESENTAZIONE DELLA FORM DI UPLOAD
            .sheet(isPresented: $showingVideoUploadSheet) {
                VideoUploadView(videoURL: $selectedVideoURL,
                                onUploadComplete: { success, message in
                    self.uploadStatusMessage = message // Salva il messaggio di stato
                    self.isUploading = false // Indica che l'upload è finito
                    if success {
                        // Puoi decidere qui se ricaricare i video principali immediatamente
                        // (dipende se l'automazione di Airtable è istantanea)
                        // viewModel.fetchVideos()
                    }
                }
                )
            }
            .onAppear {
                viewModel.fetchVideos()
            }
        }
    }
}

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

#Preview {
    ContentView()
}
