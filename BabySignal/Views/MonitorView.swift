import SwiftUI

private enum GuideStep: Int, CaseIterable, Identifiable {
  case phone = 1, watch, care
  var id: Int { rawValue }
  var imageName: String {
    switch self {
    case .phone: return "GuidePhone"
    case .watch: return "GuideWatch"
    case .care: return "GuideCare"
    }
  }
  var title: String {
    switch self {
    case .phone: return "手机放在宝宝旁边"
    case .watch: return "手表戴好，并解锁"
    case .care: return "收到提醒，去看宝宝"
    }
  }
  var summary: String {
    switch self {
    case .phone: return "放在婴儿床外，手机和电线别让宝宝碰到。"
    case .watch: return "手表贴合手腕，用这台手机配对的手表。"
    case .care: return "关闭提醒后会尝试继续；若中断，点“快速恢复监测”。"
    }
  }
}

private enum SignalStyle {
  static let ink = Color("AccentColor")
  static let button = Color("WarmPrimaryButton")
  static let canvas = Color("WarmCanvas")
  static let surface = Color("WarmSurface")
  static let secondaryText = Color("WarmSecondaryText")
}

struct MonitorView: View {
  @ObservedObject var store: MonitorStore
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var showGuide = false
  @State private var showSettings = false
  @State private var showHistory = false
  @State private var showTestWarning = false
  @State private var showStopWarning = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          Text("把宝宝的哭声\n变成手腕上的提醒")
            .font(.title2.bold()).accessibilityAddTraits(.isHeader)
          if let event = store.newestUnconfirmedEvent { reminder(event) }
          statusCard
          testCard
          guideCard
          essentials
        }
        .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
      }
      .background(SignalStyle.canvas)
      .safeAreaInset(edge: .bottom, spacing: 0) { mainAction }
      .navigationTitle("宝宝信号")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("图解", systemImage: "book.closed") { showGuide = true }
            .accessibilityLabel("查看使用图解")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button("提醒记录", systemImage: "clock.arrow.circlepath") { showHistory = true }
            Button("设置与权限", systemImage: "gearshape") { showSettings = true }
          } label: { Label("更多", systemImage: "ellipsis.circle") }
          .accessibilityLabel("更多：记录和设置")
        }
      }
      .sheet(isPresented: $showGuide) { IllustratedGuideView() }
      .sheet(isPresented: $showSettings) { MonitorSettingsView(store: store) }
      .sheet(isPresented: $showHistory) { EventHistoryView(store: store) }
      .confirmationDialog("15 秒后发出测试提醒", isPresented: $showTestWarning, titleVisibility: .visible) {
        Button("开始测试") { Task { await store.runReminderTest() } }
      } message: {
        Text("点开始后立即锁屏，留意手表是否震动。手机也可能响铃，请先避开宝宝休息的地方。")
      }
      .confirmationDialog("停止听取宝宝声音？", isPresented: $showStopWarning, titleVisibility: .visible) {
        Button("停止监测", role: .destructive) { store.stopMonitoring() }
      } message: {
        Text("停止后不再检测哭声。已经发出的提醒仍需单独关闭。")
      }
      .tint(SignalStyle.ink)
    }
  }

  private var statusTitle: String {
    switch store.phase {
    case .idle: return "还没开始监测"
    case .starting: return "正在准备"
    case .monitoring: return store.lastAnalysisAt == nil ? "正在连接麦克风" : "正在听宝宝声音"
    case .recovering: return "正在恢复监测"
    case .interrupted: return store.isSessionActive ? "正在等声音恢复" : "监测已暂停"
    case .failed: return "现在无法检测哭声"
    }
  }

  private var statusExplanation: String {
    switch store.phase {
    case .idle: return "放好手机、戴好手表，再点下面的“开始监测”。"
    case .starting: return "请按手机提示，允许使用麦克风和闹钟。"
    case .monitoring:
      return store.lastAnalysisAt == nil ? "请稍等，正在等待声音检测结果。" : "手机留在宝宝附近。此版锁屏可能中断，请留意监测状态。"
    case .recovering: return "请保持 App 打开，等待声音检测结果。"
    case .interrupted:
      return store.isSessionActive ? "声音检测暂时中断。可以点下面的“快速恢复监测”。" : "请查看宝宝，检查设置后重新开始。"
    case .failed: return "请先查看宝宝，再点“快速恢复监测”。"
    }
  }

  private var statusSymbol: String {
    switch store.phase {
    case .idle: return "pause.circle"
    case .starting, .recovering: return "arrow.clockwise"
    case .monitoring: return store.lastAnalysisAt == nil ? "hourglass" : "waveform"
    case .interrupted: return "clock.arrow.circlepath"
    case .failed: return "exclamationmark.triangle"
    }
  }

  private var statusCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      if typeSize.isAccessibilitySize {
        statusText
        guideImage(.phone, size: 140)
      } else {
        HStack(alignment: .center, spacing: 16) {
          guideImage(.phone, size: 108)
          statusText
        }
      }
      if store.isSessionActive {
        Label(store.liveActivityMessage ?? "灵动岛和锁屏可查看监测状态", systemImage: "rectangle.topthird.inset.filled")
          .font(.footnote).foregroundStyle(SignalStyle.secondaryText)
      }
      Label("使用示意图 · 不提供实时视频", systemImage: "photo")
        .font(.footnote).foregroundStyle(SignalStyle.secondaryText)
      if store.phase == .failed || store.phase == .interrupted {
        DisclosureGroup("查看具体情况") {
          Text(store.message).font(.callout).padding(.top, 6)
        }
        .font(.callout)
        Button("检查设置", systemImage: "gearshape") { showSettings = true }
          .buttonStyle(.bordered).frame(minHeight: 48)
      }
    }
    .padding(18).signalCard()
  }

  private var statusText: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(statusTitle, systemImage: statusSymbol)
        .font(.title3.bold()).foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
      Text(statusExplanation).font(.body).foregroundStyle(SignalStyle.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
  }

  private var mainAction: some View {
    VStack(spacing: 10) {
      if store.canQuickRecover || store.phase == .recovering {
        Button { Task { await store.quicklyResumeMonitoring() } } label: {
          Label(store.phase == .recovering ? "正在恢复，请稍等" : "快速恢复监测", systemImage: "arrow.clockwise.circle.fill")
            .font(.headline).frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(.white)
            .background(SignalStyle.button, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(store.phase == .recovering)
        .opacity(store.phase == .recovering ? 0.65 : 1)
        .accessibilityHint("重新连接麦克风；收到有效声音分析后才显示恢复")
      }
      if store.isSessionActive || store.phase == .interrupted {
        Button { showStopWarning = true } label: {
          Label("停止监测", systemImage: "stop.circle")
            .font(.headline).frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("停止检测新的哭声，会先询问你是否确认")
      } else if !store.canQuickRecover {
        Button { Task { await store.startMonitoring() } } label: {
          Label(store.phase == .failed ? "重新开始监测" : "开始监测", systemImage: "mic.fill")
            .font(.headline).frame(maxWidth: .infinity, minHeight: 60)
            .foregroundStyle(.white)
            .background(SignalStyle.button, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain).disabled(!store.canStart)
        .opacity(store.canStart ? 1 : 0.55)
        .accessibilityHint("允许手机听取声音，检测到哭声时安排提醒")
      }
      Text(store.isSessionActive ? "提醒结束后会尝试继续；中断时点“快速恢复监测”" : "手机留在宝宝附近；此设备锁屏可能中断")
        .font(.subheadline).foregroundStyle(SignalStyle.secondaryText).multilineTextAlignment(.center)
    }
    .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 10)
    .frame(maxWidth: 620).frame(maxWidth: .infinity).background(SignalStyle.canvas)
  }

  private func reminder(_ event: SignalEvent) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 14) {
        if !typeSize.isAccessibilitySize {
          guideImage(event.kind == .test ? .watch : .care, size: 84)
        }
        VStack(alignment: .leading, spacing: 7) {
          Text(event.kind == .test ? "手表提醒你了吗？" : "检测到哭声，请看看宝宝")
            .font(.headline).accessibilityAddTraits(.isHeader)
          Text(event.date, format: .dateTime.hour().minute())
            .font(.subheadline).foregroundStyle(SignalStyle.secondaryText)
          Text(reminderStatus(event)).font(.callout)
        }
      }
      Button(event.kind == .test ? "我感到了手表震动" : "我去看看，并继续监测") {
        Task { await store.acknowledgeAndResume(id: event.id) }
      }
      .buttonStyle(.borderedProminent).frame(minHeight: 48).tint(SignalStyle.button)
      Text(store.isSessionActive ? "只结束这次提醒；如果监测被打断，会自动尝试恢复。" : "这不会开启监测。准备好后，再点“开始监测”。")
        .font(.subheadline).foregroundStyle(SignalStyle.secondaryText)
    }
    .padding(18).signalCard()
    .overlay(RoundedRectangle(cornerRadius: 24).stroke(SignalStyle.ink, lineWidth: 2))
  }

  private func reminderStatus(_ event: SignalEvent) -> String {
    switch event.alertStatus {
    case .scheduled: return "已安排提醒，请留意手表。"
    case .alerting: return "闹钟已触发，请确认手表是否提醒你。"
    case .ended: return "这次闹钟已结束，还没有你的确认。"
    case .cancelled: return "这次提醒已关闭。"
    case .failed: return "这次提醒没有发出，请查看宝宝。"
    case .notRequested: return "正在准备提醒。"
    }
  }

  private var testCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("先试一次手表提醒", systemImage: "applewatch")
        .font(.headline).accessibilityAddTraits(.isHeader)
      Text("确认手表能震动，再开始照护时的监测。")
        .font(.body).foregroundStyle(SignalStyle.secondaryText)
      Button("测试手表震动", systemImage: "hand.tap") { showTestWarning = true }
        .buttonStyle(.bordered).frame(minHeight: 48)
        .disabled(store.isSessionActive || store.isTesting || store.hasPendingAlarm)
      if store.isSessionActive {
        Text("监测中暂不做测试，避免打断声音检测。")
          .font(.subheadline).foregroundStyle(SignalStyle.secondaryText)
      } else if store.hasPendingAlarm {
        Button("先处理已有提醒", systemImage: "clock.arrow.circlepath") { showHistory = true }
          .frame(minHeight: 48)
      } else {
        Text("15 秒后提醒 · 开始测试后立即锁屏")
          .font(.subheadline).foregroundStyle(SignalStyle.secondaryText)
      }
    }
    .padding(18).signalCard()
  }

  private var guideCard: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("照着这三步用").font(.title3.bold()).accessibilityAddTraits(.isHeader)
      ForEach(GuideStep.allCases) { step in
        GuideStepRow(step: step)
        if step != .care { Divider() }
      }
      Button("查看完整图解", systemImage: "book") { showGuide = true }
        .frame(minHeight: 48)
    }
    .padding(18).signalCard()
  }

  private var essentials: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("没有哭声提醒，也请定时查看宝宝", systemImage: "info.circle")
        .font(.callout.bold())
      Text("这是辅助照护工具，不能判断宝宝是否安全。断电、App 关闭或断连时，可能无法提醒。")
        .font(.subheadline)
      Text("不保存、不上传录音。").font(.subheadline)
      if let warning = store.storageWarning { Text(warning).font(.subheadline.bold()) }
    }
    .foregroundStyle(SignalStyle.secondaryText).padding(.horizontal, 2)
  }
}

