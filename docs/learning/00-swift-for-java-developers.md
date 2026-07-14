# Swift / SwiftUI 核心概念对照(给 Java 开发者)

> 以 Java 为参照系,快速建立 Swift 心智模型。只讲本项目会用到的核心,随开发补充。

## 一、类型系统

| Swift | 说明 | Java 类比 |
|---|---|---|
| `struct` | **值类型**,赋值/传参是拷贝;Swift 里模型、SwiftUI View 大量用它 | 没有直接对应;近似 `record` 但可变、可带方法 |
| `class` | **引用类型**,有身份、可继承、走 ARC 引用计数 | 普通 `class` |
| `enum` | 枚举,可带原始值(`String`)、可带关联值(比枚举强大得多) | `enum`,但更接近 sealed class |
| `protocol` | 接口契约,可被 struct/class/enum 遵循 | `interface` |

**关键差异**:Swift 优先用 `struct`(值语义)。`WidgetInstance`、`FocusRecord` 都是 struct —— 拷贝安全、无共享可变状态。需要"唯一身份 + 被观察"时才用 `class`(如各种 Store)。

## 二、Optional(可选值)—— 告别 NPE

```swift
var name: String?          // 可能有值,可能是 nil
let n = name ?? "默认"      // ?? 类似 Java Optional.orElse
if let n = name { ... }     // 解包:有值才进入
name?.count                 // 可选链:nil 则整个表达式为 nil
```

`String?` 编译器强制你处理 nil,等于把 `Optional<T>` 做进了语法。比 Java 的 `Optional<T>` 更彻底 —— 非可选类型**保证不为 nil**。

## 三、属性与"可观察"(SwiftUI 数据流核心)

| 标注 | 含义 | Java 类比 |
|---|---|---|
| `ObservableObject` | 可被 SwiftUI 观察的引用类型 | 带监听器的 Bean |
| `@Published` | 该属性一变,自动通知所有观察者 | 触发 PropertyChange 事件 |
| `@StateObject` | 视图**创建并持有**一个 ObservableObject | 组件内 new 一个并持有 |
| `@ObservedObject` | 视图**引用外部传入**的 ObservableObject | 注入的依赖 |
| `@EnvironmentObject` | 从环境**隐式注入**(跨层级共享) | 类似上下文/DI 容器取 Bean |
| `@State` | 视图私有的简单可变状态 | 组件内部字段 |

本项目:`WidgetStore` / `FocusStore` 是 `ObservableObject`,属性用 `@Published`;视图用 `@ObservedObject`/`@EnvironmentObject` 订阅,数据一变 UI 自动重绘 —— 不用手动刷新。

## 四、闭包(Closure)

```swift
panel.onFrameChanged = { frame in store.updateFrame(id: id, frame: frame) }
```

就是 lambda。`{ 参数 in 语句 }` 的写法。`[weak self]` 是**捕获列表**,避免闭包强引用 self 造成循环引用(见下)。

## 五、内存管理:ARC ≠ GC

Swift 用 **ARC(自动引用计数)**,不是 JVM 的可达性垃圾回收。编译期插入 retain/release。

- 两个对象互相强引用 → **循环引用**,永不释放(内存泄漏)。
- 解法:一方用 `weak`(弱引用,类比 `WeakReference`)。闭包里常见 `[weak self]`。

本项目 `WindowManager`、`WidgetPanel` 的闭包都用 `[weak self]` 防泄漏。

## 六、错误处理

```swift
func load() throws { ... }      // 声明可抛错,类比 throws
try? something()                // 出错则返回 nil,不抛(本项目持久化大量用它)
do { try f() } catch { ... }    // try/catch
```

`try?` 很实用:"尽力而为,失败就算了"。如读取不存在的 json → 返回 nil,不崩。

## 七、工程与惯例

| Swift | Java |
|---|---|
| `Package.swift` | `pom.xml` / `build.gradle` |
| `swift build` | `mvn compile` |
| `import SwiftUI` | `import` 包 |
| 命名:类型 `UpperCamel`,变量/函数 `lowerCamel` | 基本一致 |
| 没有 `;` 行尾 | 需要 `;` |
| `func` 定义函数 | `方法` |

## 八、SwiftUI 一句话心智

**声明式 UI**:你描述"界面在某状态下长什么样",状态一变,框架自动算出差异并重绘。类比:不是命令式地 `label.setText(...)`,而是 `Text(state.value)` —— state 变,Text 自动更新。和 React 是一个思路。
