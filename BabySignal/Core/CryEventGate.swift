import Foundation

enum DetectionSensitivity: String, CaseIterable, Codable, Identifiable {
  case sensitive, balanced, conservative

  var id: String { rawValue }

  var title: String {
    switch self {
    case .sensitive: return L10n.text("较灵敏")
    case .balanced: return L10n.text("标准")
    case .conservative: return L10n.text("较谨慎")
    }
  }

  // Prototype thresholds for the Apple built-in classifier; these are not measured accuracy guarantees.
  var threshold: Double {
    switch self {
    case .sensitive: return 0.45
    case .balanced: return 0.65
    case .conservative: return 0.80
    }
  }
}

/// Combines consecutive model results into events. Scores are not safety probabilities.
struct CryEventGate {
  let threshold: Double
  let requiredHits: Int
  let quietPeriod: TimeInterval
  let repeatInterval: TimeInterval
  let maximumSampleGap: TimeInterval

  private var hits = 0
  private var lastSample: TimeInterval?
  private var quietSince: TimeInterval?
  private var lastEmission: TimeInterval?

  init(
    threshold: Double,
    requiredHits: Int = 2,
    quietPeriod: TimeInterval = 10,
    repeatInterval: TimeInterval = 60,
    maximumSampleGap: TimeInterval = 4
  ) {
    self.threshold = threshold
    self.requiredHits = requiredHits
    self.quietPeriod = quietPeriod
    self.repeatInterval = repeatInterval
    self.maximumSampleGap = maximumSampleGap
  }

  mutating func ingest(confidence: Double, at time: TimeInterval) -> Bool {
    guard time.isFinite, confidence.isFinite, (0...1).contains(confidence) else {
      return false
    }
    if let previous = lastSample {
      guard time > previous else { return false }
      if time - previous > maximumSampleGap {
        hits = 0
        quietSince = nil
        lastEmission = nil
      }
    }
    lastSample = time

    guard confidence >= threshold else {
      hits = 0
      if quietSince == nil { quietSince = time }
      if let quietSince, time - quietSince >= quietPeriod { lastEmission = nil }
      return false
    }

    quietSince = nil
    hits += 1
    guard hits >= requiredHits else { return false }
    if let lastEmission, time - lastEmission < repeatInterval { return false }
    lastEmission = time
    return true
  }
}
