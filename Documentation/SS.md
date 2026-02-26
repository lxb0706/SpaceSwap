# SpaceSwap 设计文档（PRD + Tech Spec，MVP 优先）

> 说明
>
> - **最低可运行系统**: iOS 17+（依赖 SwiftData）。
> - **视觉风格口径**: 以“iOS26 / Liquid Glass”作为 UI 表达与设计语言，不代表实际部署系统版本。
> - **本轮目标**: 单视频闭环 + 技术打底；批量队列与长期后台任务属于后续版本。

## 0. 产品定义

### 0.1 背景与问题
- 系统相册中“少量大体积视频”常成为存储占用的主要来源。
- 用户的真实诉求通常不是“管理文件”，而是“**安全地释放空间**”，且不希望误删原片。

### 0.2 目标用户
- 存储紧张的重度拍摄用户（4K/60fps、长视频、旅行/孩子记录）。
- 开启 iCloud Photos 的用户（大量视频在云端，存在下载与网络依赖）。

### 0.3 术语表
- `PHAsset`: Photos 资源对象（视频/照片）。
- `localIdentifier`: 资源唯一标识（用于持久化关联）。
- “iCloud 仅云端”: 当前设备未本地缓存，需要下载后才能获得完整数据/压缩处理。
- “限制访问（Limited）”: iOS 相册权限模式，仅允许访问用户选定的部分资源。
- “Swap（安全交换）”: 先保存压缩新视频，再请求删除原视频，原视频进入系统“最近删除”。

### 0.4 成功指标（MVP 可衡量）
- 单视频压缩闭环成功率: >= 95%（失败必须可解释并可恢复/重试）。
- 节省空间显示口径:
  - 统计以历史记录中的 `originalSize - compressedSize` 累加（仅统计 `Success`）。
  - 列表/详情中的“预估”必须标注为估算，不承诺精准。
- 耗时/电量:
  - MVP 只做“提示与记录”，不承诺硬 KPI；但需要避免明显的极端耗电路径（见 NFR）。

### 0.5 In-scope / Out-of-scope（本轮）
**In-scope（MVP）**
- 单视频闭环: 扫描列表 -> 详情 -> 压缩 -> 保存新视频 -> 提示删除原片 -> 历史与统计。
- iCloud 识别与下载（按需下载，支持进度与取消）。
- 基础设置: 扫描阈值、默认压缩预设、压缩后是否自动提示删除原片。

**Out-of-scope（明确不做）**
- 批量选择/队列/并发压缩（后续版本）。
- 真正的 BGProcessingTask 长期后台压缩（进程被杀后继续，后续版本）。
- 跨设备同步/云端处理。
- 画质对比预览（Original vs Compressed 预览）与复杂编辑能力。

## 1. 核心功能点（MVP，含验收与失败处理）

> 说明: 下表为“可验收口径”。更细的技术决策见第 2/5 节。

| 模块 | 功能点 | 触发条件 / 用户可见结果 | 验收标准 | 失败处理 / 恢复 | 数据影响 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 权限与引导 | 权限请求与状态识别 | 首次进入 Home 或点击“开始扫描”时触发；识别 `.authorized/.limited/.denied/.restricted/.notDetermined` | 任何状态下 UI 不崩溃；`.limited` 有明确提示 | `.denied/.restricted` 引导到系统设置；`.limited` 提供“管理可访问照片”入口 | 无 |
| 权限与引导 | 隐私说明 | App 内可见且不含歧义: “仅本地处理，不上传云端” | 文案出现于 Onboarding/设置页至少一处 | 无 | 无 |
| 扫描与发现 | 大视频扫描（阈值可配） | 点击“开始扫描”后扫描 `.video`；默认阈值 50MB（bytes 存储，UI 用 MB 展示） | 扫描不阻塞主线程；结果按大小/日期可排序 | 无权限时提示；扫描可取消 | 无持久化（仅内存），忽略列表写入设置 |
| 扫描与发现 | iCloud 识别 | 列表项标记“云端”资产（设备未本地可用） | 云端标记与实际下载行为一致（本地先探测） | 网络不可用时提示“需要网络下载” | 无 |
| 压缩与处理 | 空间预估（估算） | 详情页显示原始大小与预估压缩后大小 | 明确标注为估算；实际落库以导出文件大小为准 | 原始大小未知时显示“未知/估算中” | 无 |
| 压缩与处理 | 一键压缩（HEVC 优先） | 点击“开始压缩”；默认 HEVC，兼容性不足则回退 H.264 | 进度可见；可取消；导出成功后可在系统相册看到新视频 | 导出失败可重试；取消必须清理临时文件 | 成功后写入 `CompressionRecord`（Success/Failed/Cancelled） |
| 替换与清理 | 安全交换（Swap） | 压缩并保存新视频成功后，弹窗提示删除原片（默认开启） | “先保存新视频再删原片”的顺序不变；删除原片进入“最近删除” | 用户拒绝删除: 记录 `Success` 且 `isAssetDeleted=false`，History 提供“再次删除原片”入口 | 更新历史记录 `isAssetDeleted` |
| 仪表盘 | 成果展示 | Home/History 顶部展示累计节省空间 | 与历史记录统计一致（仅 Success） | 无 | 统计读取 SwiftData |

