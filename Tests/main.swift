import Foundation
import SoundAnalysis
import AVFoundation

private var checks = 0

func expect(_ condition: @autoclosure () -> Bool, _ description: String) {
  checks += 1
  guard condition() else {
    fputs("FAIL: \(description)\n", stderr)
    exit(1)
  }
}

// A dead/suspended process must not leave an indefinitely reassuring island status.
let activityStart = Date(timeIntervalSince1970: 1000)
var activityState = MonitoringActivityState(
  status: .monitoring, sessionStartedAt: activityStart,
  lastAnalysisAt: activityStart.addingTimeInterval(60), updatedAt: activityStart.addingTimeInterval(65)
)
expect(!activityState.needsCheck(at: activityStart.addingTimeInterval(89)), "Fresh analysis remains current")
expect(activityState.needsCheck(at: activityStart.addingTimeInterval(90)), "Analysis expires after 30 seconds, including boundary")
expect(activityState.needsCheck(at: activityStart.addingTimeInterval(70), systemStale: true), "System stale state overrides local freshness")
expect(activityState.title(stale: true).contains("请打开 App"), "Stale display requires checking rather than claiming monitoring")
activityState.displayExpiresAt = activityStart.addingTimeInterval(75)
expect(activityState.needsCheck(at: activityStart.addingTimeInterval(75)), "Display deadline expires even while analysis remains fresh")
activityState.displayExpiresAt = nil
activityState.status = .cry
expect(activityState.compactTitle(stale: false) == "有哭声", "Compact crying state has visible text")
expect(activityState.compactTitle(stale: true) == "请检查", "Stale crying state stops claiming a fresh observation")
activityState.status = .resumed
expect(activityState.title(stale: false).contains("继续监测"), "Recovery is explained in plain words")
activityState.status = .interrupted
expect(activityState.title(stale: false).contains("监测中断"), "Interruption does not claim active analysis")
activityState.status = .stopped
expect(!activityState.needsCheck(at: activityStart.addingTimeInterval(1000)), "Stopped sessions never advertise active monitoring")
expect(activityState.title(stale: true) == "监测已停止", "Stopped display remains stopped when stale")
let activityRoundTrip = try JSONDecoder().decode(MonitoringActivityState.self, from: JSONEncoder().encode(activityState))
expect(activityRoundTrip == activityState, "App and widget payload preserves status and timestamps")

let englishBundle = Bundle(path: "Shared/Localization/en.lproj")!
let chineseBundle = Bundle(path: "Shared/Localization/zh-Hans.lproj")!
expect(L10n.text("快速恢复监测", bundle: englishBundle) == "Resume monitoring", "English recovery action is localized")
expect(L10n.text("监测中断，请打开 App", bundle: englishBundle).contains("interrupted"), "English activity warning preserves interruption meaning")
expect(L10n.text("快速恢复监测", bundle: chineseBundle) == "快速恢复监测", "Chinese recovery action is preserved")
expect(L10n.format("闹钟安排失败：%@", "example", bundle: englishBundle) == "The alarm could not be scheduled: example", "Formatted English errors preserve their argument")
expect(L10n.storedText("Monitoring interrupted", bundle: chineseBundle) == "监测中断", "Historical English fixed descriptions can be shown in Chinese")
expect(L10n.storedText("闹钟安排失败：example", bundle: englishBundle) == "The alarm could not be scheduled: example", "Historical formatted errors localize without losing diagnostics")
expect(L10n.storedText("unrecognized diagnostic", bundle: englishBundle) == "unrecognized diagnostic", "Unknown historical detail is retained")

var gate = CryEventGate(threshold: 0.65)
expect(!gate.ingest(confidence: 0.9, at: 0), "A single cry window must not alert")
expect(gate.ingest(confidence: 0.9, at: 1.5), "Consecutive cry windows must alert")
expect(!gate.ingest(confidence: 0.9, at: 3), "Continuous crying must not flood alerts")
for index in 3...40 { _ = gate.ingest(confidence: 0.9, at: Double(index) * 1.5) }
expect(gate.ingest(confidence: 0.9, at: 61.5), "Persistent crying must be eligible for another alert")

var quietGate = CryEventGate(threshold: 0.65)
_ = quietGate.ingest(confidence: 0.9, at: 0)
_ = quietGate.ingest(confidence: 0.9, at: 1.5)
for index in 2...10 { _ = quietGate.ingest(confidence: 0.1, at: Double(index) * 1.5) }
expect(!quietGate.ingest(confidence: 0.9, at: 16.5), "New event still requires consecutive windows")
expect(quietGate.ingest(confidence: 0.9, at: 18), "A quiet period must rearm the detector")

