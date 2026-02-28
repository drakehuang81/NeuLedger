# Spec: NeuLedger 啟動體驗 (Launch Experience)

## Requirements

---

### Requirement: 啟動畫面視覺呈現
啟動畫面 (Launch Screen) 必須展現 NeuLedger 的品牌形象，並提供平滑的視覺體驗。透過 `SplashView` 實作品牌動畫。

#### Scenario: 應用程式冷啟動 (Cold Launch)
- **WHEN** 使用者首次打開 App 或從完全關閉狀態啟動
- **THEN** 顯示包含 App Logo 與品牌名稱的 `SplashView`
- **AND** 顯示品牌 Logo 的縮放與透明度脈動動畫 (Scale & Pulsing)
- **AND** 背景色應與系統主題 (System Theme) 一致
- **AND** 經過由 Reducer 控制的非同步路由判斷後，過渡到 Onboarding 或主畫面。

---

### Requirement: 載入狀態回饋
若應用程式需要進行資料初始化，啟動畫面應提供適當的視覺回饋。

#### Scenario: 資料載入中
- **WHEN** App 正在背景載入初始數據
- **THEN** 保持啟動畫面顯示，避免畫面未就緒即進入主畫面造成的閃爍
- **THEN** 載入完成後自動跳轉至首頁

---

### Requirement: Dark Mode 支援
啟動畫面必須針對深色模式進行最佳化。

#### Scenario: 系統處於深色模式
- **WHEN** 使用者在深色模式下啟動 App
- **THEN** 顯示深色版本的背景與適配的 Logo 顏色
