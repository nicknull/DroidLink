# DroidLink

Android 设备桌面管理工具，通过 ADB 在电脑端管理 Android 设备的文件、相册、应用等。

## 功能

- **文件管理** — 浏览设备文件系统，支持上传/下载/删除/新建文件夹
- **相册视频** — 浏览设备照片和视频，支持拖拽框选、批量导出、视频预览播放
- **应用管理** — 查看已安装应用，支持安装/卸载/导出 APK
- **截图录屏** — 设备截图和屏幕录制

## 平台支持

| 平台 | 状态 |
|------|------|
| macOS | 已测试 |
| Windows | 尚未测试，欢迎提交 Bug 反馈和测试报告 |

如果你在 Windows 上运行遇到问题，欢迎提 [Issue](https://github.com/nicknull/DroidLink/issues)。

## 依赖

运行前需安装以下工具：

| 工具 | 必需 | 说明 |
|------|------|------|
| ADB | 是 | Android 调试桥，核心通信工具 |
| scrcpy | 否 | 投屏与录屏功能依赖 |

macOS 可通过 Homebrew 安装：

```bash
brew install android-platform-tools
brew install scrcpy
```

## 构建

```bash
# 安装 Flutter（需要 3.27+）
fvm install 3.27.0
fvm use 3.27.0

# 获取依赖
fvm flutter pub get

# 运行（macOS）
fvm flutter run -d macos

# 运行（Windows）
fvm flutter run -d windows
```

## 技术栈

- [Flutter](https://flutter.dev/) 3.27
- [media_kit](https://pub.dev/packages/media_kit) — 视频播放
- [provider](https://pub.dev/packages/provider) — 状态管理
- ADB — Android 设备通信

## 反馈

欢迎提交 [Issue](https://github.com/nicknull/DroidLink/issues) 和 [Pull Request](https://github.com/nicknull/DroidLink/pulls)。

## 开源协议

[MIT License](LICENSE)
