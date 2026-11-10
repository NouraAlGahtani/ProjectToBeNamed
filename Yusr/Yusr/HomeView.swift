import SwiftUI
import AVFoundation

private enum YusrStyle {
    static let ink = Color(red: 0.19, green: 0.19, blue: 0.27)
    static let plum = Color(red: 0.40, green: 0.30, blue: 0.56)
    static let lavender = Color(red: 0.91, green: 0.88, blue: 0.96)
    static let cream = Color(red: 0.985, green: 0.975, blue: 0.96)
    static let muted = Color(red: 0.52, green: 0.49, blue: 0.56)
}

struct HomeView: View {
    @State private var selected: PracticeMode?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Image(systemName: "sparkle")
                            .font(.title2)
                            .foregroundStyle(YusrStyle.plum)
                        Spacer()
                        Text("Yusr")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(YusrStyle.ink)
                    }
                    .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 48, weight: .ultraLight))
                                .foregroundStyle(YusrStyle.plum)
                            Spacer()
                            Text("Your voice. Your pace.")
                                .font(.system(size: 25, weight: .bold))
                                .foregroundStyle(YusrStyle.ink)
                        }
                        Text("Practice everyday conversations at your own pace, without pressure.")
                            .font(.body)
                            .foregroundStyle(YusrStyle.muted)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 8) {
                            Image(systemName: "text.bubble")
                            Text("Text-only AI replies")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(YusrStyle.plum)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.8), in: Capsule())
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(YusrStyle.lavender, in: RoundedRectangle(cornerRadius: 30))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Start a conversation")
                            .font(.title2.bold())
                            .foregroundStyle(YusrStyle.ink)
                        Text("Choose a scenario to practice")
                            .foregroundStyle(YusrStyle.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 13) {
                        ForEach(PracticeMode.allCases) { mode in
                            Button { selected = mode } label: {
                                VStack(alignment: .leading, spacing: 22) {
                                    HStack {
                                        Spacer()
                                        Image(systemName: mode.symbol)
                                            .font(.title2)
                                            .foregroundStyle(YusrStyle.plum)
                                            .frame(width: 46, height: 46)
                                            .background(YusrStyle.lavender.opacity(0.65), in: RoundedRectangle(cornerRadius: 15))
                                    }
                                    Text(mode.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(YusrStyle.ink)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(17)
                                .frame(maxWidth: .infinity, minHeight: 140)
                                .background(.white, in: RoundedRectangle(cornerRadius: 24))
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(YusrStyle.lavender.opacity(0.6)))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Yusr is for supportive practice, not a replacement for speech therapy.")
                        .font(.footnote)
                        .foregroundStyle(YusrStyle.muted)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .background(YusrStyle.cream.ignoresSafeArea())
            .navigationDestination(item: $selected) { mode in
                ConversationView(mode: mode)
            }
        }
        .tint(YusrStyle.plum)
    }
}

struct ConversationView: View {
    let mode: PracticeMode
    @StateObject private var speech = SpeechManager()
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var loading = false
    @State private var showSummary = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var voiceError: String?
    @State private var sentCount = 0
    @State private var began = Date()
    @State private var serverWarning = false
    @State private var replyAvailableAt = Date()
    @State private var recordingStartedAt: Date?
    @State private var voiceResponseDelays: [TimeInterval] = []
    @State private var recordingDurations: [TimeInterval] = []
    @State private var voiceTurns = 0
    @State private var typedTurns = 0
    @State private var pendingVoiceInput = false
    private let api = APIClient()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: mode.symbol)
                    .font(.title3)
                    .foregroundStyle(YusrStyle.plum)
                    .frame(width: 46, height: 46)
                    .background(YusrStyle.lavender, in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.rawValue).font(.headline)
                    Text("No rush · Spoken and written replies")
                        .font(.caption)
                        .foregroundStyle(YusrStyle.muted)
                }
                Spacer()
                Button("Finish") {
                    speech.stop()
                    audioPlayer?.stop()
                    showSummary = true
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(16)
            .background(.white)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 17) {
                        Text("Take your time. There is no response deadline 🤍")
                            .font(.footnote)
                            .foregroundStyle(YusrStyle.muted)
                            .padding(.top, 14)

                        ForEach(messages) { message in
                            HStack(alignment: .bottom, spacing: 9) {
                                if message.role == "user" { Spacer(minLength: 40) }
                                if message.role != "user" {
                                    Image(systemName: "sparkle")
                                        .font(.caption)
                                        .foregroundStyle(YusrStyle.plum)
                                        .frame(width: 28, height: 28)
                                        .background(YusrStyle.lavender, in: Circle())
                                }
                                Text(message.content)
                                    .font(.body)
                                    .foregroundStyle(YusrStyle.ink)
                                    .multilineTextAlignment(.leading)
                                    .padding(.horizontal, 17)
                                    .padding(.vertical, 14)
                                    .background(message.role == "user" ? YusrStyle.lavender : .white,
                                                in: RoundedRectangle(cornerRadius: 20))
                                if message.role != "user" { Spacer(minLength: 40) }
                            }
                            .id(message.id)
                        }
                        if loading {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Yusr is replying...")
                                    .font(.footnote)
                                    .foregroundStyle(YusrStyle.muted)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .onChange(of: messages.count) { _, _ in
                    if let id = messages.last?.id {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                }
            }

            if let voiceError {
                Text(voiceError).font(.caption).foregroundStyle(.orange).padding(.horizontal, 16).padding(.vertical, 7)
            }

            if serverWarning {
                Text("Offline demo: AI backend unavailable.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
            }

            if speech.listening {
                Text(speech.transcript.isEmpty ? "Listening... take your time 💜" : speech.transcript)
                    .font(.subheadline)
                    .foregroundStyle(YusrStyle.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
                    .background(YusrStyle.lavender.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            HStack(alignment: .bottom, spacing: 12) {
                Button {
                    if speech.listening {
                        let captured = speech.transcript
                        if let start = recordingStartedAt {
                            recordingDurations.append(Date().timeIntervalSince(start))
                        }
                        recordingStartedAt = nil
                        speech.stop()
                        input = captured
                        pendingVoiceInput = !captured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    } else {
                        // Never let Andrew's playback overlap microphone capture.
                        audioPlayer?.stop()
                        audioPlayer = nil
                        voiceError = nil
                        Task {
                            await speech.start()
                            if speech.listening {
                                recordingStartedAt = Date()
                                // Time until the user tapped record, not acoustic speech onset.
                                voiceResponseDelays.append(max(0, Date().timeIntervalSince(replyAvailableAt)))
                            }
                        }
                    }
                } label: {
                    Image(systemName: speech.listening ? "stop.fill" : "mic.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(speech.listening ? Color.red.opacity(0.8) : YusrStyle.plum, in: Circle())
                }
                .accessibilityLabel(speech.listening ? "Stop recording" : "Start recording")

                TextField("Type or speak here...", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 12)
                    .background(YusrStyle.cream, in: RoundedRectangle(cornerRadius: 18))
                    .multilineTextAlignment(.leading)

                Button { Task { await send() } } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 45, height: 45)
                        .background(YusrStyle.plum, in: Circle())
                }
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loading)
                .opacity(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loading ? 0.45 : 1)
                .accessibilityLabel("Send")
            }
            .padding(14)
            .background(.white)
        }
        .background(YusrStyle.cream.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSummary) {
            SummaryView(
                mode: mode,
                turnCount: sentCount,
                duration: Date().timeIntervalSince(began),
                voiceTurns: voiceTurns,
                typedTurns: typedTurns,
                responseDelays: voiceResponseDelays,
                recordingDurations: recordingDurations
            )
                .presentationDetents([.medium, .large])
        }
        .alert("Speech recognition", isPresented: Binding(
            get: { speech.errorMessage != nil },
            set: { if !$0 { speech.errorMessage = nil } }
        )) {
            Button("OK") { speech.errorMessage = nil }
        } message: {
            Text(speech.errorMessage ?? "")
        }
        .task {
            if messages.isEmpty {
                messages.append(ChatMessage(role: "assistant", content: mode.opening))
                replyAvailableAt = Date()
            }
        }
        .onDisappear { speech.stop(); audioPlayer?.stop() }
    }

    private func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !loading else { return }
        speech.stop()
        audioPlayer?.stop()
        input = ""
        messages.append(ChatMessage(role: "user", content: text))
        sentCount += 1
        if pendingVoiceInput { voiceTurns += 1 } else { typedTurns += 1 }
        pendingVoiceInput = false
        loading = true
        defer { loading = false }
        let answer: String
        do {
            answer = try await api.reply(mode: mode, messages: messages)
            serverWarning = false
        } catch {
            serverWarning = true
            answer = "Thanks for sharing. Take your time. Would you like to tell me more?"
        }
        messages.append(ChatMessage(role: "assistant", content: answer))
        replyAvailableAt = Date()
        // Display the reply immediately, then synthesize and play Andrew's voice.
        guard !serverWarning else { return }
        do {
            voiceError = nil
            let wav = try await api.voiceAudio(text: answer)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(data: wav)
            audioPlayer?.stop()
            audioPlayer = player
            guard player.play() else { throw NSError(domain: "YusrAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio playback could not start"]) }
        } catch {
            voiceError = "Andrew's audio couldn't play: \(error.localizedDescription)"
        }
    }
}

