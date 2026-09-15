# 开发环境

OTPBar 的需求与技术选择见 [初版 Issue](https://github.com/Erugihs/otpbar/issues/1)。

## 工具链

安装与当前 macOS 兼容的完整 Xcode。版本对应关系以 [Apple 官方兼容表](https://developer.apple.com/xcode/system-requirements) 为准；App Store 提示系统版本不足时，可以使用其提供的上一版兼容版本。

首次启动 Xcode，完成许可与必要组件安装。只开发 macOS 应用时，使用 macOS 平台组件即可。

在终端检查：

```sh
xcodebuild -version
xcrun swift --version
xcrun --sdk macosx --show-sdk-version
```

如果系统仍选中 Command Line Tools，可以在当前终端会话中指定完整 Xcode，无需修改全局配置：

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

若 Xcode 安装在其他位置，相应调整路径。此变量只影响当前会话及其子进程。

## 本地自用

本机开发和运行不需要付费 Apple Developer Program。应用可使用本地临时签名（ad hoc）；发布到 App Store、Developer ID 签名和公证属于另一套分发流程。

## 本机记录

工具版本、安装状态与本机验证结果放在已忽略的 `docs/local/`。真实 `.2fas` 备份和密钥不入仓。
