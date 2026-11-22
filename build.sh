#!/bin/bash
# 编译 AppCloner.app（Universal：同时支持 Apple Silicon M 系列 和 Intel）
# 只需要 Xcode 命令行工具：xcode-select --install
set -euo pipefail
cd "$(dirname "$0")"

APP="AppCloner.app"
BIN="$APP/Contents/MacOS/AppCloner"
MIN_OS="13.0"

if ! command -v swiftc >/dev/null; then
  echo "❌ 未找到 swiftc，请先运行：xcode-select --install"
  exit 1
fi

rm -rf "$APP" build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build

echo "▶ 编译 arm64（Apple Silicon）…"
swiftc -parse-as-library -O -target "arm64-apple-macos$MIN_OS" -o build/AppCloner-arm64 AppCloner.swift

echo "▶ 编译 x86_64（Intel）…"
if swiftc -parse-as-library -O -target "x86_64-apple-macos$MIN_OS" -o build/AppCloner-x86_64 AppCloner.swift; then
  echo "▶ 合并为 Universal 二进制…"
  lipo -create build/AppCloner-arm64 build/AppCloner-x86_64 -output "$BIN"
else
  echo "⚠️ x86_64 编译失败，只生成本机架构版本"
  swiftc -parse-as-library -O -target "$(uname -m)-apple-macos$MIN_OS" -o "$BIN" AppCloner.swift
fi

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>AppCloner</string>
  <key>CFBundleIdentifier</key><string>local.appcloner</string>
  <key>CFBundleName</key><string>AppCloner</string>
  <key>CFBundleDisplayName</key><string>AppCloner</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key>
  <array><string>en</string><string>zh-Hans</string><string>zh-Hant</string><string>ja</string></array>
  <key>LSHasLocalizedDisplayName</key><true/>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF

# 多语言资源：英文 / 简体中文 / 繁體中文 / 日本語（跟随系统语言）
for lproj in Resources/*.lproj; do
  plutil -lint "$lproj"/*.strings >/dev/null
  ditto "$lproj" "$APP/Contents/Resources/$(basename "$lproj")"
done

# Apple Silicon 要求 arm64 代码必须签名，这里用 ad-hoc 签名
codesign --force --sign - "$APP"
rm -rf build

echo "✅ 完成：$(pwd)/$APP"
lipo -info "$BIN"
echo "可拖到「应用程序」文件夹，或直接运行：open \"$APP\""
