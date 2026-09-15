# 开发环境

OTPBar 的需求与技术选择见 [初版 Issue](https://github.com/Erugihs/otpbar/issues/1)。

## 工具链

核心模块使用 Swift Package Manager，Swift 6 与 macOS SDK 即可编译和测试；可先使用 Command Line Tools，无需等待完整 Xcode。

需要 Xcode 的调试与界面工具时，安装与当前 macOS 兼容的版本。版本对应关系以 [Apple 官方兼容表](https://developer.apple.com/xcode/system-requirements) 为准；App Store 提示系统版本不足时，可以使用其提供的上一版兼容版本。

首次启动 Xcode，完成许可与必要组件安装。只开发 macOS 应用时，使用 macOS 平台组件即可。

在终端检查：

```sh
xcrun swift --version
xcrun --sdk macosx --show-sdk-version
```

完整 Xcode 可额外运行 `xcodebuild -version` 检查。

如果系统仍选中 Command Line Tools，可以在当前终端会话中指定完整 Xcode，无需修改全局配置：

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

若 Xcode 安装在其他位置，相应调整路径。此变量只影响当前会话及其子进程。

## 本地自用

本机开发和运行不需要付费 Apple Developer Program。应用可使用本地临时签名（ad hoc）；发布到 App Store、Developer ID 签名和公证属于另一套分发流程。

## 构建应用

```sh
bash scripts/build-app.sh
```

生成 `.build/app/OTPBar.app`，包含菜单栏模板图标与应用图标，并执行 ad hoc 签名和签名检查。构建默认使用 Release；调试时可运行 `CONFIGURATION=debug bash scripts/build-app.sh`。

如果完整 Xcode 尚未完成首次启动配置，可临时使用已安装的 CLT，不必改变系统默认工具链：

```sh
DEVELOPER_DIR=/Library/Developer/CommandLineTools bash scripts/build-app.sh
```

## 测试

在仓库根目录运行：

```sh
swift test -Xswiftc -warnings-as-errors
```

默认使用内存存储，不访问真实验证码。应用层剪贴板测试使用独立命名的临时剪贴板，不覆盖用户系统剪贴板。测试覆盖 RFC 6238、RFC 4648、独立生成的 TOTP 参数组合、2FAS 解密、错误输入、重复导入、删除、保存失败、复制时使用最新数据和清理时保留他方写入。需要实际验证本机钥匙串时运行：

```sh
OTPBAR_KEYCHAIN_TEST=1 swift test -Xswiftc -warnings-as-errors
```

该测试创建随机名称的临时钥匙串记录，使用合成数据，结束后删除该记录。所有备份样本都位于 `Tests/OTPBarCoreTests/Fixtures/`，仅包含公开测试密钥；生成脚本使用 Node 内置的 OpenSSL 实现，与 Swift 的 CryptoKit / CommonCrypto 独立：

```sh
node scripts/generate-test-fixtures.mjs
```

修改密码、加密参数或测试向量时，不应直接改预期结果来配合 Swift 实现；应对照 [2FAS 官方格式](https://github.com/twofas/2fas-ios/blob/693a08e5c89c7c247ce1ed4612edd996bcf44fd8/TwoFAS/Protection/ExchangeFileEncryption.swift)与 [RFC 6238](https://www.rfc-editor.org/rfc/rfc6238)。实时进度和已验证范围见 Issue。

### macOS 钥匙串边界

本地 ad hoc 构建通过 `SecItem` 明确使用 macOS 的文件型钥匙串，依靠系统管理的访问控制，不启用 iCloud 同步；不保存明文 JSON 文件。文件型钥匙串不会执行 iOS 的 `kSecAttrAccessible` 属性，因此不宣称具有该属性的锁屏或设备绑定保证。修改应用签名后，系统可能再次询问访问权限。

Apple 的数据保护钥匙串需要由 provisioning profile 授权的签名权限。未来改变分发方式时再考虑迁移；两种实现及权限差异见 [Apple TN3137](https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains)。

## 本机记录

工具版本、安装状态与本机验证结果放在已忽略的 `docs/local/`。真实 `.2fas` 备份和密钥不入仓。
