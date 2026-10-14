import Foundation

struct SignalEvent: Codable, Identifiable {
  enum Kind: String, Codable {
    case cry, test, interruption, recovery, failure
  }

  enum AlertStatus: String, Codable {
    case notRequested, scheduled, alerting, ended, cancelled, failed

    var title: String {
      switch self {
      case .notRequested: return "未安排闹钟"
      case .scheduled: return "系统已安排闹钟"
      case .alerting: return "系统闹钟已触发"
      case .ended: return "系统闹钟已结束 · 未确认感知"
      case .cancelled: return "已取消闹钟"
      case .failed: return "闹钟安排失败"
      }
    }
  }

  let id: UUID
  let date: Date
  let kind: Kind
  var detail: String
  var alertStatus: AlertStatus
  var confirmedAt: Date?

  init(kind: Kind, detail: String) {
    id = UUID()
    date = Date()
    self.kind = kind
    self.detail = detail
    alertStatus = .notRequested
  }

  var title: String {
    switch kind {
    case .cry: return "检测到宝宝哭声"
    case .test: return "提醒测试"
    case .interruption: return "监测中断"
    case .recovery: return "监测已恢复"
    case .failure: return "监测未能继续"
    }
  }
}
