import AlarmKit
import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
final class MonitorStore: ObservableObject {
  static weak var current: MonitorStore?

  enum Phase {
    case idle, starting, monitoring, recovering, interrupted, failed

    var title: String {
      switch self {
      case .idle: return L10n.text("尚未开始监测")
      case .starting: return L10n.text("正在准备监测")
      case .monitoring: return L10n.text("正在监听宝宝声音")
    case .recovering: return L10n.text("正在恢复声音检测")
      case .interrupted: return L10n.text("监测已暂停")
      case .failed: return L10n.text("监测需要检查")
      }
    }
  }

  @Published private(set) var phase: Phase = .idle { didSet { synchronizeLiveActivity(); recordRecoverySnapshot(force: true) } }
  @Published private(set) var events: [SignalEvent]
  @Published private(set) var alarmAuthorized = false
  @Published private(set) var microphoneAuthorized = false
  @Published private(set) var message = L10n.text("把手机放在宝宝够不到的位置，手表戴在手腕上。")
  @Published private(set) var lastAnalysisAt: Date? { didSet { synchronizeLiveActivity(); recordRecoverySnapshot() } }
  @Published private(set) var sessionStartedAt: Date? { didSet { synchronizeLiveActivity() } }
  @Published private(set) var isTesting = false
  @Published private(set) var storageWarning: String?
  @Published var sensitivity: DetectionSensitivity {
    didSet { UserDefaults.standard.set(sensitivity.rawValue, forKey: "babySignal.sensitivity") }
  }

  @Published private(set) var liveActivityMessage: String?
  private let liveActivity = MonitoringLiveActivity()
  private var liveCryID: UUID?
  private var hasResumed = false
  private var audioStartedAt: Date?
  private var handledAlarmStops = Set<UUID>()
  private var lastDiagnosticSnapshotAt = Date.distantPast
  private let audio = AudioMonitor()
  private let alarms = AlarmService()
  private let repository = EventRepository()
  private var gate = CryEventGate(threshold: DetectionSensitivity.balanced.threshold)
  private var generation = UUID()
  private var recovery = MonitoringRecovery()
  private var monitoringRequested: Bool { recovery.requested }
  private var recoveryTask: Task<Void, Never>?
  private var recoveryBackgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var interruptionTokens: [NSObjectProtocol] = []
  private var watchdog: AnyCancellable?
  private var activeAlarmIDs = Set<UUID>()
  private var alertingAlarmIDs = Set<UUID>()
  private var schedulingIDs = Set<UUID>()
  private var cancelledIDs = Set<UUID>()

  init() {
    events = repository.load()
    storageWarning = repository.lastError
    sensitivity = DetectionSensitivity(
      rawValue: UserDefaults.standard.string(forKey: "babySignal.sensitivity") ?? ""
    ) ?? .balanced
    refreshPermissions()
    reconcileCurrentAlarms()
    installAudioObservers()
    watchdog = Timer.publish(every: 3, on: .main, in: .common).autoconnect().sink { [weak self] _ in
      self?.checkAudioHealth()
    }
    Self.current = self
    liveActivity.onAvailabilityChange = { [weak self] message in self?.liveActivityMessage = message }
    liveActivity.synchronize(nil, force: true)
  }

  var isMonitoring: Bool { phase == .monitoring }
  var canStart: Bool { phase != .starting && phase != .monitoring && phase != .recovering && !isTesting }
  var isSessionActive: Bool { monitoringRequested || phase == .starting }
  var canQuickRecover: Bool { phase == .failed || phase == .interrupted }
  var hasPendingAlarm: Bool { !activeAlarmIDs.isEmpty || !schedulingIDs.isEmpty }
  var newestUnconfirmedEvent: SignalEvent? {
    events.first {
      ($0.kind == .cry || $0.kind == .test)
        && $0.confirmedAt == nil
        && [.scheduled, .alerting, .ended].contains($0.alertStatus)
    }
  }

