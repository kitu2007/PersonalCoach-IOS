//
//  AudioListener.swift
//

import AVFoundation
import UserNotifications
import WatchConnectivity

#if os(iOS)
import Speech              // ⬅︎ iOS-only framework
#else
import WatchKit            // for haptics
#endif

/// Shared actor for mic capture on both platforms.
/// • On **watchOS** we capture short audio chunks and forward them to the phone.
/// • On **iOS** we both capture (if running stand-alone) *and* run STT + LLM.
@MainActor
final class AudioListener: NSObject, ObservableObject {
    @Published private(set) var isActive = false
    private let engine = AVAudioEngine()

    #if os(iOS)   // Speech recogniser lives only on iPhone
    private let recognizer = SFSpeechRecognizer()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    #endif
    
    // MARK: – Public API
    func start() throws {
        guard !isActive else { return }
        
        // Mic session
        try AVAudioSession.sharedInstance()
            .setCategory(.record, mode: .measurement, options: .duckOthers)
        try AVAudioSession.sharedInstance().setActive(true)
        
        #if os(iOS)
        request = SFSpeechAudioBufferRecognitionRequest()
        #endif
        
        // Tap
        let fmt = engine.inputNode.outputFormat(forBus: 0)
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) {
            [weak self] buf, _ in
            guard let self else { return }
            
            #if os(iOS)
            // Feed recogniser on iPhone
            self.request?.append(buf)
            #else
            // Forward raw PCM chunk to phone
            let d = Data(bytes: buf.audioBufferList.pointee.mBuffers.mData!,
                         count: Int(buf.audioBufferList.pointee.mBuffers.mDataByteSize))
            WCSession.default.transferUserInfo(["pcm": d])
            #endif
        }
        engine.prepare()
        try engine.start()
        isActive = true
        
        #if os(iOS)
        // Speech recogniser callback – iPhone only
        task = recognizer?.recognitionTask(with: request!) { [weak self] res, err in
            guard let self, let text = res?.bestTranscription.formattedString else { return }
            if err != nil { self.stop(); return }
            Task { await self.handle(text) }
        }
        #endif
    }
    
    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        #if os(iOS)
        task?.cancel(); task = nil; request = nil
        #endif
        isActive = false
    }
    
    // MARK: – iPhone-only handler
    #if os(iOS)
    private func handle(_ text: String) async {
        Task { @MainActor in print("USER ► \(text)") }
        guard let reply = try? await chat(text) else { return }
        do {
            // Ensure authorization exists before attempting to post a local notification
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            }
            let content = banner(reply)
            try await center
                .add(UNNotificationRequest(identifier: UUID().uuidString,
                                       content: content,
                                       trigger: nil))
            // Handoff to watch
            WCSession.default.transferUserInfo(["user": text,
                                            "ai":   reply,
                                            "ts":  Date().timeIntervalSince1970])
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }
    #endif
}

// MARK: – helpers
#if os(iOS)
private func banner(_ msg: String) -> UNMutableNotificationContent {
    let c = UNMutableNotificationContent()
    c.title  = "Coach"
    c.body   = msg
    c.sound  = .default
    return c
}

// GPT call (same as before)
func chat(_ prompt: String) async throws -> String {
    struct Req: Encodable { let model = "gpt-3.5-turbo"; let messages: [[String:String]] }
    struct Res: Decodable { struct C: Decodable { let content: String }; let choices: [C] }
    
    var r = URLRequest(url: URL(string:"https://api.openai.com/v1/chat/completions")!)
    r.httpMethod = "POST"
    r.addValue("Bearer \(ProcessInfo.processInfo.environment["OPENAI_KEY"] ?? "")",
               forHTTPHeaderField: "Authorization")
    r.addValue("application/json", forHTTPHeaderField: "Content-Type")
    r.httpBody = try JSONEncoder().encode(
        Req(messages: [["role":"user","content": prompt]])
    )
    let (d, _) = try await URLSession.shared.data(for: r)
    return try JSONDecoder().decode(Res.self, from: d).choices[0].content
}
#endif

