#!/bin/bash
# 打包 AppCloner.dmg，并生成 Homebrew Cask（dist/appcloner.rb）
#
# 用法：
#   ./package.sh                                   # 未签名 dmg（自己用 / 测试）
#   GITHUB_REPO=you/appcloner ./package.sh         # Cask 里的下载地址指向你的 GitHub Releases
#
# 可选：正式发布时签名 + 公证（需要 Apple Developer 账号）
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE=appcloner-notary \
#   GITHUB_REPO=you/appcloner ./package.sh
#   NOTARY_PROFILE 先用这条命令建一次：
#   xcrun notarytool store-credentials appcloner-notary --apple-id you@example.com --team-id TEAMID
set -euo pipefail
cd "$(dirname "$0")"

APP="AppCloner.app"
GITHUB_REPO="${GITHUB_REPO:-OWNER/appcloner}"

# 1. 编译（复用 build.sh）
bash ./build.sh

VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")}"
DMG_NAME="AppCloner-$VERSION.dmg"
mkdir -p dist
DMG="dist/$DMG_NAME"

# 2. 可选：Developer ID 签名（Hardened Runtime + 时间戳，公证必需）
if [[ -n "${DEVELOPER_ID:-}" ]]; then
  echo "▶ Developer ID 签名 …"
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
else
  echo "⚠️ 未设置 DEVELOPER_ID，dmg 内为 ad-hoc 签名：用户首次打开需右键 →「打开」，或在「隐私与安全性」里允许"
fi

# 3. 制作 dmg（带「应用程序」快捷方式，拖进去即可安装）
echo "▶ 制作 $DMG_NAME …"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/$APP"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "App 分身 $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null

# 4. 可选：签名 dmg + 公证 + staple
if [[ -n "${DEVELOPER_ID:-}" ]]; then
  codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "▶ 提交公证（通常几分钟）…"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
  else
    echo "⚠️ 未设置 NOTARY_PROFILE，跳过公证"
  fi
fi

# 5. 生成 Homebrew Cask（sha256 必须在公证 / staple 之后计算）
SHA256="$(shasum -a 256 "$DMG" | awk '{print $1}')"
cat > dist/appcloner.rb <<CASK
cask "appcloner" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/$GITHUB_REPO/releases/download/v#{version}/AppCloner-#{version}.dmg"
  name "AppCloner"
  name "App 分身"
  desc "Create independent copies of apps to run multiple instances side by side"
  homepage "https://github.com/$GITHUB_REPO"

  depends_on macos: ">= :ventura"

  app "AppCloner.app"

  # 不删除 ~/Applications/AppClones：里面是用户生成的分身
  zap trash: [
    "~/Library/Preferences/local.appcloner.plist",
    "~/Library/Saved Application State/local.appcloner.savedState",
  ]

  caveats <<~EOS
    Clones are created in ~/Applications/AppClones and are not removed on uninstall.
  EOS
end
CASK

echo ""
echo "✅ dmg：  $(pwd)/$DMG"
echo "✅ Cask： $(pwd)/dist/appcloner.rb"
echo "   sha256 $SHA256"
echo ""
echo "发布步骤："
echo "  1. 在 https://github.com/$GITHUB_REPO 建 Release，tag 为 v$VERSION，上传 $DMG_NAME"
echo "  2. 把 dist/appcloner.rb 放到你的 tap 仓库（github.com/<你>/homebrew-tap）的 Casks/ 目录并推送"
echo "  3. 用户安装：brew install --cask <你>/tap/appcloner"
