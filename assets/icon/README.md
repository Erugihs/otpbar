# OTPBar 图标

标记由计时环与钥匙孔组成。先用 ImageGen 生成概念图，再整理成便于缩放和维护的单色 SVG。

- `otpbar.svg`：图标主稿，透明背景。
- `otpbar.png`：由主稿导出的 1024 × 1024 透明 PNG。
- `otpbar-template.png`、`otpbar-template@2x.png`：22 × 22 与 44 × 44 菜单栏资源。

接入 AppKit 时将菜单栏图像标记为模板图像（`NSImage.isTemplate = true`），由系统按外观和选中状态着色。当前仅交付资源，菜单栏功能仍以初版 Issue 的验收状态为准。

使用 librsvg 重新导出：

```sh
rsvg-convert -w 1024 -h 1024 otpbar.svg -o otpbar.png
rsvg-convert -w 22 -h 22 otpbar.svg -o otpbar-template.png
rsvg-convert -w 44 -h 44 otpbar.svg -o otpbar-template@2x.png
```

修改主稿后重新导出 PNG，不单独修改派生图片。
