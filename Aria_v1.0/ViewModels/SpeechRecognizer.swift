import Foundation
import Speech
import AVFoundation

@Observable
class SpeechRecognizer {
    private var audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    
    var transcript: String = ""
    var isRecording: Bool = false
    
    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "it-IT"))
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            // Gestione permessi (opzionale: print(authStatus))
        }
    }
    
    func startRecording() {
        // Evita doppi avvii
        if isRecording { return }
        
        // 1. Pulisci sessioni precedenti
        stopRecording()
        
        // 2. Configura Audio Session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Errore AudioSession: \(error)")
        }
        
        // 3. Crea la Request
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return }
        request.shouldReportPartialResults = true // FONDAMENTALE per il real-time
        
        // 4. Configura Audio Engine
        let inputNode = audioEngine.inputNode
        
        // Rimuovi tap precedenti per sicurezza
        inputNode.removeTap(onBus: 0)
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            self.request?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
            transcript = "" // Reset testo
        } catch {
            print("Errore avvio Engine: \(error)")
        }
        
        // 5. Avvia Task
        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                // Aggiorna UI in tempo reale
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
            }
            
            if error != nil {
                self.stopRecording()
            }
        }
    }
    
    // Metodo per "resettare" solo quando necessario
    func resetTranscript() {
        transcript = ""
    }

    
    func stopRecording() {
        if !isRecording { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        
        task = nil
        request = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
}