## 2. 技术架构设计（收敛后的决策）

采用 **MVVM (Model-View-ViewModel)** 架构，服务层协议化注入。

### 2.1 目录结构规划
```text
SpaceSwap/
├── App/
│   ├── SpaceSwapApp.swift      # 入口
│   └── DIContainer.swift       # 依赖注入容器 (可选)
├── Features/
│   ├── Home/                   # 首页（扫描/仪表盘/列表）
│   ├── Compression/            # 压缩详情与进度页
│   ├── History/                # 历史记录与统计
│   └── Settings/               # 设置
├── Services/
│   ├── PhotoLibraryService.swift  # 负责 PHPhotoLibrary 交互 (查、删、存)
│   ├── CompressionService.swift   # 负责 AVAssetExportSession (压缩核心，Phase 2+)
│   └── PermissionService.swift    # 负责 权限请求与状态监听
├── Models/
│   ├── PhotoAsset.swift        # 视频对象封装 (PHAsset + 大小 + 时长)
│   └── CompressionRecord.swift # SwiftData 历史记录
└── Shared/
    ├── Components/             # 通用 UI 组件 (如 ProgressButton)
    └── Extensions/             # Helper 扩展
```

### 2.2 关键技术方案（MVP 固化）

*   **视频扫描 (Scanner)**:
    *   **范围**: 仅扫描 `PHAssetMediaType.video`（不处理 Live Photo paired video，后续版本）。
    *   **过滤项**:
        *   MVP 仅按 `minSizeBytes` 过滤（默认 50MB，可在设置调整）。
        *   时长/时间范围筛选属于后续扩展（避免过早复杂化与性能陷阱）。
    *   **文件大小获取策略（收敛）**:
        1.  列表展示优先使用 `PHAssetResource` 的 `fileSize`（KVC/非公开字段，风险需接受）。
        2.  若 `fileSize` 不可用或为 0: 展示为“未知/估算中”，并在“开始压缩前”通过下载后的实际文件再次校准。
    *   **iCloud 本地可用性探测（两段式）**:
        1.  先 `isNetworkAccessAllowed = false` 请求 AVAsset，仅用于判断是否本地可用。
        2.  若判定在云端，再 `isNetworkAccessAllowed = true` 并绑定下载进度。
    *   **进度定义（可复现）**:
        *   `scanProgress = processedCount / totalVideoCount`
        *   `matchedCount` 独立统计（达到阈值的视频数量）。
    *   **性能策略**:
        *   扫描在后台队列执行，主线程只做增量 UI 更新。
        *   UI 更新节流（例如每 N 个资源或每 100ms 更新一次）。
    *   **取消策略（收敛）**:
        *   点击取消后立即停止扫描，并**保留已发现结果**（更友好）；同时标注“扫描已取消（结果不完整）”。
