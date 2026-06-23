import SwiftUI
import AppKit

/// AppKit 代理：负责窗口关闭语义 + 退出前同步落盘。
///
/// 关键修复（数据丢失根因）：早期 Info.plist 开了 NSSupportsSuddenTermination /
/// NSSupportsAutomaticTermination，授权系统在退出时绕过正常 cleanup 直接 SIGKILL 进程。
/// 表现就是「关了立刻重开数据还在，过一阵重开就丢」——后台被杀时 onDisappear 不保证
/// 触发，scheduleSave 的 0.3s 防抖任务也可能正好 pending，最终内存里没落盘的改动丢了。
/// 现在 build.sh 已移除这两个键，并在下面加 applicationWillTerminate 做退出前同步 flush。
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 由 App struct 在 onAppear 注入；用于退出前 flush。weak 不会提前释放，
    /// 因为 @StateObject 持有 state，其生命周期覆盖整个 app。
    weak var appState: AppState?

    /// 单窗口 app 的直觉是：关窗口 = 退出 app。让最后一个窗口关闭时直接退出进程，
    /// 这样再点 Dock icon 就是全新启动，不会卡在"进程还在但无窗口"的状态。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    /// 退出前最后兜底：同步落盘。
    /// 移除 NSSupportsSuddenTermination 后，这个方法保证会被调用；
    /// flush() 会先取消 pending 的防抖 save 再立即写盘，故是可靠的最终落盘点。
    func applicationWillTerminate(_ notification: Notification) {
        appState?.flush()
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
                .onAppear {
                    // 把 state 注入 delegate，让 applicationWillTerminate 能 flush 到。
                    appDelegate.appState = state
                    state.flush()
                }
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
