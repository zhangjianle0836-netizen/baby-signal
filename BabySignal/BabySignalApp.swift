import SwiftUI

@main
struct BabySignalApp: App {
  @StateObject private var store = MonitorStore()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      MonitorView(store: store)
        .modifier(UIReviewOverrides())
        .onOpenURL { url in
          if url.scheme == "babysignal", url.host == "recover" {
            Task { await store.quicklyResumeMonitoring() }
          }
        }
        .task { await store.observeSystemChanges() }
        #if DEBUG
        .task { await store.runRecoveryCheck() }
        #endif
        .onChange(of: scenePhase) { _, phase in
          if phase == .active { store.returnedToForeground() }
        }
    }
  }
}

/// Debug-only visual review without changing the user's system font or appearance settings.
private struct UIReviewOverrides: ViewModifier {
  @ViewBuilder
  func body(content: Content) -> some View {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("--ui-large-text") {
      content.environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--ui-dark") ? .dark : nil)
    } else {
      content.preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--ui-dark") ? .dark : nil)
    }
    #else
    content
    #endif
  }
}
