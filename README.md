# OTPBar

<img src="assets/icon/otpbar-app.png" width="128" alt="OTPBar 应用图标">

面向 macOS 的菜单栏动态码工具项目，让用户在 Mac 上查看、复制手机认证器中的动态码。

## 本机运行

需要 macOS 14 或更新版本，以及 Swift 6 工具链。

```sh
bash scripts/build-app.sh
open .build/app/OTPBar.app
```

可将生成的 `OTPBar.app` 放入「应用程序」。构建使用本地 ad hoc 签名，自用无需付费开发者账号；这不是经过 Apple 公证的分发版本。

- 左键点击菜单栏图标查看验证码，点击账号复制当前有效码。
- 右键点击图标打开设置或退出；关闭设置窗口后仍驻留菜单栏。
- 在设置中导入手机 2FAS 的 `.2fas` 备份。支持密码保护的备份，重复项自动跳过。
- 编辑和删除仅影响本机。导入完成后不会与手机持续同步；新增手机账号需要重新导出并导入。
- 本地数据保存在 macOS 钥匙串；不要将真实备份或密钥提交到仓库。

## 项目入口

- [初版需求、技术选择与验收进度](https://github.com/Erugihs/otpbar/issues/1)
- [后续事项：CLI 取码](https://github.com/Erugihs/otpbar/issues/2)
- [开发环境](docs/development.md)
- [图标资源](assets/icon/)

需求、设计决定与进度以对应 Issue 为准。