var intermittentGate = CryEventGate(threshold: 0.65)
_ = intermittentGate.ingest(confidence: 0.9, at: 0)
_ = intermittentGate.ingest(confidence: 0.1, at: 1.5)
expect(!intermittentGate.ingest(confidence: 0.9, at: 3), "Low-confidence windows break consecutive hits")
expect(!intermittentGate.ingest(confidence: .nan, at: 4.5), "NaN scores must not alert")
expect(!intermittentGate.ingest(confidence: 1.1, at: 4.5), "Out-of-range scores must not alert")
expect(!intermittentGate.ingest(confidence: 0.9, at: 3), "Duplicate timestamps must not count twice")
expect(!intermittentGate.ingest(confidence: 0.9, at: 2), "Out-of-order timestamps must not count")
expect(!intermittentGate.ingest(confidence: 0.9, at: 20), "Analysis gaps reset consecutive hits")
expect(intermittentGate.ingest(confidence: 0.9, at: 21.5), "Detector recovers after an analysis gap")

var alarmRecovery = MonitoringRecovery()
alarmRecovery.start()
alarmRecovery.interruptionBegan(at: 0)
alarmRecovery.alarmEnded(at: 10)
expect(!alarmRecovery.interruptionActive, "Confirmed alarm end clears a missing interruption-ended notification")
expect(!alarmRecovery.beginAttempt(at: 11, alarmAlerting: false), "Alarm dismissal allows audio hardware to settle")
expect(alarmRecovery.beginAttempt(at: 12, alarmAlerting: false), "Alarm end resumes an intended session without reopening App")
expect(alarmRecovery.beginAttempt(at: 14, alarmAlerting: false), "Second retry remains bounded")
expect(alarmRecovery.beginAttempt(at: 18, alarmAlerting: false), "Third retry remains bounded")
expect(alarmRecovery.exhausted && alarmRecovery.requested, "Retry exhaustion is not an explicit user stop")
alarmRecovery.alarmEnded(at: 30)
expect(!alarmRecovery.exhausted && alarmRecovery.attempts == 0, "A newly ended alarm gives exhausted recovery a fresh opportunity")
expect(!alarmRecovery.beginAttempt(at: 32, alarmAlerting: true), "Another alerting system alarm still prevents audio restart")
expect(alarmRecovery.beginAttempt(at: 32, alarmAlerting: false), "Microphone recovery can retry after alarm releases audio")
alarmRecovery.receivedAnalysis()
expect(!alarmRecovery.needsRecovery && alarmRecovery.requested, "Only valid analysis completes alarm recovery")
alarmRecovery.stop()
alarmRecovery.alarmEnded(at: 40)
expect(!alarmRecovery.requested && !alarmRecovery.beginAttempt(at: 42, alarmAlerting: false), "Late stop intent cannot override an explicit monitoring stop")

var manualRecovery = MonitoringRecovery()
expect(!manualRecovery.manualRetry(at: 0), "Manual recovery helper cannot revive explicitly stopped intent")
manualRecovery.start()
manualRecovery.interruptionBegan(at: 1)
expect(manualRecovery.manualRetry(at: 5), "A foreground user action permits recovery from a stale interruption")
expect(!manualRecovery.beginAttempt(at: 5.2, alarmAlerting: false), "Quick recovery still lets the audio session settle")
expect(manualRecovery.beginAttempt(at: 5.6, alarmAlerting: false), "Quick recovery does not require stopping the whole monitoring session")
manualRecovery.receivedAnalysis()
expect(manualRecovery.requested && !manualRecovery.needsRecovery, "Valid analysis confirms quick recovery while preserving user intent")

var lowGate = CryEventGate(threshold: DetectionSensitivity.conservative.threshold)
expect(!lowGate.ingest(confidence: DetectionSensitivity.conservative.threshold - 0.01, at: 0), "Conservative sensitivity must apply its threshold")
expect(!lowGate.ingest(confidence: DetectionSensitivity.conservative.threshold - 0.01, at: 1.5), "Below-threshold values must not accumulate")

