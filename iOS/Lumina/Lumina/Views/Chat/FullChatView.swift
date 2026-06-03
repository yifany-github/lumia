import AVFoundation
import FirebaseAILogic
import CoreImage
import NaturalLanguage
import Speech
import SwiftUI
import UIKit

@MainActor
final class SpeechInputController: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var activeLanguageLabel = "Auto language"

    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var isAvailable: Bool {
        !Self.supportedLocales.isEmpty
    }

    func start(preferredText: String = "") {
        guard !isListening else { return }
        Task { await startListening(preferredText: preferredText) }
    }

    func stop() {
        stopListening(cancelTask: false)
    }

    func cancel() {
        transcript = ""
        stopListening(cancelTask: true)
    }

    private func startListening(preferredText: String) async {
        errorMessage = nil
        transcript = ""

        guard let recognitionTarget = Self.makeRecognitionTarget(preferredText: preferredText) else {
            errorMessage = "Voice input is not available on this device."
            return
        }
        speechRecognizer = recognitionTarget.recognizer
        activeLanguageLabel = recognitionTarget.displayName

        let speechRecognizer = recognitionTarget.recognizer

        guard await requestSpeechAuthorization() else {
            errorMessage = "Enable Speech Recognition in Settings to use voice input."
            return
        }

        guard await requestMicrophoneAuthorization() else {
            errorMessage = "Enable Microphone access in Settings to use voice input."
            return
        }

        guard speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is unavailable right now."
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
            if #available(iOS 16.0, *) {
                request.addsPunctuation = true
            }

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
                request?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            recognitionRequest = request
            isListening = true

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        if result.isFinal {
                            self.stopListening(cancelTask: false)
                        }
                    }

                    if let error, self.isListening {
                        self.errorMessage = self.readableRecognitionError(error)
                        self.stopListening(cancelTask: true)
                    }
                }
            }
        } catch {
            errorMessage = "Could not start voice input."
            stopListening(cancelTask: true)
        }
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func stopListening(cancelTask: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        if cancelTask {
            recognitionTask?.cancel()
        } else {
            recognitionRequest?.endAudio()
        }

        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        speechRecognizer = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func readableRecognitionError(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
            return "No speech detected."
        }
        return "Voice input stopped. Try again."
    }

    private static func makeRecognitionTarget(preferredText: String) -> (recognizer: SFSpeechRecognizer, displayName: String)? {
        let supportedLocales = Self.supportedLocales
        for locale in recognitionLocaleCandidates(preferredText: preferredText, supportedLocales: supportedLocales) {
            if let recognizer = SFSpeechRecognizer(locale: locale) {
                return (recognizer, displayName(for: locale))
            }
        }
        return nil
    }

    private static let supportedLocales = SFSpeechRecognizer.supportedLocales()

    private static func recognitionLocaleCandidates(preferredText: String, supportedLocales: Set<Locale>) -> [Locale] {
        let requestedIdentifiers = languageHints(from: preferredText)
            + keyboardLanguageIdentifiers()
            + Locale.preferredLanguages
            + [Locale.current.identifier]
            + fallbackLanguageIdentifiers

        var seen = Set<String>()
        var candidates: [Locale] = []
        for identifier in requestedIdentifiers {
            guard let locale = supportedLocale(matching: identifier, supportedLocales: supportedLocales) else { continue }
            let key = normalizedIdentifier(locale.identifier)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            candidates.append(locale)
        }
        return candidates
    }

    private static let fallbackLanguageIdentifiers = [
        "en-US",
        "zh-Hans",
        "zh-Hant",
        "es-ES",
        "es-MX",
        "fr-FR",
        "de-DE",
        "ja-JP",
        "ko-KR",
        "pt-BR",
        "it-IT"
    ]

    private static func languageHints(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var hints: [String] = []
        if containsCJK(in: trimmed) {
            hints.append(contentsOf: ["zh-Hans", "zh-Hant"])
        }
        if containsSpanishSpecificCharacters(in: trimmed) {
            hints.append(contentsOf: ["es-ES", "es-MX"])
        }

        let letterCount = trimmed.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        if letterCount >= 8 {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(trimmed)
            if let language = recognizer.dominantLanguage?.rawValue {
                hints.append(contentsOf: mappedIdentifiers(forLanguage: language))
            }
        }

        return hints
    }

    private static func mappedIdentifiers(forLanguage language: String) -> [String] {
        switch language {
        case "zh", "zh-Hans":
            return ["zh-Hans", "zh-CN"]
        case "zh-Hant":
            return ["zh-Hant", "zh-TW"]
        case "en":
            return ["en-US", "en-GB"]
        case "es":
            return ["es-ES", "es-MX", "es-US"]
        case "fr":
            return ["fr-FR", "fr-CA"]
        case "pt":
            return ["pt-BR", "pt-PT"]
        default:
            return [language]
        }
    }

    private static func containsCJK(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
                || (0x3400...0x4DBF).contains(Int(scalar.value))
        }
    }

    private static func containsSpanishSpecificCharacters(in text: String) -> Bool {
        text.range(of: #"[áéíóúüñ¿¡]"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func keyboardLanguageIdentifiers() -> [String] {
        UITextInputMode.activeInputModes
            .compactMap(\.primaryLanguage)
            .filter { !$0.isEmpty && !$0.localizedCaseInsensitiveContains("emoji") }
    }

    private static func supportedLocale(matching identifier: String, supportedLocales: Set<Locale>) -> Locale? {
        let normalizedRequest = normalizedIdentifier(identifier)
        if let exact = supportedLocales.first(where: { normalizedIdentifier($0.identifier) == normalizedRequest }) {
            return exact
        }

        let requestedLanguage = languageCode(from: identifier)
        let matches = supportedLocales.filter { languageCode(from: $0.identifier) == requestedLanguage }
        return matches.sorted {
            localeMatchScore($0, requestedIdentifier: normalizedRequest) < localeMatchScore($1, requestedIdentifier: normalizedRequest)
        }.first
    }

    private static func localeMatchScore(_ locale: Locale, requestedIdentifier: String) -> Int {
        let normalizedLocale = normalizedIdentifier(locale.identifier)
        var score = normalizedLocale == requestedIdentifier ? 0 : 100

        if requestedIdentifier.contains("hans"),
           normalizedLocale.contains("hans") || normalizedLocale.contains("cn") || normalizedLocale.contains("sg") {
            score -= 35
        }
        if requestedIdentifier.contains("hant"),
           normalizedLocale.contains("hant") || normalizedLocale.contains("tw") || normalizedLocale.contains("hk") {
            score -= 35
        }

        let requestedPieces = requestedIdentifier.split(separator: "-")
        if requestedPieces.count > 1,
           let requestedRegion = requestedPieces.last,
           normalizedLocale.split(separator: "-").contains(requestedRegion) {
            score -= 20
        }

        if normalizedLocale == normalizedIdentifier(Locale.current.identifier) {
            score -= 8
        }
        return score
    }

    private static func languageCode(from identifier: String) -> String {
        Locale(identifier: identifier.replacingOccurrences(of: "-", with: "_")).languageCode
            ?? identifier.split(separator: "-").first.map(String.init)
            ?? identifier
    }

    private static func normalizedIdentifier(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    }

    private static func displayName(for locale: Locale) -> String {
        Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
    }
}

struct AudioPipelineError: Error, Sendable, CustomNSError {
    let localizedDescription: String

    init(_ localizedDescription: String) {
        self.localizedDescription = localizedDescription
    }

    var errorUserInfo: [String: Any] {
        [NSLocalizedDescriptionKey: localizedDescription]
    }
}

extension AVAudioSession.CategoryOptions {
    static var luminaAllowBluetoothHFP: AVAudioSession.CategoryOptions {
        if #available(iOS 26.0, *) {
            return .allowBluetoothHFP
        }
        return .allowBluetooth
    }
}

extension AVAudioPCMBuffer {
    static func luminaFromInterleavedData(_ data: Data, format: AVAudioFormat) throws -> AVAudioPCMBuffer? {
        guard format.isInterleaved else {
            throw AudioPipelineError("Only interleaved audio data is supported.")
        }

        let bytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
        guard bytesPerFrame > 0 else { return nil }
        let frameCapacity = AVAudioFrameCount(data.count / bytesPerFrame)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            return nil
        }

        buffer.frameLength = frameCapacity
        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            let destination = buffer.mutableAudioBufferList.pointee.mBuffers
            destination.mData?.copyMemory(from: baseAddress, byteCount: Int(destination.mDataByteSize))
        }
        return buffer
    }

    func luminaInt16Data() throws -> Data {
        guard let bufferPointer = audioBufferList.pointee.mBuffers.mData else {
            throw AudioPipelineError("Missing audio buffer.")
        }
        return Data(bytes: bufferPointer, count: Int(audioBufferList.pointee.mBuffers.mDataByteSize))
    }
}

extension AVAudioConverter {
    func luminaConvert(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        if buffer.format == outputFormat { return buffer }
        guard buffer.format == inputFormat else {
            throw AudioPipelineError("Audio converter received an incompatible format.")
        }

        let frameCapacity = AVAudioFrameCount(
            ceil(Double(buffer.frameLength) * outputFormat.sampleRate / inputFormat.sampleRate)
        )
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCapacity) else {
            throw AudioPipelineError("Could not create converted audio buffer.")
        }

        var conversionError: NSError?
        var didProvideInput = false
        convert(to: output, error: &conversionError) { _, status in
            if didProvideInput {
                status.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            status.pointee = .haveData
            return buffer
        }

        if let conversionError {
            throw AudioPipelineError("Could not convert audio: \(conversionError.localizedDescription)")
        }
        return output
    }
}

final class LiveAudioPlayer {
    private let engine: AVAudioEngine
    private let inputFormat: AVAudioFormat
    private let outputFormat: AVAudioFormat
    private let playerNode = AVAudioPlayerNode()
    private let converter: AVAudioConverter

    init(engine: AVAudioEngine, inputFormat: AVAudioFormat, outputFormat: AVAudioFormat) throws {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioPipelineError("Could not create audio playback converter.")
        }
        self.engine = engine
        self.inputFormat = inputFormat
        self.outputFormat = outputFormat
        self.converter = converter
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: outputFormat)
    }

    func play(_ audio: Data) throws {
        guard engine.isRunning,
              let inputBuffer = try AVAudioPCMBuffer.luminaFromInterleavedData(audio, format: inputFormat) else { return }
        let outputBuffer = try converter.luminaConvert(inputBuffer)
        playerNode.scheduleBuffer(outputBuffer, at: nil)
        playerNode.play()
    }

    func interrupt() {
        playerNode.stop()
    }

    func stop() {
        interrupt()
        engine.disconnectNodeInput(playerNode)
        engine.disconnectNodeOutput(playerNode)
    }
}

final class LiveMicrophone {
    let audio: AsyncStream<AVAudioPCMBuffer>
    private let audioQueue: AsyncStream<AVAudioPCMBuffer>.Continuation
    private let inputNode: AVAudioInputNode
    private var isRunning = false

    init(engine: AVAudioEngine) {
        let stream = AsyncStream<AVAudioPCMBuffer>.makeStream()
        audio = stream.stream
        audioQueue = stream.continuation
        inputNode = engine.inputNode
    }

    deinit {
        stop()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let bufferSize = UInt32(inputNode.outputFormat(forBus: 0).sampleRate / 20)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] buffer, _ in
            self?.audioQueue.yield(buffer)
        }
    }

    func stop() {
        audioQueue.finish()
        guard isRunning else { return }
        isRunning = false
        inputNode.removeTap(onBus: 0)
    }
}

final class TherapyVideoFrameEmitter: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let lock = NSLock()
    private let ciContext = CIContext()
    private var isEnabled = false
    private var lastFrameSentAt: TimeInterval = 0
    private var onFrame: ((Data) -> Void)?
    private let minimumFrameInterval: TimeInterval = 1.0

    func setEnabled(_ enabled: Bool) {
        lock.lock()
        isEnabled = enabled
        if !enabled {
            lastFrameSentAt = 0
        }
        lock.unlock()
    }

    func setOnFrame(_ handler: ((Data) -> Void)?) {
        lock.lock()
        onFrame = handler
        lock.unlock()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date().timeIntervalSince1970
        lock.lock()
        let shouldSend = isEnabled && now - lastFrameSentAt >= minimumFrameInterval
        if shouldSend {
            lastFrameSentAt = now
        }
        let frameHandler = onFrame
        lock.unlock()

        guard shouldSend,
              let frameHandler,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent),
              let jpeg = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.56) else { return }
        frameHandler(jpeg)
    }
}

actor LiveAudioController {
    private let microphoneData: AsyncStream<AVAudioPCMBuffer>
    private let microphoneDataQueue: AsyncStream<AVAudioPCMBuffer>.Continuation
    private let modelInputFormat: AVAudioFormat
    private let modelOutputFormat: AVAudioFormat
    private let headphonePortTypes: [AVAudioSession.Port] = [.headphones, .bluetoothA2DP, .bluetoothLE, .bluetoothHFP]

    private var audioEngine: AVAudioEngine?
    private var audioPlayer: LiveAudioPlayer?
    private var microphone: LiveMicrophone?
    private var listenTask: Task<Void, Error>?
    private var routeTask: Task<Void, Never>?
    private var stopped = false

    init() async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .luminaAllowBluetoothHFP, .duckOthers, .interruptSpokenAudioAndMixWithOthers, .allowBluetoothA2DP]
        )
        try session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true)

        guard let inputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true),
              let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: true) else {
            throw AudioPipelineError("Could not create Live audio formats.")
        }
        modelInputFormat = inputFormat
        modelOutputFormat = outputFormat

        let stream = AsyncStream<AVAudioPCMBuffer>.makeStream()
        microphoneData = stream.stream
        microphoneDataQueue = stream.continuation
        listenForRouteChanges()
    }

    func listenToMic() async throws -> AsyncStream<AVAudioPCMBuffer> {
        try await spawnAudioProcessingThread()
        return microphoneData
    }

    func playAudio(_ audio: Data) async throws {
        try audioPlayer?.play(audio)
    }

    func interrupt() {
        audioPlayer?.interrupt()
    }

    func stop() async {
        stopped = true
        await stopListeningAndPlayback()
        microphoneDataQueue.finish()
        routeTask?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func stopListeningAndPlayback() async {
        listenTask?.cancel()
        audioEngine?.pause()
        audioEngine?.stop()
        if let audioEngine, audioEngine.inputNode.isVoiceProcessingEnabled {
            try? audioEngine.inputNode.setVoiceProcessingEnabled(false)
        }
        microphone?.stop()
        audioPlayer?.stop()
    }

    private func spawnAudioProcessingThread() async throws {
        if stopped { return }
        await stopListeningAndPlayback()

        let engine = AVAudioEngine()
        audioEngine = engine
        try setupPlayback(engine)
        try setupVoiceProcessing(engine)
        try engine.start()
        try await setupMicrophone(engine)
    }

    private func setupPlayback(_ engine: AVAudioEngine) throws {
        let playbackFormat = engine.outputNode.outputFormat(forBus: 0)
        audioPlayer = try LiveAudioPlayer(engine: engine, inputFormat: modelOutputFormat, outputFormat: playbackFormat)
    }

    private func setupMicrophone(_ engine: AVAudioEngine) async throws {
        let microphone = LiveMicrophone(engine: engine)
        self.microphone = microphone
        microphone.start()

        let micFormat = engine.inputNode.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: micFormat, to: modelInputFormat) else {
            throw AudioPipelineError("Could not create microphone audio converter.")
        }

        listenTask = Task {
            for await audio in microphone.audio {
                try microphoneDataQueue.yield(converter.luminaConvert(audio))
            }
        }
    }

    private func setupVoiceProcessing(_ engine: AVAudioEngine) throws {
        let hasHeadphones = headphonesConnected()
        if !engine.inputNode.isVoiceProcessingEnabled, !hasHeadphones {
            try engine.inputNode.setVoiceProcessingEnabled(true)
        } else if engine.inputNode.isVoiceProcessingEnabled, hasHeadphones {
            try engine.inputNode.setVoiceProcessingEnabled(false)
        }
    }

    private func listenForRouteChanges() {
        routeTask?.cancel()
        routeTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: AVAudioSession.routeChangeNotification) {
                await self?.handleRouteChange(notification)
            }
        }
    }

    private func handleRouteChange(_ notification: Notification) async {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
              reason == .newDeviceAvailable || reason == .oldDeviceUnavailable else { return }
        try? await spawnAudioProcessingThread()
    }

    private func headphonesConnected() -> Bool {
        AVAudioSession.sharedInstance().currentRoute.outputs.contains { headphonePortTypes.contains($0.portType) }
    }
}

