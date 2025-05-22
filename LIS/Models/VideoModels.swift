//
//  VideoModels.swift
//  LIS
//
//  Created by Michele Mariniello on 23/05/25.
//

import Foundation
import SwiftUI

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

struct VideoResponse: Decodable {
    let records: [Video]
}
