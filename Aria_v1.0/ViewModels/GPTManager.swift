//
//  Report.swift
//  Aria_v1.0
//
//  Created by Giovanni Michele on 11/12/25.
//
import Foundation


final class ThreadStore {
    static let shared = ThreadStore()
    private let key = "aria_thread_map"

    private func load() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return map
    }

    private func save(_ map: [String: String]) {
        let data = try? JSONEncoder().encode(map)
        UserDefaults.standard.setValue(data, forKey: key)
    }

    func threadId(for machineKey: String) -> String? {
        load()[machineKey]
    }

    func setThreadId(_ threadId: String?, for machineKey: String) {
        var map = load()
        map[machineKey] = threadId
        if threadId == nil { map.removeValue(forKey: machineKey) }
        save(map)
    }
}


// MARK: - OpenAI Assistants Service (Threads/Messages/Runs)

final class OpenAIAssistantsService {

    private let apiKey: String
    private let baseURL = URL(string: "https://api.openai.com/v1")!
    private let assistantId: String

    init(apiKey: String, assistantId: String) {
        self.apiKey = apiKey
        self.assistantId = assistantId
    }

    // MARK: Models

    struct CreateThreadResponse: Decodable { let id: String }

    struct CreateRunResponse: Decodable {
        let id: String
        let status: String
    }

    struct RetrieveRunResponse: Decodable {
        let id: String
        let status: String
    }

    struct ListMessagesResponse: Decodable {
        let data: [ThreadMessage]
    }

    struct ThreadMessage: Decodable {
        let role: String
        let content: [ContentPart]
    }

    struct ContentPart: Decodable {
        let type: String
        let text: TextValue?

        struct TextValue: Decodable { let value: String }
    }

    // MARK: Public API

    func createThread() async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("threads"))
        req.httpMethod = "POST"
        addHeaders(&req)
        req.httpBody = try JSONSerialization.data(withJSONObject: [:])

        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(CreateThreadResponse.self, from: data).id
    }

    func addUserMessage(threadId: String, text: String) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("threads/\(threadId)/messages"))
        req.httpMethod = "POST"
        addHeaders(&req)

        let body: [String: Any] = [
            "role": "user",
            "content": text
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response: response, data: data)
    }

    func createRun(threadId: String) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("threads/\(threadId)/runs"))
        req.httpMethod = "POST"
        addHeaders(&req)

        let body: [String: Any] = [
            "assistant_id": assistantId
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(CreateRunResponse.self, from: data).id
    }

    func pollRunUntilCompleted(threadId: String, runId: String) async throws {
        while true {
            try await Task.sleep(nanoseconds: 400_000_000) // 0.4s

            var req = URLRequest(url: baseURL.appendingPathComponent("threads/\(threadId)/runs/\(runId)"))
            req.httpMethod = "GET"
            addHeaders(&req)

            let (data, response) = try await URLSession.shared.data(for: req)
            try validate(response: response, data: data)

            let run = try JSONDecoder().decode(RetrieveRunResponse.self, from: data)

            if run.status == "completed" { return }
            if run.status == "failed" || run.status == "cancelled" || run.status == "expired" {
                throw URLError(.cannotParseResponse)
            }
        }
    }

    func fetchLatestAssistantText(threadId: String) async throws -> String? {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("threads/\(threadId)/messages"),
            resolvingAgainstBaseURL: false
        )!

        comps.queryItems = [
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "limit", value: "10")
        ]

        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        addHeaders(&req)

        let (data, response) = try await URLSession.shared.data(for: req)
        try validate(response: response, data: data)

        let list = try JSONDecoder().decode(ListMessagesResponse.self, from: data)

        for msg in list.data where msg.role == "assistant" {
            if let text = msg.content.first(where: { $0.type == "text" })?.text?.value {
                return text
            }
        }
        return nil
    }

    // MARK: Helpers

    private func addHeaders(_ req: inout URLRequest) {
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }
}