// MARK: - Root

struct FullChatView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var speechInput = SpeechInputController()
    @State private var activeTherapist: Therapist?
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var showStats = false
    @State private var metrics = EmotionalMetrics()
    @State private var activeCall: TherapyCallKind?
    @State private var currentSessionID: String?
    @State private var conversationState: ConversationState = .checkIn
    @State private var riskLevel: RiskLevel = .none
    @State private var turnMetadata: [ConversationTurnMetadata] = []
    @State private var requestID = UUID()
    @State private var quotaNotice: String?
    @State private var activeUsesJournalContext = false
    @State private var activeUsesGuideMemory = false
    @State private var speechInputRequestID = 0

    var body: some View {
        ZStack {
            if let therapist = activeTherapist {
                let messageSnapshot = messages
                let metricsSnapshot = metrics
                let sessionIDSnapshot = currentSessionID
                ChatScreenView(
                    therapist: therapist,
                    messages: messageSnapshot,
                    sessionID: sessionIDSnapshot,
                    userAvatarID: appState.profileAvatarID,
                    isLoading: isLoading,
                    showStats: showStats,
                    conversationState: conversationState,
                    isNetworkAvailable: appState.isNetworkAvailable,
                    usesJournalContext: activeUsesJournalContext,
                    usesGuideMemory: activeUsesGuideMemory,
                    onBack: {
                        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.88)) {
                            closeCurrentSession()
                        }
                    },
                    onToggleStats: { showStats.toggle() },
                    onReset: {
                        startNewSession(
                            therapist: therapist,
                            previousSessionID: sessionIDSnapshot,
                            previousMessages: messageSnapshot,
                            previousMetrics: metricsSnapshot
                        )
                    },
                    onStartVoiceCall: { startCallIfAllowed(.voice) },
                    onStartVideoCall: { startCallIfAllowed(.video) },
                    speechInput: speechInput,
                    speechInputRequestID: speechInputRequestID,
                    onSelectConversationState: selectConversationState,
                    onSend: send
                )
                .id(therapist.id)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
                .sheet(isPresented: $showStats) {
                    StatsSheetContent(
                        metrics: metrics,
                        therapist: therapist,
                        sessions: appState.sessions(for: therapist),
                        currentSessionID: currentSessionID,
                        onSelectHistorySession: openSession,
                        onArchiveHistorySession: { session in
                            appState.archiveSession(id: session.id)
                        },
                        onDeleteHistorySession: { session in
                            appState.deleteSession(id: session.id)
                        }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
                .fullScreenCover(item: $activeCall) { callKind in
                    TherapyCallView(
                        therapist: therapist,
                        callKind: callKind,
                        initialMessages: messageSnapshot,
                        conversationState: conversationState,
                        riskLevel: riskLevel,
                        contextBrief: appState.therapyContextBrief(for: therapist),
                        onCommitTurn: commitCallTurn,
                        onFallbackToVoiceInput: {
                            activeCall = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                speechInputRequestID += 1
                            }
                        },
                        onFallbackToText: {
                            activeCall = nil
                        },
                        onRecordUsage: { seconds in
                            recordLiveCallUsage(seconds)
                        },
                        onEnd: { activeCall = nil }
                    )
                }
            } else {
                SelectionView(
                    sessions: appState.chatSessions,
                    onOpen: open,
                    onOpenSession: openExistingSession,
                    onArchiveSession: { session in
                        appState.archiveSession(id: session.id)
                    },
                    onDeleteSession: { session in
                        appState.deleteSession(id: session.id)
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.88), value: activeTherapist?.id)
        .onAppear(perform: openPendingTherapyRequestIfNeeded)
        .onChange(of: appState.pendingTherapySessionID) { _ in
            openPendingTherapyRequestIfNeeded()
        }
        .onChange(of: appState.pendingTherapyTherapistID) { _ in
            openPendingTherapyRequestIfNeeded()
        }
        .onChange(of: appState.isNetworkAvailable) { isAvailable in
            handleNetworkChange(isAvailable)
        }
        .alert(quotaNoticeTitle, isPresented: Binding(
            get: { quotaNotice != nil },
            set: { if !$0 { quotaNotice = nil } }
        )) {
            Button("OK", role: .cancel) { quotaNotice = nil }
        } message: {
            Text(quotaNotice ?? "")
        }
    }

    private var quotaNoticeTitle: String {
        if quotaNotice?.localizedCaseInsensitiveContains("internet") == true ||
            quotaNotice?.localizedCaseInsensitiveContains("offline") == true {
            return "Offline"
        }
        if quotaNotice?.localizedCaseInsensitiveContains("voice") == true ||
            quotaNotice?.localizedCaseInsensitiveContains("preview") == true {
            return "Free voice preview used"
        }
        return "Live unavailable"
    }

    private func handleNetworkChange(_ isAvailable: Bool) {
        guard !isAvailable else { return }
        if speechInput.isListening {
            speechInput.stop()
        }
        guard isLoading else { return }
        requestID = UUID()
        isLoading = false
        messages.append(ChatMessage(
            id: UUID().uuidString,
            role: .model,
            text: GeminiService.networkUnavailableMessage
        ))
        saveCurrentSession()
    }

    private func openPendingTherapyRequestIfNeeded() {
        if let sessionID = appState.pendingTherapySessionID {
            guard let session = appState.chatSessions[sessionID] else {
                appState.consumePendingTherapyRequest()
                return
            }
            openExistingSession(session)
            appState.consumePendingTherapyRequest()
            return
        }

        guard let id = appState.pendingTherapyTherapistID,
              let therapist = allTherapists.first(where: { $0.id == id }) else { return }
        openNewSession(therapist)
        appState.consumePendingTherapyRequest()
    }

    private func open(_ therapist: Therapist) {
        openNewSession(therapist)
    }

    private func startCallIfAllowed(_ kind: TherapyCallKind) {
        guard appState.isSignedIn else {
            NotificationCenter.default.post(name: .luminaShowRegistrationGate, object: nil)
            return
        }
        guard appState.isNetworkAvailable else {
            quotaNotice = GeminiService.networkUnavailableMessage
            return
        }
        guard appState.canStartLiveCall() else {
            quotaNotice = "Your free voice preview is used for today. Text chat is still available, and Plus keeps longer voice sessions available."
            return
        }
        activeCall = kind
    }

    private func recordLiveCallUsage(_ seconds: Int) {
        guard seconds > 0 else { return }
        appState.recordLiveCallSeconds(seconds)
        Task {
            do {
                try await GeminiService.shared.recordVoiceUsage(seconds: seconds)
                await MainActor.run {
                    appState.refreshSubscriptionFromCloud()
                }
            } catch {
                print("Lumia voice usage sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func openNewSession(_ therapist: Therapist) {
        let nextSessionID = UUID().uuidString
        let nextMessages = [ChatMessage(id: UUID().uuidString, role: .model, text: appState.personalizedTherapyOpening(for: therapist) ?? therapist.greeting)]

        requestID = UUID()
        speechInput.cancel()
        activeTherapist = therapist
        isLoading = false
        showStats = false
        activeCall = nil
        currentSessionID = nextSessionID
        messages = nextMessages
        metrics = EmotionalMetrics()
        conversationState = .checkIn
        riskLevel = .none
        turnMetadata = []
        refreshActiveContextNotice(for: therapist, excluding: nextSessionID)

        appState.saveSession(ChatSession(
            id: nextSessionID,
            therapistID: therapist.id,
            messages: nextMessages,
            metrics: EmotionalMetrics()
        ), publish: .silent)
    }

    private func openExistingSession(_ session: ChatSession) {
        let therapistID = session.therapistID == session.id ? session.id : session.therapistID
        guard let therapist = allTherapists.first(where: { $0.id == therapistID }) else { return }

        requestID = UUID()
        speechInput.cancel()
        activeTherapist = therapist
        isLoading = false
        showStats = false
        activeCall = nil
        currentSessionID = session.id
        messages = session.messages.isEmpty
            ? [ChatMessage(id: UUID().uuidString, role: .model, text: therapist.greeting)]
            : session.messages
        metrics = session.metrics
        conversationState = session.conversationState
        riskLevel = session.lastRiskLevel
        turnMetadata = session.turnMetadata
        refreshActiveContextNotice(for: therapist, excluding: session.id)
    }

    private func closeCurrentSession() {
        let session = currentSession()
        let therapistSnapshot = activeTherapist

        requestID = UUID()
        speechInput.cancel()
        isLoading = false
        showStats = false
        activeCall = nil
        activeTherapist = nil
        currentSessionID = nil
        conversationState = .checkIn
        riskLevel = .none
        turnMetadata = []
        activeUsesJournalContext = false
        activeUsesGuideMemory = false
        messages = []
        metrics = EmotionalMetrics()

        if let session {
            appState.saveSession(session)
            if let therapistSnapshot {
                appState.saveTherapySessionReflection(session, therapist: therapistSnapshot)
            }
        }
    }

    private func startNewSession(
        therapist: Therapist,
        previousSessionID: String?,
        previousMessages: [ChatMessage],
        previousMetrics: EmotionalMetrics
    ) {
        let previousSession = !previousMessages.isEmpty
            ? ChatSession(
                id: previousSessionID ?? UUID().uuidString,
                therapistID: therapist.id,
                messages: previousMessages,
                metrics: previousMetrics,
                conversationState: conversationState,
                lastRiskLevel: riskLevel,
                turnMetadata: turnMetadata
            )
            : nil
        let nextSessionID = UUID().uuidString
        let nextMessages = [ChatMessage(id: UUID().uuidString, role: .model, text: appState.personalizedTherapyOpening(for: therapist) ?? therapist.greeting)]
        let nextMetrics = EmotionalMetrics()
        let nextSession = ChatSession(
            id: nextSessionID,
            therapistID: therapist.id,
            messages: nextMessages,
            metrics: nextMetrics
        )

        requestID = UUID()
        speechInput.cancel()
        activeTherapist = therapist
        isLoading = false
        showStats = false
        activeCall = nil
        currentSessionID = nextSessionID
        messages = nextMessages
        metrics = nextMetrics
        conversationState = .checkIn
        riskLevel = .none
        turnMetadata = []

        appState.saveSessions([previousSession, nextSession].compactMap { $0 }, publish: .silent)
        refreshActiveContextNotice(for: therapist, excluding: nextSessionID)
    }

    private func openSession(_ session: ChatSession) {
        guard let therapist = activeTherapist,
              session.therapistID == therapist.id || session.id == therapist.id else { return }
        let previousSession = currentSession()

        requestID = UUID()
        speechInput.cancel()
        isLoading = false
        showStats = false
        activeCall = nil
        currentSessionID = session.id
        messages = session.messages
        metrics = session.metrics
        conversationState = session.conversationState
        riskLevel = session.lastRiskLevel
        turnMetadata = session.turnMetadata

        if let previousSession {
            appState.saveSession(previousSession, publish: .silent)
        }
        refreshActiveContextNotice(for: therapist, excluding: session.id)
    }

    private func refreshActiveContextNotice(for therapist: Therapist, excluding sessionID: String?) {
        activeUsesJournalContext = appState.isUsingJournalContext(for: therapist)
        activeUsesGuideMemory = appState.hasTherapistMemory(for: therapist, excluding: sessionID)
    }

    private func saveCurrentSession() {
        guard let session = currentSession(ensureID: true) else { return }
        appState.saveSession(session, publish: .silent)
    }

    private func commitCallTurn(userText: String, assistantText: String) {
        let cleanedUserText = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedAssistantText = assistantText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedUserText.isEmpty || !cleanedAssistantText.isEmpty else { return }
        if !cleanedUserText.isEmpty {
            messages.append(ChatMessage(id: UUID().uuidString, role: .user, text: cleanedUserText))
        }
        if !cleanedAssistantText.isEmpty {
            messages.append(ChatMessage(id: UUID().uuidString, role: .model, text: cleanedAssistantText))
        }
        saveCurrentSession()
    }

    private func selectConversationState(_ state: ConversationState) {
        guard conversationState != state else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            conversationState = state
            if riskLevel < .medium {
                riskLevel = .none
            }
        }
        saveCurrentSession()
    }

    private func currentSession(ensureID: Bool = false) -> ChatSession? {
        guard let therapist = activeTherapist else { return nil }
        let sessionID = currentSessionID ?? UUID().uuidString
        if ensureID {
            currentSessionID = sessionID
        }
        return ChatSession(
            id: sessionID,
            therapistID: therapist.id,
            messages: messages,
            metrics: metrics,
            conversationState: conversationState,
            lastRiskLevel: riskLevel,
            turnMetadata: turnMetadata
        )
    }

    private func send(_ rawText: String) {
        guard let therapist = activeTherapist else { return }
        if speechInput.isListening {
            speechInput.stop()
        }
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(id: UUID().uuidString, role: .user, text: text))

        let stateBeforeTurn = conversationState
        let turnPreparation = ConversationEngine().prepareTurn(
            userText: text,
            currentState: conversationState
        )
        riskLevel = turnPreparation.safetyAssessment.riskLevel
        conversationState = turnPreparation.nextState
        let contextBrief = turnPreparation.shouldUseAI
            ? appState.therapyContextBrief(for: therapist, excluding: currentSessionID)
            : nil
        if contextBrief != nil {
            appState.syncTherapyContextToCloud(for: therapist)
        }
        let contextReasonCodes = contextBrief == nil ? [] : appState.therapyContextReasonCodes(for: therapist)
        let metadata = ConversationTurnMetadata(
            stateBefore: stateBeforeTurn,
            stateAfter: turnPreparation.nextState,
            intent: turnPreparation.nextState.turnIntent,
            riskLevel: turnPreparation.safetyAssessment.riskLevel,
            reasonCodes: turnPreparation.safetyAssessment.reasonCodes + contextReasonCodes,
            suggestedIntervention: turnPreparation.suggestedIntervention,
            usedAI: turnPreparation.shouldUseAI
        )
        turnMetadata.append(metadata)
        appState.recordTherapyTurnEvaluation(
            sessionID: currentSessionID,
            therapistID: therapist.id,
            metadata: metadata
        )
        if turnPreparation.nextState == .plan,
           let microPlan = ConversationEngine().extractMicroPlan(from: text, sourceSessionID: currentSessionID) {
            appState.addTherapyMicroPlan(microPlan)
        }

        if turnPreparation.shouldUseAI, !appState.isNetworkAvailable {
            messages.append(ChatMessage(
                id: UUID().uuidString,
                role: .model,
                text: GeminiService.networkUnavailableMessage
            ))
            isLoading = false
            saveCurrentSession()
            return
        }

        isLoading = true

        if !turnPreparation.shouldUseAI, let immediateReply = turnPreparation.immediateReply {
            messages.append(ChatMessage(
                id: UUID().uuidString,
                role: .model,
                text: immediateReply
            ))
            isLoading = false
            saveCurrentSession()
            return
        }

        if turnPreparation.shouldUseAI, !appState.canStartAIChatReply() {
            messages.append(ChatMessage(
                id: UUID().uuidString,
                role: .model,
                text: "You have used today's free AI replies. We can keep this conversation saved here, and you can continue tomorrow or upgrade for longer support."
            ))
            isLoading = false
            saveCurrentSession()
            return
        }

        saveCurrentSession()

        let history = Array(messages.dropLast())
        let stateSnapshot = conversationState
        let riskSnapshot = riskLevel
        let contextBriefSnapshot = contextBrief
        let sessionIDSnapshot = currentSessionID
        let activeRequestID = UUID()
        requestID = activeRequestID

        Task {
            do {
                let reply = try await GeminiService.shared.chat(
                    therapist: therapist,
                    history: history,
                    newMessage: text,
                    conversationState: stateSnapshot,
                    riskLevel: riskSnapshot,
                    contextBrief: contextBriefSnapshot
                )

                await MainActor.run {
                    guard requestID == activeRequestID else { return }
                    appState.recordAIChatReplyUsed()
                    messages.append(ChatMessage(id: UUID().uuidString, role: .model, text: reply))
                    if stateSnapshot == .plan,
                       let microPlan = ConversationEngine().extractMicroPlan(from: reply, sourceSessionID: sessionIDSnapshot) {
                        appState.addTherapyMicroPlan(microPlan)
                    }
                    isLoading = false
                    saveCurrentSession()
                }

                let sentimentHistory = await MainActor.run { messages }
                if let analyzedMetrics = try? await GeminiService.shared.analyzeSentiment(history: sentimentHistory) {
                    await MainActor.run {
                        guard requestID == activeRequestID else { return }
                        metrics = analyzedMetrics
                        saveCurrentSession()
                    }
                }
            } catch {
                await MainActor.run {
                    guard requestID == activeRequestID else { return }
                    let message = GeminiService.userFacingMessage(
                        for: error,
                        fallback: "I could not respond right now. Please try again in a moment."
                    )
                    messages.append(ChatMessage(
                        id: UUID().uuidString,
                        role: .model,
                        text: message
                    ))
                    isLoading = false
                    saveCurrentSession()
                }
            }
        }
    }
}

enum TherapyCallKind: String, Identifiable {
    case voice
    case video

    var id: String { rawValue }

    var title: String {
        switch self {
        case .voice: return "Voice Session"
        case .video: return "Video Session"
        }
    }

    var systemImage: String {
        switch self {
        case .voice: return "phone.fill"
        case .video: return "video.fill"
        }
    }
}

@MainActor
final class TherapyCallSessionController: NSObject, ObservableObject {
    @Published private(set) var isMuted = false
    @Published private(set) var isSpeakerOn = true
    @Published private(set) var isCameraOn = false
    @Published private(set) var isAudioReady = false
    @Published private(set) var isCameraReady = false
    @Published private(set) var isSharingCameraWithAI = false
    @Published private(set) var permissionMessage: String?
    @Published private(set) var statusText = "Connecting..."

    let captureSession = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "Lumia.TherapyCall.CameraSession")
    private let videoFrameEmitter = TherapyVideoFrameEmitter()
    private var currentKind: TherapyCallKind = .voice
    private var cameraInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var hasConfiguredCamera = false

    func start(kind: TherapyCallKind) {
        currentKind = kind
        isMuted = false
        isSpeakerOn = true
        isCameraOn = kind == .video
        isSharingCameraWithAI = false
        videoFrameEmitter.setEnabled(false)
        isAudioReady = false
        isCameraReady = false
        permissionMessage = nil
        statusText = "Connecting..."
        configureAudioSession()

        if kind == .video {
            requestCameraAccess()
        }
    }

    func stop() {
        statusText = "Ending session..."
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
        videoFrameEmitter.setEnabled(false)
        videoFrameEmitter.setOnFrame(nil)
        isSharingCameraWithAI = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            permissionMessage = "Audio session could not close cleanly."
        }
    }

    func toggleMute() {
        isMuted.toggle()
        statusText = isMuted ? "Muted" : "Connected and listening"
    }

    func toggleSpeaker() {
        let nextValue = !isSpeakerOn
        do {
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(nextValue ? .speaker : .none)
            isSpeakerOn = nextValue
        } catch {
            permissionMessage = "Could not switch audio output."
        }
    }

    func resumeAudioSession() {
        configureAudioSession()
    }

    func setVideoFrameHandler(_ handler: ((Data) -> Void)?) {
        videoFrameEmitter.setOnFrame(handler)
    }

    func toggleCameraSharingWithAI() {
        guard currentKind == .video, isCameraOn, isCameraReady else { return }
        isSharingCameraWithAI.toggle()
        videoFrameEmitter.setEnabled(isSharingCameraWithAI)
        statusText = isSharingCameraWithAI ? "Video context shared" : "Video session ready"
    }

    func toggleCamera() {
        guard currentKind == .video else { return }
        let shouldTurnOn = !isCameraOn
        isCameraOn = shouldTurnOn
        if shouldTurnOn {
            if hasConfiguredCamera {
                startCameraRunning()
            } else {
                requestCameraAccess()
            }
        } else {
            isSharingCameraWithAI = false
            videoFrameEmitter.setEnabled(false)
            stopCameraRunning()
        }
    }

    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            activateAudioSession()
        case .denied:
            permissionMessage = "Microphone access is off. Enable it in Settings to use calls."
            statusText = "Microphone unavailable"
        case .undetermined:
            audioSession.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted {
                        self.activateAudioSession()
                    } else {
                        self.permissionMessage = "Microphone access is needed for voice sessions."
                        self.statusText = "Microphone unavailable"
                    }
                }
            }
        @unknown default:
            permissionMessage = "Microphone permission could not be checked."
            statusText = "Microphone unavailable"
        }
    }

    private func activateAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.setActive(true)
            try audioSession.overrideOutputAudioPort(.speaker)
            isAudioReady = true
            isSpeakerOn = true
            statusText = currentKind == .video ? "Video session ready" : "Connected and listening"
        } catch {
            permissionMessage = "Audio could not start. Check microphone permissions."
            statusText = "Audio unavailable"
        }
    }

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCameraIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted {
                        self.configureCameraIfNeeded()
                    } else {
                        self.isCameraReady = false
                        self.isCameraOn = false
                        self.permissionMessage = "Camera access is off. Enable it in Settings to use video."
                    }
                }
            }
        case .denied, .restricted:
            isCameraReady = false
            isCameraOn = false
            permissionMessage = "Camera access is off. Enable it in Settings to use video."
        @unknown default:
            isCameraReady = false
            isCameraOn = false
            permissionMessage = "Camera permission could not be checked."
        }
    }

    private func configureCameraIfNeeded() {
        if hasConfiguredCamera {
            isCameraReady = true
            startCameraRunning()
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            let session = self.captureSession
            session.beginConfiguration()
            session.sessionPreset = .medium

            if let currentInput = self.cameraInput {
                session.removeInput(currentInput)
            }
            if let currentOutput = self.videoOutput {
                session.removeOutput(currentOutput)
            }

            guard
                let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                let input = try? AVCaptureDeviceInput(device: camera),
                session.canAddInput(input)
            else {
                session.commitConfiguration()
                Task { @MainActor in
                    self.isCameraReady = false
                    self.isCameraOn = false
                    self.permissionMessage = "Front camera is not available."
                }
                return
            }

            session.addInput(input)
            self.cameraInput = input
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.setSampleBufferDelegate(self.videoFrameEmitter, queue: self.sessionQueue)
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                self.videoOutput = videoOutput
                videoOutput.connection(with: .video)?.isVideoMirrored = true
            }
            session.commitConfiguration()

            if !session.isRunning {
                session.startRunning()
            }

            Task { @MainActor in
                self.hasConfiguredCamera = true
                self.isCameraReady = true
                self.isCameraOn = true
                if self.statusText == "Connecting..." {
                    self.statusText = "Video session ready"
                }
            }
        }
    }

    private func startCameraRunning() {
        sessionQueue.async { [captureSession] in
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        }
    }

    private func stopCameraRunning() {
        isSharingCameraWithAI = false
        videoFrameEmitter.setEnabled(false)
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
        isCameraReady = false
    }
}

