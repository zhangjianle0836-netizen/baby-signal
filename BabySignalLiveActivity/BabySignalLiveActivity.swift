import ActivityKit
import SwiftUI
import WidgetKit

@main
struct BabySignalWidgetBundle: WidgetBundle {
  var body: some Widget { MonitoringActivityWidget() }
}

struct MonitoringActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: MonitoringActivityAttributes.self) { context in
      HStack(spacing: 12) {
        Image(systemName: context.state.symbol(stale: context.isStale))
          .font(.title).foregroundStyle(Color("AccentColor"))
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 5) {
          Text(L10n.text("宝宝信号")).font(.caption.bold()).foregroundStyle(Color("WarmSecondaryText"))
          Text(context.state.title(stale: context.isStale)).font(.headline)
          if !context.isStale && [.monitoring, .resumed, .cry].contains(context.state.status) {
            Text(context.state.sessionStartedAt, style: .timer)
              .font(.caption.monospacedDigit()).foregroundStyle(Color("WarmSecondaryText"))
              .accessibilityLabel(L10n.format("本次监测开始于 %@", context.state.sessionStartedAt.formatted()))
          }
          Text(context.isStale || context.state.status == .interrupted ? L10n.text("打开 App 快速恢复") : L10n.text("打开 App 查看")).font(.caption).foregroundStyle(Color("AccentColor"))
        }
        Spacer(minLength: 0)
      }
      .padding(16)
      .activityBackgroundTint(Color("WarmSurface"))
      .activitySystemActionForegroundColor(Color("AccentColor"))
      .widgetURL(URL(string: context.isStale || context.state.status == .interrupted ? "babysignal://recover" : "babysignal://monitor"))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: context.state.symbol(stale: context.isStale))
            .font(.title2).foregroundStyle(Color(red: 0.94, green: 0.76, blue: 0.62))
            .accessibilityLabel(context.state.compactTitle(stale: context.isStale))
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(L10n.text("宝宝信号")).font(.caption).foregroundStyle(.white)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 8) {
            Text(context.state.title(stale: context.isStale)).font(.headline).foregroundStyle(.white)
            HStack {
              if !context.isStale && [.monitoring, .resumed, .cry].contains(context.state.status) {
                Text(L10n.text("本次监测 ")).font(.caption)
                Text(context.state.sessionStartedAt, style: .timer).font(.caption.monospacedDigit())
              }
              Spacer()
              Link(context.isStale || context.state.status == .interrupted ? L10n.text("恢复监测") : L10n.text("打开 App"), destination: URL(string: context.isStale || context.state.status == .interrupted ? "babysignal://recover" : "babysignal://monitor")!)
                .font(.subheadline.bold()).padding(.horizontal, 12).padding(.vertical, 8)
                .foregroundStyle(.black)
                .background(Color(red: 0.94, green: 0.76, blue: 0.62), in: Capsule())
            }.foregroundStyle(.white)
          }
        }
      } compactLeading: {
        Image(systemName: context.state.symbol(stale: context.isStale))
          .foregroundStyle(Color(red: 0.94, green: 0.76, blue: 0.62))
          .accessibilityLabel(context.state.title(stale: context.isStale))
      } compactTrailing: {
        Text(context.state.compactTitle(stale: context.isStale)).font(.caption2.bold())
          .foregroundStyle(.white)
      } minimal: {
        Image(systemName: context.state.symbol(stale: context.isStale))
          .foregroundStyle(Color(red: 0.94, green: 0.76, blue: 0.62))
          .accessibilityLabel(context.state.title(stale: context.isStale))
      }
      .widgetURL(URL(string: context.isStale || context.state.status == .interrupted ? "babysignal://recover" : "babysignal://monitor"))
      .keylineTint(Color(red: 0.94, green: 0.76, blue: 0.62))
    }
  }
}
