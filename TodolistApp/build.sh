#!/bin/bash
# 一键编译 TodolistApp，生成可双击运行的 .app 包（含自生成 logo）。
set -e

cd "$(dirname "$0")"

APP_NAME="TodolistApp"
SRC_DIR="$(pwd)"
APP_DIR="../${APP_NAME}.app"
MACOS_DIR="${APP_DIR}/Contents/MacOS"
RES_DIR="${APP_DIR}/Contents/Resources"
BUNDLE_ID="com.local.todolistapp"
EXEC="${MACOS_DIR}/${APP_NAME}"

echo "==> 1/3 编译 Swift 源码..."
mkdir -p "${MACOS_DIR}" "${RES_DIR}"
# 注意：make_icon.swift 是独立的图标生成工具，不能编进主 app（否则 main 符号冲突）。
swiftc \
  main.swift Models.swift AppState.swift Persistence.swift Theme.swift \
  BoardView.swift CardView.swift SidebarView.swift NewCardSheet.swift \
  -parse-as-library \
  -O \
  -o "${EXEC}"

echo "==> 2/3 生成并嵌入 app 图标..."
# 编译一次性图标生成器到临时目录（避免与主源码混淆）。
ICON_GEN="$(mktemp -d)/make_icon"
swiftc "${SRC_DIR}/make_icon.swift" -parse-as-library -o "${ICON_GEN}" \
  -framework AppKit -framework Foundation

ICONSET="$(mktemp -d)/icon.iconset"
mkdir -p "${ICONSET}"
# 1024 源图占 icon_512@2x.png 这个槽位。
"${ICON_GEN}" "${ICONSET}/icon_512@2x.png" >/dev/null

# 用 sips 缩出其余 9 个标准尺寸。
declare -a SIZES=(
  "icon_16x16.png:16"
  "icon_16x16@2x.png:32"
  "icon_32x32.png:32"
  "icon_32x32@2x.png:64"
  "icon_128x128.png:128"
  "icon_128x128@2x.png:256"
  "icon_256x256.png:256"
  "icon_256x256@2x.png:512"
  "icon_512x512.png:512"
)
for entry in "${SIZES[@]}"; do
  name="${entry%%:*}"; px="${entry##*:}"
  sips -z "$px" "$px" "${ICONSET}/icon_512@2x.png" --out "${ICONSET}/${name}" >/dev/null
done

iconutil -c icns "${ICONSET}" -o "${RES_DIR}/AppIcon.icns"
rm -rf "$(dirname "${ICON_GEN}")" "$(dirname "${ICONSET}")"

echo "==> 3/3 写入 Info.plist / PkgInfo..."
cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticTermination</key><true/>
  <key>NSSupportsSuddenTermination</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "${APP_DIR}/Contents/PkgInfo"

echo "==> 完成：${APP_DIR}"
echo "双击运行，或执行： open '${APP_DIR}'"
