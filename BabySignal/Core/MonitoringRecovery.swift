import Foundation

/// Tracks user intent separately from temporary loss of the audio engine.
struct MonitoringRecovery {
  private(set) var requested = false
  private(set) var needsRecovery = false
  private(set) var interruptionActive = false
  private(set) var attempts = 0
  private var nextAttemptAt: TimeInterval = 0
  let maximumAttempts = 3

  var exhausted: Bool { needsRecovery && attempts >= maximumAttempts }

  mutating func start() {
    requested = true
    needsRecovery = false
    interruptionActive = false
    attempts = 0
  }

  mutating func stop() {
    requested = false
    needsRecovery = false
    interruptionActive = false
    attempts = 0
  }

  mutating func requireRecovery(at time: TimeInterval) {
    guard requested else { return }
    if !needsRecovery {
      attempts = 0
      nextAttemptAt = time + 0.5
    }
    needsRecovery = true
  }

  mutating func interruptionBegan(at time: TimeInterval) {
    guard requested else { return }
    requireRecovery(at: time)
    interruptionActive = true
  }

  mutating func interruptionEnded(at time: TimeInterval) {
    guard requested else { return }
    requireRecovery(at: time)
    interruptionActive = false
    nextAttemptAt = time + 0.5
  }

  mutating func beginAttempt(at time: TimeInterval, alarmAlerting: Bool) -> Bool {
    guard requested, needsRecovery, !interruptionActive, !alarmAlerting,
          !exhausted, time >= nextAttemptAt else { return false }
    attempts += 1
    nextAttemptAt = time + pow(2, Double(attempts))
    return true
  }

  /// A confirmed alarm dismissal is a new recovery opportunity, not another retry tick.
  mutating func alarmEnded(at time: TimeInterval) {
    guard requested else { return }
    requireRecovery(at: time)
    interruptionActive = false
    attempts = 0
    nextAttemptAt = time + 1.5
  }

  @discardableResult
  mutating func manualRetry(at time: TimeInterval) -> Bool {
    guard requested else { return false }
    requireRecovery(at: time)
    interruptionActive = false
    attempts = 0
    nextAttemptAt = time + 0.5
    return true
  }

  mutating func receivedAnalysis() {
    needsRecovery = false
    interruptionActive = false
    attempts = 0
  }
}