*   **视频压缩 (Compressor)**:
    *   **核心**: 使用 `AVAssetExportSession`（MVP 只做“单个视频压缩”）。
    *   **输出容器（收敛）**:
        *   默认输出 `.mp4`（体积与兼容性更稳妥）。
        *   若 `.mp4` 输出失败或不兼容，fallback 为 `.mov`（记录在错误信息中，便于排查）。
    *   **编码策略（收敛）**:
        *   首选 HEVC（H.265）；若 `exportPresets(compatibleWith:)` 不支持则回退 H.264 预设。
    *   **预设映射（MVP 固定 3 档）**:
        *   `low` -> `AVAssetExportPresetLowQuality`（若不兼容，回退 Medium）
        *   `medium` -> `AVAssetExportPresetMediumQuality`
        *   `high` -> `AVAssetExportPresetHighestQuality`（若可用则优先 HEVC 1080p/原分辨率预设，后续版本细化）
    *   **预估大小口径**:
        *   UI 估算采用经验比例（例如 0.3/0.5/0.7），必须显示“估算”字样。
        *   `CompressionRecord` 存储以实际导出文件大小为准。
    *   **进度与取消**:
        *   进度: 定时轮询 `exportSession.progress`（或 async/await 观察任务）。
        *   取消: `cancelExport()`，并删除临时目录半成品文件。
    *   **参考资料**:
        *   PhotoKit 资产扫描与 iCloud: [PHPhotoLibrary_Video_Guide.md](PHPhotoLibrary_Video_Guide.md)
        *   ExportSession 实战示例: [VIDEO_COMPRESSION_EXAMPLES.md](VIDEO_COMPRESSION_EXAMPLES.md)
*   **安全交换 (Swap)**:
    1.  压缩完成并保存新视频（得到 `compressedAssetID`）。
    2.  验证新视频写入成功（可在 Photos 中 fetch 到）。
    3.  弹窗请求删除旧视频（默认开启；用户可关闭该提示）。
    4.  若删除成功: 更新历史记录 `isAssetDeleted=true`；若用户拒绝/删除失败: 保持 `false` 并提供后续入口。

## 3. UI/UX 交互设计 (Update)

### 3.0 导航架构 (Navigation)
*   **平台**: iOS 17+ 可运行；UI 采用 “iOS26 / Liquid Glass” 视觉语言表达。
*   **Tab 结构**: 底部 TabBar，采用 **"液态玻璃" (Liquid/Glassmorphism)** 风格 —— 半透明磨砂 + 悬浮感。
*   **Tabs**:
    1.  **首页 (Home)**: 扫描、核心仪表盘、视频列表。
    2.  **历史 (History)**: 压缩记录、节省统计、回收站入口。
    3.  **设置 (Settings)**: 偏好配置、策略管理。

### 3.1 首页 (Home) - "准备扫描"
*   **状态**: 默认空状态/未扫描状态。
*   **核心动作**: 巨大的 **"开始扫描" (Scan)** 按钮。
*   **配置入口 (Scan Options)**: 扫描按钮旁的“设置/滤镜”图标，点击弹出 Sheet：
    *   **MVP**: 仅大小阈值（默认 50MB，可在 Settings 中精细调整）。
    *   **后续**: 时长阈值、时间范围属于迭代项（不阻塞 MVP）。
*   **权限引导**: 若无权限，显示友好的“去设置开启”引导页。
*   **Limited 提示**: 若权限为 `.limited`，显示“仅扫描已授权的项目”，并提供“管理可访问照片”入口（系统面板）。

### 3.2 扫描结果页 (Results)
*   **布局**: 垂直列表。
*   **排序栏**: 支持按 **大小** (默认)、**时长**、**日期** 排序。
*   **列表项**: 缩略图 | 原始大小 (高亮) | 时长 | *iCloud图标(如需下载)*。
*   **操作**: 点击进入详情，或左滑“忽略”。

### 3.3 压缩详情页 (Detail)
*   **MVP**: 以“进度 + 预估节省空间 + 可取消”为主，确保闭环稳定。
*   **P2（非 MVP）动画**: **"Space Black Hole"** 作为视觉增强，不阻塞核心交付。
*   **参数配置 (Settings)**:
    *   **推荐策略 (Smart Default)**: H.265 + Highest Quality (平衡体积与画质)。
    *   **MVP 自定义**: 仅 quality（low/medium/high）；分辨率与编码细粒度在后续版本开放。
