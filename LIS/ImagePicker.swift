//
//  ImagePicker.swift
//  LIS
//
//  Created by Michele Mariniello on 22/05/25.
//

import Foundation
import SwiftUI
import UIKit // Import necessario per UIImagePickerController
import UniformTypeIdentifiers

struct ImagePicker: UIViewControllerRepresentable {
    // Binding per passare l'URL del video selezionato alla ContentView
    @Binding var selectedVideoURL: URL?
    // Binding per controllare la visibilità della sheet
    @Binding var showingSheet: Bool
    // La sorgente (camera o photoLibrary)
    var sourceType: UIImagePickerController.SourceType

    // Questo metodo crea e configura il controller UIKit
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        // MODIFICA QUESTA RIGA:
        picker.mediaTypes = [UTType.movie.identifier] // Usa UTType.movie.identifier
        picker.allowsEditing = true
        
        // >>> AGGIUNGI QUESTA RIGA PER LA QUALITÀ VIDEO <<<
        picker.videoQuality = .typeHigh // O .type640x480, .typeMedium, .typeLow, .typeIFrame960x540, .typeIFrame1280x720, .typeIFrame1920x1080 (se disponibili)
        
        return picker
    }

    // Questo metodo viene chiamato quando la view SwiftUI si aggiorna, ma non faremo nulla qui
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // Questo metodo crea un coordinatore per gestire gli eventi del picker
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Il Coordinator è una classe annidata che agisce come delegato per UIImagePickerController
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker // Riferimento alla vista SwiftUI padre

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        // Questo metodo viene chiamato quando l'utente finisce di selezionare/registrare un media
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                parent.selectedVideoURL = videoURL // Assegna l'URL del video alla binding property
            }
            parent.showingSheet = false // Chiudi la sheet del picker
        }

        // Questo metodo viene chiamato se l'utente annulla il picker
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.showingSheet = false // Chiudi la sheet del picker
        }
    }
}
