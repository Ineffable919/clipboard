<p align="center">
    <div align="center"><img src=Clipboard/Resource/Assets.xcassets/AppIcon.appiconset/icon-256.png width=135  /></div>
    <h2 align="center">Clipboard</h2>
    <div align="center">一款 macOS 剪贴板管理工具，帮助您更高效地管理和使用剪贴板历史记录。
</div>
    <div align="center"><a href="https://github.com/Ineffable919/clipboard/blob/master/README_EN.md">English</a> | <strong>中文</strong></div>
</p>

<img src="temp.png">

## 下载

下载最新版本 [releases](https://github.com/Ineffable919/clipboard/releases/latest)

## 功能特性

- **实时监控剪贴板**：自动捕获并保存您复制的文本、图片和文件
- **智能分类**：按文本、图片、文件类型自动分类管理
- **历史记录**：保存您的剪贴板历史记录，方便随时查看
- **自定义设置**：支持自定义分类，设置保存历史时长等
- **快速搜索**：通过关键词快速查找历史记录
- **直观界面**：现代化的卡片式界面设计，操作简单直观，适配浅深色外观
- **快捷操作**：
  - 双击直接粘贴
  - shift + 鼠标滚动
  - 空格键预览内容
  - 支持键盘导航选择
  - 右键菜单提供更多操作选项
- **安全删除**：支持确认删除避免误操作
- **拖拽支持**：可将内容拖拽到其他应用中使用

## 系统要求

- macOS 14.0 或更高版本 （已适配macOS 26）
- 支持 Apple Silicon (arm64) 和 Intel (x86_64) 架构

## 使用方法

1. 正常复制任何内容（文本、图片或文件）
2. 打开 Clipboard 应用查看历史记录
3. 通过以下方式操作历史记录：
   - 双击项目直接粘贴
   - 单击选中后按回车键粘贴
   - 使用空格键预览内容
   - 使用左右箭头键导航选择
   - 右键点击项目打开上下文菜单进行更多操作

## 键盘快捷键

- `ESC`：关闭应用窗口
- `← →`：在历史记录间导航
- `空格`：预览选中的项目
- `↩`：粘贴选中的项目
- `Shift + ⏎`：粘贴为纯文本
- `⌘ + C`：复制选中的项目到剪贴板
- `Delete`：删除选中的项目

## FAQ

### 应用打不开?

1. 检查系统设置 -> 隐私与安全性 -> 允许以下来源程序.
2. 试试以下命令
``` sh
sudo xattr -r -d com.apple.quarantine /Applications/Clipboard.app 
sudo codesign --force --deep --sign - /Applications/Clipboard.app
```

### 应用更新后辅助权限丢失？
  - 请使用0.3.1版本，后续版本已解决该问题。


## 许可证

Creative Commons Attribution-NonCommercial 4.0 International Public License [LICENSE](LICENSE)