struct SummaryView: View {
    let mode: PracticeMode
    let turnCount: Int
    let duration: TimeInterval
    let voiceTurns: Int
    let typedTurns: Int
    let responseDelays: [TimeInterval]
    let recordingDurations: [TimeInterval]
    @Environment(\.dismiss) private var dismiss
    @State private var comfort = 3

    private var averageDelay: TimeInterval? {
        guard !responseDelays.isEmpty else { return nil }
        return responseDelays.reduce(0, +) / Double(responseDelays.count)
    }
    private var averageRecording: TimeInterval? {
        guard !recordingDurations.isEmpty else { return nil }
        return recordingDurations.reduce(0, +) / Double(recordingDurations.count)
    }
    private func seconds(_ time: TimeInterval?) -> String {
        guard let time else { return "—" }
        return String(format: "%.1f sec", time)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 9) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.title)
                            .foregroundStyle(YusrStyle.plum)
                        Text("Every conversation counts")
                            .font(.title2.bold())
                            .foregroundStyle(YusrStyle.ink)
                        Text("These are practice observations, not a fluency score or diagnosis.")
                            .font(.subheadline)
                            .foregroundStyle(YusrStyle.muted)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(YusrStyle.lavender, in: RoundedRectangle(cornerRadius: 24))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        metric("Your turns", value: "\(turnCount)", symbol: "bubble.right")
                        metric("Session length", value: "\(Int(duration / 60)) min", symbol: "clock")
                        metric("Voice turns", value: "\(voiceTurns)", symbol: "mic")
                        metric("Typed turns", value: "\(typedTurns)", symbol: "keyboard")
                        metric("Average mic-start delay", value: seconds(averageDelay), symbol: "timer")
                        metric("Avg. recording time", value: seconds(averageRecording), symbol: "waveform")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("How comfortable did you feel?")
                            .font(.headline)
                        Picker("Comfort level", selection: $comfort) {
                            ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Text("1 = not comfortable; 5 = very comfortable. Your own rating.")
                            .font(.caption)
                            .foregroundStyle(YusrStyle.muted)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22))

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Understanding your insights", systemImage: "info.circle")
                            .font(.headline)
                        Text("This measures time from the AI reply until you tap the microphone, not the onset of speech.")
                        Text("Recording duration includes silence, thinking, and speech. It cannot establish stuttering or its severity.")
                        Text("Repetitions, prolongations, and blocks require carefully validated audio analysis. They are not detected by this version.")
                    }
                    .font(.footnote)
                    .foregroundStyle(YusrStyle.muted)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22))
                }
                .padding(18)
            }
            .background(YusrStyle.cream.ignoresSafeArea())
            .navigationTitle("Conversation insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private func metric(_ label: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(YusrStyle.plum)
                .font(.title3)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(YusrStyle.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(YusrStyle.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}
