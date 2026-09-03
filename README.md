# NoteWrite · 笔记与待办

一款为 **iOS 26** 打造的 SwiftUI 应用：笔记记录 + 待办事项（提醒 / 长期任务 / 重复 / 优先级），界面充满动效。使用 **GitHub Actions 云端编译**，无需 Mac 也能产出 IPA。

![Build](https://github.com/OWNER/NoteWrite/actions/workflows/build.yml/badge.svg)

## ✨ 功能

### 待办
- **提醒**：本地推送通知，支持「截止时 / 提前 1 小时」快捷预设
- **重复**：每天 / 每周 / 每两周 / 每月 / 每年 / 自定义间隔 N 天 / 每周指定日（多选），完成一次自动滚动到下一次
- **长期任务**：子任务拆解 + 自动进度环 + 进度条
- **优先级**：无 / 低 / 中 / 高 / 紧急（五档颜色）
- 分组：置顶 / 已逾期 / 今天 / 即将到来 / 随时 / 已完成
- 标签、备注、置顶、四种排序、搜索、左滑操作、清除已完成

### 笔记
- 标题 + 正文 + **笔记内清单**（带进度）
- 文件夹、彩色标签（8 色）、置顶、标签
- 网格 / 列表双布局切换、三种排序、全文搜索、分享导出

### 统计
- 连续完成天数（火焰 🔥）、最长纪录、累计次数
- 最近 7 天柱状图（Swift Charts 动画生长）
- **18 周完成热力图**（逐列弹入动画，GitHub 风格）
- 今日完成 / 进行中 / 笔记数 / 完成率磁贴

### 其他
- 今天仪表盘：流动网格渐变英雄卡、今日进度环、逾期抖动提醒、快捷新建
- 设置：深浅色模式、7 种主题色、触感反馈开关、彩带特效开关、数据导出、清理

## 🎬 动效清单
启动过渡动画 · 自定义毛玻璃底栏（匹配几何指示器 + 图标弹跳）· 页面交叉淡入 · **MeshGradient 流动渐变** · 完成待办 **彩带粒子**（Canvas 物理）· 勾选框弹性缩放 · 删除线过渡 · 进度环弹簧 · 优先级/文件夹药丸 matchedGeometry · 热力图逐列弹入 · 柱状图生长 · 数字滚动（numericText）· 逾期卡抖动 · 符号脉冲/弹跳 · 全局触感反馈 · 120Hz ProMotion

## 🔨 构建（GitHub Actions）

推送到 `main` 即自动触发 [.github/workflows/build.yml](.github/workflows/build.yml)：

1. `macos-26` 运行器 + 最新稳定版 Xcode 26
2. `brew install xcodegen` 后由 `project.yml` 生成工程
3. `xcodebuild` 以免签名方式编译 Release（iOS 设备）
4. 打包为 `NoteWrite-unsigned.ipa` 并上传 Artifact；打 `v*` tag 时附加到 Release

## 📦 安装 IPA

构建产物是**未签名** IPA，按需选择：

| 方式 | 说明 |
| --- | --- |
| **AltStore / SideStore** | 免费 Apple ID 重签名安装，7 天续签 |
| **Sideloadly** | 电脑端用 Apple ID 重签名安装 |
| **TrollStore** | 支持的系统版本上免签安装 |
| **企业/开发者证书** | 用 codesign 重签后分发 |

> 免费个人 Apple ID 每个最多 3 个应用、7 天有效期；付费账号 1 年。

## 🗂 结构

```
NoteWrite/
├── project.yml              # XcodeGen 工程定义
├── gen_icon.py              # 生成 1024 图标
├── .github/workflows/build.yml
└── NoteWrite/
    ├── App/                 # 入口 + 根视图/底栏/启动动画
    ├── Models/              # SwiftData 模型、设置、重复引擎
    ├── Services/            # 通知、触感
    └── Views/
        ├── Components/      # 彩带、网格渐变、进度环等动效组件
        ├── Dashboard/ Todos/ Notes/ Stats/ Settings/
```

## 本地开发

```bash
brew install xcodegen
xcodegen generate
open NoteWrite.xcodeproj   # Xcode 26+, iOS 26 SDK
```
