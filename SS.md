# SpaceSwap 设计文档

## 1. 核心功能点 (MVP)

| 模块 | 功能点 | 说明 |
| :--- | :--- | :--- |
| **1. 权限与引导** | **智能权限请求** | 首次启动请求相册读写权限，支持「限制访问」模式的引导。 |
| | **隐私说明** | 明确告知用户：App 仅在本地处理视频，不会上传云端。 |
| **2. 扫描与发现** | **大视频扫描** | 自动扫描相册中体积 > 50MB（可配置）的视频。 |
| | **智能排序** | 按“占用空间大小”降序排列，优先展示最占空间的视频。 |
| | **iCloud 识别** | 标记哪些视频仅在 iCloud 中（需要下载才能压缩）。 |
| **3. 压缩与处理** | **空间预估** | 展示“原始大小” vs “预估压缩后大小”（例如：1GB → 200MB）。 |
| | **一键压缩** | 使用 H.265 (HEVC) 编码，在保持高画质的同时大幅减少体积。 |
| | **后台处理** | 支持 App 切到后台时继续压缩（利用 `BackgroundTasks`）。 |
| **4. 替换与清理** | **安全交换 (Swap)** | 流程：保存压缩后的新视频 → 验证成功 → 弹窗请求删除原视频。 |
| | **回收站机制** | 原视频删除后进入系统“最近删除”，给予用户后悔药。 |
| **5. 仪表盘** | **成果展示** | 顶部显示“已为您节省 XX GB 空间”。 |

## 2. 技术架构设计

采用 **MVVM (Model-View-ViewModel)** 架构。

### 2.1 目录结构规划
```text
SpaceSwap/
├── App/
│   ├── SpaceSwapApp.swift      # 入口
│   └── DIContainer.swift       # 依赖注入容器 (可选)
├── Features/
│   ├── Home/                   # 首页（仪表盘 + 列表）
│   ├── Scanner/                # 扫描页
│   └── Compressor/             # 压缩详情与进度页
├── Services/
│   ├── PhotoLibraryService.swift  # 负责 PHPhotoLibrary 交互 (查、删、存)
│   ├── CompressionService.swift   # 负责 AVAssetExportSession (压缩核心)
│   └── PermissionService.swift    # 负责 权限请求与状态监听
├── Models/
│   ├── PhotoAsset.swift        # 视频对象封装 (PHAsset + 大小 + 时长)
│   └── CompressionConfig.swift # 压缩配置 (画质、格式)
└── Shared/
    ├── Components/             # 通用 UI 组件 (如 ProgressButton)
    └── Extensions/             # Helper 扩展
```

### 2.2 关键技术方案

*   **视频扫描 (Scanner)**:
    *   **策略**: 由于 `PHAsset` 不支持 `fileSize` 过滤，采用 **分级扫描** 策略。
        1.  **快速筛选**: 使用 `PHFetchOptions` 的 `predicate` 过滤 `mediaType = .video` 和 `duration` (如 > 60秒)。
        2.  **异步获取大小**: 对初筛结果，使用 `PHAssetResource` 批量/懒加载获取文件大小。
    *   **性能优化**: 扫描过程中即时更新 UI，不阻塞主线程。
*   **视频压缩 (Compressor)**:
    *   **核心**: 使用 `AVAssetExportSession`。
    *   **自定义参数**: MVP 阶段支持 **预设选择** (而非任意码率)。
        *   **画质**: 高 (Highest)、中 (Medium)、低 (Low)。
        *   **格式**: H.265 (HEVC, 推荐)、H.264 (兼容性好)。
        *   **分辨率**: 保持原样、降级到 1080p/720p。
    *   **iCloud**: 处理 `isNetworkAccessAllowed = true` 及下载进度。
*   **安全交换 (Swap)**:
    1.  压缩并写入新视频 (得到 new localIdentifier)。
    2.  确认写入成功。
    3.  请求删除旧视频 (`PHAssetChangeRequest.deleteAssets`)。

## 3. UI/UX 交互设计 (Update)

### 3.0 导航架构 (Navigation)
*   **平台**: 适配 iOS 18 (用户提到的 iOS 26 为未来设定，实际对应最新原生系统风格)。
*   **Tab 结构**: 底部 TabBar，采用 **"液态玻璃" (Liquid/Glassmorphism)** 风格 —— 半透明磨砂 + 悬浮感。
*   **Tabs**:
    1.  **首页 (Home)**: 扫描、核心仪表盘、视频列表。
    2.  **历史 (History)**: 压缩记录、节省统计、回收站入口。
    3.  **设置 (Settings)**: 偏好配置、策略管理。

### 3.1 首页 (Home) - "准备扫描"
*   **状态**: 默认空状态/未扫描状态。
*   **核心动作**: 巨大的 **"开始扫描" (Scan)** 按钮。
*   **配置入口 (Scan Options)**: 扫描按钮旁的“设置/滤镜”图标，点击弹出 Sheet：
    *   **大小阈值**: 全部 / >50MB / >200MB / >500MB (默认: 全部)。
    *   **时长阈值**: 全部 / >1分钟 / >3分钟 (默认: 全部)。
    *   **时间范围**: 全部 / 最近一周 / 最近一月 / 最近一年 (默认: 全部)。
*   **权限引导**: 若无权限，显示友好的“去设置开启”引导页。

### 3.2 扫描结果页 (Results)
*   **布局**: 垂直列表。
*   **排序栏**: 支持按 **大小** (默认)、**时长**、**日期** 排序。
*   **列表项**: 缩略图 | 原始大小 (高亮) | 时长 | *iCloud图标(如需下载)*。
*   **操作**: 点击进入详情，或左滑“忽略”。