enum TherapyLiveState: Equatable {
    case idle
    case connecting
    case connected
    case failed(String)

    var label: String {
        switch self {
        case .idle: return "Ready"
        case .connecting: return "Calling..."
        case .connected: return "Live connected"
        case .failed(let message):
            if message.localizedCaseInsensitiveContains("internet") ||
                message.localizedCaseInsensitiveContains("offline") {
                return "Offline"
            }
            return "Voice unavailable"
        }
    }
}

@MainActor
final class CallToneFeedback {
    private var timer: Timer?
    private var player: AVAudioPlayer?

    func startDialTone() {
        stop()
        playTone(frequency: 440, duration: 0.18, volume: 0.24)
        timer = Timer.scheduledTimer(withTimeInterval: 1.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.playTone(frequency: 440, duration: 0.18, volume: 0.24)
            }
        }
    }

    func playConnectedTone() {
        stop()
        playTone(frequency: 880, duration: 0.10, volume: 0.18)
    }

    func playFailedTone() {
        stop()
        playTone(frequency: 220, duration: 0.16, volume: 0.16)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
    }

    private func playTone(frequency: Double, duration: Double, volume: Float) {
        guard let data = Self.wavToneData(frequency: frequency, duration: duration) else { return }
        do {
            player = try AVAudioPlayer(data: data)
            player?.volume = volume
            player?.prepareToPlay()
            player?.play()
        } catch {
            player = nil
        }
    }

    private static func wavToneData(frequency: Double, duration: Double) -> Data? {
        let sampleRate = 44_100
        let sampleCount = Int(Double(sampleRate) * duration)
        let byteRate = sampleRate * 2
        let dataSize = sampleCount * 2
        var data = Data()

        func appendString(_ value: String) {
            data.append(value.data(using: .ascii) ?? Data())
        }

        func appendUInt16(_ value: UInt16) {
            var little = value.littleEndian
            data.append(Data(bytes: &little, count: MemoryLayout<UInt16>.size))
        }

        func appendUInt32(_ value: UInt32) {
            var little = value.littleEndian
            data.append(Data(bytes: &little, count: MemoryLayout<UInt32>.size))
        }

        appendString("RIFF")
        appendUInt32(UInt32(36 + dataSize))
        appendString("WAVEfmt ")
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(1)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(byteRate))
        appendUInt16(2)
        appendUInt16(16)
        appendString("data")
        appendUInt32(UInt32(dataSize))

        for index in 0..<sampleCount {
            let envelope = min(1.0, Double(index) / 400.0) * min(1.0, Double(sampleCount - index) / 400.0)
            let sample = sin(2.0 * .pi * frequency * Double(index) / Double(sampleRate)) * 0.7 * envelope
            var intSample = Int16(sample * Double(Int16.max)).littleEndian
            data.append(Data(bytes: &intSample, count: MemoryLayout<Int16>.size))
        }

        return data
    }
}

@MainActor
final class TherapyLiveCallController: ObservableObject {
    @Published private(set) var state: TherapyLiveState = .idle
    @Published private(set) var isMuted = false
    @Published private(set) var inputTranscript = ""
    @Published private(set) var outputTranscript = "Connecting to Gemini Live..."
    @Published private(set) var errorMessage: String?

    private var liveModel: LiveGenerativeModel?
    private var liveSession: LiveSession?
    private var audioController: LiveAudioController?
    private var microphoneTask: Task<Void, Never>?
    private var responseTask: Task<Void, Never>?
    private let toneFeedback = CallToneFeedback()
    private var currentInputTurn = ""
    private var currentOutputTurn = ""
    private var onCommitTurn: ((_ userText: String, _ assistantText: String) -> Void)?

    func connect(
        therapist: Therapist,
        history: [ChatMessage],
        contextBrief: String?,
        isVideoCall: Bool,
        onCommitTurn: @escaping (_ userText: String, _ assistantText: String) -> Void
    ) {
        guard state == .idle else { return }
        self.onCommitTurn = onCommitTurn
        state = .connecting
        errorMessage = nil
        inputTranscript = ""
        outputTranscript = "Calling \(therapist.name)..."
        toneFeedback.startDialTone()

        Task {
            guard await requestRecordPermission() else {
                await MainActor.run {
                    self.markFailed(
                        "Microphone access is off. Enable it in Settings, or continue in text chat.",
                        output: "Microphone access is needed for Live voice."
                    )
                }
                return
            }

            do {
                let systemInstruction = Self.liveSystemInstruction(
                    therapist: therapist,
                    history: history,
                    contextBrief: contextBrief,
                    isVideoCall: isVideoCall
                )
                let runtimeConfig = try await GeminiService.shared.runtimeConfig()
                let ai = FirebaseAI.firebaseAI(backend: .googleAI())
                let model = ai.liveModel(
                    modelName: runtimeConfig.liveModel,
                    generationConfig: LiveGenerationConfig(
                        temperature: 0.7,
                        responseModalities: [.audio],
                        speech: SpeechConfig(voiceName: Self.voiceName(for: therapist)),
                        inputAudioTranscription: AudioTranscriptionConfig(),
                        outputAudioTranscription: AudioTranscriptionConfig()
                    ),
                    systemInstruction: ModelContent(parts: systemInstruction)
                )
                let session = try await model.connect()
                let audio = try await LiveAudioController()

                await MainActor.run {
                    self.liveModel = model
                    self.liveSession = session
                    self.audioController = audio
                    self.state = .connected
                    self.outputTranscript = "Connected. You can speak naturally now."
                    self.toneFeedback.playConnectedTone()
                }

                startResponseProcessing(session: session, audio: audio)
                await session.sendTextRealtime(Self.liveOpeningContext(history: history, contextBrief: contextBrief, isVideoCall: isVideoCall))
                try await startMicrophoneStreaming(audio: audio, session: session)
            } catch {
                await MainActor.run {
                    let message = Self.userFacingLiveError(error)
                    self.markFailed(message, output: message)
                }
                await disconnect()
            }
        }
    }

    func retry(
        therapist: Therapist,
        history: [ChatMessage],
        contextBrief: String?,
        isVideoCall: Bool,
        onCommitTurn: @escaping (_ userText: String, _ assistantText: String) -> Void
    ) {
        Task {
            await disconnect(resetAfterFailure: true)
            connect(
                therapist: therapist,
                history: history,
                contextBrief: contextBrief,
                isVideoCall: isVideoCall,
                onCommitTurn: onCommitTurn
            )
        }
    }