*   **动作**: "立即压缩" (带预估体积，如 "预计节省 600MB")。


### 3.4 历史记录页 (History)
*   **列表**: 简单的日志流 (Timeline)。
*   **Item 内容**: 日期 | 原视频时长 | ⬇️ 节省空间 (如 "Saved 420MB") | 状态图标。
*   **操作**:
    *   **原片未删**: 显示 "删除原片" 按钮 (红色)。
    *   **原片已删**: 显示 "恢复" (跳转系统相册) 或 "查看新视频"。

### 3.6 设计系统 (Design System)
*   **主题色 (Primary)**: **iOS System Blue** (`Color.blue`)。
    *   保持纯粹、原生的 iOS 工具质感。
    *   支持 Light/Dark Mode 自适应。
*   **背景 (Background)**:
    *   使用系统语义色 (`systemBackground`, `secondarySystemBackground`) 确保完美的深色模式体验。
*   **风格**:
    *   **Liquid Glass**: 底部 TabBar 和悬浮卡片使用 `Material` (UltraThinMaterial) 背景。
    *   **Space Theme**: 仅在“扫描”和“压缩动画”等关键节点使用深邃的太空元素，其余界面保持干净的系统风格。

## 4. 数据与持久化 (New)

### 4.1 历史记录 (History)
*   **技术选型**: **SwiftData**（iOS 17+）。
*   **数据模型 (`CompressionRecord`)**:
    *   `id`: UUID
    *   `originalAssetID`: String (关联 PHAsset)
    *   `compressedAssetID`: String（新视频的 `localIdentifier`）
    *   `date`: Date（完成压缩并成功保存新视频的时间）
    *   `originalSize`: Int64 (Bytes)
    *   `compressedSize`: Int64 (Bytes)
    *   `compressionRatio`: Double（`compressedSize / originalSize`）
    *   `quality`: String（low/medium/high 等）
    *   `status`: Int（1=Success, 0=Failed, -1=Cancelled）
    *   `isAssetDeleted`: Bool（原片是否已删除）
*   **统计逻辑**: 首页“节省空间” = Sum(originalSize - compressedSize) where status=Success。

### 4.2 通用配置 (Settings)
*   **存储**: `UserDefaults` (轻量级)。
*   **配置项 (`SettingsService`)**:
    *   `scanThreshold`: Int64（bytes，默认 50MB）
    *   `defaultCompressionPreset`: String（默认 H.265 High / 对应 MVP 的 `high`）
    *   `autoPromptDelete`: Bool（默认 true，压缩成功后自动弹窗请求删除）
    *   `ignoredAssetIDs`: [String]（忽略的视频 `localIdentifier` 列表）

## 5. 核心逻辑补全（状态机 + 落库规则）

### 5.1 压缩状态机
*   States: `idle` -> `downloading` -> `compressing` -> `writing` -> `success / failed / cancelled`。
*   **取消机制**:
    *   持有 `AVAssetExportSession` 引用。
    *   调用 `cancelExport()`。
    *   **Cleanup**: 必须删除 Temporary Directory 中的半成品文件。

### 5.2 Swap 与历史记录写入时机（强约束）
*   **写入历史记录（Success）**: 当且仅当“压缩完成 + 新视频保存到相册成功”时写入（生成 `compressedAssetID`）。
*   **写入历史记录（Failed/Cancelled）**:
    *   Failed: 失败原因可用时写入错误摘要（MVP 可仅提示 UI，不一定持久化错误字符串）。
    *   Cancelled: 用户取消导出或取消 iCloud 下载后写入 `status=-1`（或不写入，二选一需固定；MVP 建议写入，便于统计与排查）。
*   **删除原片的结果**:
    *   删除成功: 更新 `CompressionRecord.isAssetDeleted=true`。
    *   用户拒绝/删除失败: 保持 `false`，并在 History 提供“再次删除原片”的动作入口。

### 5.3 失败模式与提示口径（MVP 必须覆盖）
*   权限不足: “未获得相册权限，无法扫描/压缩，请前往设置开启。”
*   iCloud 下载失败/网络不可用: “该视频仅在 iCloud 中，需要网络下载后才能压缩。”
*   磁盘空间不足: “本机空间不足，无法生成压缩文件，请先释放空间后重试。”
*   导出失败: “压缩失败（系统导出错误），可重试或更换画质档位。”
*   保存失败: “保存到相册失败，请稍后重试。”
*   删除失败/拒绝删除: “新视频已保存，可在历史记录中再次删除原片以释放空间。”

