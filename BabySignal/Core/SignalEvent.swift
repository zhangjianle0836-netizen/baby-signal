import Foundation

struct SignalEvent: Codable, Identifiable {
  enum Kind: String, Codable {
    case cry, test, interruption, recovery, failure
  }

  enum AlertStatus: String, Codable {
    case notRequested, scheduled, alerting, ended, cancelled, failed

    var title: String {
      switch self {
      case .notRequested: return L10n.text("未安排闹钟")
      case .scheduled: return L10n.text("系统已安排闹钟")
      case .alerting: return L10n.text("系统闹钟已触发")
      case .ended: return L10n.text("系统闹钟已结束 · 未确认感知")
      case .cancelled: return L10n.text("已取消闹钟")
      case .failed: return L10n.text("闹钟安排失败")
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
    case .cry: return L10n.text("检测到宝宝哭声")
    case .test: return L10n.text("提醒测试")
    case .interruption: return L10n.text("监测中断")
    case .recovery: return L10n.text("监测已恢复")
    case .failure: return L10n.text("监测未能继续")
    }
  }
}
