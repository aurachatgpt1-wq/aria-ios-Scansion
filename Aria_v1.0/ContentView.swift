//
//  ContentView.swift
//  Aria_v1.0
//
//  Created by Giovanni Michele on 05/12/25.
//


import SwiftUI

struct ContentView: View {

    // UI state
    @State private var showCameraPopup = false
    @State private var showMicBar = false
    @State private var showHistory = false
    @State private var activateTags = false
    
    @State private var isChatMinimized = false

    // Input
    @State private var transcription = ""
    @State private var speechRecognizer = SpeechRecognizer()
    @State private var reportManager = ReportManager()

    // Dipendenze
    @State private var vm: AriaAssistantViewModel

    var inspectorDescription = "THERMOCOUPLE TEMPERATURE IN CHAMBER"

    init() {
        // Configure with environment variables or Config.plist
        // See Config.swift for setup instructions
        let apiKey = ConfigManager.openAIAPIKey
        let assistantId = ConfigManager.openAIAssistantId
        
        let service = OpenAIAssistantsService(
            apiKey: apiKey,
            assistantId: assistantId
        )
        _vm = State(wrappedValue: AriaAssistantViewModel(service: service))
    }
    
    var body: some View {
           ZStack(alignment: .bottom) {
//
               Image("Background2")
                   .resizable()
                   .ignoresSafeArea()

               // TOP MENU
               VStack {
                   HStack {
                       Spacer()
                       Menu {
                           Toggle(isOn: $activateTags) {
                               Label("Activate tags", systemImage: "tag.fill")
                           }
                           Divider()
                           Button(action: { showHistory = true }) {
                               Label("Chat history", systemImage: "clock.fill")
                           }
                       } label: {
                           Image(systemName: "ellipsis.circle")
                               .font(.system(size: 40))
                               .foregroundStyle(.black)
                               .padding(20)
                               .glassEffect()
                               .clipShape(Circle())
                               .shadow(radius: 4)
                       }
                   }
                   .padding(.top, 40)
                   .padding(.horizontal, 20)
                   Spacer()
               }
               .zIndex(1)

               // Reopen minimized chat button
               if isChatMinimized && !vm.messages.isEmpty && !vm.showResponsePanel {
                   HStack {
                       Button {
                           withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                               vm.showResponsePanel = true
                               isChatMinimized = false
                           }
                       } label: {
                           HStack(spacing: 10) {
                               Image(systemName: "bubble.left.and.bubble.right.fill")
                               Text("Reopen chat").font(.headline)
                           }
                           .foregroundStyle(.black)
                           .padding(.vertical, 12)
                           .padding(.horizontal, 16)
                           .glassEffect()
                           .clipShape(Capsule())
                           .shadow(radius: 8)
                       }

                       Spacer()
                   }
                   .padding(.horizontal, 18)
                   .padding(.bottom, 18)
                   .zIndex(50)
               }

               // Main floating buttons
               // Visible when chat panel isn't open and MicBar isn't open.
               if !showMicBar && !vm.showResponsePanel {
                   VStack(spacing: 16) {
                       Spacer()
                       HStack {
                           Spacer()
                           VStack(spacing: 16) {

                               // Inspector always visible
                               Button(action: { withAnimation { showCameraPopup = true } }) {
                                   CircleButton(icon: "camera.viewfinder")
                               }

                               // Mic hidden when chat minimized
                               if !isChatMinimized {
                                   Button(action: { withAnimation { showMicBar = true } }) {
                                       CircleButton(icon: "mic.fill")
                                   }
                               }
                           }
                           .padding(.bottom, 24)
                           .padding(.trailing, 20)
                       }
                   }
                   .transition(.scale.combined(with: .opacity))
                   .zIndex(10)
               }

               // CAMERA POPUP
               if showCameraPopup {
                   CameraPopupView(
                       isPresented: $showCameraPopup,
                       description: inspectorDescription
                   )
                   .zIndex(20)
                   .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottom)))
               }

               // RESPONSE PANEL (full chat)
               if vm.showResponsePanel {
                   ResponsePanelView(
                       isPresented: $vm.showResponsePanel,
                       messages: vm.messages,
                       isLoading: vm.isLoading,
                       onCloseAndArchive: closeAndArchive,
                       onMinimize: {
                           withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                               vm.showResponsePanel = false
                               isChatMinimized = true
                           }
                       },
                       transcription: $transcription,
                       speechRecognizer: speechRecognizer,
                       onSendPrompt: { prompt in
                           Task { await vm.send(prompt: prompt, machineKey: inspectorDescription) }
                       }
                   )
                   .zIndex(30)
                   .transition(.move(edge: .bottom))
                   .padding(.bottom, 10)
               } else if showMicBar {
                   // MIC BAR (first request)
                   MicBarView(
                       isPresented: $showMicBar,
                       transcription: $transcription,
                       speechRecognizer: speechRecognizer,
                       onSend: { prompt in
                           withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                               showMicBar = false
                               vm.showResponsePanel = true
                               isChatMinimized = false
                           }
                           Task { await vm.send(prompt: prompt, machineKey: inspectorDescription) }
                       },
                       onClose: {
                           if speechRecognizer.isRecording { speechRecognizer.stopRecording() }
                           withAnimation {
                               showMicBar = false
                               transcription = ""
                               speechRecognizer.transcript = ""
                           }
                       }
                   )
                   .zIndex(40)
                   .transition(.move(edge: .bottom))
               }
           }
           .sheet(isPresented: $showHistory) {
               ReportsListView(reportManager: reportManager)
           }
       }

       @MainActor
       private func closeAndArchive() {
           guard let sid = vm.sessionId else {
               vm.resetSession()
               showMicBar = false
               isChatMinimized = false
               return
           }

           let fullText = vm.formattedConversation()
           let firstPrompt = vm.messages.first(where: { $0.role == .user })?.content ?? ""

           if !fullText.isEmpty {
               reportManager.saveSession(
                   id: sid,
                   objectName: inspectorDescription,
                   prompt: firstPrompt,
                   response: fullText
               )
           }

           vm.resetSession()
           transcription = ""
           speechRecognizer.transcript = ""
           showMicBar = false
           isChatMinimized = false
       }
   }


   // MARK: - ResponsePanelView

   struct ResponsePanelView: View {

       @Binding var isPresented: Bool
       let messages: [ChatMessage]
       let isLoading: Bool

       var onCloseAndArchive: () -> Void
       var onMinimize: () -> Void

       @Binding var transcription: String
       var speechRecognizer: SpeechRecognizer
       var onSendPrompt: (String) -> Void

       @State private var messageIdToScroll: UUID? = nil
       @State private var glowReady: Bool = false

       @State private var showCloseDialog = false

       var body: some View {
           VStack(alignment: .leading, spacing: 0) {

               HStack(spacing: 12) {
                   Text("Aria Engine")
                       .font(.title3.bold())
                       .foregroundStyle(.white)

                   Spacer()

                   Button(action: { showCloseDialog = true }) {
                       Image(systemName: "xmark.circle.fill")
                           .font(.system(size: 30))
                           .foregroundStyle(.white.opacity(0.65))
                   }
                   .confirmationDialog(
                       "What would you like to do?",
                       isPresented: $showCloseDialog,
                       titleVisibility: .visible
                   ) {
                       Button("Minimize (keep chat)") { onMinimize() }
                       Button("Close and archive", role: .destructive) { onCloseAndArchive() }
                       Button("Cancel", role: .cancel) { }
                   }
               }
               .padding(22)

               Divider()
                   .background(.white.opacity(0.25))
                   .padding(.horizontal, 16)

               ScrollViewReader { proxy in
                   ScrollView {
                       VStack(alignment: .leading, spacing: 14) {
                           ForEach(messages) { msg in
                               MessageBubble(msg: msg).id(msg.id)
                           }

                           if isLoading {
                               LoadingWaveView()
                                   .transition(.opacity.combined(with: .move(edge: .bottom)))
                           }
                       }
                       .padding(22)
                   }
                   .frame(maxHeight: 320)
                   .onChange(of: messages) { _, newValue in
                       messageIdToScroll = newValue.last?.id
                   }
                   .onChange(of: messageIdToScroll) { _, id in
                       guard let id else { return }
                       withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                   }
               }

               MicBarInlineView(
                   transcription: $transcription,
                   speechRecognizer: speechRecognizer,
                   onSend: { text in onSendPrompt(text) }
               )
               .environment(\.colorScheme, .light)
               .padding(.vertical, 14)
               .padding(.horizontal, 12)
           }
           .background {
               if #available(iOS 26.0, *) {
                   Color.clear
                       .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
               } else {
                   RoundedRectangle(cornerRadius: 32, style: .continuous)
                       .fill(.ultraThinMaterial)
               }
           }

           .environment(\.colorScheme, .dark)
           .overlay(
               RoundedRectangle(cornerRadius: 32, style: .continuous)
                   .stroke(.white.opacity(0.12), lineWidth: 1)
           )
           .overlay(
               AnimatedGlowBorder(
                   cornerRadius: 32,
                   lineWidth: 3.2,
                   isActive: isLoading && glowReady
               )
           )
           .shadow(color: .black.opacity(0.45), radius: 24, y: 14)
           .padding(.horizontal, 16)
           .onAppear {
               glowReady = false
               DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                   glowReady = true
               }
           }
           .onChange(of: isPresented) { _, newValue in
               if newValue == false { glowReady = false }
           }
       }
   }


   // MARK: - MessageBubble

   private struct MessageBubble: View {
       let msg: ChatMessage
       private var isUser: Bool { msg.role == .user }

       var body: some View {
           HStack {
               if isUser { Spacer(minLength: 40) }

               VStack(alignment: .leading, spacing: 6) {
                   Text(isUser ? "ME" : "ARIA")
                       .font(.caption.weight(.semibold))
                       .foregroundStyle(.white.opacity(0.70))

                   Text(msg.content.isEmpty ? " " : msg.content)
                       .font(.body)
                       .lineSpacing(4)
                       .foregroundStyle(.white.opacity(0.94))
               }
               .padding(.vertical, 12)
               .padding(.horizontal, 14)
               .background(
                   RoundedRectangle(cornerRadius: 16, style: .continuous)
                       .fill(bubbleFill)
               )
               .overlay(
                   RoundedRectangle(cornerRadius: 16, style: .continuous)
                       .stroke(borderStroke, lineWidth: 1)
               )
               .overlay(
                   RoundedRectangle(cornerRadius: 16, style: .continuous)
                       .stroke(.white.opacity(0.06), lineWidth: 1)
                       .blur(radius: 0.5)
                       .offset(y: 1)
                       .mask(
                           LinearGradient(
                               colors: [.white, .clear],
                               startPoint: .top,
                               endPoint: .bottom
                           )
                       )
               )
               .shadow(color: .black.opacity(0.25), radius: 14, y: 10)
               .shadow(color: glowColor, radius: 14)
               .frame(maxWidth: 420, alignment: isUser ? .trailing : .leading)

               if !isUser { Spacer(minLength: 40) }
           }
       }

       private var bubbleFill: some ShapeStyle {
           if isUser {
               return AnyShapeStyle(
                   LinearGradient(
                       colors: [Color.blue.opacity(0.38), Color.cyan.opacity(0.22)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing
                   )
               )
           } else {
               return AnyShapeStyle(
                   LinearGradient(
                       colors: [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing
                   )
               )
           }
       }

       private var borderStroke: Color {
           isUser ? Color.cyan.opacity(0.22) : Color.white.opacity(0.12)
       }

       private var glowColor: Color {
           isUser ? Color.cyan.opacity(0.16) : Color.blue.opacity(0.10)
       }
   }


   // MARK: - Small UI Pieces

   struct CircleButton: View {
       let icon: String
       var body: some View {
           Image(systemName: icon)
               .font(.system(size: 40))
               .foregroundStyle(.black)
               .padding(20)
               .glassEffect()
               .clipShape(Circle())
               .shadow(radius: 4)
       }
   }


   // MARK: - CameraPopupView

   struct CameraPopupView: View {
       @Binding var isPresented: Bool
       let description: String

       var body: some View {
           VStack {
               Spacer()
               HStack(alignment: .bottom, spacing: 12) {
                   Spacer()

                   VStack(spacing: -1) {
                       Text(description.isEmpty ? "Scanning..." : description)
                           .font(.subheadline.weight(.medium))
                           .foregroundStyle(.black)
                           .multilineTextAlignment(.center)
                           .padding(.horizontal, 20)
                           .padding(.vertical, 14)
                           .glassEffect()
                           .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                           .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.4), lineWidth: 1))

                       Image(systemName: "triangle.fill")
                           .font(.system(size: 14))
                           .foregroundStyle(.white.opacity(0.8))
                           .rotationEffect(.degrees(180))
                           .shadow(radius: 2)
                           .offset(y: -2)
                   }
                   .shadow(radius: 10)
                   .onTapGesture { withAnimation { isPresented = false } }

                   // INFO MENU: Datasheet / Manual / Schematic (no-op)
                   Menu {
                       Button(action: { }) { Label("Datasheet", systemImage: "doc.text") }
                       Button(action: { }) { Label("Manual", systemImage: "book") }
                       Button(action: { }) { Label("Schematic", systemImage: "square.and.pencil") }
                   } label: {
                       HStack {
                           Image(systemName: "info.circle.fill").font(.title2)
                           Text("Info").font(.headline.bold())
                       }
                       .foregroundStyle(.black)
                       .padding(14)
                       .background(Color.white.opacity(0.8))
                       .clipShape(Capsule())
                       .shadow(radius: 8)
                   }
                   .padding(.bottom, 12)

                   Spacer()
               }
               Spacer(minLength: 220)
           }
           .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottom)))
       }
   }

   #Preview {
       ContentView()
   }