  func observeSystemChanges() async {
    await withTaskGroup(of: Void.self) { group in
      group.addTask { [weak self] in
        await self?.alarms.observe { [weak self] alarms in self?.reconcile(alarms) }
      }
      group.addTask { [weak self] in
        await self?.alarms.observeAuthorization { [weak self] authorized in
          guard let self else { return }
          self.alarmAuthorized = authorized
          if !authorized, self.monitoringRequested {
            self.halt(reason: L10n.text("闹钟权限已关闭，无法继续提醒。请开启权限后重新开始。"), kind: .failure)
          }
        }
      }
      await group.waitForAll()
    }
  }

  func refreshPermissions() {
    alarmAuthorized = alarms.authorized
    microphoneAuthorized = AVAudioApplication.shared.recordPermission == .granted
  }

  func returnedToForeground() {
    synchronizeLiveActivity(force: true)
    refreshPermissions()
    reconcileCurrentAlarms()
    if monitoringRequested, !alarmAuthorized || !microphoneAuthorized {
      halt(reason: L10n.text("麦克风或闹钟权限已关闭，请检查系统设置后重新开始。"), kind: .failure)
    } else {
      if monitoringRequested, recovery.exhausted, let current = try? alarms.currentAlarms(), !current.contains(where: { $0.state == .alerting }) {
        recovery.alarmEnded(at: ProcessInfo.processInfo.systemUptime)
        phase = .interrupted
      }
      if recovery.needsRecovery { queueRecoveryAttempt() }
      checkAudioHealth()
    }
  }

  func startMonitoring() async {
    guard canStart else { return }
    recovery.stop()
    cancelRecoveryWork()
    generation = UUID()
    let token = generation
    phase = .starting
    message = L10n.text("正在检查麦克风和闹钟权限…")
    do {
      let microphone = await AVAudioApplication.requestRecordPermission()
      guard token == generation else { return }
      microphoneAuthorized = microphone
      guard microphone else {
        phase = .failed
        message = L10n.text("未允许使用麦克风。请在系统设置中开启后重试。")
        return
      }
      let alarm = try await alarms.requestAuthorization()
      guard token == generation else { return }
      alarmAuthorized = alarm
      guard alarm else {
        phase = .failed
        message = L10n.text("未允许闹钟提醒。请在系统设置中开启后重试。")
        return
      }
      recovery.start()
      liveCryID = nil
      hasResumed = false
      handledAlarmStops.removeAll()
      sessionStartedAt = nil
      try startAudio(token: token)
    } catch {
      guard token == generation else { return }
      recovery.stop()
      audio.stop()
      phase = .failed
      message = error.localizedDescription
      append(SignalEvent(kind: .failure, detail: message))
    }
  }

  func quicklyResumeMonitoring() async {
    guard phase != .starting, phase != .recovering else { return }
    guard monitoringRequested else {
      await startMonitoring()
      return
    }
    do {
      guard !(try alarms.currentAlarms()).contains(where: { $0.state == .alerting }) else {
        message = L10n.text("请先关闭正在响的系统提醒，再恢复监测。")
        return
      }
    } catch {
      message = L10n.text("暂时无法确认提醒是否结束，请先关闭系统提醒后再试。")
      return
    }
    guard canQuickRecover || !audio.isRunning else { return }
    generation = UUID()
    audio.stop(deactivateSession: false)
    cancelRecoveryWork()
    recovery.manualRetry(at: ProcessInfo.processInfo.systemUptime)
    phase = .interrupted
    message = L10n.text("正在重新连接麦克风，请稍等声音检测恢复。")
    queueRecoveryAttempt()
  }

  func acknowledgeAndResume(id: UUID) async {
    confirmPerception(id: id)
    if monitoringRequested, canQuickRecover { await quicklyResumeMonitoring() }
  }

