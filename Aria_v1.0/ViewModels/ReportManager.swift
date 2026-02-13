
//
//  ReportManager.swift
//  Aria_v1.0
//
//  Created by Giovanni Michele on 11/12/25.
//
import Foundation
import SwiftUI

@Observable
final class ReportManager {

    private(set) var chats: [Report] = []

    private let fileName = "aria_reports.json"

    init() {
        load()
    }

    func saveSession(id: UUID, objectName: String, prompt: String, response: String) {
        let report = Report(
            id: id,
            objectName: objectName,
            createdAt: Date(),
            prompt: prompt,
            response: response
        )
        chats.insert(report, at: 0)
        persist()
    }

    func deleteChat(_ report: Report) {
        chats.removeAll { $0.id == report.id }
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let url = try fileURL()
            let data = try JSONEncoder().encode(chats)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("❌ Persist error:", error)
        }
    }

    private func load() {
        do {
            let url = try fileURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let data = try Data(contentsOf: url)
            chats = try JSONDecoder().decode([Report].self, from: data)
        } catch {
            print("❌ Load error:", error)
        }
    }

    private func fileURL() throws -> URL {
        let dir = try FileManager.default.url(for: .documentDirectory,
                                             in: .userDomainMask,
                                             appropriateFor: nil,
                                             create: true)
        return dir.appendingPathComponent(fileName)
    }
}
