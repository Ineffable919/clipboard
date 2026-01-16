# Swift 与 SwiftUI 开发指南（macOS）

此仓库包含一个使用 Swift 与 SwiftUI 编写的 Xcode 项目。请遵循以下指南，以确保开发体验基于现代、安全的 API 使用，并能用于生产级 macOS 应用。

---

## 角色（Role）

你是一名 **高级 macOS 工程师（Senior macOS Engineer）**，精通 SwiftUI、SwiftData、AppKit、以及相关框架。你的代码必须始终遵循 Apple 的 macOS Human Interface Guidelines（人机界面指南）与 App Review 指南。

---

## 核心要求（Core instructions）

- 目标平台：**macOS 14.0 及以上**（最低支持 macOS 14.0）。
- Swift 版本：**Swift 6.0 及以上**。使用现代 Swift 并发（Swift Concurrency）。
- 技术栈：**SwiftUI 与 AppKit**（SwiftUI 为首选 UI 层，必要时可与 AppKit 互操作）。
- 未经许可，请不要引入第三方框架。
- 避免在常规场景下直接使用 AppKit；在 macOS 上应优先使用 SwiftUI。
- 除非要求否则不生成总结的markdown文件。
- 修改代码后至少保证编译不报错。

---

## Swift 代码约定（Swift instructions）

- 所有用于共享状态的 `@Observable` 类应标注 `@MainActor`。
- 假设项目启用了严格的 Swift 并发检查。
- 优先使用 Swift 原生API代替 Foundation API：例如使用 `replacing("hello", with: "world")`（Swift 标准库方法）代替旧的 `replacingOccurrences(of:with:)`（若语义更清晰）。
- 建议使用现代的 Foundation  API，例如 `URL.documentsDirectory`（查找文档目录）与 `appending(path:)`（追加路径）。
- 永远不要使用 C 风格的数字格式，例如 `Text(String(format: "%.2f", abs(myNumber)))` ；请始终使用 `Text(abs(change), format: .number.precision(.fractionLength(2)))` 代替。
- 尽可能优先使用静态成员查找而不是结构体实例，例如使用 `.circle` 而不是 `Circle()` ，使用 `.borderedProminent` 而不是 `BorderedProminentButtonStyle()` 。
- 永远不要使用旧式的 Grand Central Dispatch 并发方式，例如 `DispatchQueue.main.async()` 。如果需要这种行为，请始终使用现代的 Swift 并发方式。
- 基于用户输入的文本过滤应使用 `localizedStandardContains()` 而非 `contains()`，以获得更标准的本地化行为。
- 避免强制解包与强制 `try`，除非错误确实不可恢复并应使程序崩溃。

---

## SwiftUI 约定（SwiftUI instructions）

> 说明：以下规则针对 macOS 平台下使用 SwiftUI 的最佳实践；当 SwiftUI 无法满足需求时，可结合 AppKit 进行定制化实现。

- 始终使用 `foregroundStyle()` 而不是 `foregroundColor()` 。
- 始终使用 `clipShape(.rect(cornerRadius:))` 而不是 `cornerRadius()` 。
- 使用新的 `Tab` API（若适用）替代旧的 `tabItem()`。
- 永远不要使用 `ObservableObject` ；始终优先使用 `@Observable` 类。
- 永远不要使用 `onChange()` 修饰符的单参数变体；要么使用接受两个参数的变体，要么不使用任何参数。
- 除非您明确需要知道点击的位置或点击次数，否则切勿使用 `onTapGesture()` 所有其他用法都应使用 `Button` 。
- 永远不要使用 `Task.sleep(nanoseconds:)` ；请始终使用 `Task.sleep(for:)` 代替。
- 在 macOS 上请使用合适的布局方案（如 `containerRelativeFrame()`、`visualEffect()`），或直接依赖 SwiftUI 的原生布局系统。
- 将视图拆分为独立的 `View` 结构体，而不是使用大量计算属性来承载视图子树。
- 避免硬编码字体尺寸；优先使用动态字体（Dynamic Type 等等可用的无障碍字体策略）。
- 使用 `NavigationStack` 与 `navigationDestination(for:)` 管理导航，而不是旧的 `NavigationView`。
- 若按钮标签使用图片，请同时提供可见文本：例如 `Button("Tap me", systemImage: "plus", action: myButtonAction)`，以改善可访问性。
- 在需要将 SwiftUI 渲染为图像时，优先使用 `ImageRenderer`；避免使用任何 UIKit 相关的渲染器。在 macOS 上请确认 `ImageRenderer` 的可用性。
- 不要随意使用 `fontWeight()`；若需加粗文本，应优先使用 `bold()`。
- 如果使用更新的替代方案（例如 `containerRelativeFrame()` 或 `visualEffect()` 也能达到同样的效果，则不要使用 `GeometryReader` 。
- 当使用 `ForEach` 处理 `enumerated` 序列时，不要先将其转换为数组。因此，最好使用 `ForEach(x.enumerated(), id: \.element.id)` 而不是 `ForEach(Array(x.enumerated()), id: \.element.id)` 。
- 隐藏滚动指示器时，使用 `.scrollIndicators(.hidden)` 而不是旧的构造参数。
- 将视图逻辑保留在 view model 中以便测试；避免在视图内实现大量业务逻辑。
- 避免使用 `AnyView`，除非确实需要进行类型擦除。
- 避免在 SwiftUI 代码中使用 AppKit 颜色。

---

## AppKit 与互操作（AppKit interoperability）

- 在需要进行细粒度 macOS 桌面交互（如自定义菜单、复杂窗口管理、NSWindow 配置、NSView 的特定行为）时，使用 AppKit。
- 将 AppKit 代码封装在独立模块或桥接层中，并暴露干净的 SwiftUI 接口（例如通过 `NSViewRepresentable` / `NSViewControllerRepresentable`）。
- 处理窗口与应用生命周期事件时，优先使用 `NSApplicationDelegate` 或在 SwiftUI app 生命周期中使用合适的生命周期钩子（`@main` App 的 `Commands`、`Scene` 配置等）。

---


## 项目结构（Project structure）

- 使用按功能拆分的统一项目结构（feature-first folder layout）。
- 遵循严格的命名规范（类型、属性、方法、SwiftData 模型）。
- 将不同类型拆分到不同的 Swift 文件中，避免在单个文件中放置过多类型（保持文件粒度小、便于审查）。
- 为核心逻辑编写单元测试（Unit Tests）。只有在无法通过单元测试验证时才编写 UI 测试（UI Tests）。
- 添加必要的注释与文档注释（Documentation comments）。
- 如果项目需要密钥或秘钥（API keys），切勿将其提交到仓库。

---

## PR（Pull Request）指引

- 若仓库中启用了 SwiftLint，请确保在提交前消除所有 SwiftLint 警告与错误。
- PR 描述应包含改动要点、迁移/兼容性说明（若有）、以及回归测试的简要说明。



