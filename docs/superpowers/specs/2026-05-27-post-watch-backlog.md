# Post-Watch 功能 Backlog

> **狀態**：未排程。Watch MVP（Phase 1–4）與 Watch Phase 5+ backlog（見 `2026-05-27-apple-watch-phase5-backlog.md`）之外的非-Watch 方向收斂清單。
>
> **目的**：避免 Watch 工作期間發散到別處。本檔列出兩個經過 brainstorming 篩選出來、優先序最高的非-Watch 方向，以及為什麼。

## 候選 A：統一發票載具自動拉

### 想做什麼

手機條碼載具 / 自然人憑證載具登錄後，App 定時打財政部「電子發票整合服務平台」API 拉回發票明細 → AI 依商家 / 品項套分類 → 使用者在「待匯入」清單一鍵或批次匯入。

### 為什麼值得

- 台灣記帳場景最痛的「電子發票還要手動抄」直接解掉。
- 既有 `Carrier` domain（`2026-04-03-carrier-management-design.md`）只能存條碼字串供查閱；本功能讓條碼變成「自動入帳管線的起點」，把已花費的開發 leverage 起來。
- 配合既有 AI 分類 client，新代碼集中在「API 整合 + inbox UI + 去重」。

### 技術切點

| 部分 | 概要 |
|---|---|
| Networking | 財政部「電子發票整合服務平台」API（OAuth + invoice query），規格需先實驗確認 |
| Domain | 新增 `InvoiceRecord` entity；新增 `InvoiceClient`；可能新增 `PendingInvoice` 概念 |
| Core | Live client 走 URLSession；持久化「最後拉取時間」「已匯入發票 ID」防重複 |
| 排程 | BGAppRefreshTask 定時拉；UI 可手動 Pull-to-refresh |
| Features | 新「待匯入發票」inbox 頁，每筆顯示 AI 建議分類；單筆 / 全選匯入 |
| AI | 重用 `aiServiceClient.suggestCategories` 套商家+品項 |
| 隱私 / 安全 | 載具憑證安全儲存（Keychain）；token refresh；本機快取加密考量 |

### 風險

- 財政部 API **未確認公開穩定的官方規範**，可能需要 reverse engineer 第三方非官方文件；隨政府改版易壞。
- OAuth / token flow 複雜，錯誤處理面廣。
- 隱私敏感 — 跟政府服務拿真實消費紀錄，要在 onboarding / Settings 明確說明資料流。

### 估時感

中大型 — 假設 API spec 順利，2–4 週；不順利可能無止盡。**建議動手前先花 1–2 天做 API spike 確認可行性。**

---

## 候選 B：異常消費主動提醒

### 想做什麼

定期（每天 / 每週）背景跑統計，比對「某分類本期 vs 過去 N 期 baseline」，跨閾值時：
1. 推送 local notification：「⚠️ 餐飲本週已比過去 4 週平均高 60%」
2. 在 Dashboard 顯示 dismissable `InsightCard`
3. 使用者可在 Settings 為個別分類設「不要再提醒」

### 為什麼值得

- 把資料從「被動查詢」變「主動洞察」。現有 AI Chat（`2026-03-30-analysis-ai-assistant-design.md`）你問才答，本功能讓 App 主動開口。
- 純本地計算 — 不需外部 API、不增加雲端依賴、不耗電。
- 落地後產生的 `SpendingBaseline` / `InsightCard` pattern 可被未來「月度敘事報告」「預算智能建議」重用，是 AI 深化的基礎建設。

### 技術切點

| 部分 | 概要 |
|---|---|
| Domain | 新增 `SpendingBaseline`（per category, per window, mean+stddev）；新增 `AnomalyDetection` entity；新增 `BaselineClient` / `AnomalyDetectorClient` |
| Core | Live 實作：query SwiftData 計算 baseline；持久化最近 detection 結果防重複 notify |
| 排程 | 共用既有 `RecurringTransaction` 已掛的 BGAppRefreshTask；新增 daily anomaly scan |
| Notifications | 走既有 `LocalNotificationsClient`；新類別 `anomaly` 可在 Settings 獨立開關 |
| Features | Dashboard 上 `AnomalyInsightCard` 元件；Settings 提供「異常提醒」總開關 + per-category mute |
| 閾值策略 | 預設 mean + 2σ **且** 漲幅 ≥ 50%（避免低基數雜訊）；提供 Settings 調整敏感度 |

### 風險

- 低。
- 主要難點是**閾值調校** — 太敏感變垃圾通知、太鈍沒用。Phase 1 先用保守預設，後續觀察使用者實際 mute 行為再調。
- 樣本不足（資料 < 4 週）時須優雅降級（不提醒、不顯示卡片，而非顯示錯誤）。

### 估時感

小到中型 — 1–2 週，全部本地，技術都是現有元件組合。

---

## 優先序建議

**B 先於 A**。理由：

1. **B 風險低、可快速交付** — 純本地計算，所有元件都是 stack 內既有的（SwiftData 查詢、LocalNotifications、BGAppRefreshTask、Dashboard 卡片 pattern）。可預期兩週內見效。
2. **A 卡 external dependency** — 財政部 API spec 未確認，可能花很久研究 spec / 處理 OAuth / 應付政府改版才動得了手，期間 visible progress 為零。
3. **B 是 A 的前置基礎** — A 匯入時也想推薦最佳分類、也想用「跟你過去消費比起來」的語言給 UI hint；B 做完的 baseline + insight card 可直接重用。
4. 若 A 結果做不出來（政府不給 access），時間就浪費了；B 一定做得出來。

## 後續處理

- 本 backlog **不進 writing-plans**。
- Watch MVP（Phase 1–4）落地後，從 B 起手：走 brainstorming → spec → plan。
- A 動手前**先做 1–2 天 API 可行性 spike**；若 spike 失敗則本檔保留 A 但無限期延後。
- 其他 idea（OCR、銀行通知、訂閱偵測、月度敘事、預算智能建議、模式 insight）若日後升溫，再各自 brainstorming，不在此檔展開。
