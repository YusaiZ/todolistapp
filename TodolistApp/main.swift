import SwiftUI
import AppKit

/// AppKit 代理：修复「点红点关闭窗口后，Dock icon 点击无法再开」的问题。
/// 单窗口 app 的直觉是：关窗口 = 退出 app。所以让最后一个窗口关闭时直接退出进程，
/// 这样再点 Dock icon 就是全新启动，不会卡在"进程还在但无窗口"的状态。
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct TodolistApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 600)
                .environmentObject(state)
                // 外观偏好：nil（跟随系统）/ .light / .dark。
                .preferredColorScheme(state.appearance.preferredScheme)
                .background(Color.appBackground)
                .onAppear { state.flush() }
                .onDisappear { state.flush() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 780)
    }
}

/// 根视图：左侧标签栏 + 右侧看板。
struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var showNewCard = false
    @State private var editingCard: Card? = nil

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 210)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            Divider().frame(width: 1)
            BoardView(showNewCard: $showNewCard, editingCard: $editingCard)
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showNewCard) {
            NewCardSheet(mode: .create)
        }
        .sheet(item: $editingCard) { card in
            NewCardSheet(mode: .edit(card))
        }
    }
}