## 6. NFR（Non-Functional Requirements）
*   **隐私**: 全程本地处理；不上传云端；不收集相册内容/缩略图到网络服务。
*   **性能**:
    *   扫描不阻塞主线程，UI 可滚动/可交互。
    *   大库（> 10k 视频）场景: 扫描进度持续更新且不触发系统 watchdog。
*   **存储**:
    *   临时文件统一放置在 Temporary Directory，任务结束（成功/失败/取消）都要清理。
    *   压缩前预估“额外临时占用”并在空间不足时阻止开始压缩（或明确提示风险）。
*   **电量/温控**:
    *   压缩时提示“建议连接电源/避免低电量模式”。
    *   MVP 仅提示；后续可增加“低电量模式自动降档”策略。

## 7. Test Plan（验收用例）
### 7.1 权限
*   `.notDetermined`: 首次请求权限流程正确；拒绝后进入引导。
*   `.authorized`: 可扫描/压缩/删除。
*   `.limited`: 显示限定提示，且仅处理可访问资源；入口可打开系统“管理可访问照片”。
*   `.denied/.restricted`: 扫描与压缩动作均被拦截并提示去设置。

### 7.2 iCloud
*   本地可用视频: 无网络也能压缩。
*   仅云端视频: 列表显示云端标记；点击压缩触发下载进度。
*   下载中取消: 取消后任务停止，UI 恢复可操作，临时文件无残留。
*   网络失败/超时: 明确提示可重试。

### 7.3 压缩
*   成功: 进度正确，新视频出现在系统相册，历史记录新增，统计累加。
*   失败: UI 提示，允许重试；History 按约定记录 failed/cancelled（若启用记录）。
*   取消: 导出会话取消，临时文件清理完成。
*   预设切换: low/medium/high 都可执行（至少不会崩溃），不兼容时有回退策略。

### 7.4 Swap（删除原片）
*   删除成功: 原视频进入“最近删除”；History `isAssetDeleted=true`。
*   用户拒绝删除: 新视频仍保留；History `isAssetDeleted=false` 且有“再次删除原片”入口。
*   删除失败: 提示原因（若可用），并可在 History 重试。

### 7.5 历史与设置
*   历史统计: 仅统计 `Success`；删除/清空历史后统计刷新。
*   设置阈值变更: 对下一次扫描生效（需重新扫描）；UI 文案明确这一点。

## 8. 实施路线图（对齐 MVP vs P2）

### Phase 1: 基础架构（Base Infrastructure）
*   目录结构与 MVVM 分层。
*   3 Tab 骨架: Home/History/Settings。
*   SwiftData 容器与基础 SettingsService。

### Phase 2: 单视频闭环（MVP 核心）
*   扫描: 大视频列表、排序、iCloud 标记、取消扫描。
*   压缩: HEVC 优先、进度、取消、输出保存到相册。
*   Swap: 压缩成功后提示删除原片；History 支持二次删除。
*   统计: Home/History 顶部累计节省空间。

### Phase 3: P2 视觉与体验（不阻塞 MVP）
*   “Space Black Hole” 动画、Haptics、过渡动效。
*   更精细的压缩预设（分辨率/编码选择）与预估模型。

### Phase 4: P2+ 工作流与后台能力（风险项）
*   批量选择、队列、并发控制、失败重试策略。
*   BGProcessingTask 长期后台压缩（需要额外系统限制评估与配置，且不可承诺被杀后继续）。

## 9. Open Questions（不阻塞 MVP）
*   `PHAssetResource.fileSize` 的非公开访问若在部分系统版本失效，fallback 的 UI 与精确大小校准策略如何表达。
*   Cancelled/Failed 是否必须落库（当前建议落库以便统计与排查，若不落库需统一口径）。
*   输出 `.mp4` 与 `.mov` 在极端编码/兼容性场景的默认选择是否需要基于设备能力动态切换。
