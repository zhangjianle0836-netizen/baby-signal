import ActivityKit
import Foundation

struct MonitoringActivityAttributes: ActivityAttributes {
  typealias ContentState = MonitoringActivityState
  var sessionID: UUID
}
