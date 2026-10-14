import AlarmKit
import SwiftUI

struct BabyAlarmMetadata: AlarmMetadata {
  let eventID: UUID
}

@MainActor
final class AlarmService {
  private let manager = AlarmManager.shared

  var authorized: Bool { manager.authorizationState == .authorized }

  func requestAuthorization() async throws -> Bool {
    try await manager.requestAuthorization() == .authorized
  }

  func schedule(event: SignalEvent) async throws {
    guard authorized else { throw AlarmError.permissionDenied }
    let title: LocalizedStringResource
    switch event.kind {
    case .cry: title = "检测到宝宝哭声，请查看"
    case .test: title = "提醒测试，请确认是否感到震动"
    case .interruption, .recovery, .failure: title = "宝宝声音监测已暂停，请检查手机"
    }
    let alert: AlarmPresentation.Alert
    if #available(iOS 26.1, *) {
      alert = AlarmPresentation.Alert(title: title)
    } else {
      alert = AlarmPresentation.Alert(
        title: title,
        stopButton: AlarmButton(text: "停止提醒", textColor: .white, systemImageName: "stop.circle")
      )
    }
    let attributes = AlarmAttributes(
      presentation: AlarmPresentation(alert: alert),
      metadata: BabyAlarmMetadata(eventID: event.id),
      tintColor: Color(red: 0.12, green: 0.40, blue: 0.36)
    )
    // A fixed alarm avoids a countdown Live Activity/widget requirement in the first prototype.
    let delay: TimeInterval = event.kind == .test ? 15 : 3
    let configuration = AlarmManager.AlarmConfiguration(
      schedule: .fixed(Date().addingTimeInterval(delay)),
      attributes: attributes,
      stopIntent: StopBabyAlarmIntent(alarmID: event.id)
    )
    _ = try await manager.schedule(id: event.id, configuration: configuration)
  }

  func cancel(id: UUID) throws { try manager.cancel(id: id) }

  func currentAlarms() throws -> [Alarm] { try manager.alarms }

  func observe(_ update: @escaping @MainActor ([Alarm]) -> Void) async {
    for await alarms in manager.alarmUpdates {
      guard !Task.isCancelled else { return }
      update(alarms)
    }
  }

  func observeAuthorization(_ update: @escaping @MainActor (Bool) -> Void) async {
    for await state in manager.authorizationUpdates {
      guard !Task.isCancelled else { return }
      update(state == .authorized)
    }
  }

  enum AlarmError: LocalizedError {
    case permissionDenied
    var errorDescription: String? { L10n.text("未允许闹钟提醒，请在系统设置中开启。") }
  }
}