private func guideImage(_ step: GuideStep, size: CGFloat) -> some View {
  Image(step.imageName).resizable().scaledToFit().frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: 18)).accessibilityHidden(true)
}

private struct GuideStepRow: View {
  let step: GuideStep
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    if typeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: 14) {
        guideImage(step, size: 140)
        explanation
      }
      .accessibilityElement(children: .combine)
    } else {
      HStack(alignment: .center, spacing: 16) {
        guideImage(step, size: 92)
        explanation
      }
      .accessibilityElement(children: .combine)
    }
  }

  private var explanation: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("\(step.rawValue). \(step.title)").font(.headline)
      Text(step.summary).font(.body).foregroundStyle(SignalStyle.secondaryText)
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}

private struct IllustratedGuideView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          ForEach(GuideStep.allCases) { step in
            VStack(alignment: .leading, spacing: 16) {
              Image(step.imageName).resizable().scaledToFit().frame(maxWidth: 340)
                .clipShape(RoundedRectangle(cornerRadius: 24)).accessibilityHidden(true)
              Text("\(step.rawValue). \(step.title)").font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
              Text(step.summary).font(.body)
              Text(detail(step)).font(.body).foregroundStyle(SignalStyle.secondaryText)
            }
            .padding(20).signalCard()
          }
          Label("图示为操作说明，不是实时宝宝画面", systemImage: "photo")
            .font(.subheadline).foregroundStyle(SignalStyle.secondaryText)
          Text("夜间唤醒效果需要实际测试。原型试用时请保留原有照护安排；没有哭声提醒不能证明宝宝安全。")
            .font(.body).foregroundStyle(SignalStyle.secondaryText)
        }
        .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
      }
      .background(SignalStyle.canvas)
      .navigationTitle("使用图解").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
    }
  }

  private func detail(_ step: GuideStep) -> String {
    switch step {
    case .phone: return "开始监测后请锁屏。不要把手机带离宝宝，也不要放进婴儿床或盖在被褥下。"
    case .watch: return "先做一次提醒测试。夜间使用前给手表充好电，并确认你能感知到震动。"
    case .care: return "如果首页显示正在恢复，请稍等；若显示无法检测，请检查设置或重新开始。"
    }
  }
}

