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
    @Binding var isUploading: Bool

    @State private var suggestedTitle: String = ""
    @State private var userEmail: String = ""
    @State private var uploadProgress: Double = 0.0 // Progresso di caricamento ad Airtable
    @State private var currentStep: String = "Pronto per l'invio ad Airtable..." // Messaggio di stato
    @State private var errorMessage: String? = nil // Per mostrare errori all'utente

    @Environment(\.dismiss) var dismiss // Per chiudere la sheet SwiftUI

    // --- SOSTITUISCI QUESTI CON I TUOI DATI AIRTABLE ---
    private let airtableBaseID = "appqb5aHMDsKPQZdI" // Il tuo Base ID di Airtable
    private let airtableTableName = "Video in Attesa di Approvazione" // Il nome esatto della tabella creata nel Punto 1
    // ATTENZIONE: Usare la chiave API direttamente nel codice client NON è la pratica più sicura
    // per un'app pubblica. Per test/prototipi va bene, ma per produzione valuta un backend serverless.
    // Assicurati che questa API Key abbia solo permessi di scrittura sulla tabella "Video in Attesa di Approvazione".
    private let airtableAPIKey = "patME7YvFXBbm1l1q.6e72c32928ce37e19811a3e630ecce2c39be4671bbe5ab3bd1189087827bad1c" // La tua API Key Airtable
    // ---------------------------------------------------

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

    // Funzione asincrona che gestisce il processo di upload
    private func handleVideoUpload() async {
        guard let videoURL = videoURL else {
            errorMessage = "Nessun video selezionato."
            return
        }

        isUploading = true // Imposta lo stato di caricamento
        errorMessage = nil // Resetta eventuali errori precedenti

        do {
            // Invio del file video e dei dati ad Airtable
            self.currentStep = "Invio video e dati ad Airtable..."
            try await createAirtableReviewRecordWithVideo(videoURL: videoURL, title: suggestedTitle, email: userEmail)

            self.currentStep = "Completato!"
            onUploadComplete(true, "Video inviato con successo per la revisione!") // Invia feedback a ContentView
            dismiss() // Chiude la sheet dopo il successo

        } catch {
            self.errorMessage = "Errore durante l'invio: \(error.localizedDescription)"
            onUploadComplete(false, "Errore durante l'invio del video.") // Invia feedback di errore
            print("Upload Error: \(error.localizedDescription)")
        }
        isUploading = false // Termina lo stato di caricamento
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