    func disconnect(resetAfterFailure: Bool = false) async {
        let failed: Bool
        if case .failed = state {
            failed = true
        } else {
            failed = false
        }
        microphoneTask?.cancel()
        responseTask?.cancel()
        microphoneTask = nil
        responseTask = nil
        await audioController?.stop()
        await liveSession?.close()
        flushCurrentTranscriptTurn()
        if !failed || resetAfterFailure {
            toneFeedback.stop()
        }
        liveSession = nil
        liveModel = nil
        audioController = nil
        if failed && !resetAfterFailure {
            return
        }
        state = .idle
        errorMessage = nil
        if resetAfterFailure {
            inputTranscript = ""
            outputTranscript = "Calling..."
        }
    }

    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            outputTranscript = "Microphone muted."
        } else if state == .connected {
            outputTranscript = "You can speak naturally now."
        }
    }

    func interruptPlayback() {
        Task {
            await audioController?.interrupt()
        }
    }

    func flushCurrentTranscriptTurn() {
        let userText = currentInputTurn.trimmingCharacters(in: .whitespacesAndNewlines)
        let assistantText = currentOutputTurn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty || !assistantText.isEmpty else { return }
        onCommitTurn?(userText, assistantText)
        currentInputTurn = ""
        currentOutputTurn = ""
    }

    func sendVideoFrame(_ jpegData: Data) {
        guard state == .connected, let liveSession else { return }
        Task {
            await liveSession.sendVideoRealtime(jpegData, mimeType: "image/jpeg")
        }
    }

    private func startMicrophoneStreaming(audio: LiveAudioController, session: LiveSession) async throws {
        let stream = try await audio.listenToMic()
        microphoneTask = Task { [weak self] in
            do {
                for await audioBuffer in stream {
                    let muted = await MainActor.run { self?.isMuted ?? true }
                    if muted { continue }
                    await session.sendAudioRealtime(try audioBuffer.luminaInt16Data())
                }
            } catch {
                let message = Self.userFacingLiveError(error)
                await MainActor.run {
                    self?.markFailed(message)
                }
                await self?.disconnect()
            }
        }
    }

    private func startResponseProcessing(session: LiveSession, audio: LiveAudioController) {
        responseTask = Task { [weak self] in
            do {
                for try await message in session.responses {
                    await self?.process(message, audio: audio)
                }
            } catch {
                let message = Self.userFacingLiveError(error)
                await MainActor.run {
                    self?.markFailed(message)
                }
                await self?.disconnect()
            }
        }
    }

    private func process(_ message: LiveServerMessage, audio: LiveAudioController) async {
        switch message.payload {
        case .content(let content):
            await process(content, audio: audio)
        case .goingAwayNotice:
            await MainActor.run {
                outputTranscript = "This Live session will end soon."
            }
        default:
            return
        }
    }

    private func process(_ content: LiveServerContent, audio: LiveAudioController) async {
        if content.wasInterrupted {
            await audio.interrupt()
            await MainActor.run {
                currentOutputTurn = ""
                outputTranscript = "Listening..."
            }
        }

        if let inputText = content.inputAudioTranscription?.text {
            await MainActor.run {
                currentInputTurn += inputText
                inputTranscript = currentInputTurn
            }
        }

        if let outputText = content.outputAudioTranscription?.text {
            await MainActor.run {
                currentOutputTurn += outputText
                outputTranscript = currentOutputTurn
            }
        }

        if let modelTurn = content.modelTurn {
            for part in modelTurn.parts {
                if let inline = part as? InlineDataPart,
                   inline.mimeType.starts(with: "audio/pcm") {
                    try? await audio.playAudio(inline.data)
                }
            }
        }

        if content.isTurnComplete {
            await MainActor.run {
                flushCurrentTranscriptTurn()
            }
        }
    }

    private func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                Task {
                    continuation.resume(returning: await AVAudioApplication.requestRecordPermission())
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private static func liveSystemInstruction(therapist: Therapist, history: [ChatMessage], contextBrief: String?, isVideoCall: Bool) -> String {
        let recent = history.suffix(8).map { "\($0.role.rawValue): \($0.text)" }.joined(separator: "\n")
        return """
        You are \(therapist.name), \(therapist.role), in Lumia's Therapy \(isVideoCall ? "video" : "voice") session.
        Speak naturally, warmly, and briefly. This is emotional support, not medical diagnosis.
        Listen to the speaker carefully. Respond unmistakably in the user's language.
        Ask one question at a time. Avoid sounding scripted. If there is self-harm or immediate danger, encourage contacting local emergency support.
        \(isVideoCall ? "The user may explicitly share low-frequency camera frames with you. Use visible context only when it is clearly relevant. Do not infer identity, health, emotion, attractiveness, age, or sensitive traits from appearance. Do not mention the camera unless the user asks or visual context directly helps." : "No visual context is available.")
        Recent journal context, if user allowed it:
        \(contextBrief ?? "No journal context available.")
        Recent therapy chat:
        \(recent.isEmpty ? "No previous turns." : recent)
        """
    }

    private static func liveOpeningContext(history: [ChatMessage], contextBrief: String?, isVideoCall: Bool) -> String {
        let recent = history.suffix(4).map { "\($0.role.rawValue): \($0.text)" }.joined(separator: "\n")
        return """
        Start the live conversation. Use this only as quiet context; do not recite it.
        Session mode: \(isVideoCall ? "video with optional user-controlled visual context" : "voice only")
        Journal context: \(contextBrief ?? "none")
        Recent chat: \(recent.isEmpty ? "none" : recent)
        """
    }

    private static func voiceName(for therapist: Therapist) -> String {
        switch therapist.id {
        case "serena", "eden": return "Leda"
        case "atlas", "orion": return "Orus"
        case "nimbus": return "Aoede"
        default: return "Zephyr"
        }
    }

    private static func userFacingLiveError(_ error: Error) -> String {
        let raw = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        #if DEBUG
        print("Lumia Gemini Live session closed.")
        #endif
        if GeminiService.isNetworkUnavailable(error) {
            return GeminiService.networkUnavailableMessage
        }
        if raw.localizedCaseInsensitiveContains("Firebase AI Logic API") ||
            raw.localizedCaseInsensitiveContains("has not been used") ||
            raw.localizedCaseInsensitiveContains("disabled") {
            return "Live voice is not available right now. Text chat still works."
        }
        if raw.localizedCaseInsensitiveContains("model") &&
            (raw.localizedCaseInsensitiveContains("not found") || raw.localizedCaseInsensitiveContains("unsupported")) {
            return "Live voice is not available right now. Text chat still works."
        }
        if raw.localizedCaseInsensitiveContains("quota") || raw.localizedCaseInsensitiveContains("rate") {
            return "Live voice is temporarily limited. Try again later, or continue in text chat."
        }
        if raw.localizedCaseInsensitiveContains("unauthorized") || raw.localizedCaseInsensitiveContains("auth") {
            return "Live voice needs a fresh sign-in. Text chat still works."
        }
        if raw.localizedCaseInsensitiveContains("1008") || raw.localizedCaseInsensitiveContains("policy") {
            return "The live audio session closed unexpectedly. Please try again, or continue in text chat."
        }
        if raw.localizedCaseInsensitiveContains("permission") {
            return "Microphone access is needed for Live voice."
        }
        if raw.localizedCaseInsensitiveContains("network") {
            return "Live voice lost its connection. Check the network and try again."
        }
        return "Live voice is unavailable right now. Text chat still works."
    }

    private func markFailed(_ message: String, output: String? = nil) {
        state = .failed(message)
        errorMessage = message
        outputTranscript = output ?? message
        toneFeedback.playFailedTone()
        flushCurrentTranscriptTurn()
    }
}

// MARK: - Therapist Selection

struct SelectionView: View {
    let sessions: [String: ChatSession]
    let onOpen: (Therapist) -> Void
    let onOpenSession: (ChatSession) -> Void
    let onArchiveSession: (ChatSession) -> Void
    let onDeleteSession: (ChatSession) -> Void

    @State private var selectedTherapist: Therapist?

    private var historyGroups: [TherapistSessionGroup] {
        allTherapists.compactMap { therapist in
            let groupedSessions = sessions.values
                .filter {
                    !$0.messages.isEmpty &&
                    $0.archivedAt == nil &&
                    ($0.therapistID == therapist.id || $0.id == therapist.id)
                }
                .sorted { $0.lastUpdated > $1.lastUpdated }

            guard !groupedSessions.isEmpty else { return nil }
            return TherapistSessionGroup(therapist: therapist, sessions: groupedSessions)
        }
    }

    var body: some View {
        ZStack {
            Color.organicBackground.ignoresSafeArea()

            if let selectedTherapist {
                TherapistDetailSelectionView(
                    therapist: selectedTherapist,
                    sessionCount: sessionCount(for: selectedTherapist),
                    latestSession: latestSession(for: selectedTherapist),
                    onBack: {
                        withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.88)) {
                            self.selectedTherapist = nil
                        }
                    },
                    onStart: {
                        onOpen(selectedTherapist)
                    },
                    onContinue: { session in
                        onOpenSession(session)
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            TherapySelectionHeader()
                            TherapySafetyBoundaryCard()
                            TherapistGuideSection(
                                sessions: sessions,
                                onSelect: { therapist in
                                    withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86)) {
                                        selectedTherapist = therapist
                                    }
                                }
                            )
                            TherapyHistoryGroupsSection(
                                groups: historyGroups,
                                onOpenSession: onOpenSession,
                                onArchiveSession: onArchiveSession,
                                onDeleteSession: onDeleteSession,
                                onCollapseGroup: { groupID in
                                    DispatchQueue.main.async {
                                        withAnimation(.easeOut(duration: 0.18)) {
                                            proxy.scrollTo(TherapyHistoryScrollAnchor.group(groupID), anchor: .top)
                                        }
                                    }
                                }
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 36)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
        }
    }

    private func hasSession(for therapist: Therapist) -> Bool {
        sessions.values.contains { $0.therapistID == therapist.id || $0.id == therapist.id }
    }

    private func sessionCount(for therapist: Therapist) -> Int {
        sessions.values.filter {
            !$0.messages.isEmpty &&
            $0.archivedAt == nil &&
            ($0.therapistID == therapist.id || $0.id == therapist.id)
        }.count
    }

    private func latestSession(for therapist: Therapist) -> ChatSession? {
        sessions.values
            .filter {
                !$0.messages.isEmpty &&
                $0.archivedAt == nil &&
                ($0.therapistID == therapist.id || $0.id == therapist.id)
            }
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .first
    }
}

private struct TherapistSessionGroup: Identifiable {
    let therapist: Therapist
    let sessions: [ChatSession]
    var id: String { therapist.id }
}

private enum TherapyHistoryScrollAnchor {
    static func group(_ id: String) -> String {
        "therapy-history-group-\(id)"
    }
}

private struct TherapistGuideSection: View {
    let sessions: [String: ChatSession]
    let onSelect: (Therapist) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderLabel(
                icon: "person.2.fill",
                title: "GUIDES",
                count: "\(allTherapists.count)"
            )

            VStack(spacing: 10) {
                ForEach(allTherapists) { therapist in
                    Button {
                        onSelect(therapist)
                    } label: {
                        TherapistTile(
                            therapist: therapist,
                            hasSession: hasSession(for: therapist)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func hasSession(for therapist: Therapist) -> Bool {
        sessions.values.contains {
            !$0.messages.isEmpty &&
            $0.archivedAt == nil &&
            ($0.therapistID == therapist.id || $0.id == therapist.id)
        }
    }
}

private struct TherapyHistoryGroupsSection: View {
    let groups: [TherapistSessionGroup]
    let onOpenSession: (ChatSession) -> Void
    let onArchiveSession: (ChatSession) -> Void
    let onDeleteSession: (ChatSession) -> Void
    let onCollapseGroup: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderLabel(
                icon: "clock.arrow.circlepath",
                title: "PAST CONVERSATIONS",
                count: "\(groups.reduce(0) { $0 + $1.sessions.count })"
            )

            if groups.isEmpty {
                EmptyHistoryCard()
            } else {
                VStack(spacing: 14) {
                    ForEach(groups) { group in
                        TherapistHistoryGroupCard(
                            group: group,
                            onOpenSession: onOpenSession,
                            onArchiveSession: onArchiveSession,
                            onDeleteSession: onDeleteSession,
                            onCollapse: { onCollapseGroup(group.id) }
                        )
                        .id(TherapyHistoryScrollAnchor.group(group.id))
                    }
                }
            }
        }
    }
}

private struct SectionHeaderLabel: View {
    let icon: String
    let title: String
    let count: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .luminaFont(size: 12, weight: .black)
                .foregroundStyle(Color.organicPrimary)
            Text(title)
                .luminaFont(size: 10, weight: .black)
                .foregroundStyle(Color.organicMutedFg)
                .kerning(1.4)
            Spacer()
            Text(count)
                .luminaFont(size: 10, weight: .black, design: .serif)
                .foregroundStyle(Color.organicMutedFg)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.organicMuted)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 2)
    }
}

private struct EmptyHistoryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .luminaFont(size: 14, weight: .black)
                    .foregroundStyle(Color.organicPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.organicPrimary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("No saved conversations yet")
                        .luminaFont(size: 13, weight: .black)
                        .foregroundStyle(Color.organicForeground)
                    Text("Choose a guide above. Your sessions will be grouped here by doctor.")
                        .luminaFont(size: 12)
                        .foregroundStyle(Color.organicMutedFg)
                }
                Spacer()
            }

            TherapyGuideExampleCard()
        }
        .padding(13)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.organicBorder, lineWidth: 0.8)
        }
    }
}

private struct TherapyGuideExampleCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Text("Example")
                    .luminaFont(size: 9, weight: .black)
                    .kerning(1.0)
                    .textCase(.uppercase)
                Spacer(minLength: 0)
                Text("How a session can start")
                    .luminaFont(size: 10, weight: .bold)
            }
            .foregroundStyle(Color.organicMutedFg)

            VStack(alignment: .leading, spacing: 7) {
                ExampleChatBubble(
                    speaker: "You",
                    text: "I keep replaying a conversation from work.",
                    isGuide: false
                )
                ExampleChatBubble(
                    speaker: "Dr. Willow",
                    text: "Let’s separate what happened from what your mind added. What is one fact you feel sure about?",
                    isGuide: true
                )
            }
        }
        .padding(12)
        .background(Color.organicMuted.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ExampleChatBubble: View {
    let speaker: String
    let text: String
    let isGuide: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(speaker)
                .luminaFont(size: 10, weight: .black)
                .foregroundStyle(isGuide ? Color.organicPrimary : Color.organicMutedFg)
                .frame(width: 58, alignment: .leading)
            Text(text)
                .luminaFont(size: 11, weight: .semibold)
                .foregroundStyle(Color.organicForeground)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TherapistHistoryGroupCard: View {
    let group: TherapistSessionGroup
    let onOpenSession: (ChatSession) -> Void
    let onArchiveSession: (ChatSession) -> Void
    let onDeleteSession: (ChatSession) -> Void
    let onCollapse: () -> Void

    @State private var visibleLimit = 3
    @State private var isPreparingCollapse = false

    private let collapsedLimit = 3
    private let expansionStep = 5
    private var accent: Color { Color(hex: group.therapist.accentHex) }
    private var clampedVisibleLimit: Int { min(max(collapsedLimit, visibleLimit), group.sessions.count) }
    private var remainingCount: Int { max(0, group.sessions.count - clampedVisibleLimit) }
    private var isShowingOlder: Bool { clampedVisibleLimit > collapsedLimit }
    private var visibleSessions: [ChatSession] {
        Array(group.sessions.prefix(clampedVisibleLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                MiniAvatar(
                    url: group.therapist.avatarUrl,
                    accent: accent,
                    size: 36,
                    radius: 12,
                    label: group.therapist.name
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.therapist.name)
                        .luminaFont(size: 14, weight: .black, design: .serif)
                        .foregroundStyle(Color.organicForeground)
                    Text(group.therapist.role)
                        .luminaFont(size: 10, weight: .bold)
                        .foregroundStyle(accent)
                }

                Spacer()

                Text("\(group.sessions.count)")
                    .luminaFont(size: 11, weight: .black, design: .serif)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(accent.opacity(0.12))
                    .clipShape(Capsule())
            }

            LazyVStack(spacing: 8) {
                ForEach(visibleSessions) { session in
                    SwipeableSessionRow(
                        onArchive: { onArchiveSession(session) },
                        onDelete: { onDeleteSession(session) }
                    ) {
                        onOpenSession(session)
                    } content: {
                        RecentTile(session: session, therapist: group.therapist)
                    }
                }

                if remainingCount > 0 {
                    Button {
                        showMore()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.down")
                                .luminaFont(size: 10, weight: .black)
                            Text(showMoreTitle)
                                .luminaFont(size: 11, weight: .black)
                            Spacer(minLength: 0)
                            Text("\(clampedVisibleLimit)/\(group.sessions.count)")
                                .luminaFont(size: 10, weight: .bold)
                                .foregroundStyle(Color.organicMutedFg.opacity(0.82))
                        }
                        .foregroundStyle(accent)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isPreparingCollapse)
                    .accessibilityLabel("Show \(remainingCount) older conversations")
                }

                if isShowingOlder {
                    Button {
                        collapseToRecent()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.up")
                                .luminaFont(size: 10, weight: .black)
                            Text(isPreparingCollapse ? "Returning..." : "Show fewer")
                                .luminaFont(size: 11, weight: .black)
                            Spacer(minLength: 0)
                            Text("Recent \(collapsedLimit)")
                                .luminaFont(size: 10, weight: .bold)
                                .foregroundStyle(Color.organicMutedFg.opacity(0.82))
                        }
                        .foregroundStyle(Color.organicMutedFg)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.organicMuted.opacity(0.56))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isPreparingCollapse)
                    .accessibilityLabel("Collapse older conversations")
                }
            }
        }
        .padding(12)
        .background(Color.organicCard.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accent.opacity(0.16), lineWidth: 1)
        }
        .onChange(of: group.sessions.count) { newCount in
            visibleLimit = min(max(collapsedLimit, visibleLimit), max(collapsedLimit, newCount))
        }
    }

    private var showMoreTitle: String {
        let nextCount = min(expansionStep, remainingCount)
        if clampedVisibleLimit <= collapsedLimit {
            return "Show \(nextCount) older"
        }
        return "Show \(nextCount) more"
    }

    private func showMore() {
        guard !isPreparingCollapse else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visibleLimit = min(group.sessions.count, clampedVisibleLimit + expansionStep)
        }
    }

    private func collapseToRecent() {
        guard !isPreparingCollapse else { return }
        isPreparingCollapse = true
        onCollapse()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                visibleLimit = collapsedLimit
                isPreparingCollapse = false
            }
            DispatchQueue.main.async {
                onCollapse()
            }
        }
    }
}