### 3.3 压缩详情页 (Detail)
*   **动画 (Cool Animation)**: **"Space Black Hole" (空间黑洞)** 效果。
    *   **视觉**: 屏幕中央发光的旋转核心，周围粒子流（代表原始数据）被吸入，核心脉冲律动。
    *   **技术**: 使用 SwiftUI `Canvas` + `TimelineView` 实现高性能粒子系统，配合 Haptic 震动反馈。
*   **对比**: 左右分屏对比 (Original vs Compressed Preview)。
*   **参数配置 (Settings)**:
    *   **推荐策略 (Smart Default)**: H.265 + Highest Quality (平衡体积与画质)。
    *   **自定义**: 用户可手动修改 分辨率 (1080p/Original) 和 编码格式。
*   **动作**: "立即压缩" (带预估体积，如 "预计节省 600MB")。


### 3.4 历史记录页 (History)
*   **列表**: 简单的日志流 (Timeline)。
*   **Item 内容**: 日期 | 原视频时长 | ⬇️ 节省空间 (如 "Saved 420MB") | 状态图标。
*   **操作**:
    *   **原片未删**: 显示 "删除原片" 按钮 (红色)。
    *   **原片已删**: 显示 "恢复" (跳转系统相册) 或 "查看新视频"。

### 3.5 设置页 (Settings)
*   **分组结构**:
    *   **扫描配置 (Scan)**: 忽略小文件阈值 (默认 50MB)。
    *   **压缩策略 (Strategy)**: 默认编码格式 (H.265)、默认画质偏好。
    *   **自动化 (Automation)**: "压缩后自动请求删除" (Toggle)。
    *   **关于 (About)**: 隐私政策、版本号。

## 4. 数据与持久化 (New)

### 4.1 历史记录 (History)
*   **技术选型**: **SwiftData** (iOS 17+) 或 CoreData。
*   **数据模型 (`CompressionRecord`)**:
    *   `id`: UUID
    *   `originalAssetID`: String (关联 PHAsset)
    *   `date`: Date
    *   `originalSize`: Int64 (Bytes)
    *   `compressedSize`: Int64 (Bytes)
    *   `status`: Int (1=Success, 0=Failed, -1=Cancelled)
    *   `isAssetDeleted`: Bool (原片是否已删除)
*   **统计逻辑**: 首页“节省空间” = Sum(originalSize - compressedSize) where status=Success。

### 4.2 通用配置 (Settings)
*   **存储**: `UserDefaults` (轻量级)。
*   **配置项 (`SettingsManager`)**:
    *   `scanThreshold`: Int (默认 50MB)
    *   `defaultCompressionPreset`: String (默认 H.265 High)
    *   `autoPromptDelete`: Bool (默认 true, 压缩成功后自动弹窗请求删除)
    *   `ignoredAssetIDs`: [String] (左滑忽略的视频 ID 列表)

## 5. 核心逻辑补全 (New)

### 5.1 压缩状态机
*   States: `Idle` -> `Downloading (iCloud)` -> `Compressing` -> `Finishing (Writing)` -> `Success/Failed/Cancelled`。
*   **取消机制**:
    *   持有 `AVAssetExportSession` 引用。
    *   调用 `cancelExport()`。
    *   **Cleanup**: 必须删除 Temporary Directory 中的半成品文件。

### 5.2 异常处理 (Swap Flow)
*   **删除失败**: 若新视频保存成功，但用户拒绝删除旧视频 ->
    *   **UI**: 提示“新视频已保存，请手动删除旧视频”。
    *   **History**: 记录 `status=Success`, `isAssetDeleted=false`。
    *   **后续**: 可在 History 列表中再次发起删除请求。

## 6. 实施路线图 (Detailed Plan)

### Phase 1: 基础架构 (Base Infrastructure)
*   **目录结构**: 建立 `App`, `Features`, `Services`, `Models`, `Shared` 分层结构。
*   **UI 框架**:
    *   实现 **Liquid Glass TabBar** (SwiftUI 自定义 TabView，适配 iOS 18+ 风格)。
    *   搭建 3 Tab 骨架: `HomeView`, `HistoryView`, `SettingsView` (Stubs)。
*   **核心服务**:
    *   `PersistenceService`: 配置 SwiftData 容器。
    *   `PermissionService`: 封装 PHPhotoLibrary 权限请求与状态流。
    *   `SettingsService`: 封装 UserDefaults 配置项。
*   **数据模型**: 定义 `CompressionRecord` (SwiftData Model)。

### Phase 2: 扫描模块 (Scanner)
*   `ScannerService`: 实现 `fetchAssets` + `NSPredicate` 筛选。
*   首页 UI: 扫描按钮、仪表盘状态切换、列表展示。

### Phase 3: 压缩核心 (Core Engine)
*   `CompressionService`: 封装 `AVAssetExportSession`。
*   状态机管理: 进度、取消、后台任务处理。
*   **Space Black Hole**: 实现 Canvas 粒子压缩动画。

### Phase 4: 闭环与历史 (Loop & History)
*   Swap 流程: 保存新视频 -> 验证 -> 删除旧视频。
*   历史记录 UI: 数据接入与展示。
*   通用设置 UI: 接入 SettingsService。

### Phase 5: 润色与交付 (Polish)
*   Onboarding 引导页。
*   全局 Haptics 反馈。
*   文案检查与隐私描述更新。

