# Handoff · NeuLedger (B1 · Warm)

> 本資料夾是 NeuLedger 一個個人記帳 App 的設計交付包。
> 設計方向已定稿為 **B1 · Warm**(暖色玻璃 / orange accent / Bricolage + DM Sans + DM Mono)。

---

## 0. About these files

`prototypes/` 內的 HTML / JSX 檔案 是設計稿,**不是 production code**。它們是用 React (via Babel standalone) + 原生 CSS 寫成的可互動 prototype,目的是精準地呈現「最終成品該長什麼樣、怎麼動」。

> **你的任務**:在你的目標 codebase(SwiftUI、React Native、Flutter、Next.js、Compose 等都可以)中,**重現這些畫面**,使用該環境的原生 component + 動畫系統。**不要把 HTML 直接搬進去**。

如果目前還沒有 codebase,根據「個人記帳 App,主要平台 iOS,可能擴及 Android / Web」這個前提,推薦的技術選擇:
- **iOS 原生**:SwiftUI(色彩、blur、spring 動畫都是一等公民,最貼合視覺)
- **跨平台**:React Native + Reanimated + expo-blur,或 Flutter(BackdropFilter + ImageFilter.blur)

---

## 1. Fidelity

**High-fidelity (hifi)**。所有顏色、字級、間距、圓角、陰影、動畫曲線都已在 `prototypes/NeuLedger Design Tokens.html` 中定稿。請按 token 1:1 還原。

---

## 2. 產品結構

NeuLedger 是一個 **AI-assisted 個人記帳 App**,核心差異點是:
1. **自然語言記帳**:輸入「午餐 三明治 120」就會被 AI 抽出 amount / category / merchant。
2. **暖玻璃視覺語言**:warm radial gradient 背景 + frosted glass cards,有別於常見的灰色 fintech app。
3. **多帳戶**:現金 / 銀行 / 電子錢包 / 信用卡 / 儲蓄,各有 accent 色。

### 已設計完成的畫面群

| 群組 | 畫面 | 來源檔 |
|---|---|---|
| **Onboarding** | Welcome → Accounts setup → Ready (3 steps + done) | `prototypes/onboarding-variations.jsx`, `onboarding-b-prototype.jsx` |
| **Dashboard** | 月份總覽 / Net worth / Transactions / Categories | `prototypes/dashboard-b1.jsx` |
| **Add Transaction** | 自然語言輸入 → AI 抽取 → 確認 sheet | `prototypes/add-transaction.jsx` |
| **First-run flow demo** | 22 秒自動播放,串接 onboarding → home → add tx → confirm | `prototypes/flow-screens.jsx`, `flow-controller.jsx` |

---

## 3. Design Tokens

> 所有 token 在 `tokens/` 資料夾中以三種格式提供:
> - `tokens.css` — CSS custom properties(Web / RN-Web)
> - `tokens.json` — 通用 JSON(可灌進 Style Dictionary)
> - `Tokens.swift` — SwiftUI Color / Font / CGFloat 常數

### 3.1 Colors

| Token | Light | Dark | 用途 |
|---|---|---|---|
| `--accent` | `#FF9500` | `#FF9F0A` | 主色,所有 CTA、active state |
| **CTA gradient** | `linear-gradient(135°, #FF9500 → #FF6A00)` | 同 | 主按鈕、FAB、大金額正值,**永遠 135°** |
| `--accent-soft` | `#FFD27A` | `#FFD27A` | Glow orbs,背景強調 |
| `--income` | `#34C759` | `#30D158` | 收入金額、AI 抽取成功 badge |
| `--expense` | `#FF3B30` | `#FF453A` | 支出金額、刪除動作 |
| `--acc-cash` | `#8E8E93` | — | 現金帳戶 |
| `--acc-bank` | `#0A84FF` | — | 銀行帳戶 |
| `--acc-ewallet` | `#5E5CE6` | — | 電子錢包 |
| `--acc-credit` | `#FF2D55` | — | 信用卡 |
| `--acc-savings` | `#34C759` | — | 儲蓄帳戶 |
| `--canvas` | `#FAF7F2` | `#1A1714` | 頁面底色 |
| `--ink` | `#0A0A0A` | `#FFFFFF` | 主要文字 |
| `--muted` | `rgba(60,60,67,0.65)` | `rgba(235,235,245,0.65)` | 次要文字 |