private struct SwipeableSessionRow<Content: View>: View {
    let onArchive: () -> Void
    let onDelete: () -> Void
    let onOpen: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offsetX: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var suppressTap = false
    private let revealWidth: CGFloat = 154
    private let activationDistance: CGFloat = 44
    private let actionHeight: CGFloat = 58
    private var revealProgress: CGFloat {
        min(1, max(0, -offsetX / revealWidth))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 8) {
                SwipeRowActionButton(
                    title: "Archive",
                    systemName: "archivebox.fill",
                    color: Color.organicPrimary,
                    progress: revealProgress,
                    delay: 0.08,
                    height: actionHeight,
                    action: {
                        close()
                        onArchive()
                    }
                )
                SwipeRowActionButton(
                    title: "Delete",
                    systemName: "trash.fill",
                    color: Color(hex: 0xC94A3C),
                    progress: revealProgress,
                    delay: 0,
                    height: actionHeight,
                    action: {
                        close()
                        onDelete()
                    }
                )
            }
            .padding(.trailing, 2)
            .frame(height: actionHeight)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .offset(x: revealWidth * (1 - easedRevealProgress) * 0.58)
            .zIndex(2)
            .opacity(Double(min(1, revealProgress * 1.35)))
            .allowsHitTesting(offsetX < -activationDistance)
            .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.88), value: revealProgress)

            content()
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isDragging, !suppressTap else { return }
                    if offsetX == 0 {
                        onOpen()
                    } else {
                        close()
                    }
                }
                .offset(x: offsetX)
                .zIndex(1)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18, coordinateSpace: .local)
                        .onChanged { value in
                            let horizontal = value.translation.width
                            let vertical = value.translation.height
                            guard abs(horizontal) > abs(vertical), abs(horizontal) > 10 else { return }

                            if !isDragging {
                                isDragging = true
                                dragStartOffset = offsetX
                                UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.35)
                            }

                            let proposed = dragStartOffset + horizontal
                            if proposed < -revealWidth {
                                let overflow = proposed + revealWidth
                                offsetX = -revealWidth + overflow * 0.18
                            } else {
                                offsetX = min(0, proposed)
                            }
                        }
                        .onEnded { value in
                            guard isDragging else { return }
                            let horizontal = value.translation.width
                            let vertical = value.translation.height
                            isDragging = false
                            suppressTapBriefly()

                            guard abs(horizontal) > abs(vertical) else {
                                settle()
                                return
                            }

                            let predicted = dragStartOffset + value.predictedEndTranslation.width
                            let shouldOpen = predicted < -activationDistance || offsetX < -revealWidth * 0.42
                            withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.82, blendDuration: 0.08)) {
                                offsetX = shouldOpen ? -revealWidth : 0
                            }
                            if shouldOpen {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45)
                            }
                            dragStartOffset = 0
                        }
                )
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .clipped()
        .accessibilityAction(named: "Archive", onArchive)
        .accessibilityAction(named: "Delete", onDelete)
    }

    private func settle() {
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86, blendDuration: 0.05)) {
            offsetX = offsetX < -activationDistance ? -revealWidth : 0
        }
        dragStartOffset = 0
    }

    private func suppressTapBriefly() {
        suppressTap = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            suppressTap = false
        }
    }

    private func close() {
        withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88, blendDuration: 0.05)) {
            offsetX = 0
        }
    }

    private var easedRevealProgress: CGFloat {
        1 - pow(1 - revealProgress, 2.2)
    }
}

private struct SwipeRowActionButton: View {
    let title: String
    let systemName: String
    let color: Color
    let progress: CGFloat
    let delay: CGFloat
    let height: CGFloat
    let action: () -> Void

    private var localProgress: CGFloat {
        min(1, max(0, (progress - delay) / max(0.001, 1 - delay)))
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemName)
                    .luminaFont(size: 13, weight: .black)
                Text(title)
                    .luminaFont(size: 9, weight: .black)
                    .lineLimit(1)
            }
            .foregroundStyle(Color.white)
            .frame(width: 70, height: height)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .offset(x: 18 * (1 - localProgress))
        .scaleEffect(0.88 + localProgress * 0.12)
        .opacity(Double(min(1, localProgress * 1.25)))
    }
}

private struct TherapySelectionHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GUIDES")
                .luminaFont(size: 10, weight: .heavy)
                .foregroundStyle(Color.organicMutedFg)

            Text("Therapy")
                .luminaFont(size: 36, weight: .black)
                .foregroundStyle(Color.organicForeground)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text("Choose a guide for the kind of support you need today.")
                .luminaFont(size: 15, weight: .medium)
                .foregroundStyle(Color.organicMutedFg)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.bottom, 8)
    }
}

private struct TherapySafetyBoundaryCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .luminaFont(size: 15, weight: .black)
                .foregroundStyle(Color.organicPrimary)
                .frame(width: 30, height: 30)
                .background(Color.organicPrimary.opacity(0.11))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Support boundary")
                    .luminaFont(size: 13, weight: .black)
                    .foregroundStyle(Color.organicForeground)
                Text("Lumia offers emotional support and self-help reflection, not diagnosis or emergency care. If you may be in danger, contact local emergency services or a crisis line now.")
                    .luminaFont(size: 12, weight: .semibold)
                    .foregroundStyle(Color.organicMutedFg)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.organicBorder, lineWidth: 0.8)
        }
    }
}

private struct TherapistDetailSelectionView: View {
    let therapist: Therapist
    let sessionCount: Int
    let latestSession: ChatSession?
    let onBack: () -> Void
    let onStart: () -> Void
    let onContinue: (ChatSession) -> Void

    private var accent: Color { Color(hex: therapist.accentHex) }
    private var detailPoints: [TherapistDetailPoint] {
        switch therapist.id {
        case "willow":
            return [
                TherapistDetailPoint(icon: "checklist", title: "Good for", text: "Breaking one tangled problem into a few workable steps."),
                TherapistDetailPoint(icon: "brain.head.profile", title: "Method", text: "CBT-style reflection, pattern naming, and practical reframing."),
                TherapistDetailPoint(icon: "leaf.fill", title: "Tone", text: "Grounded, calm, structured, and gently direct.")
            ]
        case "serena":
            return [
                TherapistDetailPoint(icon: "heart.fill", title: "Good for", text: "Feeling overwhelmed, lonely, unseen, or emotionally full."),
                TherapistDetailPoint(icon: "ear.fill", title: "Method", text: "Validation, reflective listening, and emotional safety first."),
                TherapistDetailPoint(icon: "sparkles", title: "Tone", text: "Warm, soft, patient, and comforting.")
            ]
        case "atlas":
            return [
                TherapistDetailPoint(icon: "mountain.2.fill", title: "Good for", text: "Finding steadiness when events feel bigger than you."),
                TherapistDetailPoint(icon: "scope", title: "Method", text: "Perspective taking, values, and what remains within your control."),
                TherapistDetailPoint(icon: "circle.hexagongrid.fill", title: "Tone", text: "Steady, spare, resilient, and clear.")
            ]
        case "nimbus":
            return [
                TherapistDetailPoint(icon: "wind", title: "Good for", text: "Anxiety, restlessness, racing thoughts, or body tension."),
                TherapistDetailPoint(icon: "lungs.fill", title: "Method", text: "Breathing, grounding, and present-moment attention."),
                TherapistDetailPoint(icon: "drop.fill", title: "Tone", text: "Slow, spacious, sensory, and peaceful.")
            ]
        case "nova":
            return [
                TherapistDetailPoint(icon: "flame.fill", title: "Good for", text: "Burnout, procrastination, low drive, or restarting momentum."),
                TherapistDetailPoint(icon: "target", title: "Method", text: "Small goals, energy checks, and next-action planning."),
                TherapistDetailPoint(icon: "bolt.fill", title: "Tone", text: "Bright, encouraging, focused, and forward-moving.")
            ]
        case "eden":
            return [
                TherapistDetailPoint(icon: "person.2.fill", title: "Good for", text: "Relationship stress, boundaries, conflict, and repair."),
                TherapistDetailPoint(icon: "bubble.left.and.bubble.right.fill", title: "Method", text: "Communication scripts, needs, limits, and attachment-aware reflection."),
                TherapistDetailPoint(icon: "hands.sparkles.fill", title: "Tone", text: "Gentle, honest, relational, and respectful.")
            ]
        case "orion":
            return [
                TherapistDetailPoint(icon: "function", title: "Good for", text: "Sorting facts from assumptions when your mind feels noisy."),
                TherapistDetailPoint(icon: "questionmark.bubble.fill", title: "Method", text: "Socratic questions, evidence checks, and decision clarity."),
                TherapistDetailPoint(icon: "lightbulb.fill", title: "Tone", text: "Precise, analytical, calm, and concise.")
            ]
        case "luna":
            return [
                TherapistDetailPoint(icon: "moon.stars.fill", title: "Good for", text: "Dreams, creative blocks, symbols, and deeper self-reflection."),
                TherapistDetailPoint(icon: "paintpalette.fill", title: "Method", text: "Symbolic exploration, imagination, and gentle meaning-making."),
                TherapistDetailPoint(icon: "sparkle.magnifyingglass", title: "Tone", text: "Intuitive, poetic, reflective, and spacious.")
            ]
        default:
            return [
                TherapistDetailPoint(icon: "sparkles", title: "Good for", text: therapist.description),
                TherapistDetailPoint(icon: "bubble.left.and.bubble.right.fill", title: "Method", text: "Supportive conversation matched to your current need."),
                TherapistDetailPoint(icon: "leaf.fill", title: "Tone", text: "Calm, clear, and emotionally careful.")
            ]
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Button(action: onBack) {
                    HStack(spacing: 7) {
                        Image(systemName: "chevron.left")
                            .luminaFont(size: 13, weight: .black)
                        Text("Guides")
                            .luminaFont(size: 13, weight: .black)
                    }
                    .foregroundStyle(Color.organicPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.organicMuted)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 14) {
                        MiniAvatar(
                            url: therapist.avatarUrl,
                            accent: accent,
                            size: 68,
                            radius: 20,
                            label: therapist.name
                        )

                        VStack(alignment: .leading, spacing: 5) {
                            Text(therapist.name)
                                .luminaFont(size: 26, weight: .black, design: .serif)
                                .foregroundStyle(Color.organicForeground)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Text(therapist.role.uppercased())
                                .luminaFont(size: 10, weight: .black)
                                .kerning(1.3)
                                .foregroundStyle(accent)
                            Text(sessionCount == 0 ? "No previous sessions" : "\(sessionCount) saved session\(sessionCount == 1 ? "" : "s")")
                                .luminaFont(size: 11, weight: .bold)
                                .foregroundStyle(Color.organicMutedFg)
                        }
                    }

                    Text(therapist.description)
                        .luminaFont(size: 15, weight: .semibold)
                        .foregroundStyle(Color.organicForeground)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [accent.opacity(0.18), Color.organicCard],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(accent.opacity(0.20), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeaderLabel(icon: "info.circle.fill", title: "HOW THIS GUIDE HELPS", count: "3")

                    VStack(spacing: 10) {
                        ForEach(detailPoints) { point in
                            TherapistDetailPointRow(point: point, accent: accent)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeaderLabel(
                        icon: "arrow.triangle.branch",
                        title: "BEGIN",
                        count: latestSession == nil ? "1" : "2"
                    )

                    Button(action: onStart) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.bubble.fill")
                                .luminaFont(size: 17, weight: .black)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.16))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start new session")
                                    .luminaFont(size: 15, weight: .black)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Text("Begin fresh with \(therapist.name)")
                                    .luminaFont(size: 11, weight: .bold)
                                    .foregroundStyle(Color.organicPrimaryFg.opacity(0.78))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "arrow.right")
                                .luminaFont(size: 13, weight: .black)
                        }
                        .foregroundStyle(Color.organicPrimaryFg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(accent)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start a new session with \(therapist.name)")

                    if let latestSession {
                        TherapistContinuePreviousCard(
                            session: latestSession,
                            therapist: therapist,
                            accent: accent,
                            onContinue: { onContinue(latestSession) }
                        )
                    }
                }

                TherapySafetyBoundaryCard()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 36)
        }
        .modifier(NativeEdgeBackSwipeModifier(onBack: onBack))
    }
}

private struct TherapistContinuePreviousCard: View {
    let session: ChatSession
    let therapist: Therapist
    let accent: Color
    let onContinue: () -> Void

    private var timeAgo: String {
        let delta = max(0, Date().timeIntervalSince1970 - session.lastUpdated)
        if delta < 3_600 { return "\(max(1, Int(delta / 60)))m ago" }
        if delta < 86_400 { return "\(Int(delta / 3_600))h ago" }
        return "\(Int(delta / 86_400))d ago"
    }

    var body: some View {
        Button(action: onContinue) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "arrow.uturn.left.circle.fill")
                    .luminaFont(size: 18, weight: .black)
                    .foregroundStyle(accent)
                    .frame(width: 40, height: 40)
                    .background(accent.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text("Continue previous")
                            .luminaFont(size: 13, weight: .black)
                            .foregroundStyle(Color.organicForeground)
                        Text(timeAgo)
                            .luminaFont(size: 10, weight: .bold)
                            .foregroundStyle(Color.organicMutedFg)
                    }
                    Text(session.lastMessagePreview.isEmpty ? "Saved conversation with \(therapist.name)." : session.lastMessagePreview)
                        .luminaFont(size: 12, weight: .medium)
                        .foregroundStyle(Color.organicMutedFg)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .luminaFont(size: 12, weight: .black)
                    .foregroundStyle(accent.opacity(0.68))
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.organicCard)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(accent.opacity(0.20), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue previous conversation with \(therapist.name)")
    }
}

private struct TherapistDetailPoint: Identifiable {
    let icon: String
    let title: String
    let text: String
    var id: String { title }
}

private struct TherapistDetailPointRow: View {
    let point: TherapistDetailPoint
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: point.icon)
                .luminaFont(size: 14, weight: .black)
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background(accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(point.title)
                    .luminaFont(size: 12, weight: .black)
                    .foregroundStyle(Color.organicForeground)
                Text(point.text)
                    .luminaFont(size: 12, weight: .medium)
                    .foregroundStyle(Color.organicMutedFg)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.organicBorder, lineWidth: 0.8)
        }
    }
}

// MARK: - Therapist Tile

struct TherapistTile: View {
    let therapist: Therapist
    let hasSession: Bool
    private var accent: Color { Color(hex: therapist.accentHex) }

    var body: some View {
        HStack(spacing: 14) {
            MiniAvatar(url: therapist.avatarUrl, accent: accent, size: 60, radius: 16, label: therapist.name)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(therapist.name)
                        .luminaFont(size: 15, weight: .bold, design: .serif)
                        .foregroundStyle(Color.organicForeground)
                    if hasSession {
                        Text("Saved")
                            .luminaFont(size: 9, weight: .black)
                            .foregroundStyle(accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(accent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                Text(therapist.role)
                    .luminaFont(size: 11, weight: .bold).foregroundStyle(accent)
                Text(therapist.description)
                    .luminaFont(size: 12, weight: .medium).foregroundStyle(Color.organicMutedFg).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .luminaFont(size: 12, weight: .semibold).foregroundStyle(accent.opacity(0.5))
        }
        .padding(14)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(accent.opacity(0.2), lineWidth: 1) }
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        .contentShape(Rectangle())
    }
}

// MARK: - Recent Tile

struct RecentTile: View {
    let session: ChatSession
    let therapist: Therapist
    private var accent: Color { Color(hex: therapist.accentHex) }
    private var timeAgo: String {
        let d = Date().timeIntervalSince1970 - session.lastUpdated
        if d < 3600  { return "\(Int(d / 60))m ago" }
        if d < 86400 { return "\(Int(d / 3600))h ago" }
        return "\(Int(d / 86400))d ago"
    }
    var body: some View {
        HStack(spacing: 10) {
            MiniAvatar(url: therapist.avatarUrl, accent: accent, size: 38, radius: 19, label: therapist.name)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(therapist.name)
                        .luminaFont(size: 13, weight: .bold).foregroundStyle(Color.organicForeground)
                    Spacer()
                    Text(timeAgo).luminaFont(size: 10).foregroundStyle(Color.organicMutedFg)
                }
                Text(session.lastMessagePreview)
                    .luminaFont(size: 12).foregroundStyle(Color.organicMutedFg).lineLimit(1)
            }
        }
        .padding(12)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.organicBorder, lineWidth: 0.5) }
        .contentShape(Rectangle())
    }
}

