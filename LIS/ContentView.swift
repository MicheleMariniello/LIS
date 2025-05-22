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
                    //                    if success {
                    // Puoi decidere qui se ricaricare i video principali immediatamente
                    // (dipende se l'automazione di Airtable è istantanea)
                    // viewModel.fetchVideos()
                    //                    }
                }
                )
            }
            .onAppear {
                viewModel.fetchVideos()
            }
        }
    }
}

#Preview {
    ContentView()
}
