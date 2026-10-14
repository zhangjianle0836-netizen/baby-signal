import ActivityKit
import UIKit

@MainActor
final class MonitoringLiveActivity {
  private var activity: Activity<MonitoringActivityAttributes>?
  private var tail: Task<Void, Never>?
  private var lastSubmitted: MonitoringActivityState?
  private var createdAt: Date?
  private var dismissedSession: Date?
  var onAvailabilityChange: ((String?) -> Void)?
  private var availabilityMessage: String? { didSet { onAvailabilityChange?(availabilityMessage) } }

  func synchronize(_ state: MonitoringActivityState?, force: Bool = false) {
    if let state, !force, let previous = lastSubmitted,
       previous.status == state.status,
       previous.sessionStartedAt == state.sessionStartedAt,
       state.updatedAt.timeIntervalSince(previous.updatedAt) < 10 { return }
    lastSubmitted = state
    let prior = tail
    tail = Task { [weak self] in
      await prior?.value
      guard let self else { return }
      await self.apply(state)
    }
  }

  private func apply(_ state: MonitoringActivityState?) async {
    guard var state else {
      for old in Activity<MonitoringActivityAttributes>.activities {
        var stopped = old.content.state
        stopped.status = .stopped
        stopped.updatedAt = Date()
        await old.end(ActivityContent(state: stopped, staleDate: nil), dismissalPolicy: .immediate)
      }
      activity = nil
      createdAt = nil
      dismissedSession = nil
      availabilityMessage = nil
      return
    }
    if let current = activity {
      if current.activityState == .dismissed {
        // Respect a person's removal until a new monitoring session starts.
        dismissedSession = current.content.state.sessionStartedAt
        activity = nil
      } else if current.activityState == .ended {
        activity = nil
        createdAt = nil
      } else if let createdAt, Date().timeIntervalSince(createdAt) > 7.5 * 3600,
                UIApplication.shared.applicationState == .active {
        var ended = current.content.state
        ended.status = .stopped
        await current.end(ActivityContent(state: ended, staleDate: nil), dismissalPolicy: .immediate)
        activity = nil
        self.createdAt = nil
      }
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      availabilityMessage = L10n.text("实时活动未开启，可在手机系统设置中开启。")
      return
    }
    if let createdAt { state.displayExpiresAt = createdAt.addingTimeInterval(7 * 3600 + 55 * 60) }
    if activity == nil {
      guard dismissedSession != state.sessionStartedAt else {
        availabilityMessage = L10n.text("实时活动已被移除，下次开始监测时会再显示。")
        return
      }
      guard UIApplication.shared.applicationState == .active else {
        availabilityMessage = L10n.text("打开 App 后可重新显示灵动岛状态，声音检测单独运行。")
        return
      }
      do {
        let start = Date()
        state.displayExpiresAt = start.addingTimeInterval(7 * 3600 + 55 * 60)
        activity = try Activity.request(
          attributes: MonitoringActivityAttributes(sessionID: UUID()),
          content: ActivityContent(state: state, staleDate: state.staleDate), pushType: nil
        )
        createdAt = start
      } catch {
        availabilityMessage = L10n.text("实时活动未能显示，请检查系统设置。")
        return
      }
    } else {
      await activity?.update(ActivityContent(state: state, staleDate: state.staleDate))
    }
    availabilityMessage = nil
  }
}
