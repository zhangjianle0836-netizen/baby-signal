import AVFoundation
import CoreML

/// Serialized local inference. Explicit CPU-only execution avoids background GPU work.
final class YAMNetClassifier {
  private let model: MLModel
  private let features = YAMNetFeatures()
  private var samples: [Float] = []
  private var samplePosition = 0
  private var converter: AVAudioConverter?
  private let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!

  init(modelURL: URL? = nil) throws {
    guard let url = modelURL ?? Bundle.main.url(forResource: "YAMNet", withExtension: "mlmodelc") else {
      throw ClassifierError.missingModel
    }
    let configuration = MLModelConfiguration()
    configuration.computeUnits = .cpuOnly
    model = try MLModel(contentsOf: url, configuration: configuration)
  }

  func analyze(_ buffer: AVAudioPCMBuffer) throws -> [AudioObservation] {
    if converter == nil { converter = AVAudioConverter(from: buffer.format, to: target) }
    guard let converter else { throw ClassifierError.invalidInput }
    let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * 16_000 / buffer.format.sampleRate) + 64)
    guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else {
      throw ClassifierError.invalidInput
    }
    var supplied = false
    var error: NSError?
    let status = converter.convert(to: output, error: &error) { _, inputStatus in
      if supplied { inputStatus.pointee = .noDataNow; return nil }
      supplied = true
      inputStatus.pointee = .haveData
      return buffer
    }
    if status == .error { throw error ?? ClassifierError.invalidInput as NSError }
    guard let channel = output.floatChannelData?[0] else { throw ClassifierError.invalidInput }
    samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    var observations: [AudioObservation] = []
    while samples.count >= YAMNetFeatures.sampleCount {
      let score = try confidence(Array(samples.prefix(YAMNetFeatures.sampleCount)))
      observations.append(AudioObservation(confidence: score,
        time: Double(samplePosition + YAMNetFeatures.sampleCount) / 16_000))
      samples.removeFirst(YAMNetFeatures.hopCount)
      samplePosition += YAMNetFeatures.hopCount
    }
    return observations
  }

  func confidence(_ monoSamples: [Float]) throws -> Double {
    let patch = features.extract(monoSamples)
    let array = try MLMultiArray(shape: [1, 96, 64], dataType: .float16)
    for (index, value) in patch.enumerated() { array[index] = NSNumber(value: value) }
    let input = try MLDictionaryFeatureProvider(dictionary: ["features": MLFeatureValue(multiArray: array)])
    let output = try model.prediction(from: input)
    guard let scores = output.featureValue(for: "Identity")?.multiArrayValue, scores.count == 521 else {
      throw ClassifierError.invalidOutput
    }
    // Index 20 is "Baby cry, infant cry" in the pinned Google AudioSet class map.
    let score = scores[20].doubleValue
    guard score.isFinite, (0...1).contains(score) else { throw ClassifierError.invalidOutput }
    return score
  }

  enum ClassifierError: LocalizedError {
    case missingModel, invalidInput, invalidOutput
    var errorDescription: String? {
      switch self {
      case .missingModel: return "本地识别模型未能加载，请重新安装 App。"
      case .invalidInput, .invalidOutput: return "本地声音识别暂时不可用，请重新开始。"
      }
    }
  }
}
