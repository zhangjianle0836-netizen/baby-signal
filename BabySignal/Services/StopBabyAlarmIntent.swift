import AlarmKit
import AppIntents
import Foundation

struct StopBabyAlarmIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "停止宝宝提醒"

  @Parameter(title: "提醒编号")
  var alarmID: String

  init() {}

  init(alarmID: UUID) {
    self.alarmID = alarmID.uuidString
  }

  func perform() async throws -> some IntentResult {
    guard let id = UUID(uuidString: alarmID) else { return .result() }
    do {
      try AlarmManager.shared.stop(id: id)
    } catch {
      // The system may have already removed the alarm before invoking the stop intent.
      // A genuine failure with an alarm still present must not be reported as a dismissal.
      if try AlarmManager.shared.alarms.contains(where: { $0.id == id }) { throw error }
    }
    // No persisted auto-start: a cold launch or an explicit user stop must not enable the mic.
    await MonitorStore.current?.systemAlarmStopped(id: id)
    return .result()
  }
}
