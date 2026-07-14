#!/usr/bin/env bash
# 把 SwiftPM 产物组装成 .app bundle —— 无需 Xcode 即可运行验证。
# GUI App(菜单栏图标/窗口激活)需要在 .app bundle 结构内才能正常工作。
set -euo pipefail

CONFIG="${1:-debug}"          # debug(默认,快) | release
APP_NAME="DeskWidgets"
BUILD_DIR=".build/${CONFIG}"
APP="${APP_NAME}.app"

echo "==> swift build -c ${CONFIG}"
swift build -c "${CONFIG}"

echo "==> assembling ${APP}"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BUILD_DIR}/${APP_NAME}" "${APP}/Contents/MacOS/${APP_NAME}"
cp Info.plist "${APP}/Contents/Info.plist"

echo "==> done: ${APP}"
echo ""
echo "运行方式:"
echo "  open ${APP}                              # 正常启动(菜单栏出现图标)"
echo "  ./${APP}/Contents/MacOS/${APP_NAME}      # 前台运行,可看到日志/崩溃信息"
