# OTPBar 图标

标记由计时环与钥匙孔组成，菜单栏与应用图标使用同一视觉标记。

## 菜单栏标记

先用 ImageGen 生成概念图，再整理成便于缩放和维护的单色 SVG。

- `otpbar.svg`：图标主稿，透明背景。
- `otpbar.png`：由主稿导出的 1024 × 1024 透明 PNG。
- `otpbar-template.png`、`otpbar-template@2x.png`：22 × 22 与 44 × 44 菜单栏资源。

接入 AppKit 时将菜单栏图像标记为模板图像（`NSImage.isTemplate = true`），由系统按外观和选中状态着色。

使用 librsvg 重新导出：

```sh
rsvg-convert -w 1024 -h 1024 otpbar.svg -o otpbar.png
rsvg-convert -w 22 -h 22 otpbar.svg -o otpbar-template.png
rsvg-convert -w 44 -h 44 otpbar.svg -o otpbar-template@2x.png
```

修改主稿后重新导出 PNG，不单独修改派生图片。

## 应用图标

- `otpbar-app.png`：ImageGen 生成的应用图标源图，深蓝圆角底板、青绿计时环与暖白钥匙孔，底板之外透明。
- `OTPBar.icns`：从源图缩放并封装的 macOS 图标资源，包含 16、32、128、256、512 点的标准及 Retina 图像。

此版本保留生图的材质层次，应用包可使用 `.icns`，菜单栏继续使用单色模板资源。

当前仅交付图标资源，应用功能仍以初版 Issue 的验收状态为准。
