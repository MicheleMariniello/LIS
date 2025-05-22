//
//  VideoUploadView.swift
//  LIS
//
//  Created by Michele Mariniello on 22/05/25.
//

import Foundation
import SwiftUI
import AVFoundation // Non per compressione qui, ma potrebbe servire per altre manipolazioni future se volessi
import Photos // Per gestire i file media dal device

struct VideoUploadView: View {
    // L'URL temporaneo del video selezionato da ImagePicker/VideoPicker
    @Binding var videoURL: URL?
    // Callback per informare ContentView dell'esito dell'upload
    var onUploadComplete: (Bool, String) -> Void
    // Binding per indicare lo stato di caricamento (mostra un ProgressView)
    
    @State private var isUploading: Bool = false
    @State private var suggestedTitle: String = ""
    @State private var userEmail: String = ""
    @State private var uploadProgress: Double = 0.0 // Progresso di caricamento ad Airtable
    @State private var currentStep: String = "Pronto per l'invio ad Airtable..." // Messaggio di stato
    @State private var errorMessage: String? = nil // Per mostrare errori all'utente

    @State private var compressionProgress: Double = 0.0 // Progresso della compressione video (0.0 a 1.0)
    
    @Environment(\.dismiss) var dismiss // Per chiudere la sheet SwiftUI

    // ---DATI AIRTABLE ---
    private let airtableBaseID = "appqb5aHMDsKPQZdI" // Il tuo Base ID di Airtable
    private let airtableTableName = "Video in Attesa di Approvazione" // Il nome esatto della tabella creata nel Punto 1
    // ATTENZIONE: Usare la chiave API direttamente nel codice client NON è la pratica più sicura
    // per un'app pubblica. Per test/prototipi va bene, ma per produzione valuta un backend serverless.
    // Assicurati che questa API Key abbia solo permessi di scrittura sulla tabella "Video in Attesa di Approvazione".
    private let airtableAPIKey = "patME7YvFXBbm1l1q.6e72c32928ce37e19811a3e630ecce2c39be4671bbe5ab3bd1189087827bad1c" // La tua API Key Airtable
    // ---------------------------------------------------
    
