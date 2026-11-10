import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechManager: ObservableObject {
    @Published var transcript = ""
    @Published var listening = false
    @Published var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var sessionID = UUID()
    private let synthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?

    func authorize() async -> Bool {
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        let micAllowed = await AVAudioApplication.requestRecordPermission()
        if !speechAllowed || !micAllowed {
            errorMessage = "Please enable Microphone and Speech Recognition permissions for Yusr in Settings."
        }
        return speechAllowed && micAllowed
    }

    func start() async {
        guard await authorize() else { return }
        stop()
        errorMessage = nil
        transcript = ""
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition is currently unavailable. Please try again."
            return
        }

        let currentID = UUID()
        sessionID = currentID
        do {
            // Measurement mode avoids voice-processing effects while recording.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                throw NSError(domain: "YusrSpeech", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "No usable microphone input format was found."])
            }

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            req.taskHint = .dictation
            if recognizer.supportsOnDeviceRecognition {
                req.requiresOnDeviceRecognition = true
            }
            request = req

            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                req.append(buffer)
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            listening = true

            task = recognizer.recognitionTask(with: req) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self, self.sessionID == currentID else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }
                    if let error {
                        let nsError = error as NSError
                        self.stop()
                        // Code 1110 means no recognizable speech in this attempt,
                        // not a microphone hardware or permission failure.
                        if nsError.code == 1110 && nsError.domain == "kAFAssistantErrorDomain" {
                            self.errorMessage = "No speech was recognized this time. Tap the microphone to try again, and take your time."
                        } else {
                            self.errorMessage = "Speech recognition error: \(error.localizedDescription) (\(nsError.domain): \(nsError.code))"
                        }
                    } else if result?.isFinal == true {
                        self.stop()
                    }
                }
            }
        } catch {
            stop()
            let nsError = error as NSError
            errorMessage = "Couldn't start recording: \(error.localizedDescription) (\(nsError.domain): \(nsError.code))"
        }
    }

    func stop() {
        sessionID = UUID() // Ignore callbacks from cancelled recognition tasks.
        if engine.isRunning { engine.stop() }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        listening = false
    }

    func speak(_ text: String) {
        audioPlayer?.stop()
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.47
        synthesizer.speak(utterance)
    }

    func speakAudio(_ data: Data) async {
        do {
            stop()
            synthesizer.stopSpeaking(at: .immediate)
            audioPlayer?.stop()
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(data: data)
            audioPlayer = player
            guard player.play() else {
                throw NSError(domain: "YusrAudio", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Audio playback could not start."])
            }
        } catch {
            errorMessage = "Could not play generated audio: \(error.localizedDescription)"
        }
    }
}