#### Background gradients(關鍵視覺)
```css
/* Light · warm */
background: radial-gradient(ellipse at 20% 0%, #FFE4B8 0%, #FFF6E8 50%, #FAFAF7 90%);

/* Dark · warm */
background: radial-gradient(ellipse at 50% 30%, #4A2A0E 0%, #1a0f08 40%, #050505 90%);
```
SwiftUI 對應:`RadialGradient(...)` 或 `MeshGradient`(iOS 18+)。
RN:`react-native-linear-gradient` + `expo-radial-gradient`(或自繪 SVG)。

### 3.2 Typography

| Family | Use | Source |
|---|---|---|
| **Bricolage Grotesque** (400/500/600/700) | Display · 標題 · 大金額 | Google Fonts |
| **DM Sans** (400/500/600/700) | Body · UI 文字 · 按鈕 | Google Fonts |
| **DM Mono** (400/500) | Numbers · Tags · ALL-CAPS eyebrow | Google Fonts |

#### Type scale

| Token | Family | Size / LH | Letter-spacing | Weight |
|---|---|---|---|---|
| `display-xl` | Bricolage | 56 / 1.0 | -1.8px | 700 |
| `display-l` | Bricolage | 40 / 1.05 | -1.2px | 700 |
| `display-m` | Bricolage | 24 / 1.1 | -0.6px | 700 |
| `display-s` | Bricolage | 18 / 1.2 | -0.3px | 600 |
| `body-l` | DM Sans | 16 / 1.45 | -0.15px | 400-500 |
| `body-m` | DM Sans | 14 / 1.45 | -0.1px | 400-500 |
| `body-s` | DM Sans | 12 / 1.4 | 0 | 400-500 |
| `mono-l` | DM Mono | 38 / 1.0 | -1.2px | 500 |
| `mono-m` | DM Mono | 14 / 1.2 | -0.2px | 500 |
| `mono-eyebrow` | DM Mono | 10-11 / 1.4 | **+1.2~1.6px** | 500 ALL CAPS |

> ⚠️ 大金額(餘額、Net worth)固定用 **Bricolage 700, -1.8px tracking**;交易列表用 **DM Mono**。這是視覺節奏的核心對比,不要混用。

### 3.3 Spacing(8pt baseline)

| Token | px | 用途 |
|---|---|---|
| `s-1` | 4 | inline gap |
| `s-2` | 8 | tight |
| `s-3` | 12 | chip / badge padding |
| `s-4` | 16 | card padding · row gap |
| `s-5` | 20 | glass card inner padding |
| `s-6` | 24 | section gap |
| `s-7` | 32 | major section break |
| `s-8` | 40 | hero spacing |
| `s-9` | 56 | screen-edge top padding |

### 3.4 Radius

| Token | px | 用途 |
|---|---|---|
| `r-tap` | 8 | small interactive(icon button) |
| `r-chip` | 12 | chips, badges |
| `r-input` | 16 | text fields, secondary buttons |
| `r-glass` | 20 | glass cards |
| `r-card` | 22 | major cards(transaction list, NL bar) |
| `r-pill` | 999 | pills, primary buttons, FAB |
| (phone) | 50 | iPhone bezel(iOS frame mock 用) |

### 3.5 Shadows

```
shadow-glass-light: 0 1px 0 rgba(255,255,255,0.7) inset, 0 8px 24px rgba(180,140,100,0.10);
shadow-glass-dark:  0 1px 0 rgba(255,255,255,0.06) inset, 0 8px 24px rgba(0,0,0,0.40);
shadow-cta:         0 10px 28px rgba(255,149,0,0.35);
shadow-card:        0 30px 80px rgba(180,140,100,0.25);
```
SwiftUI 對應:`.shadow(color: ..., radius: ..., x: 0, y: ...)`,內陰影需用 overlay stroke 模擬。

### 3.6 Motion

| Token | Value | 用途 |
|---|---|---|
| `ease-std` | `cubic-bezier(0.22, 0.9, 0.32, 1)` | 預設,所有畫面切換 / 元件出場 |
| `ease-soft` | `cubic-bezier(0.4, 0, 0.2, 1)` | Sheet / 背景過渡 |
| `dur-fast` | 180ms | tap feedback, ripple |
| `dur-base` | 320ms | screen transitions |
| `dur-reveal` | 480ms | card 飛入、AI 抽取結果展開 |

#### 必要 keyframes(在 `prototypes/NeuLedger Flow Demo.html` `<style>` 中)
- `tapRipple` — 0.6→1.6 scale, opacity 1→0
- `pulseRing` — emphasis ring(等待 AI、tap target hint)
- `confettiFall` — 完成首次記帳的慶祝(translate Y 900px + rotate 720deg)
- `highlightFlash` — 新交易插入時的橘色 flash(rgba(232,131,90,0→0.25→0))
- `rowGrowIn` — 交易 row 從 -8px / scale 0.96 入場
- `celebrateIn` / `celebrateIcon` — 完成卡片
- `bDot` — Bricolage 大寫 B 標誌的呼吸(opacity 0.3↔1)

