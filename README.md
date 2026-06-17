# TodolistApp — macOS 看板待办

一个用纯 SwiftUI 写的 macOS 桌面看板应用，黑白色系 + 弥散投影的卡片风格。**不需要安装 Xcode.app**，用系统自带的 Command Line Tools（`swiftc`）即可编译运行。

## 功能

- **四列看板**：Plan / Todo / Doing / Done，每列顶部显示该列事件数量
- **事件卡片**：白色卡片 + 弥散投影悬浮，显示内容（最多 3 行）和标签
- **新建/编辑事件**：顶部「新建」按钮或 `⌘N`，弹窗输入内容；标签输入框输入 `#` 后实时下拉已有标签建议，点选或回车创建
- **左侧标签栏**：显示全部标签及每个标签的数量，点击筛选（四列各自只显示该标签的卡片）
- **拖拽**：按住卡片拖到任意列即自动吸附，附系统提示音
- **单击编辑**：点卡片重新编辑内容和标签
- **本地持久化**：数据自动存到 `~/Library/Application Support/TodolistApp/data.json`，关闭重开不丢失

## 编译运行

```bash
cd TodolistApp
bash build.sh
open ../TodolistApp.app
```

> 首次打开可能因「未签名」被 Gatekeeper 拦截：到 **系统设置 → 隐私与安全性** 点「仍要打开」即可。

## 目录结构

```
TodolistApp/
├── main.swift          # @main 入口、主窗口、根视图
├── Models.swift        # Status / Tag / Card 数据模型（Codable）
├── AppState.swift      # 全局状态：增删改、筛选、防抖持久化
├── Persistence.swift   # JSON 读写（Application Support）
├── BoardView.swift     # 顶部工具栏 + 四列看板 + 拖放/音效
├── CardView.swift      # 卡片视图 + FlowLayout 标签流式布局
├── SidebarView.swift   # 左侧标签栏
├── NewCardSheet.swift  # 新建/编辑弹窗 + # 标签建议下拉
└── build.sh            # 一键编译脚本
```

## 数据位置

`~/Library/Application Support/TodolistApp/data.json` — 手动备份或迁移直接拷这个文件即可。

## 技术说明

- 部署目标 macOS 13+（`LSMinimumSystemVersion`）
- 拖拽用 SwiftUI 原生 `.draggable` / `.dropDestination`
- 状态用 `ObservableObject` + `@Published`（兼容 macOS 13）
- 持久化写入做了 300ms 防抖，避免高频落盘