    // ---VARIABILI CLOUDINARY ---
    private let cloudinaryCloudName = "dpdus5caf" // !!! SOSTITUISCI QUI CON IL TUO CLOUD NAME VERO !!!
    private let cloudinaryUploadPreset = "video_upload_preset" // !!! SOSTITUISCI QUI CON IL NOME DEL TUO UPLOAD PRESET VERO !!!
    // ------------------------------------

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dettagli Video")) {
                    TextField("Titolo suggerito", text: $suggestedTitle)
                        .disableAutocorrection(true)
                        .autocapitalization(.sentences) // Capitale la prima lettera automaticamente
                    TextField("La tua email (opzionale)", text: $userEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none) // Non capitale, tipico delle email
                        .disableAutocorrection(true)
                }

                Section(header: Text("Stato Caricamento")) {
                    if isUploading {
                        VStack(alignment: .leading) {
                            Text(currentStep)
                                .font(.caption)
                                .foregroundColor(.gray)
                            ProgressView(value: uploadProgress)
                                .progressViewStyle(.linear)
                            Text("Caricamento: \(Int(uploadProgress * 100))%")
                                .font(.footnote)
                        }
                    } else {
                        Text("Pronto per l'invio.")
                    }

                    if let error = errorMessage {
                        Text("Errore: \(error)")
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: {
                        Task { // SwiftUI task per eseguire operazioni asincrone
                            await handleVideoUpload()
                        }
                    }) {
                        Text(isUploading ? "Caricamento in corso..." : "Invia Video per Revisione")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isUploading || videoURL == nil) // Disabilita il pulsante se già in upload o se nessun video è selezionato
                    .font(.headline)
                    .padding(.vertical, 8)
                    .background(isUploading || videoURL == nil ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)

                    Button("Annulla") {
                        dismiss() // Chiude la sheet
                        videoURL = nil // Resetta l'URL del video selezionato per evitare riutilizzi indesiderati
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Invia Video")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    
    // Funzione per comprimere il video
    private func compressVideo(originalURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let asset = AVAsset(url: originalURL)
            // Scegli la qualità di compressione: MediumQuality è un buon compromesso
            // Puoi provare HighestQuality per la massima fedeltà, ma files più grandi.
            let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality)!

            // Crea un URL temporaneo dove salvare il video compresso
            let tempDirectory = FileManager.default.temporaryDirectory
            let outputURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")

            exportSession.outputURL = outputURL
            exportSession.outputFileType = .mov // Puoi usare anche .mp4 se preferisci, ma .mov è comune su iOS

            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? NSError(domain: "VideoCompression", code: 0, userInfo: [NSLocalizedDescriptionKey: "Errore sconosciuto nella compressione video"]))
                case .cancelled:
                    continuation.resume(throwing: NSError(domain: "VideoCompression", code: 0, userInfo: [NSLocalizedDescriptionKey: "Compressione video annullata"]))
                default:
                    // Per altri stati come .waiting, .exporting, .unknown, non facciamo nulla qui.
                    // Il continuation attende il completamento, fallimento o annullamento.
                    break
                }
            }
        }
    }
    
    // Funzione per caricare il video su Cloudinary
    private func uploadVideoToCloudinary(fileURL: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            // Controlla che il tuo Cloud Name sia valido e formi un URL corretto
            guard let uploadURL = URL(string: "https://api.cloudinary.com/v1_1/\(cloudinaryCloudName)/video/upload") else {
                continuation.resume(throwing: NSError(domain: "CloudinaryAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "URL Cloudinary per l'upload non valido."]))
                return
            }

            var request = URLRequest(url: uploadURL)
            request.httpMethod = "POST"

            // Usiamo multipart/form-data per inviare il file
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            var body = Data()

            // Aggiungi il campo 'upload_preset' (il nome del preset unsigned che hai creato)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(cloudinaryUploadPreset)\r\n".data(using: .utf8)!)

            // Aggiungi il file video stesso
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
            // Puoi provare a dedurre il MIME type, ma video/quicktime o video/mp4 sono spesso usati.
            body.append("Content-Type: video/quicktime\r\n\r\n".data(using: .utf8)!)
            do {
                let videoData = try Data(contentsOf: fileURL)
                body.append(videoData)
                body.append("\r\n".data(using: .utf8)!)
            } catch {
                continuation.resume(throwing: error)
                return
            }

            // Chiudi il body della richiesta
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async { // Assicurati che la gestione della risposta avvenga sul main thread
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    // Tentativo di parsare la risposta JSON di Cloudinary
                    guard let data = data,
                          let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let secureURLString = json["secure_url"] as? String, // Cloudinary restituisce l'URL finale qui
                          let secureURL = URL(string: secureURLString) else {
                        let responseString = data.map { String(data: $0, encoding: .utf8) } ?? "No response body"
                        continuation.resume(throwing: NSError(domain: "CloudinaryAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Risposta Cloudinary non valida o URL mancante. Risposta: \(responseString)"]))
                        return
                    }

                    continuation.resume(returning: secureURL) // Restituisce l'URL pubblico del video
                }
            }
            task.resume() // Avvia la richiesta di upload
        }
    }
    
    // Funzione asincrona che gestisce il processo di upload
    // Funzione principale che gestisce il processo di caricamento del video
        private func handleVideoUpload() async {
            guard let videoURL = videoURL else {
                errorMessage = "Nessun video selezionato."
                return
            }

            // Imposta lo stato di caricamento e resetta gli errori
            isUploading = true
            errorMessage = nil

            do {
                // 1. Compressione del video (opzionale ma consigliata per ridurre le dimensioni)
                // Aggiorna lo stato per l'utente
                self.currentStep = "Compressione video..."
                // Chiama la funzione di compressione
                let compressedURL = try await compressVideo(originalURL: videoURL)
                // Aggiorna la UI per mostrare che la compressione è completa
                DispatchQueue.main.async {
                    self.compressionProgress = 1.0 // Imposta il progresso a 1.0 al completamento della compressione
                }


                // 2. Upload del video compresso su Cloudinary
                self.currentStep = "Caricamento video su Cloudinary..."
                // Chiama la funzione di upload su Cloudinary
                let cloudinaryPublicURL = try await uploadVideoToCloudinary(fileURL: compressedURL)
                // Aggiorna la UI per mostrare che l'upload Cloudinary è completo
                DispatchQueue.main.async {
                     self.uploadProgress = 1.0 // Imposta il progresso a 1.0 al completamento dell'upload Cloudinary
                }


                // 3. Invio dell'URL pubblico di Cloudinary e dei dati ad Airtable
                self.currentStep = "Invio dati ad Airtable..."
                // Chiama la funzione Airtable, passando l'URL pubblico di Cloudinary
                try await createAirtableReviewRecordWithVideo(videoURL: cloudinaryPublicURL, title: suggestedTitle, email: userEmail)


                // Se tutto va a buon fine
                self.currentStep = "Completato!"
                onUploadComplete(true, "Video inviato con successo per la revisione!") // Invia feedback a ContentView
                dismiss() // Chiude la sheet dopo il successo

            } catch {
                // Gestione degli errori
                self.errorMessage = "Errore durante l'invio: \(error.localizedDescription)"
                onUploadComplete(false, "Errore durante l'invio del video.") // Invia feedback di errore
                print("Upload Error: \(error.localizedDescription)")
            }
            // Imposta lo stato di caricamento a falso sia in caso di successo che di errore
            isUploading = false
        }

    // MARK: - Creazione Record Airtable con File Video

    private func createAirtableReviewRecordWithVideo(videoURL: URL, title: String, email: String) async throws {
        // Utilizziamo un CheckedContinuation per convertire un'API basata su callback (URLSession)
        // in una funzione asincrona (async/await).
        return try await withCheckedThrowingContinuation { continuation in
            guard let url = URL(string: "https://api.airtable.com/v0/\(airtableBaseID)/\(airtableTableName)") else {
                continuation.resume(throwing: NSError(domain: "AirtableAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "URL Airtable non valido."]))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(airtableAPIKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Preparo il JSON per il record. Airtable accetta un URL per il campo Attachment.
            // Quando l'URL è un 'file://' locale, Airtable lo legge e lo carica nei suoi storage.
            let record: [String: Any] = [
                "fields": [
                    "Titolo Proposto": title.isEmpty ? "Video senza titolo" : title,
                    "Email Mittente": email,
                    "Stato": "In Attesa",
                    "Allegato Video": [ // Il campo "Attachment" di Airtable si aspetta un array di oggetti
                        [
                            "url": videoURL.absoluteString // Qui passiamo l'URL completo del file locale
                        ]
                    ]
                ]
            ]

            do {
                let jsonData = try JSONSerialization.data(withJSONObject: record, options: [])
                request.httpBody = jsonData

                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    // Il codice qui viene eseguito al termine della richiesta HTTP
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.resume(throwing: NSError(domain: "AirtableAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Risposta HTTP non valida."]))
                        return
                    }

                    if httpResponse.statusCode == 200 { // Airtable restituisce 200 OK per una creazione record di successo
                        continuation.resume(returning: ()) // Segnala il successo
                    } else {
                        // C'è stato un errore da Airtable, recuperiamo il codice di stato e il corpo della risposta per il debug
                        let statusCode = httpResponse.statusCode
                        let responseBody = data.map { String(data: $0, encoding: .utf8) } ?? "Nessun corpo di risposta"
                        continuation.resume(throwing: NSError(domain: "AirtableAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Errore Airtable (Status Code: \(statusCode)). Risposta: \(String(describing: responseBody))"]))
                    }
                }

                // Airtable non fornisce un callback di progresso mentre carica il file dal tuo URL.
                // Quindi, simuleremo un progresso basato su un tempo stimato.
                let simulatedUploadDuration: TimeInterval = 3.0 // Stima 3 secondi per un video di 3s
                let startTime = Date()
                _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                    let elapsed = Date().timeIntervalSince(startTime)
                    DispatchQueue.main.async {
                        self.uploadProgress = min(elapsed / simulatedUploadDuration, 0.99) // Progresso fino al 99%
                        if self.uploadProgress >= 0.99 {
                            timer.invalidate() // Ferma il timer quando quasi completo
                        }
                    }
                }

                task.resume() // Avvia la richiesta HTTP
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}


