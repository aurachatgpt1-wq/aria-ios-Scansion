//
//  ResponsePanelView.swift
//  Aria_v1.0
//
//  Created by Giovanni Michele on 11/12/25.
//

import SwiftUI
import UIKit



// MARK: - Mic Bar

struct MicBarView: View {
    @Binding var isPresented: Bool
    @Binding var transcription: String
    var speechRecognizer: SpeechRecognizer

    var onSend: (String) -> Void
    var onClose: () -> Void

    var body: some View {
        if isPresented {
            HStack(spacing: 12) {
                TextField(
                    "",
                    text: $transcription,
                    prompt: Text("Type or press and hold...").foregroundColor(.black.opacity(0.5))
                )
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .glassEffect()
                .clipShape(Capsule())
                .foregroundColor(.black)

                ZStack {
                    if !transcription.isEmpty && !speechRecognizer.isRecording {
                        Button {
                            let text = transcription
                            transcription = ""
                            speechRecognizer.transcript = ""
                            onSend(text)
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                                .background(Circle().fill(Color.blue))
                                .shadow(radius: 5)
                        }
                        .transition(.scale)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(speechRecognizer.isRecording ? Color.red : Color.blue))
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if !speechRecognizer.isRecording { speechRecognizer.startRecording() }
                                        if !speechRecognizer.transcript.isEmpty { transcription = speechRecognizer.transcript }
                                    }
                                    .onEnded { _ in
                                        speechRecognizer.stopRecording()
                                        if !speechRecognizer.transcript.isEmpty { transcription = speechRecognizer.transcript }
                                    }
                            )
                            .transition(.scale)
                    }
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.red)
                        .clipShape(Circle())
                }
            }
            .padding(12)
            .glassEffect(.clear)
            .clipShape(RoundedRectangle(cornerRadius: 35))
            .shadow(radius: 15, y: 10)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(1)
        }
    }
}

struct MicBarInlineView: View {
    @Binding var transcription: String
    var speechRecognizer: SpeechRecognizer
    var onSend: (String) -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField(
                "",
                text: $transcription,
                prompt: Text("Type or press and hold...").foregroundColor(.white.opacity(0.5))
            )
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .glassEffect(.clear)

            .foregroundColor(.white)

            ZStack {
                if !transcription.isEmpty && !speechRecognizer.isRecording {
                    Button {
                        let text = transcription
                        transcription = ""
                        speechRecognizer.transcript = ""
                        onSend(text)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.blue))
                            .glassEffect()
                            .shadow(radius: 5)
                    }
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(speechRecognizer.isRecording ? Color.red : Color.blue))
                        .glassEffect()
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !speechRecognizer.isRecording { speechRecognizer.startRecording() }
                                    if !speechRecognizer.transcript.isEmpty { transcription = speechRecognizer.transcript }
                                }
                                .onEnded { _ in
                                    speechRecognizer.stopRecording()
                                    if !speechRecognizer.transcript.isEmpty { transcription = speechRecognizer.transcript }
                                }
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }
}



// MARK: - Reports list

struct ReportsListView: View {
    var reportManager: ReportManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(reportManager.chats) { report in
                    NavigationLink {
                        ReportDetailView(report: report)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(report.objectName)
                                .font(.headline)
                                .lineLimit(1)

                            Text(report.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Divider()

                            Text("Q: \(report.prompt)")
                                .font(.caption)
                                .italic()
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let report = reportManager.chats[index]
                        reportManager.deleteChat(report)
                    }
                }
            }
            .navigationTitle("Historical Report")
            .toolbar {
                Button("Chiudi") { dismiss() }
            }
            .overlay {
                if reportManager.chats.isEmpty {
                    ContentUnavailableView(
                        "No Report Saved",
                        systemImage: "tray",
                        description: Text("Save generated reports to view them here.")
                    )
                }
            }
        }
    }
}
