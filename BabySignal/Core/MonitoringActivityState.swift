import Foundation

/// Small shared payload; no audio or personal data enters the widget extension.
struct MonitoringActivityState: Codable, Hashable {
  enum Status: String, Codable {
    case preparing, monitoring, cry, resumed, interrupted, stopped
  }

  var status: Status
  var sessionStartedAt: Date
  var lastAnalysisAt: Date?
  var displayExpiresAt: Date? = nil
  var updatedAt: Date

  // Even if the process dies, the system marks old content stale without another app callback.
  var staleDate: Date {
    let analysisExpiry = (lastAnalysisAt ?? updatedAt).addingTimeInterval(30)
    return min(analysisExpiry, displayExpiresAt ?? analysisExpiry)
  }

  func needsCheck(at date: Date, systemStale: Bool = false) -> Bool {
    status != .stopped && (systemStale || date >= staleDate)
  }

  func title(stale: Bool) -> String {
    if stale && status != .stopped { return "状态未更新，请打开 App" }
    switch status {
    case .preparing: return "正在准备监测"
    case .monitoring: return "宝宝声音监测中"
    case .cry: return "检测到哭声，请查看宝宝"
    case .resumed: return "已恢复，继续监测中"
    case .interrupted: return "监测中断，请打开 App"
    case .stopped: return "监测已停止"
    }
  }

  func compactTitle(stale: Bool) -> String {
    if stale && status != .stopped { return "请检查" }
    switch status {
    case .preparing: return "准备中"
    case .monitoring, .resumed: return "监测中"
    case .cry: return "有哭声"
    case .interrupted: return "已中断"
    case .stopped: return "已停止"
    }
  }

  func symbol(stale: Bool) -> String {
    if stale && status != .stopped { return "exclamationmark.triangle.fill" }
    switch status {
    case .preparing: return "hourglass"
    case .monitoring, .resumed: return "figure.child"
    case .cry: return "bell.badge.fill"
    case .interrupted: return "exclamationmark.triangle.fill"
    case .stopped: return "stop.circle"
    }
  }
}
