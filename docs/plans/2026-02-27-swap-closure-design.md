# SpaceSwap MVP 闭环补全设计（Swap 手动删除 + 扫描去重/区分）

日期：2026-02-27

## 背景

当前实现已具备：
- Home 扫描系统相册大视频并进入详情页
- 单视频压缩（含 iCloud 按需下载、进度、取消）、保存新视频到系统相册
- 全局压缩队列（同会话 asset 仅允许入队一次）
- SwiftData 持久化 `CompressionRecord` 与 History/Settings 基础页面

但尚未形成 PRD（`Documentation/SS.md`）定义的「闭环」：用户完成压缩后，能明确完成“释放空间”的最后一步（删除原片），并在后续扫描中避免重复出现在待处理列表里。

## 目标（本次）

1. **Swap 闭环**：压缩成功后不自动弹窗删除；用户可在 History 手动删除原片（带二次确认），删除后写回 `CompressionRecord.isAssetDeleted=true`。
2. **扫描去重**：已压缩过的原视频（`originalAssetID`）在后续扫描中不再出现在扫描列表。
3. **压缩副本区分**：压缩生成的新视频（`compressedAssetID`）若被扫描出来，需要在列表明显区分为 “Compressed Copy”，并在 App 内显示 `xxx_SS_1` 风格的显示名（`xxx` 为去掉扩展名的原始文件名）。
4. **统计口径对齐**：Home/History 的“累计节省空间”采用 SwiftData Success 记录累加：`Sum(originalSize - compressedSize) where status==1`。

## 非目标（本次不做）

- 批量多选编排与跨会话队列恢复
- BGProcessingTask 后台持续压缩
- 真正修改系统相册中文件名（PhotoKit 通常不保证可改文件名）
- “已真正释放空间”新口径（与 `isAssetDeleted` 绑定的统计）

## 产品决策（已确认）

- 删除原片策略：**不主动弹窗提示删除**；仅在 **History** 提供“删除原片”按钮（并弹出二次确认）。
- 扫描策略：**压缩副本仍可出现在扫描列表**，但必须标记为 “Compressed Copy” 并提供 `xxx_SS_1` 显示名。
- `xxx` 的来源：使用 **去掉扩展名的原始文件名**（例如 `IMG_1234.MOV` → `IMG_1234`）。

## 核心流程

### 1) 压缩成功（Compression / Queue）

触发：压缩完成并成功保存新视频到相册（得到 `compressedAssetID`）。

- 写入 `CompressionRecord`：
  - `status=1 (Success)`
  - `isAssetDeleted=false`
  - `originalAssetID`（原视频 localIdentifier）
  - `compressedAssetID`（新视频 localIdentifier）
  - `originalSize/compressedSize/quality/compressionRatio/date`
  - `originalFilename`（新增字段，写入原视频文件名，用于后续显示名继承）

UI：
- `CompressionView` 成功态不弹窗删除，仅提示“可到 History 删除原片以释放空间”，并提供 “Go to History” 的快捷入口（切换 Tab）。

### 2) History 手动删除原片（Swap）

展示规则：
- `record.status==1` 且 `record.isAssetDeleted==false`：显示红色按钮 **Delete Original**
- `record.isAssetDeleted==true`：显示标签 **Original Deleted**

交互：
1. 点击 **Delete Original**
2. 弹出二次确认 Alert（说明原视频进入“最近删除”）
3. 确认后执行删除：
   - 通过 `record.originalAssetID` fetch 对应 `PHAsset`
   - `PHPhotoLibrary.performChanges` 删除该资产
4. 删除成功：
   - 更新该条 `CompressionRecord.isAssetDeleted=true` 并持久化
   - 刷新列表与统计
5. 删除失败：
   - 展示错误，不修改 record

### 3) Home 扫描列表：去重 + 区分 + 显示名

扫描结果展示前进行二次过滤/标记（读取 SwiftData 中 `status==1` 的记录集）：

1. `asset.id ∈ SuccessRecords.originalAssetID` ⇒ **不显示**（原视频已处理）
2. `asset.id ∈ SuccessRecords.compressedAssetID` ⇒ **显示**，并标记为 **Compressed Copy**

显示名（仅 App 内）：
- 普通视频：`asset.filename`
- 压缩副本（Compressed Copy）：`baseName(record.originalFilename) + "_SS_1"`
  - `baseName`：去掉扩展名（以最后一个 `.` 作为分隔）

详情页保护（建议）：
- 若进入的是 Compressed Copy：隐藏或禁用“Start Compression”，避免对压缩副本重复压缩造成混乱；同时给出提示文案。

## 数据与接口变更

### SwiftData 模型

`CompressionRecord` 新增：
- `originalFilename: String`（用于压缩副本显示名继承）

### Services

- `PhotoLibraryServiceProtocol` 新增：
  - `deleteAsset(localIdentifier: String) async throws`
- `PersistenceServiceProtocol` 新增（或等效能力）：
  - `update(record: CompressionRecord) async throws`

## 验收清单（MVP）

- 压缩成功后，History 出现记录，`isAssetDeleted=false`。
- History 点击 “Delete Original”：
  - 出现二次确认 Alert
  - 确认后原视频进入“最近删除”
  - 记录更新为 `isAssetDeleted=true`
- 再次扫描：
  - 原视频（`originalAssetID`）不再出现
  - 压缩副本若体积仍大：会出现并标记 “Compressed Copy”，显示名为 `原名_SS_1`
- Home/History 的“累计节省空间”与历史 Success 统计一致。

## 风险与注意

- PhotoKit 不保证可修改系统相册文件名，因此 `xxx_SS_1` 作为 **App 内显示名**。
- SwiftData schema 变更（新增字段）需要验证数据迁移行为，并通过 `xcodebuild` 与测试保障稳定。

