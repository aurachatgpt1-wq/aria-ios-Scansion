//
//  Report.swift
//  Aria_v1.0
//
//  Created by Giovanni Michele on 11/12/25.
//
import Foundation

// MARK: - ViewModel (Observation macro)

@Observable @MainActor
final class AriaAssistantViewModel {

    // Session/UI
    var isLoading: Bool = false
    var showResponsePanel: Bool = false

    // Chat session state
    var sessionId: UUID? = nil
    var messages: [ChatMessage] = []
    var lastPrompt: String = ""

    @ObservationIgnored private let service: OpenAIAssistantsService
    @ObservationIgnored private let store: ThreadStore

    init(service: OpenAIAssistantsService, store: ThreadStore? = nil) {
        self.service = service
        self.store = store ?? .shared
    }

    func threadId(for machineKey: String) -> String? {
        store.threadId(for: machineKey)
    }

    func resetThread(for machineKey: String) {
        store.setThreadId(nil, for: machineKey)
    }

    func startSessionIfNeeded() {
        if sessionId == nil {
            sessionId = UUID()
            messages.removeAll()
        }
    }

    func resetSession() {
        sessionId = nil
        messages.removeAll()
        isLoading = false
        showResponsePanel = false
        lastPrompt = ""
    }

    func send(prompt: String, machineKey: String) async {
        let clean = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        startSessionIfNeeded()
        lastPrompt = clean

        // 1) Mostra subito il pannello e il messaggio utente
        showResponsePanel = true
        messages.append(ChatMessage(role: .user, content: clean))

        // 2) Aspetta un turno del runloop (così ResponsePanelView viene montata)
        await Task.yield()

        // 3) Ora attiva loading/glow
        isLoading = true
        defer { isLoading = false }

        do {
            let tid = try await getOrCreateThreadId(machineKey: machineKey)
            try await service.addUserMessage(threadId: tid, text: clean)

            let runId = try await service.createRun(threadId: tid)
            try await service.pollRunUntilCompleted(threadId: tid, runId: runId)

            let answer = try await service.fetchLatestAssistantText(threadId: tid)
                ?? "Nessuna risposta generata."

            messages.append(ChatMessage(role: .assistant, content: answer))
        } catch {
            messages.append(ChatMessage(role: .assistant, content: "Errore: \(error.localizedDescription)"))
        }
    }


    func formattedConversation() -> String {
        messages.map { msg in
            switch msg.role {
            case .user: return "📩 TU:\n\(msg.content)"
            case .assistant: return "💬 ARIA:\n\(msg.content)"
            }
        }
        .joined(separator: "\n\n________________\n\n")
    }

    private func getOrCreateThreadId(machineKey: String) async throws -> String {
        if let existing = store.threadId(for: machineKey) { return existing }
        let newId = try await service.createThread()
        store.setThreadId(newId, for: machineKey)
        return newId
    }
}
