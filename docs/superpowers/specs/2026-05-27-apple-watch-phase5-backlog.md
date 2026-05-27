# Apple Watch Phase 5+ 功能 Backlog

> **狀態**：未排程。等待 Phase 1–4（MVP 記帳流程 + Today Complication + Settings 整合）落地後，再從本文件挑選下一波。
>
> **目的**：把 brainstorming 出來的方向先收斂成清單，避免 MVP 完成後重新發散。每個項目只寫「想做什麼 / 為什麼有價值 / 大概的技術切入點」，**不寫 design**——真正動手前須各自走 brainstorming → writing-plans。

## 方向 A：語音 / Siri 輸入

iPhone 端已有「語音記帳 + AI 解析」（見 `2026-03-27-voice-input-ai-recording`、`2026-03-30-voice-note-input`），Watch 是天然延伸——抬腕說一句比掏手機快得多。

| Item | 描述 | 價值 | 技術切入 |
|---|---|---|---|
| A1. Watch 內建語音記帳 | Watch 錄音 → 透過 `WCSession.transferFile` 送回 iPhone → 沿用既有 AI pipeline 解析成 `TransactionDraft` → 推回 Watch 確認 | 主流程外的「無鍵盤」快速入口 | 需 Watch 端錄音 client + iPhone 端收檔 handler；可重用 `WatchBridgeAdapter` 反向通道 |
| A2. Siri Shortcut「嗨 Siri，記一筆」 | App Intents 揭露 `RecordExpenseIntent(amount, category?, note?)`；在 Watch / iPhone / HomePod 都能觸發 | 不需要打開 App | App Intents（iOS/watchOS 共用 framework）；參數 disambiguation |
| A3. 從 Watch 喚起 iPhone AI 對話 | Watch 上長按 → 跳到 iPhone Analysis AI Assistant 並聚焦輸入 | 把 Watch 當 iPhone AI 的快捷觸發 | Handoff 或 `WKApplicationDelegate` URL routing |

## 方向 B：快速瀏覽 / 查看

目前 Watch 只能「寫入」，缺「讀取」。Watch 適合一眼看完的資訊。

| Item | 描述 | 價值 | 技術切入 |
|---|---|---|---|
| B1. 最近交易列表 | Watch app 增加第二個 tab「Recent」，顯示最近 10 筆，可點進去看詳情、刪除、改分類 | 對帳、確認剛剛是否記成功 | 從 `WatchContextSnapshot` 擴充欄位；點擊 = 送 `TransactionDraft` 反向操作？或唯讀即可 |
| B2. 預算進度 glance | 顯示前 3 個 active budget 的進度條與剩餘金額 | 抬腕就知道還能花多少 | snapshot 新增 `budgets: [WatchBudgetStatus]` |
| B3. 帳戶餘額快查 | 列出未封存帳戶的當前餘額（已扣除/已加總） | 出門前確認悠遊卡 / 信用卡狀態 | snapshot 新增 `accounts: [WatchAccountBalance]` |
| B4. 今日 / 本週 / 本月 摘要切換 | 主畫面可滑動切換時間區間，顯示對應總額與筆數 | 把 Complication 上看不下的內容放主畫面 | snapshot 新增多時段欄位；TCA 切換 reducer |

> **設計考量**：B1-B4 全部都會放大 snapshot 體積。需評估是否拆成多個 `updateApplicationContext` 通道，或某些資料改用 `transferUserInfo` on demand。

## 方向 C：主動推送警示

iPhone 端已有 `LocalNotifications`、`Reminders`（見 `2026-03-24-local-notifications`、`2026-03-27-recurring-to-notification-settings`）。Watch local notification 可獨立 fire，不依賴 iPhone 在身邊。

| Item | 描述 | 價值 | 技術切入 |
|---|---|---|---|
| C1. 預算接近上限警示 | 達 80% / 100% 時 Watch haptic + notification | 比 iPhone notification 更難忽略 | iPhone 端跨閾值時透過 `UNNotificationContent` + watchOS 鏡像送達；或 Watch 端讀 snapshot 自行判斷 |
| C2. 異常大金額提醒 | 單筆超過該分類過去 30 天 mean + 2σ 時，記帳完成後 5 秒在 Watch 確認「這筆沒打錯吧？」 | 防呆 | 需歷史統計；可放 snapshot |
| C3. 連續記帳天數 streak | 連續記帳 N 天提醒；中斷 1 天後傍晚提醒 | 養成習慣 | 需 streak 計算 + 排程 |
| C4. 訂閱扣款 / 重複交易到期 | `RecurringTransaction` 觸發前一天推送，Watch 可一鍵確認生成 | 配合既有 recurring 功能 | App Intent + Watch notification action |

## 方向 D：Complication 多樣變體

MVP 只實作「Today 花費」一個 Complication，Phase 3 已規劃 4 個 families。本方向是「同 timeline provider，多種 chart 內容」。

| Item | 描述 | 技術切入 |
|---|---|---|
| D1. 剩餘預算 Complication | 主預算的剩餘額 / 進度環，circular 適合用 `Gauge` | 新 widget kind + 共用 snapshot |
| D2. 本月趨勢 sparkline | rectangular family 用 `Chart` 畫迷你折線圖 | Swift Charts in widget |
| D3. 主要帳戶餘額 | 使用者選一個帳戶釘在錶面 | 需 widget configuration intent |
| D4. Smart Stack 智能堆疊 | 接 `relevantContexts`（時間 / 地點 / Workout 結束）讓 Watch 自動把 NeuLedger widget 浮上來 | `WidgetRelevances` API |
| D5. Photos 錶面適配 | 確認所有 widget 在 Photos 錶面背景下對比度足夠 | accessibilityLargeContent + tint 處理 |

## 方向 E：較開放的探索（保留）

> Phase 1–4 期間不討論，等實際使用後再決定要不要做。

- E1. **Workout / Health 整合**：跑步結束 push「補給金額」？喝水次數 vs 飲料消費關聯？——idea 階段，**價值假設未驗證**。
- E2. **Watch 獨立高級互動**：Double Tap 快速確認最近預設記帳、Digital Crown 滾動選金額（取代鍵盤）、AssistiveTouch 場景——等真實使用 MVP 後再看哪個動作最高頻。
- E3. **多 Watch 場景**：通勤、運動、睡眠不同 context 給不同預設分類；可能要 Live Activity 才合適。

## 後續處理

- 此 backlog **不進 writing-plans**。
- MVP（Phase 1–4）完成後，挑選 1–2 個項目（建議起手：B1 最近交易 + D1 剩餘預算 Complication，能立即帶來「Watch 不只能寫還能讀」的體感）走完整 brainstorming → spec → plan 流程。
- 若使用 NeuLedger 一陣子後對某個 idea 的價值假設改觀，直接更新本檔；不需要的條目刪掉即可。