  private func startAudio(token: UUID) throws {
    let restoring = recovery.needsRecovery
    if !restoring { gate = CryEventGate(threshold: sensitivity.threshold) }
    lastAnalysisAt = nil
    try audio.start { [weak self] sample in
      Task { @MainActor in
        guard let self, self.generation == token,
              self.phase == .monitoring || self.phase == .recovering else { return }
        guard sample.time.isFinite, sample.confidence.isFinite,
              (0...1).contains(sample.confidence) else { return }
        self.lastAnalysisAt = Date()
        if self.recovery.needsRecovery {
          self.recovery.receivedAnalysis()
          self.hasResumed = true
          self.phase = .monitoring
          self.cancelRecoveryWork()
          self.message = L10n.text("声音检测已恢复。内置识别器在锁屏时可能中断，请留意状态。")
          self.append(SignalEvent(kind: .recovery, detail: L10n.text("麦克风已重新输出有效声音分析结果。")))
        }
        // Analyzer frame time restarts with each engine; use one monotonic clock across recoveries.
        if self.gate.ingest(confidence: sample.confidence, at: ProcessInfo.processInfo.systemUptime) {
          self.detectedCry()
        }
      }
    } failure: { [weak self] reason in
      Task { @MainActor in
        guard let self, self.generation == token else { return }
        self.requestAutomaticRecovery(reason: reason)
      }
    }
    audioStartedAt = Date()
    phase = restoring ? .recovering : .monitoring
    if !restoring { sessionStartedAt = Date() }
    message = restoring
      ? L10n.text("麦克风已重启，正在等待声音分析结果。")
      : L10n.text("正在使用内置声音识别。此设备锁屏可能中断，请留意监测状态。")
  }

  func stopMonitoring() {
    recovery.stop()
    cancelRecoveryWork()
    generation = UUID()
    audio.stop()
    phase = .idle
    sessionStartedAt = nil
    lastAnalysisAt = nil
    message = L10n.text("监测已停止。已安排的提醒仍会保留，可单独取消。")
  }

  func runReminderTest() async {
    guard !isTesting, phase != .monitoring, phase != .starting, !hasPendingAlarm else { return }
    isTesting = true
    defer { isTesting = false }
    do {
      alarmAuthorized = try await alarms.requestAuthorization()
      guard alarmAuthorized else {
        message = L10n.text("请允许闹钟提醒后再测试。")
        return
      }
      let event = SignalEvent(kind: .test, detail: L10n.text("约 15 秒后提醒。请先锁屏，并留意配对手表。测试可能同时让手机发声。"))
      append(event)
      await schedule(event)
    } catch {
      message = L10n.format("测试未能开始：%@", error.localizedDescription)
    }
  }

  func confirmPerception(id: UUID) {
    update(id) { $0.confirmedAt = Date() }
    cancelReminder(id: id)
    systemAlarmStopped(id: id)
    if !recovery.needsRecovery {
      message = L10n.text("已记录你感知到提醒。请实际查看宝宝；持续哭声仍可能再次提醒。")
    }
  }

  func cancelReminder(id: UUID) {
    cancelledIDs.insert(id)
    guard activeAlarmIDs.contains(id) else {
      if !schedulingIDs.contains(id) { cancelledIDs.remove(id) }
      return
    }
    do {
      try alarms.cancel(id: id)
      activeAlarmIDs.remove(id)
      update(id) { $0.alertStatus = .cancelled }
      cancelledIDs.remove(id)
      systemAlarmStopped(id: id)
    } catch {
      message = L10n.text("未能取消提醒，请在系统闹钟界面停止。")
      reconcileCurrentAlarms()
    }
  }

  func clearHistory() {
    // Keep any event that still owns an alarm, otherwise its cancel control would disappear.
    events.removeAll { !activeAlarmIDs.contains($0.id) && !schedulingIDs.contains($0.id) }
    persist()
  }

