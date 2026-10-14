import AVFoundation
import SoundAnalysis
import OSLog

private final class ClassificationObserver: NSObject, SNResultsObserving {
  let resultHandler: (AudioObservation) -> Void
  let failureHandler: (String) -> Void

  init(result: @escaping (AudioObservation) -> Void, failure: @escaping (String) -> Void) {
    resultHandler = result
    failureHandler = failure
  }

  func request(_ request: SNRequest, didProduce result: SNResult) {
    guard let result = result as? SNClassificationResult else { return }
    let score = result.classifications.first { $0.identifier == "baby_crying" }?.confidence ?? 0
    resultHandler(AudioObservation(confidence: score,
      time: CMTimeGetSeconds(CMTimeRangeGetEnd(result.timeRange))))
  }

  func request(_ request: SNRequest, didFailWithError error: Error) {
    MonitoringDiagnostics.record("Built-in classifier failed: \(MonitoringDiagnostics.describe(error))")
    failureHandler("内置声音识别暂时中断，请打开 App 快速恢复监测。")
  }

  func requestDidComplete(_ request: SNRequest) {}
}

/// Engine lifecycle is controlled on the main thread; analysis runs on one serial queue.
final class AudioMonitor {
  private var engine: AVAudioEngine?
  private var analyzer: SNAudioStreamAnalyzer?
  private var observer: ClassificationObserver?
  private var framePosition: AVAudioFramePosition = 0
  private let queue = DispatchQueue(label: "app.babysignal.audio-analysis", qos: .userInitiated)
  private let slots = DispatchSemaphore(value: 2)

  func start(
    result: @escaping (AudioObservation) -> Void,
    failure: @escaping (String) -> Void
  ) throws {
    stop(deactivateSession: false)
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
      try session.setPreferredIOBufferDuration(0.1)
      try session.setActive(true)
      guard let microphone = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else {
        throw MonitorError.noInput
      }
      try session.setPreferredInput(microphone)
      let engine = AVAudioEngine()
      let input = engine.inputNode
      let format = input.outputFormat(forBus: 0)
      guard format.sampleRate > 0, format.channelCount > 0 else {
        throw MonitorError.noInput
      }
      let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
      guard request.knownClassifications.contains("baby_crying") else { throw MonitorError.noClassifier }
      request.overlapFactor = 0.5
      let analyzer = SNAudioStreamAnalyzer(format: format)
      let observer = ClassificationObserver(result: result, failure: failure)
      try analyzer.add(request, withObserver: observer)
      self.observer = observer
      queue.sync {
        self.analyzer = analyzer
        self.framePosition = 0
      }

      input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
        guard let self, self.slots.wait(timeout: .now()) == .success else { return }
        // The audio engine reuses its buffer after the callback. Copy before queuing.
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
          self.slots.signal()
          return
        }
        copy.frameLength = buffer.frameLength
        let sources = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: buffer.audioBufferList))
        let destinations = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for (source, destination) in zip(sources, destinations) {
          if let sourceData = source.mData, let destinationData = destination.mData {
            memcpy(destinationData, sourceData, Int(source.mDataByteSize))
          }
        }
        self.queue.async {
          defer { self.slots.signal() }
          guard self.analyzer === analyzer else { return }
          analyzer.analyze(copy, atAudioFramePosition: self.framePosition)
          self.framePosition += AVAudioFramePosition(copy.frameLength)
        }
      }
      self.engine = engine
      engine.prepare()
      try engine.start()
    } catch {
      MonitoringDiagnostics.record("Audio start failed: \(MonitoringDiagnostics.describe(error))")
      stop(deactivateSession: false)
      throw error
    }
  }

  func stop(deactivateSession: Bool = true) {
    if let engine {
      engine.stop()
      engine.inputNode.removeTap(onBus: 0)
    }
    engine = nil
    queue.sync {
      analyzer?.removeAllRequests()
      analyzer = nil
    }
    observer = nil
    if deactivateSession {
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
  }

  var isRunning: Bool { engine?.isRunning == true }

  func isCurrentEngine(_ candidate: AVAudioEngine?) -> Bool {
    guard let engine, let candidate else { return false }
    return engine === candidate
  }

  enum MonitorError: LocalizedError {
    case noInput, noClassifier

    var errorDescription: String? {
      switch self {
      case .noInput: return "麦克风暂时不可用，请检查音频设备后重试。"
      case .noClassifier: return "当前系统不提供宝宝哭声分类，请更新系统后重试。"
      }
    }
  }
}


/// Bounded local diagnostics contain lifecycle/error details, never recorded audio.
enum MonitoringDiagnostics {
  private static let lock = NSLock()

  static func describe(_ error: Error) -> String {
    var current = error as NSError
    var parts: [String] = []
    for _ in 0..<3 {
      parts.append("\(current.domain) / \(current.code): \(current.localizedDescription)")
      guard let next = current.userInfo[NSUnderlyingErrorKey] as? NSError else { break }
      current = next
    }
    return parts.joined(separator: " -> ")
  }

  static func record(_ message: String) {
    lock.lock()
    defer { lock.unlock() }
    var entries = UserDefaults.standard.stringArray(forKey: "babySignal.recoveryDiagnostics") ?? []
    entries.append("\(Date().timeIntervalSince1970): \(message)")
    UserDefaults.standard.set(Array(entries.suffix(60)), forKey: "babySignal.recoveryDiagnostics")
  }
}
