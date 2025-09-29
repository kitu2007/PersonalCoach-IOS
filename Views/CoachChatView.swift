import SwiftUI
import SwiftData

struct CoachChatView: View {
    @Environment(\.modelContext) private var modelContext
    // Persisted chat history
    @Query(sort: \Session.timestamp) private var sessions: [Session]
    
    @State private var draft = ""
    @State private var isSending = false
    @FocusState private var isInputFocused: Bool
    @StateObject private var openAIService = OpenAIService.shared
    @State private var showingSettings = false
    @State private var useVoiceInput = false
    @State private var useVoiceOutput = false
    @State private var includeWebSearch = false
    
    var body: some View {
        VStack {
            if sessions.isEmpty {
                ContentUnavailableView(
                    "Say hello!",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Ask your coach anything—from motivation to habit advice.")
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(sessions) { chat in
                                MessageBubble(chat: chat)
                                    .id(chat.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: sessions.count) { _ in
                        // Auto-scroll to latest
                        if let last = sessions.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            Divider()
            
            // Voice input display
            if openAIService.isListening {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                        .scaleEffect(1.2)
                    Text("Listening...")
                        .foregroundColor(.secondary)
                    Spacer()
                    if openAIService.isListening {
                        Button("Stop") {
                            Task {
                                openAIService.stopListening()
                            }
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            HStack(alignment: .bottom) {
                // Voice input button
                Button {
                    if openAIService.isListening {
                        openAIService.stopListening()
                    } else {
                        openAIService.startListening()
                    }
                } label: {
                    Image(systemName: openAIService.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(openAIService.isListening ? .red : .blue)
                }
                .disabled(!openAIService.hasValidAPIKey())
                
                TextField("Message", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .disabled(isSending)
                    .textFieldStyle(.roundedBorder)
                    .focused($isInputFocused)
                    .onChange(of: openAIService.transcribedText) { newValue in
                        if !newValue.isEmpty {
                            draft = newValue
                        }
                    }
                
                Button {
                    Task { await send() }
                } label: {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Image(systemName: "paperplane.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding([.horizontal, .bottom])
        }
        .navigationTitle("Coach")
        .toolbar { 
            ToolbarItemGroup(placement: .keyboard) { 
                Spacer()
                Button("Done") { isInputFocused = false }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(useVoiceInput: $useVoiceInput, useVoiceOutput: $useVoiceOutput, includeWebSearch: $includeWebSearch)
        }
        .alert("API Key Required", isPresented: .constant(!openAIService.hasValidAPIKey())) {
            Button("Add API Key") {
                showingSettings = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please add your OpenAI API key in Settings to use the chat feature.")
        }
    }
    
    // MARK: – Networking
    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        print("🔄 Starting send process for: '\(text)'")
        draft = ""
        isSending = true
        isInputFocused = false
        
        // Insert user message locally first for instant UI update (on main thread)
        let userSession = Session(text, "")
        await MainActor.run {
            modelContext.insert(userSession)
            try? modelContext.save()
        }
        print("✅ User message saved to database")
        
        var history: [ChatMessage] = []
        for s in sessions {
            if !s.userText.isEmpty { history.append(.init(role: .user, content: s.userText)) }
            if !s.assistantText.isEmpty { history.append(.init(role: .assistant, content: s.assistantText)) }
        }
        history.append(.init(role: .user, content: text))
        if includeWebSearch {
            if let results = try? await WebSearchService.search(query: text, maxResults: 3), !results.isEmpty {
                let compiled = results.enumerated().map { "\($0+1). \($1.title): \($1.snippet) (\($1.url))" }.joined(separator: "\n")
                let systemMessage = "You can use the following web results to answer the user question.\n" + compiled
                history.insert(ChatMessage(role: .assistant, content: systemMessage), at: 0)
            }
        }
        print("📝 Chat history built with \(history.count) messages")
        
        do {
            var assistantReply = ""
            print("🤖 Calling OpenAI service...")
            _ = try await openAIService.chat(messages: history, streamHandler: { chunk in
                assistantReply.append(chunk)
                print("📨 Received chunk: '\(chunk)'")
                // Live-update last session during streaming
                Task { @MainActor in
                    userSession.assistantText = assistantReply
                    try? modelContext.save()
                }
            })
            // Ensure final text persisted
            userSession.assistantText = assistantReply
            try? modelContext.save()
            print("✅ Assistant reply saved: '\(assistantReply)'")
            
            // Speak the response if voice output is enabled
            if useVoiceOutput { openAIService.speak(assistantReply) }
        } catch {
            print("❌ Error in chat: \(error.localizedDescription)")
            userSession.assistantText = "⚠️ " + (error.localizedDescription)
            try? modelContext.save()
        }
        isSending = false
        print("🏁 Send process completed")
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var openAIService = OpenAIService.shared
    @State private var apiKey = ""
    @Binding var useVoiceInput: Bool
    @Binding var useVoiceOutput: Bool
    @Binding var includeWebSearch: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section("OpenAI API Key") {
                    SecureField("Enter your OpenAI API key", text: $apiKey)
                        .textContentType(.password)
                    
                    if openAIService.hasValidAPIKey() {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("API Key is set")
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text("API Key required")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button("Save API Key") {
                        openAIService.setAPIKey(apiKey)
                    }
                    .disabled(apiKey.isEmpty)
                }
                
                Section("Voice Features") {
                    Toggle("Voice Input", isOn: $useVoiceInput)
                    Toggle("Voice Output", isOn: $useVoiceOutput)
                    Toggle("Include Web Search", isOn: $includeWebSearch)
                    
                    if useVoiceInput || useVoiceOutput {
                        Text("Voice features require microphone and speech recognition permissions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("About") {
                    Link("Get OpenAI API Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    Link("OpenAI Pricing", destination: URL(string: "https://openai.com/pricing")!)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                apiKey = openAIService.getAPIKey() ?? ""
            }
        }
    }
}

// MARK: – Message bubble
private struct MessageBubble: View {
    let chat: Session
    var body: some View {
        VStack(alignment: chat.userText.isEmpty ? .leading : .trailing, spacing: 4) {
            if !chat.userText.isEmpty {
                HStack {
                    Spacer()
                    Text(chat.userText)
                        .padding(10)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.primary)
                }
            }
            if !chat.assistantText.isEmpty {
                HStack {
                    Text(chat.assistantText)
                        .padding(10)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Session.self, configurations: config)
    NavigationStack { CoachChatView().modelContainer(container) }
} 