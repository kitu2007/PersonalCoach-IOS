import Foundation
import AVFoundation
import Speech
import WatchConnectivity

/// A lightweight service to call OpenAI's Chat Completions API with voice support.
/// Uses streaming when available, otherwise falls back to a single completion.
/// Make sure to provide the `OPENAI_API_KEY` in your Info.plist or via an
/// environment variable at runtime.
@MainActor
final class OpenAIService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let appGroupID = "group.com.kg.personalcoach"
    // Singleton
    static let shared = OpenAIService()
    private override init() {
        super.init()
        setupSpeechRecognition()
    }
    
    // MARK: – Configuration
    private let apiURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private var apiKey: String? {
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            return key
        }
        if let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String, !key.isEmpty {
            return key
        }
        if let key = UserDefaults(suiteName: appGroupID)?.string(forKey: "OPENAI_API_KEY"), !key.isEmpty {
            return key
        }
        if let key = UserDefaults.standard.string(forKey: "OPENAI_API_KEY"), !key.isEmpty {
            return key
        }
        return nil
    }
    
    // MARK: – Speech Recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Published voice properties
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var transcribedText = ""
    
    // MARK: – API Key helpers
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "OPENAI_API_KEY")
        UserDefaults(suiteName: appGroupID)?.set(key, forKey: "OPENAI_API_KEY")
    }
    func getAPIKey() -> String? {
        return UserDefaults.standard.string(forKey: "OPENAI_API_KEY") ??
               UserDefaults(suiteName: appGroupID)?.string(forKey: "OPENAI_API_KEY")
    }
    func hasValidAPIKey() -> Bool { apiKey != nil }
    
    // MARK: – Chat API
    func chat(messages: [ChatMessage], temperature: Double = 0.7, streamHandler: ((String)->Void)? = nil) async throws -> String {
        guard let key = apiKey else { throw OpenAIError.missingAPIKey }
        let primaryModel = "gpt-4o-mini"
        let fallbackModel = "gpt-3.5-turbo"
        do {
            return try await performChat(model: primaryModel, key: key, messages: messages, temperature: temperature, streamHandler: streamHandler)
        } catch {
            // Fallback to a widely available model if the first fails
            return try await performChat(model: fallbackModel, key: key, messages: messages, temperature: temperature, streamHandler: streamHandler)
        }
    }

    private func performChat(model: String, key: String, messages: [ChatMessage], temperature: Double, streamHandler: ((String)->Void)? = nil) async throws -> String {
        let body = ChatRequest(model: model, messages: messages.map { $0.toOpenAI() }, temperature: temperature, stream: streamHandler != nil)
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if body.stream { request.addValue("text/event-stream", forHTTPHeaderField: "Accept") }
        request.httpBody = try JSONEncoder().encode(body)
        if body.stream, let handler = streamHandler {
            let full = try await streamResponse(with: request, chunkHandler: handler)
            if !full.isEmpty { return full }
            // If streaming gave nothing, fall back to non-stream for reliability
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw OpenAIError.invalidHTTP }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let first = decoded.choices.first?.message.content else { throw OpenAIError.emptyResponse }
        return first.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: – Voice Input
    func startListening() {
        guard !isListening else { return }
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if status == .authorized { self.beginRecording() }
            }
        }
    }
    func stopListening() {
        audioEngine.stop(); recognitionRequest?.endAudio(); isListening = false
    }
    private func beginRecording() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true
            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            audioEngine.prepare(); try audioEngine.start()
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let result = result { self.transcribedText = result.bestTranscription.formattedString }
                    if error != nil { self.stopListening() }
                }
            }
            isListening = true
        } catch { print("Speech start error: \(error)") }
    }
    
    // MARK: – Voice Output
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US"); utterance.rate = 0.5
        let synth = AVSpeechSynthesizer(); synth.delegate = self; synth.speak(utterance); isSpeaking = true
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish _: AVSpeechUtterance) { 
        Task { @MainActor in
            isSpeaking = false
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel _: AVSpeechUtterance) { 
        Task { @MainActor in
            isSpeaking = false
        }
    }
    
    // MARK: – Helpers
    private func setupSpeechRecognition() { SFSpeechRecognizer.requestAuthorization { _ in } }
    private func streamResponse(with request: URLRequest, chunkHandler: @escaping(String)->Void) async throws -> String {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw OpenAIError.invalidHTTP }
        var full = ""
        for try await rawLine in bytes.lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("data:") else { continue }
            let payload = line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespaces)
            if payload.isEmpty { continue }
            if payload == "[DONE]" { break }
            if let data = payload.data(using: .utf8),
               let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data),
               let delta = chunk.choices.first?.delta.content {
                full.append(delta)
                chunkHandler(delta)
            }
        }
        return full.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: – Models
private struct ChatRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let stream: Bool
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

private struct ChatResponse: Codable {
    struct Choice: Codable { let message: OpenAIMessage }
    let choices: [Choice]
}

private struct StreamChunk: Codable {
    struct Choice: Codable { let delta: Delta }
    struct Delta: Codable { let content: String? }
    let choices: [Choice]
}

private struct WhisperResponse: Codable {
    let text: String
}

private struct TTSRequest: Codable {
    let model: String
    let input: String
    let voice: String
}

// MARK: – Error
enum OpenAIError: Error, LocalizedError {
    case missingAPIKey, invalidHTTP, emptyResponse
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "OpenAI API key not set. Please add your API key in Settings."
        case .invalidHTTP:   return "OpenAI server returned an error."
        case .emptyResponse: return "The assistant replied with an empty message."
        }
    }
}

// MARK: – Convenience Model for Views
struct ChatMessage: Identifiable, Hashable {
    enum Role: String { case user, assistant }
    let id = UUID()
    let role: Role
    var content: String
    
    func toOpenAI() -> OpenAIMessage {
        .init(role: role.rawValue, content: content)
    }
} 