---

## 4. 畫面詳規

### 4.1 Onboarding · Welcome screen
- **Frame**: iPhone 17 Pro · 402 × 874
- **Background**: warm radial gradient(見上),light mode 為 peach,dark mode 為深棕;再疊兩個 70px blur orange orbs(top-right 220×220 / bottom-left 280×280)。
- **Layout**:
  - 頂部 status bar(模擬 iOS,9:41 / 訊號 / 電池)
  - 中央 stack:Eyebrow(`mono-eyebrow`「NEULEDGER · A NEW WAY TO LEDGER」)→ Display heading(Bricolage 40px / 700 / -1.2px)→ Sub copy(DM Sans 16px,3 行,muted)
  - 底部 CTA:`btn-cta` 全寬,「Get started」+ 右側箭頭。下方一行「Already have an account? · Sign in」(body-s, muted)
- **Interaction**: Tap CTA → push 第二步(spring animation, 320ms ease-std,從右滑入)

### 4.2 Onboarding · Accounts setup
- 同背景。標題「Your accounts」(display-m)+ sub「Pick what you use. You can add more later.」。
- **Account cards** grid(2 列,每列 2 個):Cash / Bank / E-Wallet / Credit · Savings 在第三列佔滿。
  - 每張 card:`r-glass` 20px / `glass-card` 樣式 / 對應 accent 色的 16×16 圓點 / Title(body-l 600)/ subtitle(body-s muted)。
  - **Active state**: 邊框換成 `1.5px solid var(--accent)` + accent 色 16% alpha 填底 + 右上角打勾 icon(SF Symbol `checkmark.circle.fill`,accent 色,16px)。
  - Tap toggle,有 spring scale 0.97 → 1 的 micro-interaction。
- 「+ Add custom account」全寬虛線 outline pill,tap 開 bottom sheet(輸入名字 + 選 icon + 選色)。
- 底部 CTA「Continue」disabled 直到至少選 1 個。

### 4.3 Onboarding · Ready / Done
- **Ready**:大字「You're set.」(Bricolage 56px)+ 三條 checklist(checkmark + label),逐條 stagger fade-in(100ms 間隔)。CTA「Try extraction」開 demo,「Start fresh」直接進首頁。
- **Done celebration**:confetti(8 片紙屑,各自 random `--drift` 與 delay,2.4s) + center 大 emoji icon(`celebrateIcon` 動畫)+「Welcome to NeuLedger」+ auto-redirect to dashboard after 1.6s。

### 4.4 Dashboard
- 同 warm 背景。Top bar:greeting(「Good morning, Tina」)+ avatar(36px round)。
- **Hero**: Glass card(`r-card` 22px, `shadow-card`),內含
  - Eyebrow「NET WORTH · APRIL」
  - 大數字 `Bricolage 56 / 700 / -1.8px`,`+NT$ 128,400`(income 色,正值)
  - 副行 mono-m 「+12.4% from March」(income 色)
  - 底部 sparkline(60px 高,SVG path,accent 色 stroke 2px,fill 12% alpha 漸層)
- **Spend by category**: 橫向 scroll chip-row,每個 chip 顯示 emoji + 類別 + 金額。
- **Recent transactions**: 玻璃卡片 list,每筆 row:
  - 左:48×48 圓 icon(對應帳戶 accent 色 + 12% alpha background)
  - 中:Merchant(body-l 600)+ category(body-s muted)
  - 右:金額(DM Mono 14 / 500 / income or expense 色)+ 時間(body-s muted)
  - 「New」交易加 `badge-new`(income 色 18% alpha)
- **FAB**: 右下角 64×64 pill,CTA gradient,`shadow-cta`,`+` icon。Tap 開 Add transaction sheet。

### 4.5 Add Transaction(NL bar)
- Bottom sheet `r-card` 22px top corners,height auto。Drag handle 36×4 muted。
- **NL input**: 大字 input(Bricolage 24 / 700 / -0.6px),placeholder「Try: lunch sandwich 120」,游標自動聚焦。
- 輸入時下方 `badge-ai`(「AI · ON-DEVICE」income 色)+ 抽取出的欄位 chip-row(amount / category / account / date),每個 chip tap 可編輯。
- 「Save」按鈕 = `btn-pill`(CTA gradient)。Tap 後:
  1. Sheet dismiss(spring 320ms)
  2. Transaction list 頂部 `rowGrowIn` 插入新 row + `highlightFlash` 1.2s