private struct MonitorSettingsView: View {
  @ObservedObject var store: MonitorStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section {
          permission("允许听取声音", symbol: "mic", granted: store.microphoneAuthorized)
          permission("允许闹钟提醒", symbol: "bell", granted: store.alarmAuthorized)
          Button("打开手机系统设置", systemImage: "gearshape") { store.openSettings() }
            .frame(minHeight: 48)
        } header: { Text("使用权限") } footer: {
          Text("听取声音需要麦克风权限，发出提醒需要闹钟权限。")
        }
        Section {
          Picker("哭声检测灵敏度", selection: $store.sensitivity) {
            ForEach(DetectionSensitivity.allCases) { Text($0.title).tag($0) }
          }
          .disabled(store.isSessionActive)
        } header: { Text("检测灵敏度") } footer: {
          Text(store.isSessionActive ? "请先停止监测，再调整灵敏度。" : "较灵敏可能增加误报。更改后在下次开始时生效，请在家中试用。")
        }
        Section("佩戴检查") {
          Label("手表戴在手腕上，并保持解锁", systemImage: "applewatch")
          Label("手机和手表电量充足", systemImage: "battery.100percent")
          Text("在手机的 Watch App → 时钟中，检查“推送来自 iPhone 的提醒”是否开启。")
        }
        Section("本地识别模型") {
          Text("当前使用 Apple 内置声音识别器，识别结果只在手机本地处理。")
          Text("这台测试设备锁屏后可能中断识别。中断时先查看宝宝，再点“快速恢复监测”。")
        }
        Section("录音与记录") {
          Text("声音只在手机本地分析，不保存、不上传录音。")
          Text("本机保留最近 100 条提醒记录，可在“提醒记录”中清除。")
        }
      }
      .scrollContentBackground(.hidden)
      .background(SignalStyle.canvas)
      .navigationTitle("设置与权限").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
    }
  }

  private func permission(_ title: String, symbol: String, granted: Bool) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(title, systemImage: symbol).font(.body)
      Label(granted ? "已允许" : "尚未允许", systemImage: granted ? "checkmark.circle" : "exclamationmark.circle")
        .font(.subheadline).foregroundStyle(SignalStyle.secondaryText)
    }
    .accessibilityElement(children: .combine)
  }
}