// MARK: - Mini Avatar

struct MiniAvatar: View {
    let url: String
    let accent: Color
    let size: CGFloat
    let radius: CGFloat
    let label: String

    init(url: String, accent: Color, size: CGFloat, radius: CGFloat, label: String = "AI") {
        self.url = url
        self.accent = accent
        self.size = size
        self.radius = radius
        self.label = label
    }

    var body: some View {
        TherapistAvatarMark(name: label, accent: accent, size: size, radius: radius)
    }
}

struct TherapistAvatarMark: View {
    let name: String
    let accent: Color
    let size: CGFloat
    let radius: CGFloat

    private var initials: String {
        let cleaned = name.replacingOccurrences(of: "Dr. ", with: "")
        let letters = cleaned
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0) }
            .joined()
        return letters.isEmpty ? "AI" : letters.uppercased()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(accent.opacity(0.16))
            Circle()
                .fill(Color.white.opacity(0.42))
                .frame(width: size * 0.58, height: size * 0.58)
                .offset(x: size * 0.20, y: -size * 0.18)
            Text(initials)
                .luminaFont(size: max(11, size * 0.34), weight: .black, design: .serif)
                .foregroundStyle(accent)
                .minimumScaleFactor(0.7)
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.24), lineWidth: 1)
        }
    }
}

struct ChatScreenView: View {
    let therapist: Therapist
    let messages: [ChatMessage]
    let sessionID: String?
    let userAvatarID: ProfileAvatarID
    let isLoading: Bool
    let showStats: Bool
    let conversationState: ConversationState
    let isNetworkAvailable: Bool
    let usesJournalContext: Bool
    let usesGuideMemory: Bool
    let onBack: () -> Void
    let onToggleStats: () -> Void
    let onReset: () -> Void
    let onStartVoiceCall: () -> Void
    let onStartVideoCall: () -> Void
    @ObservedObject var speechInput: SpeechInputController
    let speechInputRequestID: Int
    let onSelectConversationState: (ConversationState) -> Void
    let onSend: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView(
                therapist: therapist,
                showStats: showStats,
                conversationState: conversationState,
                onBack: onBack,
                onToggleStats: onToggleStats,
                onReset: onReset
            )
            Divider()
            ConversationModePicker(
                selectedState: conversationState,
                accent: Color(hex: therapist.accentHex),
                onSelect: onSelectConversationState
            )
            if usesJournalContext || usesGuideMemory {
                TherapyContextNotice(
                    accent: Color(hex: therapist.accentHex),
                    usesJournalContext: usesJournalContext,
                    usesGuideMemory: usesGuideMemory
                )
            }
            Divider()
            MessageListView(
                messages: messages,
                sessionID: sessionID,
                isLoading: isLoading,
                therapist: therapist,
                userAvatarID: userAvatarID
            )
            .equatable()
            Divider()
            ChatInputView(
                sessionID: sessionID,
                isLoading: isLoading,
                isNetworkAvailable: isNetworkAvailable,
                therapist: therapist,
                onStartVoiceCall: onStartVoiceCall,
                onStartVideoCall: onStartVideoCall,
                speechInput: speechInput,
                speechInputRequestID: speechInputRequestID,
                onSend: onSend
            )
        }
        .background(Color.organicBackground)
        .background {
            KeyboardPrewarmView(triggerID: sessionID ?? therapist.id)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
        }
        .modifier(NativeEdgeBackSwipeModifier(onBack: onBack))
    }
}

// MARK: - Chat Header

struct ChatHeaderView: View {
    let therapist: Therapist
    let showStats: Bool
    let conversationState: ConversationState
    let onBack: () -> Void
    let onToggleStats: () -> Void
    let onReset: () -> Void
    private var accent: Color { Color(hex: therapist.accentHex) }

    var body: some View {
        HStack(spacing: 10) {
            HeaderIconButton(
                systemName: "chevron.left",
                foreground: Color.organicPrimary,
                background: Color.organicMuted,
                action: onBack
            )
            ChatHeaderIdentity(therapist: therapist, accent: accent, conversationState: conversationState)
            Spacer()
            HeaderIconButton(
                systemName: "chart.bar.xaxis",
                foreground: showStats ? accent : Color.organicMutedFg,
                background: showStats ? accent.opacity(0.12) : Color.organicMuted,
                action: onToggleStats
            )
            HeaderIconButton(
                systemName: "arrow.counterclockwise",
                foreground: Color.organicMutedFg,
                background: Color.organicMuted,
                action: onReset
            )
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.organicCard)
    }
}

struct ChatHeaderIdentity: View {
    let therapist: Therapist
    let accent: Color
    let conversationState: ConversationState

    var body: some View {
        HStack(spacing: 10) {
            MiniAvatar(url: therapist.avatarUrl, accent: accent, size: 40, radius: 12, label: therapist.name)
            VStack(alignment: .leading, spacing: 1) {
                Text(therapist.name)
                    .luminaFont(size: 15, weight: .bold, design: .serif)
                    .foregroundStyle(Color.organicForeground)
                HStack(spacing: 4) {
                    Circle().frame(width: 5, height: 5).foregroundStyle(Color.green)
                    Text(conversationState.headerStatus)
                        .luminaFont(size: 10, weight: .semibold).foregroundStyle(Color.green)
                }
            }
        }
    }
}

struct ConversationModePicker: View {
    let selectedState: ConversationState
    let accent: Color
    let onSelect: (ConversationState) -> Void

    var body: some View {
        HStack(spacing: 7) {
            ForEach(ConversationState.selectableModes, id: \.rawValue) { state in
                Button {
                    onSelect(state)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: state.modeIcon)
                            .luminaFont(size: 12, weight: .black)
                        Text(state.modeTitle)
                            .luminaFont(size: 11, weight: .black)
                            .lineLimit(1)
                    }
                    .foregroundStyle(selectedState == state ? Color.organicPrimaryFg : Color.organicMutedFg)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(selectedState == state ? accent : Color.organicMuted.opacity(0.72))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(selectedState == state ? Color.white.opacity(0.24) : Color.organicBorder.opacity(0.7), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(state.modeTitle)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.organicCard.opacity(0.72))
    }
}

private struct TherapyContextNotice: View {
    let accent: Color
    let usesJournalContext: Bool
    let usesGuideMemory: Bool

    private var title: String {
        switch (usesJournalContext, usesGuideMemory) {
        case (true, true):
            return "We can use recent notes and past sessions"
        case (false, true):
            return "We can pick up where we left off"
        case (true, false):
            return "Recent reflections can guide this"
        default:
            return ""
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(accent)
                .frame(width: 6, height: 6)
            Text(title)
                .luminaFont(size: 10, weight: .bold)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.organicMutedFg)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.organicCard.opacity(0.70))
        .accessibilityLabel(title)
    }
}

private extension ConversationState {
    static var selectableModes: [ConversationState] { [.listen, .coach, .plan] }

    var modeTitle: String {
        switch self {
        case .listen: return "Listen"
        case .coach: return "Coach"
        case .plan: return "Plan"
        case .triage: return "Triage"
        case .crisis: return "Crisis"
        case .fallback: return "Clarify"
        case .checkIn: return "Check-in"
        case .wrapUp: return "Wrap-up"
        }
    }

    var headerStatus: String {
        switch self {
        case .listen: return "Listening"
        case .coach: return "Coaching"
        case .plan: return "Planning"
        case .triage: return "Checking in"
        case .crisis: return "Safety first"
        case .fallback: return "Clarifying"
        case .checkIn: return "Checking in"
        case .wrapUp: return "Wrapping up"
        }
    }

    var modeIcon: String {
        switch self {
        case .listen: return "ear"
        case .coach: return "sparkles"
        case .plan: return "checklist"
        case .triage: return "questionmark.circle.fill"
        case .crisis: return "shield.lefthalf.filled"
        case .fallback: return "ellipsis.bubble.fill"
        case .checkIn: return "heart.text.square.fill"
        case .wrapUp: return "checkmark.seal.fill"
        }
    }

    var turnIntent: UserIntent {
        switch self {
        case .listen: return .listening
        case .coach: return .coaching
        case .plan: return .planning
        case .crisis: return .crisis
        case .checkIn, .triage, .fallback, .wrapUp: return .unsure
        }
    }
}

struct HeaderIconButton: View {
    let systemName: String
    let foreground: Color
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .luminaFont(size: 14, weight: .semibold)
                .foregroundStyle(foreground)
                .frame(width: 40, height: 40)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct NativeEdgeBackSwipeModifier: ViewModifier {
    let onBack: () -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var isTracking = false

    private let edgeActivationWidth: CGFloat = 32
    private let commitDistance: CGFloat = 86

    func body(content: Content) -> some View {
        content
            .offset(x: dragOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 16, coordinateSpace: .local)
                    .onChanged { value in
                        guard isTracking || value.startLocation.x <= edgeActivationWidth else { return }

                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        guard horizontal > 0, abs(horizontal) > abs(vertical) * 1.18 else { return }

                        if !isTracking {
                            isTracking = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.25)
                        }

                        dragOffset = min(132, horizontal * 0.52)
                    }
                    .onEnded { value in
                        guard isTracking else { return }
                        isTracking = false

                        let shouldReturn = value.translation.width > commitDistance || value.predictedEndTranslation.width > 150
                        if shouldReturn {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45)
                            withAnimation(.easeOut(duration: 0.16)) {
                                dragOffset = 220
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                                dragOffset = 0
                                onBack()
                            }
                        } else {
                            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
    }
}

// MARK: - Message List View

struct MessageListView: View {
    let messages: [ChatMessage]
    let sessionID: String?
    let isLoading: Bool
    let therapist: Therapist
    let userAvatarID: ProfileAvatarID

    private var scrollIdentity: String {
        [
            sessionID ?? "draft",
            messages.first?.id ?? "empty",
            messages.last?.id ?? "empty",
            String(messages.count)
        ].joined(separator: "|")
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                MessageListContentView(
                    messages: messages,
                    isLoading: isLoading,
                    therapist: therapist,
                    userAvatarID: userAvatarID
                )
            }
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: scrollIdentity) { _ in
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: isLoading) { loading in
                guard loading else { return }
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        let action = {
            proxy.scrollTo(MessageListBottomAnchor.bottom.rawValue, anchor: .bottom)
        }

        let delays: [Double] = animated ? [0.02] : [0, 0.12]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard animated else {
                    action()
                    return
                }
                withAnimation(.easeOut(duration: 0.18)) {
                    action()
                }
            }
        }
    }
}

extension MessageListView: Equatable {
    static func == (lhs: MessageListView, rhs: MessageListView) -> Bool {
        lhs.sessionID == rhs.sessionID
            && lhs.isLoading == rhs.isLoading
            && lhs.therapist.id == rhs.therapist.id
            && lhs.userAvatarID == rhs.userAvatarID
            && lhs.messages.count == rhs.messages.count
            && lhs.messages.first?.id == rhs.messages.first?.id
            && lhs.messages.last?.id == rhs.messages.last?.id
    }
}

private enum MessageListBottomAnchor: String {
    case bottom
}

struct MessageListContentView: View {
    let messages: [ChatMessage]
    let isLoading: Bool
    let therapist: Therapist
    let userAvatarID: ProfileAvatarID
    private var accent: Color { Color(hex: therapist.accentHex) }

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(messages) { msg in
                ChatBubble(
                    message:   msg,
                    accent:    accent,
                    avatarUrl: therapist.avatarUrl,
                    avatarLabel: therapist.name,
                    userAvatarID: userAvatarID
                )
                .id(msg.id)
            }
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().tint(accent)
                    Text("Thinking…").font(.caption).foregroundStyle(Color.organicMutedFg)
                    Spacer()
                }
                .padding(.horizontal, 18)
            }
            Color.clear
                .frame(height: 1)
                .id(MessageListBottomAnchor.bottom.rawValue)
        }
        .padding(14)
    }
}

// MARK: - Chat Input View

struct ChatInputView: View {
    let sessionID: String?
    let isLoading: Bool
    let isNetworkAvailable: Bool
    let therapist: Therapist
    let onStartVoiceCall: () -> Void
    let onStartVideoCall: () -> Void
    @ObservedObject var speechInput: SpeechInputController
    let speechInputRequestID: Int
    let onSend: (String) -> Void
    @State private var draft = ""
    @State private var speechInputPrefix = ""

    private var accent: Color { Color(hex: therapist.accentHex) }
    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
    private var canToggleSpeechInput: Bool {
        speechInput.isAvailable && (!isLoading || speechInput.isListening)
    }
    private var editorHeight: CGFloat {
        44
    }
    private var speechStatusText: String? {
        if let errorMessage = speechInput.errorMessage {
            return errorMessage
        }
        if speechInput.isListening {
            return "Listening • Auto: \(speechInput.activeLanguageLabel)"
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.45)

            if !isNetworkAvailable {
                HStack(spacing: 7) {
                    Image(systemName: "wifi.slash")
                        .luminaFont(size: 11, weight: .black)
                    Text("Offline. AI replies and calls will resume when you're connected.")
                        .luminaFont(size: 11, weight: .bold)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Color.organicMutedFg)
                .padding(.horizontal, 14)
                .padding(.top, 8)
            }

            HStack(alignment: .bottom, spacing: 8) {
                HStack(spacing: 4) {
                    CallIconButton(
                        systemName: "phone.fill",
                        accessibilityLabel: "Start voice call",
                        accent: accent,
                        action: onStartVoiceCall
                    )
                    CallIconButton(
                        systemName: "video.fill",
                        accessibilityLabel: "Start video call",
                        accent: accent,
                        action: onStartVideoCall
                    )
                    SpeechInputIconButton(
                        isListening: speechInput.isListening,
                        isEnabled: canToggleSpeechInput,
                        accent: accent,
                        action: toggleSpeechInput
                    )
                }
                .padding(4)
                .background(Color.organicMuted.opacity(0.72))
                .clipShape(Capsule())

                ChatComposerTextField(
                    text: $draft,
                    placeholder: "Share what's on your mind...",
                    accentColor: UIColor(accent),
                    textColor: UIColor(Color.organicForeground),
                    placeholderColor: UIColor(Color.organicMutedFg).withAlphaComponent(0.52),
                    onSubmit: submitDraft
                )
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: editorHeight)
                .background(Color.organicCard)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(canSend ? accent.opacity(0.34) : Color.organicBorder.opacity(0.75), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 4)

                Button {
                    submitDraft()
                } label: {
                    Image(systemName: "arrow.up")
                        .luminaFont(size: 16, weight: .black)
                        .foregroundStyle(canSend ? Color.white : Color.organicMutedFg.opacity(0.42))
                        .frame(width: 44, height: 44)
                        .background(canSend ? accent : Color.organicMuted.opacity(0.75))
                        .clipShape(Circle())
                        .shadow(color: canSend ? accent.opacity(0.22) : .clear, radius: 8, x: 0, y: 4)
                }
                .disabled(!canSend)
                .accessibilityLabel("Send message")
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.top, 10)