var recovery = MonitoringRecovery()
recovery.requireRecovery(at: 0)
expect(!recovery.beginAttempt(at: 1, alarmAlerting: false), "Recovery cannot start before user monitoring intent")
recovery.start()
recovery.interruptionBegan(at: 0)
expect(recovery.requested, "An audio interruption must preserve monitoring intent")
expect(!recovery.beginAttempt(at: 1, alarmAlerting: false), "Do not fight an active audio interruption")
recovery.interruptionEnded(at: 1)
expect(!recovery.beginAttempt(at: 1.4, alarmAlerting: false), "Allow time for system audio to settle")
expect(!recovery.beginAttempt(at: 2, alarmAlerting: true), "Do not restart while a system alarm is alerting")
expect(recovery.beginAttempt(at: 2, alarmAlerting: false), "Ending the interruption resumes without a playback flag")
expect(!recovery.beginAttempt(at: 2.1, alarmAlerting: false), "Retries must be spaced out")
expect(recovery.beginAttempt(at: 4, alarmAlerting: false), "Transient first failure permits a second attempt")
expect(recovery.beginAttempt(at: 8, alarmAlerting: false), "Transient second failure permits the final attempt")
expect(recovery.exhausted && !recovery.beginAttempt(at: 30, alarmAlerting: false), "Repeated failure has a finite retry budget")
recovery.receivedAnalysis()
expect(!recovery.needsRecovery && recovery.attempts == 0, "Valid analysis completes recovery")
recovery.requireRecovery(at: 40)
expect(recovery.beginAttempt(at: 41, alarmAlerting: false), "Later interruptions have a fresh budget after genuine recovery")
recovery.stop()
recovery.interruptionEnded(at: 42)
expect(!recovery.requested && !recovery.beginAttempt(at: 43, alarmAlerting: false), "Late alarm/interruption endings cannot undo a user stop")

let suite = "BabySignalTests.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let repository = EventRepository(defaults: defaults)
expect(repository.load().isEmpty, "Fresh history starts empty")
var event = SignalEvent(kind: .cry, detail: "Test")
event.alertStatus = .scheduled
event.confirmedAt = Date()
repository.save([event])
let restored = repository.load()
expect(restored.count == 1 && restored[0].id == event.id, "Event identity must persist")
expect(restored[0].confirmedAt != nil && restored[0].alertStatus == .scheduled, "Perception and alarm status remain separate")
repository.save((0..<110).map { _ in SignalEvent(kind: .test, detail: "Test") })
expect(repository.load().count == 100, "History must remain bounded")
defaults.set(Data("invalid".utf8), forKey: "babySignal.events.v1")
expect(repository.load().isEmpty && repository.lastError != nil, "Corrupt history must not prevent startup")

final class SilenceObserver: NSObject, SNResultsObserving {
  var resultCount = 0
  var failure: Error?
  var maxCryConfidence = 0.0
  let completed = DispatchSemaphore(value: 0)

  func request(_ request: SNRequest, didProduce result: SNResult) {
    guard let result = result as? SNClassificationResult else { return }
    resultCount += 1
    maxCryConfidence = max(maxCryConfidence, result.classifications.first { $0.identifier == "baby_crying" }?.confidence ?? 0)
  }
  func request(_ request: SNRequest, didFailWithError error: Error) {
    failure = error
    completed.signal()
  }
  func requestDidComplete(_ request: SNRequest) { completed.signal() }
}

// Exercise Apple's actual classifier and callback path without requesting a microphone.
let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
expect(request.knownClassifications.contains("baby_crying"), "The installed classifier exposes baby_crying")
let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16000 * 9)!
buffer.frameLength = buffer.frameCapacity
memset(buffer.floatChannelData![0], 0, Int(buffer.frameLength) * MemoryLayout<Float>.size)
let observer = SilenceObserver()
let analyzer = SNAudioStreamAnalyzer(format: format)
try analyzer.add(request, withObserver: observer)
DispatchQueue(label: "BabySignalTests.classifier").async {
  analyzer.analyze(buffer, atAudioFramePosition: 0)
  analyzer.completeAnalysis()
}
expect(observer.completed.wait(timeout: .now() + 30) == .success, "Classifier completes within the test deadline")
expect(observer.failure == nil && observer.resultCount > 0, "Real analysis produces results")
expect(observer.maxCryConfidence < DetectionSensitivity.sensitive.threshold, "Digital silence must not trigger the cry threshold")
print("PASS: \(checks) checks, \(observer.resultCount) real classifier windows; no microphone or network used.")