### 4.6 First-run flow(整合 demo)
22 秒自動播放(見 `prototypes/flow-controller.jsx`),敘事:
1. (0-3s) Welcome → tap Get started
2. (3-7s) Accounts → 自動 toggle 3 帳戶 → Continue
3. (7-10s) Ready → Try extraction
4. (10-15s) Dashboard 入場(orbs 旋轉就位、cards stagger)
5. (15-19s) FAB tap → NL「四月薪水 65000」打字 → AI 抽取
6. (19-22s) Save → confetti + dashboard Net worth 從 0 變 +65,000(數字 tween)

---

## 5. 互動與狀態

### 全域 state(建議結構)
```ts
interface AppState {
  user: { name: string };
  accounts: Account[];        // {id, type, name, color, balance}
  transactions: Transaction[]; // {id, accountId, amount, category, merchant, date, source: 'manual'|'nl'|'import'}
  categories: Category[];
  currentMonth: string;        // 'YYYY-MM'
}
```

### 關鍵互動
- **Tap feedback**: 所有 tappable 元件有 scale 0.97(180ms ease-std);glass cards tap 還會有 ripple(從 tap 點 expand)。
- **Sheet dismiss**: drag down > 80px or velocity > 500 → dismiss with spring。
- **Number tween**: Net worth 變化用 lerp 600ms ease-std 跑數字,而不是直接 set。

### Loading / Error
- AI 抽取中:NL bar 右側顯示 3 個 dot `bDot` 動畫。
- AI 失敗:整列 amber background + 「Tap to fix manually」,tap 展開全表單。
- Empty state:transactions list 空時放置「No transactions yet · Tap + to add」+ 一個淡 illustration placeholder。

---

## 6. Assets

- **Fonts**: 透過 Google Fonts CDN 載入(prototype),production 請用本地檔(`.otf`/`.ttf`)避免 FOIT。
- **Icons**: 目前 prototype 多數位置用 SF Symbols 系字串(`checkmark.circle.fill` 等)或 emoji。production iOS 直接用 SF Symbols;Android / Web 推薦 [Lucide](https://lucide.dev)(線條風格與 DM Sans 搭配最佳,粗細 1.5-1.75px)。
- **Illustrations / Logos**: 尚無正式 logo,prototype 中用 Bricolage 大寫 **B** + bDot 呼吸做暫代。需要時再補。
- **Images**: 無實圖。Avatar 為 40px 圓形 placeholder(灰底 + initials)。

---

## 7. Files in this handoff

```
design_handoff_neuledger/
├── README.md                                     ← 你正在讀
├── tokens/
│   ├── tokens.css                                ← Web / RN
│   ├── tokens.json                               ← Style Dictionary input
│   └── Tokens.swift                              ← SwiftUI 直接使用
└── prototypes/                                   ← HTML/JSX 設計稿(reference only)
    ├── NeuLedger Onboarding B.html
    ├── NeuLedger Dashboard.html
    ├── NeuLedger Flow Demo.html                  ← 22 秒自動播放
    ├── NeuLedger Design Tokens.html              ← 視覺化的所有 token
    ├── onboarding-b-prototype.jsx
    ├── onboarding-variations.jsx
    ├── dashboard-b1.jsx
    ├── add-transaction.jsx
    ├── flow-screens.jsx
    ├── flow-controller.jsx
    ├── ios-frame.jsx                             ← iPhone 17 Pro frame mock
    ├── design-canvas.jsx                         ← 並排 viewer(僅設計用,不是產品)
    └── tweaks-panel.jsx                          ← prototype 調參工具(不是產品)
```

直接在瀏覽器開 `prototypes/NeuLedger Flow Demo.html` 看自動播放最快。

---

## 8. 給開發者的建議步驟

1. **先把所有 token 倒進你的 codebase**(`tokens/Tokens.swift` 或 `tokens.css` 改成你 framework 的格式)。
2. **做 Onboarding 第一頁**(視覺 elements 最少,先把背景 + glass card + CTA + Bricolage / DM Sans / DM Mono 三個字體跑起來,確認質感對了再前進)。
3. **做 Dashboard hero card**(沒有它整個 app 就沒 identity)。
4. **做 NL Add Transaction**(這是核心差異點,AI 抽取先用 mock function,再接真模型)。
5. **最後做 onboarding flow + first-run demo 串接**。

> 質感 > 功能。如果背景 gradient 或 glass 模糊感不到位,**停下來解到位再繼續**。NeuLedger 的差異化全在這上面。

---

有任何 spec 不清楚的,直接打開對應 `.jsx` 檔案看 source code,所有數值都在裡面。