            if let speechStatusText {
                HStack(spacing: 6) {
                    Circle()
                        .fill(speechInput.errorMessage == nil ? accent : Color.red)
                        .frame(width: 6, height: 6)
                    Text(speechStatusText)
                        .luminaFont(size: 11, weight: .semibold)
                        .foregroundStyle(speechInput.errorMessage == nil ? Color.organicMutedFg : Color.red.opacity(0.86))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 7)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !speechInput.isAvailable {
                Text("Voice input is not available on this device.")
                    .luminaFont(size: 11, weight: .semibold)
                    .foregroundStyle(Color.organicMutedFg)
                    .padding(.horizontal, 18)
                    .padding(.top, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer().frame(height: 12)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.organicBackground.opacity(0.86),
                    Color.organicBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onChange(of: speechInput.transcript) { transcript in
            applySpeechTranscript(transcript)
        }
        .onChange(of: speechInputRequestID) { _ in
            beginSpeechInputFromDraft()
        }
        .onChange(of: sessionID ?? therapist.id) { _ in
            draft = ""
            speechInputPrefix = ""
        }
    }

    private func submitDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        if speechInput.isListening {
            speechInput.stop()
        }
        draft = ""
        speechInputPrefix = ""
        onSend(text)
    }

    private func toggleSpeechInput() {
        if speechInput.isListening {
            speechInput.stop()
        } else {
            beginSpeechInputFromDraft()
        }
    }

    private func beginSpeechInputFromDraft() {
        guard !speechInput.isListening else { return }
        speechInputPrefix = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        speechInput.start(preferredText: speechInputPrefix)
    }

    private func applySpeechTranscript(_ transcript: String) {
        guard !transcript.isEmpty else { return }
        let prefix = speechInputPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = prefix.isEmpty ? transcript : "\(prefix) \(transcript)"
    }
}

private struct ChatComposerTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let accentColor: UIColor
    let textColor: UIColor
    let placeholderColor: UIColor
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = ChatComposerUIKitTextField()
        textField.delegate = context.coordinator
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        textField.textColor = textColor
        textField.tintColor = accentColor
        textField.returnKeyType = .send
        textField.textContentType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no
        textField.autocapitalizationType = .sentences
        textField.clearButtonMode = .never
        textField.clipsToBounds = true
        textField.adjustsFontSizeToFitWidth = false
        textField.minimumFontSize = 15
        textField.keyboardType = .default
        textField.enablesReturnKeyAutomatically = false
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []
        if #available(iOS 17.0, *) {
            textField.inlinePredictionType = .no
        }

        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderColor]
        )
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)

        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self

        if textField.text != text, textField.markedTextRange == nil {
            textField.text = text
        }

        if textField.textColor != textColor {
            textField.textColor = textColor
        }
        if textField.tintColor != accentColor {
            textField.tintColor = accentColor
        }
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderColor]
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ChatComposerTextField
        private var pendingText: String?
        private var isTextSyncScheduled = false

        init(_ parent: ChatComposerTextField) {
            self.parent = parent
        }

        @objc func textDidChange(_ textField: UITextField) {
            guard textField.markedTextRange == nil else { return }
            scheduleTextSync(textField.text ?? "")
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            pendingText = nil
            isTextSyncScheduled = false
            parent.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            pendingText = nil
            isTextSyncScheduled = false
            parent.text = textField.text ?? ""
            parent.onSubmit()
            return false
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            string != "\n"
        }

        private func scheduleTextSync(_ text: String) {
            pendingText = text
            guard !isTextSyncScheduled else { return }
            isTextSyncScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isTextSyncScheduled = false
                guard let text = self.pendingText else { return }
                self.pendingText = nil
                self.parent.text = text
            }
        }
    }
}

private final class ChatComposerUIKitTextField: UITextField {
    private let horizontalPadding: CGFloat = 16

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: super.intrinsicContentSize.height)
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: horizontalPadding, dy: 0)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: horizontalPadding, dy: 0)
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: horizontalPadding, dy: 0)
    }
}

private struct KeyboardPrewarmView: UIViewRepresentable {
    let triggerID: String

    func makeUIView(context: Context) -> KeyboardPrewarmHostView {
        KeyboardPrewarmHostView()
    }

    func updateUIView(_ uiView: KeyboardPrewarmHostView, context: Context) {
        uiView.schedulePrewarm(triggerID: triggerID)
    }
}

private final class KeyboardPrewarmHostView: UIView {
    private static var warmedTriggerIDs = Set<String>()
    private let textField = UITextField(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
    private var scheduledTriggerID: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        alpha = 0.01
        isUserInteractionEnabled = false
        configureTextField()
        addSubview(textField)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textField.frame = CGRect(x: -1000, y: -1000, width: 1, height: 1)
    }

    func schedulePrewarm(triggerID: String) {
        guard scheduledTriggerID != triggerID else { return }
        scheduledTriggerID = triggerID
        guard !Self.warmedTriggerIDs.contains(triggerID) else { return }
        Self.warmedTriggerIDs.insert(triggerID)

        // iOS can do expensive keyboard service setup on the first responder change.
        // Warm it after the chat transition so the user's first tap does less work.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, self.window != nil else { return }
            _ = UITextInputMode.activeInputModes.compactMap(\.primaryLanguage)
            self.textField.becomeFirstResponder()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
                self?.textField.resignFirstResponder()
            }
        }
    }

    private func configureTextField() {
        textField.alpha = 0.01
        textField.isUserInteractionEnabled = false
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.textContentType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartDashesType = .no
        textField.smartQuotesType = .no
        textField.smartInsertDeleteType = .no
        textField.keyboardType = .default
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []
        textField.inputView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        if #available(iOS 17.0, *) {
            textField.inlinePredictionType = .no
        }
    }
}

struct CallIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .luminaFont(size: 13, weight: .bold)
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background(Color.organicCard.opacity(0.86))
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(accent.opacity(0.10), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct SpeechInputIconButton: View {
    let isListening: Bool
    let isEnabled: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isListening ? "mic.slash.fill" : "mic.fill")
                .luminaFont(size: 13, weight: .bold)
                .foregroundStyle(isListening ? Color.white : accent)
                .frame(width: 34, height: 34)
                .background(isListening ? Color.red.opacity(0.88) : Color.organicCard.opacity(0.86))
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(isListening ? Color.red.opacity(0.20) : accent.opacity(0.10), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
        .accessibilityLabel(isListening ? "Stop voice input" : "Start voice input")
    }
}

// MARK: - Therapy Call View

struct TherapyCallView: View {
    let therapist: Therapist
    let callKind: TherapyCallKind
    let initialMessages: [ChatMessage]
    let conversationState: ConversationState
    let riskLevel: RiskLevel
    let contextBrief: String?
    let onCommitTurn: (_ userText: String, _ assistantText: String) -> Void
    let onFallbackToVoiceInput: () -> Void
    let onFallbackToText: () -> Void
    let onRecordUsage: (_ seconds: Int) -> Void
    let onEnd: () -> Void

    @StateObject private var callSession = TherapyCallSessionController()
    @StateObject private var liveController = TherapyLiveCallController()
    @State private var elapsedSeconds = 0
    @State private var isTranscriptExpanded = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var accent: Color { Color(hex: therapist.accentHex) }
    private var elapsedText: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    private var isVideoCall: Bool { callKind == .video }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 760
            ZStack {
                CallBackgroundView(accent: accent)
                VStack(spacing: compact ? 12 : 16) {
                    CallTopBar(
                        callKind: callKind,
                        therapist: therapist,
                        elapsedText: elapsedText,
                        accent: accent,
                        onEnd: onEnd
                    )

                    if isVideoCall {
                        VideoCallStage(
                            therapist: therapist,
                            accent: accent,
                            stageHeight: videoStageHeight(for: geometry.size.height),
                            isCameraOn: callSession.isCameraOn,
                            isCameraReady: callSession.isCameraReady,
                            isSharingCameraWithAI: callSession.isSharingCameraWithAI,
                            permissionMessage: callSession.permissionMessage,
                            captureSession: callSession.captureSession,
                            onToggleCameraSharing: { callSession.toggleCameraSharingWithAI() }
                        )
                    } else {
                        VoiceCallStage(
                            therapist: therapist,
                            accent: accent,
                            isCompact: compact,
                            statusText: liveStageStatus,
                            isMuted: callSession.isMuted,
                            permissionMessage: callSession.permissionMessage
                        )
                        Spacer(minLength: compact ? 4 : 12)
                    }

                    CallConversationPanel(
                        accent: accent,
                        therapistName: therapist.name,
                        liveState: liveController.state,
                        isMuted: liveController.isMuted,
                        inputTranscript: liveController.inputTranscript,
                        outputTranscript: liveController.outputTranscript,
                        isTranscriptExpanded: isTranscriptExpanded,
                        errorMessage: liveController.errorMessage,
                        onToggleMute: { liveController.toggleMute() },
                        onRetry: retryLive,
                        onUseVoiceInput: onFallbackToVoiceInput,
                        onUseTextChat: onFallbackToText,
                        onToggleTranscript: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                isTranscriptExpanded.toggle()
                            }
                        },
                        onInterrupt: { liveController.interruptPlayback() }
                    )

                    CallControlDock(
                        isVideoCall: isVideoCall,
                        isMuted: liveController.isMuted,
                        isSpeakerOn: callSession.isSpeakerOn,
                        isCameraOn: callSession.isCameraOn,
                        accent: accent,
                        onToggleMute: { liveController.toggleMute() },
                        onToggleSpeaker: { callSession.toggleSpeaker() },
                        onToggleCamera: { callSession.toggleCamera() },
                        onEnd: onEnd
                    )
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
        }
        .onReceive(timer) { _ in elapsedSeconds += 1 }
        .onAppear {
            callSession.start(kind: callKind)
            liveController.connect(
                therapist: therapist,
                history: initialMessages,
                contextBrief: contextBrief,
                isVideoCall: isVideoCall,
                onCommitTurn: onCommitTurn
            )
            callSession.setVideoFrameHandler { frameData in
                Task { @MainActor in
                    liveController.sendVideoFrame(frameData)
                }
            }
        }
        .onDisappear {
            onRecordUsage(elapsedSeconds)
            callSession.setVideoFrameHandler(nil)
            Task {
                await liveController.disconnect()
            }
            callSession.stop()
        }
    }

    private func videoStageHeight(for availableHeight: CGFloat) -> CGFloat {
        min(max(availableHeight * 0.43, 300), 408)
    }

    private func retryLive() {
        liveController.retry(
            therapist: therapist,
            history: initialMessages,
            contextBrief: contextBrief,
            isVideoCall: isVideoCall,
            onCommitTurn: onCommitTurn
        )
    }

    private var liveStageStatus: String {
        if liveController.isMuted { return "You are muted" }
        switch liveController.state {
        case .idle:
            return "Ready to call"
        case .connecting:
            return "Calling \(therapist.name)..."
        case .connected:
            return "Connected and listening"
        case .failed:
            if liveController.errorMessage?.localizedCaseInsensitiveContains("internet") == true ||
                liveController.errorMessage?.localizedCaseInsensitiveContains("offline") == true {
                return "Offline"
            }
            return "Live voice is unavailable"
        }
    }
}

struct CallBackgroundView: View {
    let accent: Color

    var body: some View {
        ZStack {
            Color.organicBackground.ignoresSafeArea()
            LinearGradient(
                colors: [
                    accent.opacity(0.22),
                    Color.organicAccent.opacity(0.36),
                    Color.organicBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            VStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 220, height: 220)
                    .offset(x: 120, y: -70)
                Spacer()
                Circle()
                    .fill(Color.organicSecondary.opacity(0.10))
                    .frame(width: 280, height: 280)
                    .offset(x: -150, y: 100)
            }
            .ignoresSafeArea()
        }
    }
}

struct VoiceCallStage: View {
    let therapist: Therapist
    let accent: Color
    let isCompact: Bool
    let statusText: String
    let isMuted: Bool
    let permissionMessage: String?

    var body: some View {
        VStack(spacing: isCompact ? 18 : 22) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.10), lineWidth: isCompact ? 26 : 32)
                    .frame(width: isCompact ? 190 : 224, height: isCompact ? 190 : 224)
                Circle()
                    .stroke(accent.opacity(0.16), lineWidth: 2)
                    .frame(width: isCompact ? 230 : 268, height: isCompact ? 230 : 268)
                MiniAvatar(url: therapist.avatarUrl, accent: accent, size: isCompact ? 126 : 148, radius: isCompact ? 40 : 48, label: therapist.name)
                    .shadow(color: accent.opacity(0.24), radius: 28, x: 0, y: 14)
            }

            VStack(spacing: 8) {
                Text(therapist.name)
                    .luminaFont(size: isCompact ? 30 : 34, weight: .bold, design: .serif)
                    .foregroundStyle(Color.organicForeground)
                Text(therapist.role)
                    .luminaFont(size: 13, weight: .bold)
                    .foregroundStyle(accent)
                Text(permissionMessage ?? (isMuted ? "You are muted" : statusText))
                    .luminaFont(size: 13, weight: .semibold)
                    .foregroundStyle(Color.organicMutedFg)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
        }
    }
}

struct VideoCallStage: View {
    let therapist: Therapist
    let accent: Color
    let stageHeight: CGFloat
    let isCameraOn: Bool
    let isCameraReady: Bool
    let isSharingCameraWithAI: Bool
    let permissionMessage: String?
    let captureSession: AVCaptureSession
    let onToggleCameraSharing: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(accent.opacity(0.16))
                LinearGradient(
                    colors: [accent.opacity(0.35), Color.organicCard.opacity(0.94)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                VStack(spacing: 12) {
                    MiniAvatar(url: therapist.avatarUrl, accent: accent, size: 104, radius: 32, label: therapist.name)
                    VStack(spacing: 5) {
                        Text(therapist.name)
                            .luminaFont(size: 26, weight: .bold, design: .serif)
                            .foregroundStyle(Color.organicForeground)
                        Text(videoStatusText)
                            .luminaFont(size: 12, weight: .bold)
                            .foregroundStyle(Color.organicMutedFg)
                        if let permissionMessage {
                            Text(permissionMessage)
                                .luminaFont(size: 12, weight: .semibold)
                                .foregroundStyle(Color.organicMutedFg)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                LocalVideoPreview(
                    accent: accent,
                    isCameraOn: isCameraOn,
                    isCameraReady: isCameraReady,
                    captureSession: captureSession
                )
                    .padding(14)

                Button(action: onToggleCameraSharing) {
                    HStack(spacing: 7) {
                        Image(systemName: isSharingCameraWithAI ? "eye.fill" : "eye.slash.fill")
                            .luminaFont(size: 11, weight: .black)
                        Text(isSharingCameraWithAI ? "Video context on" : "Share camera")
                            .luminaFont(size: 11, weight: .black)
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSharingCameraWithAI ? Color.white : Color.organicForeground)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(isSharingCameraWithAI ? accent.opacity(0.90) : Color.organicCard.opacity(0.90))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().strokeBorder(Color.white.opacity(0.32), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isCameraOn || !isCameraReady)
                .opacity(isCameraOn && isCameraReady ? 1 : 0.48)
                .padding(.trailing, 14)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .frame(maxWidth: .infinity)
            .frame(height: stageHeight)
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.58), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 22, x: 0, y: 14)
        }
    }

    private var videoStatusText: String {
        if !isCameraOn { return "Camera paused" }
        if isSharingCameraWithAI { return "Visual context shared" }
        return "Camera preview only"
    }
}

struct LocalVideoPreview: View {
    let accent: Color
    let isCameraOn: Bool
    let isCameraReady: Bool
    let captureSession: AVCaptureSession

    var body: some View {
        ZStack {
            if isCameraOn && isCameraReady {
                CameraPreviewView(session: captureSession)
                    .overlay(alignment: .bottomLeading) {
                        Text("You")
                            .luminaFont(size: 10, weight: .black)
                            .foregroundStyle(Color.white.opacity(0.92))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.34))
                            .clipShape(Capsule())
                            .padding(8)
                    }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "video.slash.fill")
                        .luminaFont(size: 18, weight: .bold)
                        .foregroundStyle(Color.organicMutedFg)
                    Text("Camera off")
                        .luminaFont(size: 9, weight: .black)
                        .foregroundStyle(Color.organicMutedFg)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.organicMuted)
            }
        }
        .frame(width: 96, height: 124)
        .background(isCameraOn ? accent : Color.organicMuted)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.50), lineWidth: 1)
        }
    }
}

struct CallConversationPanel: View {
    let accent: Color
    let therapistName: String
    let liveState: TherapyLiveState
    let isMuted: Bool
    let inputTranscript: String
    let outputTranscript: String
    let isTranscriptExpanded: Bool
    let errorMessage: String?
    let onToggleMute: () -> Void
    let onRetry: () -> Void
    let onUseVoiceInput: () -> Void
    let onUseTextChat: () -> Void
    let onToggleTranscript: () -> Void
    let onInterrupt: () -> Void

