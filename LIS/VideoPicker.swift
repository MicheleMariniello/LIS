//
//  VideoPicker.swift
//  LIS
//
//  Created by Michele Mariniello on 22/05/25.
//

import Foundation
import SwiftUI
import PhotosUI // Import necessario per PHPickerViewController
import UniformTypeIdentifiers // Import necessario per UTType (identificatori di tipo universali)

// Marca questa struct come disponibile solo da iOS 14 in poi
@available(iOS 14, *)
struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?
    @Binding var showingSheet: Bool

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos // Filtra la libreria per mostrare solo i video
        configuration.selectionLimit = 1 // Permetti la selezione di un solo video

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator // Il delegato gestirà gli eventi del picker
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: VideoPicker

        init(_ parent: VideoPicker) {
            self.parent = parent
        }

        // Questo metodo viene chiamato quando l'utente finisce di selezionare media
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Prendi il primo (e unico) risultato
            guard let itemProvider = results.first?.itemProvider else {
                parent.showingSheet = false // Nessun video selezionato, chiudi la sheet
                return
            }

            // Verifica se l'itemProvider può caricare un file video
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                // Carica il video come rappresentazione di file.
                // Questo potrebbe richiedere tempo per file grandi.
                itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    if let url = url {
                        // PHPickerViewController fornisce un URL temporaneo che potremmo dover copiare.
                        // È buona pratica copiarlo in una posizione sicura prima di usarlo.
                        let tempDirectory = FileManager.default.temporaryDirectory
                        let newURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov") // Crea un URL unico nel temp dir

                        do {
                            // Rimuovi il file precedente se esiste già con lo stesso nome (poco probabile con UUID)
                            if FileManager.default.fileExists(atPath: newURL.path) {
                                try FileManager.default.removeItem(at: newURL)
                            }
                            // Copia il file temporaneo fornito dal picker nella nostra posizione temporanea
                            try FileManager.default.copyItem(at: url, to: newURL)

                            DispatchQueue.main.async {
                                self.parent.selectedVideoURL = newURL // Assegna l'URL copiato
                                self.parent.showingSheet = false // Chiudi la sheet del picker
                            }
                        } catch {
                            print("Error copying video file from PHPicker: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                self.parent.showingSheet = false // Chiudi la sheet anche in caso di errore
                            }
                        }
                    } else if let error = error {
                        print("Error loading video file from PHPicker: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.parent.showingSheet = false // Chiudi la sheet in caso di errore
                        }
                    }
                }
            } else {
                // L'itemProvider non contiene un video (es. ha solo foto, anche se filtrato)
                parent.showingSheet = false
            }
        }
    }
}
