//
//  ReportListView.swift
//  Aria_v1.0
//
//  Created by Giovanni Michele on 11/12/25.
//


import SwiftUI

struct ReportDetailView: View {
    let report: Report
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Intestazione
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.objectName)
                        .font(.title2.bold())
                    Text(report.createdAt.formatted(date: .long, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Conversazione “a bolle”
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(parsedMessages) { msg in
                        if msg.role == .user {
                            PromptCard(text: msg.content)
                        } else {
                            ResponseCard(text: msg.content)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Parsing

    private var parsedMessages: [ParsedChatItem] {
        // 1) Prova a parsare lo storico con tag (📩 ME / 💬 ARIA)
        let parsed = parseConversation(from: report.response)

        // 2) Se nello storico non c’è nessun messaggio user,
        //    fallback: usa report.prompt come domanda utente + response come risposta
        let hasUser = parsed.contains(where: { $0.role == .user })
        if hasUser { return parsed }

        var out: [ParsedChatItem] = []

        let prompt = report.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prompt.isEmpty {
            out.append(.init(role: .user, content: prompt))
        }

        // Se parsed contiene già qualcosa (es. solo ARIA taggato) usalo,
        // altrimenti usa response “raw” come assistant.
        if !parsed.isEmpty {
            out.append(contentsOf: parsed)
        } else {
            let resp = report.response.trimmingCharacters(in: .whitespacesAndNewlines)
            if !resp.isEmpty {
                out.append(.init(role: .assistant, content: resp))
            }
        }

        return out
    }

    private func parseConversation(from fullText: String) -> [ParsedChatItem] {
        var out: [ParsedChatItem] = []

        // Split per linee (robusto per multi-linea) [web:7][web:10]
        let lines = fullText.components(separatedBy: .newlines)

        let userTags = ["📩 ME:", "📩 TU:", "ME:", "YOU:", "USER:"]
        let assistantTags = ["💬 ARIA:", "ARIA:", "ASSISTANT:", "AI:"]

        func stripPrefix(_ line: String, prefixes: [String]) -> String? {
            for p in prefixes where line.hasPrefix(p) {
                return line.replacingOccurrences(of: p, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        }

        var currentRole: ChatRole?
        var currentContent = ""

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            // ignora separatori
            if line == "________________" { continue }

            if let userText = stripPrefix(line, prefixes: userTags) {
                if let role = currentRole, !currentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    out.append(.init(role: role, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentRole = .user
                currentContent = userText
                continue
            }

            if let assistantText = stripPrefix(line, prefixes: assistantTags) {
                if let role = currentRole, !currentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    out.append(.init(role: role, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                currentRole = .assistant
                currentContent = assistantText
                continue
            }

            // Continuazione testo (mantiene newline interni)
            if currentRole != nil {
                if !line.isEmpty {
                    currentContent += (currentContent.isEmpty ? "" : "\n") + rawLine
                }
            }
        }

        if let role = currentRole, !currentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out.append(.init(role: role, content: currentContent.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        return out
    }

    // MARK: - UI Cards
    
    private struct PromptCard: View {
        let text: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Label("My request", systemImage: "person.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
                
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    private struct ResponseCard: View {
        let text: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Label("Aria Response", systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(.purple)
                
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.purple.opacity(0.20), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Parsed model
    
    private struct ParsedChatItem: Identifiable {
        let id = UUID()
        let role: ChatRole
        let content: String
    }
}