    private var isFailed: Bool {
        if case .failed = liveState { return true }
        return false
    }

    private var isNetworkFailure: Bool {
        guard let errorMessage else { return false }
        return errorMessage.localizedCaseInsensitiveContains("internet") ||
            errorMessage.localizedCaseInsensitiveContains("network") ||
            errorMessage.localizedCaseInsensitiveContains("connection") ||
            errorMessage.localizedCaseInsensitiveContains("offline")
    }

    private var statusText: String {
        if isMuted { return "Muted" }
        if case .failed = liveState {
            return isNetworkFailure ? "Offline" : "Voice off"
        }
        return liveState.label
    }

    private var instructionText: String {
        if isNetworkFailure {
            return "Connect to the internet to use calls or AI replies."
        }
        if errorMessage != nil {
            return "The call could not stay connected. End the call to continue in text chat."
        }
        return inputTranscript.isEmpty ? "Speak naturally. The mic is live unless muted." : inputTranscript
    }

    private var responseText: String {
        errorMessage ?? outputTranscript
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isMuted ? Color.red.opacity(0.88) : accent.opacity(0.86))
                    .frame(width: 8, height: 8)
                Text(statusText.uppercased())
                    .luminaFont(size: 9, weight: .black)
                    .foregroundStyle(Color.organicMutedFg)
                    .kerning(1.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                Button(action: onToggleTranscript) {
                    HStack(spacing: 7) {
                        Image(systemName: isTranscriptExpanded ? "text.bubble.fill" : "text.bubble")
                            .luminaFont(size: 11, weight: .black)
                        Text("Transcript")
                            .luminaFont(size: 10, weight: .black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                    }
                    .foregroundStyle(Color.organicForeground)
                    .frame(width: 112, height: 38)
                    .background(isTranscriptExpanded ? accent.opacity(0.22) : Color.organicMuted.opacity(0.72))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isTranscriptExpanded ? "Hide transcript" : "Show transcript")

                if isFailed {
                    Button(action: onRetry) {
                        HStack(spacing: 7) {
                            Image(systemName: "arrow.clockwise")
                                .luminaFont(size: 11, weight: .black)
                            Text("Retry")
                                .luminaFont(size: 12, weight: .black)
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.organicForeground)
                        .frame(width: 88, height: 38)
                        .background(accent.opacity(0.18))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onToggleMute) {
                        HStack(spacing: 8) {
                            Image(systemName: isMuted ? "mic.slash.fill" : "mic.fill")
                                .luminaFont(size: 12, weight: .black)
                            Text(isMuted ? "Muted" : "Live")
                                .luminaFont(size: 13, weight: .black)
                                .lineLimit(1)
                        }
                        .foregroundStyle(isMuted ? Color.white : Color.organicForeground)
                        .frame(width: 92, height: 38)
                        .background(isMuted ? Color.red.opacity(0.86) : accent.opacity(0.22))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(instructionText)
                    .luminaFont(size: 12, weight: .semibold)
                    .foregroundStyle(inputTranscript.isEmpty || errorMessage != nil ? Color.organicMutedFg : Color.organicForeground)
                    .lineLimit(2)
                Text(responseText)
                    .luminaFont(size: 14, weight: .bold)
                    .foregroundStyle(errorMessage == nil ? Color.organicForeground : Color(hex: 0xB94A5D))
                    .lineLimit(2)
            }

            if isFailed {
                HStack(spacing: 9) {
                    LiveFallbackButton(
                        title: "Dictate",
                        systemName: "waveform",
                        accent: accent,
                        action: onUseVoiceInput
                    )
                    LiveFallbackButton(
                        title: "Text chat",
                        systemName: "keyboard",
                        accent: accent,
                        action: onUseTextChat
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if isTranscriptExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    transcriptRow(title: "You", text: inputTranscript, fallback: "Waiting for your voice...")
                    Divider().background(Color.organicMutedFg.opacity(0.18))
                    transcriptRow(title: therapistName, text: responseText, fallback: "Waiting for response...")
                }
                .padding(12)
                .background(Color.organicMuted.opacity(0.44))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(Color.organicCard.opacity(0.90))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(accent.opacity(liveState == .connected ? 0.34 : 0.12), lineWidth: 1)
        }
    }

    private func transcriptRow(title: String, text: String, fallback: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .luminaFont(size: 8, weight: .black)
                .foregroundStyle(Color.organicMutedFg)
                .kerning(1)
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : text)
                .luminaFont(size: 11, weight: .semibold)
                .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.organicMutedFg : Color.organicForeground)
                .lineLimit(4)
        }
    }
}

private struct LiveFallbackButton: View {
    let title: String
    let systemName: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemName)
                    .luminaFont(size: 11, weight: .black)
                Text(title)
                    .luminaFont(size: 11, weight: .black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(Color.organicForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(Color.organicMuted.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(accent.opacity(0.16), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewContainerView {
        CameraPreviewContainerView(session: session)
    }

    func updateUIView(_ uiView: CameraPreviewContainerView, context: Context) {
        uiView.session = session
    }
}

final class CameraPreviewContainerView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    var session: AVCaptureSession {
        get { previewLayer.session! }
        set {
            previewLayer.session = newValue
            previewLayer.videoGravity = .resizeAspectFill
        }
    }

    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
    }

    required init?(coder: NSCoder) {
        nil
    }
}

struct CallTopBar: View {
    let callKind: TherapyCallKind
    let therapist: Therapist
    let elapsedText: String
    let accent: Color
    let onEnd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: callKind.systemImage)
                .luminaFont(size: 13, weight: .bold)
                .foregroundStyle(accent)
                .frame(width: 38, height: 38)
                .background(Color.organicCard.opacity(0.74))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(therapist.name)
                    .luminaFont(size: 17, weight: .bold, design: .serif)
                    .foregroundStyle(Color.organicForeground)
                Text("\(callKind.title) · \(elapsedText)")
                    .luminaFont(size: 11, weight: .bold)
                    .foregroundStyle(Color.organicMutedFg)
            }

            Spacer()

            Button(action: onEnd) {
                Image(systemName: "xmark")
                    .luminaFont(size: 12, weight: .black)
                    .foregroundStyle(Color.organicMutedFg)
                    .frame(width: 44, height: 44)
                    .background(Color.organicCard.opacity(0.84))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close call")
        }
    }
}

struct CallControlDock: View {
    let isVideoCall: Bool
    let isMuted: Bool
    let isSpeakerOn: Bool
    let isCameraOn: Bool
    let accent: Color
    let onToggleMute: () -> Void
    let onToggleSpeaker: () -> Void
    let onToggleCamera: () -> Void
    let onEnd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            HStack(spacing: 12) {
                CallControlButton(
                    systemName: isMuted ? "mic.slash.fill" : "mic.fill",
                    label: isMuted ? "Muted" : "Mute",
                    isActive: isMuted,
                    accent: accent,
                    action: onToggleMute
                )
                CallControlButton(
                    systemName: isSpeakerOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    label: "Speaker",
                    isActive: isSpeakerOn,
                    accent: accent,
                    action: onToggleSpeaker
                )
                if isVideoCall {
                    CallControlButton(
                        systemName: isCameraOn ? "video.fill" : "video.slash.fill",
                        label: isCameraOn ? "Camera" : "Off",
                        isActive: !isCameraOn,
                        accent: accent,
                        action: onToggleCamera
                    )
                }
            }

            Spacer(minLength: 4)

            CallEndButton(action: onEnd)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.organicCard.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.64), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

struct CallControlButton: View {
    let systemName: String
    let label: String
    let isActive: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .luminaFont(size: 16, weight: .bold)
                    .foregroundStyle(isActive ? Color.white : accent)
                    .frame(width: 50, height: 50)
                    .background(isActive ? accent : Color.organicMuted.opacity(0.76))
                    .clipShape(Circle())
                Text(label)
                    .luminaFont(size: 10, weight: .black)
                    .foregroundStyle(Color.organicMutedFg)
                    .lineLimit(1)
            }
            .frame(width: 62)
        }
        .buttonStyle(.plain)
    }
}

struct CallEndButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "phone.down.fill")
                    .luminaFont(size: 17, weight: .bold)
                    .foregroundStyle(Color.white)
                    .frame(width: 54, height: 54)
                    .background(Color(hex: 0xC94A3C))
                    .clipShape(Circle())
                Text("End")
                    .luminaFont(size: 10, weight: .black)
                    .foregroundStyle(Color.organicMutedFg)
            }
            .frame(width: 62)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("End call")
    }
}

// MARK: - Stats Panel

struct StatsSheetContent: View {
    let metrics: EmotionalMetrics
    let therapist: Therapist
    let sessions: [ChatSession]
    let currentSessionID: String?
    let onSelectHistorySession: (ChatSession) -> Void
    let onArchiveHistorySession: (ChatSession) -> Void
    let onDeleteHistorySession: (ChatSession) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .luminaFont(size: 14, weight: .bold)
                    .foregroundStyle(Color.organicPrimary)
                    .frame(width: 34, height: 34)
                    .background(Color.organicPrimary.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text("MENTAL HEALTH PULSE")
                        .luminaFont(size: 10, weight: .black)
                        .foregroundStyle(Color.organicMutedFg)
                        .kerning(1.5)
                    Text("Session snapshot")
                        .luminaFont(size: 18, weight: .bold, design: .serif)
                        .foregroundStyle(Color.organicForeground)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .luminaFont(size: 12, weight: .bold)
                        .foregroundStyle(Color.organicMutedFg)
                        .frame(width: 32, height: 32)
                        .background(Color.organicCard)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    StatsPanel(metrics: metrics)
                    DoctorHistorySection(
                        therapist: therapist,
                        sessions: sessions,
                        currentSessionID: currentSessionID,
                        onSelectSession: { session in
                            onSelectHistorySession(session)
                            dismiss()
                        },
                        onArchiveSession: onArchiveHistorySession,
                        onDeleteSession: onDeleteHistorySession
                    )
                }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 28)
            }
        }
        .background(Color.organicMuted)
    }
}

struct DoctorHistorySection: View {
    let therapist: Therapist
    let sessions: [ChatSession]
    let currentSessionID: String?
    let onSelectSession: (ChatSession) -> Void
    let onArchiveSession: (ChatSession) -> Void
    let onDeleteSession: (ChatSession) -> Void

    private var accent: Color { Color(hex: therapist.accentHex) }
    private var history: [ChatSession] {
        sessions.filter { $0.id != currentSessionID && $0.archivedAt == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundStyle(accent)
                Text("CHAT HISTORY")
                    .luminaFont(size: 10, weight: .black)
                    .foregroundStyle(Color.organicMutedFg)
                    .kerning(1.3)
                Spacer()
                Text("\(history.count)")
                    .luminaFont(size: 11, weight: .bold, design: .serif)
                    .foregroundStyle(accent)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)

            if history.isEmpty {
                Text("No earlier sessions with \(therapist.name) yet.")
                    .luminaFont(size: 13, design: .serif)
                    .foregroundStyle(Color.organicMutedFg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.organicCard)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ForEach(history) { session in
                        SwipeableSessionRow(
                            onArchive: { onArchiveSession(session) },
                            onDelete: { onDeleteSession(session) }
                        ) {
                            onSelectSession(session)
                        } content: {
                            DoctorHistoryRow(session: session, therapist: therapist, accent: accent)
                        }
                    }
                }
            }
        }
    }
}

struct DoctorHistoryRow: View {
    let session: ChatSession
    let therapist: Therapist
    let accent: Color

    private var timeAgo: String {
        let d = Date().timeIntervalSince1970 - session.lastUpdated
        if d < 3600  { return "\(max(1, Int(d / 60)))m ago" }
        if d < 86400 { return "\(Int(d / 3600))h ago" }
        return "\(Int(d / 86400))d ago"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .luminaFont(size: 12, weight: .bold)
                    .foregroundStyle(accent)
            }
            .frame(width: 34, height: 34)
            .background(accent.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(timeAgo.uppercased())
                        .luminaFont(size: 9, weight: .black)
                        .foregroundStyle(accent)
                        .kerning(1)
                    Text("\(session.messageCount) messages")
                        .luminaFont(size: 10, weight: .semibold)
                        .foregroundStyle(Color.organicMutedFg)
                }
                Text(session.lastMessagePreview.isEmpty ? "New conversation" : session.lastMessagePreview)
                    .luminaFont(size: 13, design: .serif)
                    .foregroundStyle(Color.organicForeground)
                    .lineLimit(2)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .luminaFont(size: 11, weight: .bold)
                .foregroundStyle(accent.opacity(0.45))
        }
        .padding(12)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.4), lineWidth: 1)
        }
    }
}

struct StatsPanel: View {
    let metrics: EmotionalMetrics
    private var items: [PulseMetric] {
        [
            PulseMetric(label: "Wellness", pct: metrics.wellness, hex: 0x5D7052),
            PulseMetric(label: "Clarity", pct: metrics.clarity, hex: 0xC18C5D),
            PulseMetric(label: "Calm", pct: metrics.calm, hex: 0x4A90E2),
            PulseMetric(label: "Energy", pct: metrics.energy, hex: 0xD97706)
        ]
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(items) { item in
                PulseMetricCard(metric: item)
            }
        }
    }
}

struct PulseMetric: Identifiable {
    let label: String
    let pct: Int
    let hex: UInt
    var id: String { label }
}

struct PulseMetricCard: View {
    let metric: PulseMetric
    private var color: Color { Color(hex: metric.hex) }
    private var fraction: Double {
        max(0.0, min(1.0, Double(metric.pct) / 100.0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(metric.label.uppercased())
                    .luminaFont(size: 10, weight: .black)
                    .foregroundStyle(Color.organicMutedFg)
                    .kerning(1.2)

                SparklineView(pct: metric.pct, color: color)
                    .frame(width: 58, height: 18)

                Spacer()

                Text("\(metric.pct)%")
                    .luminaFont(size: 20, weight: .bold, design: .serif)
                    .foregroundStyle(color)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.organicMuted)
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(Color.organicCard)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.organicBorder.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

struct SparklineView: View {
    let pct: Int
    let color: Color

    private var samples: [Double] {
        [-9, 4, -3, 8, -5, 6, -2, 5, 0].map { delta in
            max(0, min(100, Double(pct + delta)))
        }
    }

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                for index in samples.indices {
                    let x = proxy.size.width * CGFloat(index) / CGFloat(max(samples.count - 1, 1))
                    let y = proxy.size.height * CGFloat(1 - samples[index] / 100.0)
                    if index == samples.startIndex {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Metric Bar

struct MetricBar: View {
    let label: String
    let pct:   Int
    let hex:   UInt
    var body: some View {
        let c        = Color(hex: hex)
        let fraction = max(0.0, min(1.0, Double(pct) / 100.0))
        return HStack(spacing: 8) {
            Text(label)
                .luminaFont(size: 11, weight: .semibold)
                .foregroundStyle(Color.organicForeground)
                .frame(width: 58, alignment: .leading)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.organicMuted)
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(c)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(x: fraction, anchor: .leading)
                }
            Text("\(pct)%")
                .luminaFont(size: 10, weight: .black)
                .foregroundStyle(c)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message:   ChatMessage
    let accent:    Color
    let avatarUrl: String
    let avatarLabel: String
    let userAvatarID: ProfileAvatarID
    private var isUser: Bool { message.role == .user }
    private var renderedText: Text {
        guard !isUser,
              let attributed = try? AttributedString(
                markdown: message.text,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
              )
        else {
            return Text(message.text)
        }
        return Text(attributed)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }
            if !isUser { MiniAvatar(url: avatarUrl, accent: accent, size: 32, radius: 10, label: avatarLabel) }
            renderedText
                .luminaFont(size: 15, design: .serif)
                .foregroundStyle(isUser ? Color.white : Color.organicForeground)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(isUser ? accent : Color.organicCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
            if isUser {
                ProfileAvatarImage(avatarID: userAvatarID, fallbackText: "", size: 32)
            }
            if !isUser { Spacer(minLength: 60) }
        }
    }
}