  func openSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }

  private func detectedCry() {
    guard !hasPendingAlarm else { return }
    let event = SignalEvent(kind: .cry, detail: L10n.text("连续分析结果达到当前灵敏度条件，请查看宝宝。"))
    append(event)
    liveCryID = event.id
    synchronizeLiveActivity(force: true)
    // Reserve before starting the task so two results cannot schedule duplicate alarms.
    schedulingIDs.insert(event.id)
    Task { await schedule(event) }
  }

  private func schedule(_ event: SignalEvent) async {
    schedulingIDs.insert(event.id)
    defer { schedulingIDs.remove(event.id) }
    do {
      try await alarms.schedule(event: event)
      activeAlarmIDs.insert(event.id)
      if cancelledIDs.remove(event.id) != nil {
        cancelReminder(id: event.id)
        return
      }
      update(event.id) { if $0.alertStatus != .alerting { $0.alertStatus = .scheduled } }
      message = event.kind == .test
        ? L10n.text("系统已安排约 15 秒后的测试闹钟。请先锁屏，再留意手表是否震动。")
        : L10n.text("系统已安排提醒。是否到达手表、是否叫醒，需要由你确认。")
      reconcileCurrentAlarms()
    } catch {
      cancelledIDs.remove(event.id)
      update(event.id) {
        $0.alertStatus = .failed
        $0.detail = L10n.format("闹钟安排失败：%@", error.localizedDescription)
      }
      message = L10n.text("未能安排闹钟提醒，请检查权限并直接查看宝宝。")
      if monitoringRequested {
        recovery.stop()
        cancelRecoveryWork()
        generation = UUID()
        audio.stop()
        phase = .failed
      }
    }
  }

  private func halt(reason: String, kind: SignalEvent.Kind) {
    let wasRequested = monitoringRequested
    generation = UUID()
    audio.stop()
    phase = kind == .interruption ? .interrupted : .failed
    message = reason
    if kind == .failure {
      recovery.stop()
      cancelRecoveryWork()
    }
    let event = SignalEvent(kind: kind, detail: reason)
    append(event)
    if wasRequested, alarmAuthorized, !hasPendingAlarm {
      schedulingIDs.insert(event.id)
      Task { await schedule(event) }
    }
  }

  private func installAudioObservers() {
    let center = NotificationCenter.default
    interruptionTokens.append(center.addObserver(
      forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
    ) { [weak self] notification in
      let engine = notification.object as? AVAudioEngine
      Task { @MainActor in
        guard let self, self.monitoringRequested,
              self.audio.isCurrentEngine(engine), !self.audio.isRunning else { return }
        self.requestAutomaticRecovery(reason: L10n.text("音频引擎已暂停，正在尝试恢复声音检测。"))
      }
    })
    interruptionTokens.append(center.addObserver(
      forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
    ) { [weak self] notification in
      let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
      let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
      Task { @MainActor in self?.handleInterruption(type: typeValue, options: optionsValue) }
    })
    interruptionTokens.append(center.addObserver(
      forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self, self.monitoringRequested else { return }
        self.halt(reason: L10n.text("系统音频服务已重启，请重新开始监测。"), kind: .failure)
      }
    })
    interruptionTokens.append(center.addObserver(
      forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
    ) { [weak self] notification in
      let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
      // Our own audio category changes also post route notifications during start/stop.
      guard let reasonValue,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
            reason == .newDeviceAvailable || reason == .oldDeviceUnavailable else { return }
      Task { @MainActor in
        guard let self, self.isMonitoring else { return }
        self.halt(reason: L10n.text("音频设备发生变化，请确认使用手机麦克风后重新开始。"), kind: .failure)
      }
    })
  }

  private func handleInterruption(type: UInt?, options: UInt) {
    guard let type, let interruption = AVAudioSession.InterruptionType(rawValue: type) else { return }
    switch interruption {
    case .began:
      guard monitoringRequested else { return }
      requestAutomaticRecovery(reason: L10n.text("提醒或系统音频暂时打断监听，结束后会自动尝试恢复。"))
      recovery.interruptionBegan(at: ProcessInfo.processInfo.systemUptime)
    case .ended:
      guard monitoringRequested, recovery.needsRecovery else { return }
      // shouldResume is a playback hint, not the user's decision to stop microphone monitoring.
      recovery.interruptionEnded(at: ProcessInfo.processInfo.systemUptime)
      queueRecoveryAttempt()
    @unknown default: break
    }
  }

  private func checkAudioHealth() {
    if monitoringRequested, hasPendingAlarm || recovery.needsRecovery { reconcileCurrentAlarms() }
    if recovery.needsRecovery, phase == .interrupted {
      attemptAudioRecovery()
      return
    }
    guard phase == .monitoring || phase == .recovering else { return }
    let reference = lastAnalysisAt ?? audioStartedAt ?? Date()
    if !audio.isRunning || Date().timeIntervalSince(reference) > 20 {
      requestAutomaticRecovery(reason: L10n.text("声音分析暂时没有更新，正在尝试恢复。"))
    }
  }

  private func reconcileCurrentAlarms() {
    do { reconcile(try alarms.currentAlarms()) } catch {
      message = L10n.text("暂时无法读取系统闹钟状态，请先做提醒测试。")
    }
  }

  private func reconcile(_ current: [Alarm]) {
    let byID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
    activeAlarmIDs = Set(current.map(\.id)).intersection(Set(events.map(\.id)))
    alertingAlarmIDs = Set(current.filter { $0.state == .alerting }.map(\.id))
    var changed = false
    var endedIDs: [UUID] = []
    for index in events.indices {
      let event = events[index]
      let status: SignalEvent.AlertStatus?
      if let alarm = byID[event.id] {
        status = alarm.state == .alerting ? .alerting : .scheduled
      } else if !schedulingIDs.contains(event.id), event.alertStatus == .scheduled || event.alertStatus == .alerting {
        status = .ended
      } else {
        status = nil
      }
      if let status, status != event.alertStatus {
        events[index].alertStatus = status
        if status == .ended { endedIDs.append(event.id) }
        changed = true
      }
    }
    if changed { persist() }
    if let id = liveCryID, let event = events.first(where: { $0.id == id }),
       [.ended, .cancelled].contains(event.alertStatus) {
      liveCryID = nil
      hasResumed = true
      synchronizeLiveActivity(force: true)
    }
    // Scheduled -> absent also matters: the app may never observe the brief alerting state.
    for id in endedIDs { systemAlarmStopped(id: id) }
  }

  func systemAlarmStopped(id: UUID) {
    guard events.contains(where: { $0.id == id }), handledAlarmStops.insert(id).inserted else { return }
    MonitoringDiagnostics.record("Alarm ended: \(id)")
    if liveCryID == id {
      liveCryID = nil
      hasResumed = true
      synchronizeLiveActivity(force: true)
    }
    guard monitoringRequested else { return }
    if recovery.needsRecovery || !audio.isRunning {
      recovery.alarmEnded(at: ProcessInfo.processInfo.systemUptime)
      phase = .interrupted
      message = L10n.text("提醒已结束，正在重新连接麦克风。")
      queueRecoveryAttempt()
    } else {
      checkAudioHealth()
    }
  }

  private func requestAutomaticRecovery(reason: String) {
    guard monitoringRequested else { return }
    let newlyInterrupted = !recovery.needsRecovery
    recovery.requireRecovery(at: ProcessInfo.processInfo.systemUptime)
    generation = UUID()
    // Deactivating an already interrupted session can prevent its end notification from arriving.
    audio.stop(deactivateSession: false)
    phase = .interrupted
    message = reason
    if newlyInterrupted { append(SignalEvent(kind: .interruption, detail: reason)) }
    if recovery.exhausted {
      pauseAfterRecoveryFailure(reason: L10n.text("暂时未能恢复声音检测。提醒结束后会再尝试，也可打开 App 检查。"))
      return
    }
    queueRecoveryAttempt()
  }

  private func queueRecoveryAttempt() {
    guard monitoringRequested, recovery.needsRecovery else { return }
    if recoveryBackgroundTask == .invalid {
      recoveryBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: L10n.text("恢复宝宝声音监测")) { [weak self] in
        Task { @MainActor in self?.endRecoveryBackgroundTask() }
      }
    }
    recoveryTask?.cancel()
    recoveryTask = Task { [weak self] in
      do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
      guard !Task.isCancelled else { return }
      self?.attemptAudioRecovery()
    }
  }

  private func attemptAudioRecovery() {
    guard monitoringRequested, recovery.needsRecovery else { return }
    refreshPermissions()
    guard alarmAuthorized, microphoneAuthorized else {
      halt(reason: L10n.text("恢复监测需要麦克风和闹钟权限，请检查系统设置。"), kind: .failure)
      return
    }
    if recovery.exhausted {
      pauseAfterRecoveryFailure(reason: L10n.text("声音检测暂时无法恢复，请打开 App 检查。"))
      return
    }
    guard let systemAlarms = try? alarms.currentAlarms() else { return }
    guard recovery.beginAttempt(
      at: ProcessInfo.processInfo.systemUptime,
      alarmAlerting: systemAlarms.contains { $0.state == .alerting }
    ) else { return }
    generation = UUID()
    do {
      try startAudio(token: generation)
    } catch {
      MonitoringDiagnostics.record("Recovery start failed: \(MonitoringDiagnostics.describe(error))")
      phase = .interrupted
      message = L10n.text("麦克风暂时无法恢复，将再次尝试。")
      if recovery.exhausted {
        pauseAfterRecoveryFailure(reason: L10n.text("麦克风暂时无法恢复，提醒结束后会再尝试。"))
      }
    }
  }

  private func pauseAfterRecoveryFailure(reason: String) {
    // Preserve the user's monitoring intent; only explicit stop and terminal permission errors end it.
    audio.stop(deactivateSession: false)
    cancelRecoveryWork()
    phase = .failed
    message = reason
    if events.first?.kind != .failure { append(SignalEvent(kind: .failure, detail: reason)) }
  }

  private func recordRecoverySnapshot(force: Bool = false) {
    let now = Date()
    guard force || now.timeIntervalSince(lastDiagnosticSnapshotAt) >= 5 else { return }
    lastDiagnosticSnapshotAt = now
    UserDefaults.standard.set([
      "phase": String(describing: phase), "requested": String(monitoringRequested),
      "attempts": String(recovery.attempts), "interruption": String(recovery.interruptionActive),
      "lastAnalysis": String(lastAnalysisAt?.timeIntervalSince1970 ?? 0),
      "snapshotAt": String(now.timeIntervalSince1970)
    ], forKey: "babySignal.recoverySnapshot")
  }

  #if DEBUG
  func runRecoveryCheck() async {
    guard ProcessInfo.processInfo.arguments.contains("--recovery-check") else { return }
    await startMonitoring()
    do { try await Task.sleep(for: .seconds(8)) } catch { return }
    guard phase == .monitoring, lastAnalysisAt != nil, !hasPendingAlarm else {
      MonitoringDiagnostics.record("Recovery check could not schedule: no healthy analysis or pending alarm")
      return
    }
    let event = SignalEvent(kind: .test, detail: L10n.text("恢复验证：约 15 秒后提醒。请停止系统提醒，保持监测开启。"))
    append(event)
    await schedule(event)
  }
  #endif

  private func endRecoveryBackgroundTask() {
    guard recoveryBackgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(recoveryBackgroundTask)
    recoveryBackgroundTask = .invalid
  }

  private func cancelRecoveryWork() {
    recoveryTask?.cancel()
    recoveryTask = nil
    endRecoveryBackgroundTask()
  }

  private func synchronizeLiveActivity(force: Bool = false) {
    if phase == .idle {
      liveActivity.synchronize(nil, force: force)
      return
    }
    guard phase != .starting, let sessionStartedAt else { return }
    let status: MonitoringActivityState.Status
    switch phase {
    case .failed, .interrupted, .recovering: status = .interrupted
    case .monitoring:
      status = lastAnalysisAt == nil ? .preparing
        : (liveCryID != nil ? .cry : (hasResumed ? .resumed : .monitoring))
    case .idle, .starting: return
    }
    liveActivity.synchronize(MonitoringActivityState(
      status: status, sessionStartedAt: sessionStartedAt,
      lastAnalysisAt: lastAnalysisAt, updatedAt: Date()
    ), force: force)
  }

  private func append(_ event: SignalEvent) {
    events.insert(event, at: 0)
    if events.count > 100 { events.removeLast(events.count - 100) }
    persist()
  }

  private func update(_ id: UUID, mutation: (inout SignalEvent) -> Void) {
    guard let index = events.firstIndex(where: { $0.id == id }) else { return }
    mutation(&events[index])
    persist()
  }

  private func persist() {
    repository.save(events)
    storageWarning = repository.lastError
  }
}
