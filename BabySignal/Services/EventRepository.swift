import Foundation

final class EventRepository {
  private let defaults: UserDefaults
  private let key = "babySignal.events.v1"
  private(set) var lastError: String?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func load() -> [SignalEvent] {
    guard let data = defaults.data(forKey: key) else { return [] }
    do {
      return Array(try JSONDecoder().decode([SignalEvent].self, from: data).prefix(100))
    } catch {
      lastError = "历史记录读取失败；本次监测仍可使用。"
      return []
    }
  }

  func save(_ events: [SignalEvent]) {
    do {
      defaults.set(try JSONEncoder().encode(Array(events.prefix(100))), forKey: key)
      lastError = nil
    } catch {
      lastError = "记录未能保存。"
    }
  }
}