private struct EventHistoryView: View {
  @ObservedObject var store: MonitorStore
  @Environment(\.dismiss) private var dismiss
  @State private var showClear = false

  var body: some View {
    NavigationStack {
      List {
        if store.events.isEmpty {
          ContentUnavailableView("还没有提醒记录", systemImage: "clock", description: Text("检测到哭声或测试手表提醒后，可以在这里查看。"))
        }
        ForEach(store.events) { event in
          VStack(alignment: .leading, spacing: 10) {
            Text(event.title).font(.headline)
            Text(event.date, format: .dateTime.month().day().hour().minute().second())
              .font(.subheadline).foregroundStyle(SignalStyle.secondaryText)
            if event.kind == .cry || event.kind == .test || event.alertStatus != .notRequested {
              Text(event.alertStatus.title).font(.callout)
            }
            if event.confirmedAt != nil {
              Label("你已确认收到提醒", systemImage: "checkmark.circle").font(.callout)
            }
            if event.alertStatus == .scheduled || event.alertStatus == .alerting {
              Button("关闭这次提醒", role: .destructive) { store.cancelReminder(id: event.id) }
                .frame(minHeight: 48)
            }
            DisclosureGroup("详情") {
              Text(event.detail).font(.body).padding(.top, 6)
            }
          }
          .padding(.vertical, 8)
        }
      }
      .scrollContentBackground(.hidden)
      .background(SignalStyle.canvas)
      .navigationTitle("提醒记录").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) { Button("清除", role: .destructive) { showClear = true }.disabled(store.events.isEmpty) }
        ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
      }
      .confirmationDialog("清除已结束的记录？", isPresented: $showClear, titleVisibility: .visible) {
        Button("清除记录", role: .destructive) { store.clearHistory() }
      } message: { Text("正在安排或尚未结束的提醒记录会保留。") }
    }
  }
}

private extension View {
  func signalCard() -> some View {
    frame(maxWidth: .infinity, alignment: .leading)
      .background(SignalStyle.surface, in: RoundedRectangle(cornerRadius: 24))
  }
}
