# DeskWidgets 文档中心

本项目所有技术方案、学习笔记、决策记录统一放在这里。

## 目录

### 📐 design/ — 技术方案设计
组件与架构的设计文档,动手前先写、动手后随代码更新。
- [00-architecture.md](design/00-architecture.md) — 整体架构总览
- [01-focus-widget.md](design/01-focus-widget.md) — 专注组件「守苗」设计

### 📚 learning/ — 学习文档
面向资深 Java 开发者的 Swift/SwiftUI 学习笔记,以 Java 类比为主线。
- [00-swift-for-java-developers.md](learning/00-swift-for-java-developers.md) — Swift 核心概念对照

### 🧭 decisions/ — 技术决策记录(ADR)
记录"为什么这么选"的关键决策,轻量格式:背景 / 决策 / 理由 / 影响。
- [0001-unified-json-coders.md](decisions/0001-unified-json-coders.md) — 统一 JSON 编解码约定

## 归置约定

| 类型 | 放这里 | 命名 |
|---|---|---|
| 某个组件/架构的设计方案 | `design/` | `NN-主题.md` |
| Swift/SwiftUI 学习笔记 | `learning/` | `NN-主题.md` |
| 影响长远的技术选择 | `decisions/` | `NNNN-主题.md`(顺序编号,不复用) |

> 后续所有技术方案、学习文档都往这三个目录里放,不要散落在项目根目录。
