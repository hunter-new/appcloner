# App 分身（AppCloner）

图形界面的 macOS 多开工具，可用于微信、QQ、企业微信等任意 App。支持 **Apple Silicon（M1–M4）和 Intel**（Universal 二进制），系统要求 macOS 13 及以上。

## 编译

```bash
xcode-select --install      # 只装一次，不需要完整 Xcode
cd AppCloner
chmod +x build.sh && ./build.sh
open AppCloner.app
```

## 使用

1. 把 App 拖进窗口（或点「选择 App…」），例如 `/Applications/WeChat.app`
2. 填好分身名称，点「生成分身」
3. 在列表里点「启动」。分身放在 `~/Applications/AppClones/`，也可以从启动台或 Spotlight 打开
4. 原版 App 更新后，列表里会提示，点「重建」就行。重建不会丢数据，因为 Bundle ID 不变

## 原理

复制原版 → 把 Bundle ID 改成 `原ID.cloneN` → 清除隔离属性 → ad-hoc 重新签名（Apple Silicon 必须做这一步）→ 注册到 LaunchServices。
系统会把分身当成另一个独立的 App，所以登录状态和聊天记录各自独立。

## 多语言

界面支持 English、简体中文、繁體中文、日本語，自动跟随系统语言（其他语言显示英文）。
也可以在「系统设置 → 通用 → 语言与地区 → App」里单独给 AppCloner 指定语言。

翻译文件在 `Resources/<语言>.lproj/Localizable.strings`。新增语言：复制 `en.lproj` 改名（如 `ko.lproj`）并翻译，再把语言代码加到 `build.sh` 里的 `CFBundleLocalizations`。

## 打包发布（dmg + Homebrew）

```bash
GITHUB_REPO=你的用户名/appcloner ./package.sh
```

会生成 `dist/AppCloner-<版本>.dmg` 和 `dist/appcloner.rb`（Cask，sha256 已自动填好）。
正式发布建议同时设置 `DEVELOPER_ID` 和 `NOTARY_PROFILE` 做签名和公证，用法见 `package.sh` 开头注释。

Cask 放到自己的 tap 仓库 `github.com/<你>/homebrew-tap` 的 `Casks/` 目录，用户安装：

```bash
brew install --cask <你>/tap/appcloner
```

## 常见问题

- **提示 Operation not permitted**：打开「系统设置 → 隐私与安全性 → App 管理」，允许 AppCloner。
- **分身打不开或闪退**：勾选或取消「保留权限声明」后重建。
- **分身需要重新授权**：摄像头、麦克风、通知等权限要在分身里重新允许一次，这是正常的。
- **Electron 类 App（Claude、Slack、VS Code 等）**：这类 App 的数据目录按名称而不是 Bundle ID 区分，分身会和原版抢同一份数据而闪退。现在会自动加一个启动脚本，用 `--user-data-dir` 把分身数据放到 `~/Library/Application Support/<分身 Bundle ID>`。旧分身点「重建」即可生效（分身需要重新登录）。
- **原版和分身图标一样**：可以在 Dock 里右键查看名字来区分。
- 微信等 App 的用户协议可能限制多开，请自行斟酌。
