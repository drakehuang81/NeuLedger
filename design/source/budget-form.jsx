// NeuLedger — Budget Form (Add / Edit)
// Maps to BudgetFormFeature / BudgetFormView (drakehuang81/NeuLedger)
//
// Form sections (per Swift):
//   1 · Name      (TextField + nameError)
//   2 · Amount    (NT$ prefix + TextField + amountError)
//   3 · Period    (Segmented Picker — BudgetPeriod.allCases: weekly/monthly/yearly)
//   4 · StartDate (DatePicker .date)
//   5 · Category  (Picker, optional — only when availableCategories not empty)
//                  First tag is "All expenses" with nil ID, then each .expense category
// Toolbar: Cancel · Save
// Title: add → "新增預算" · edit → "編輯預算"
//
// 3 artboards:
//   01 · Add · 預設 (empty, Save disabled)
//   02 · Add · 已填寫 (name + amount + monthly + 餐飲 category, Save active, w/ per-day breakdown)
//   03 · Edit · amountError (金額 0 或空白 → 紅色錯誤訊息)

// ─── L10n keys ───────────────────────────────────────────────
const BL = {
  cancel: '取消',
  save: '儲存',
  addTitle: '新增預算',
  editTitle: '編輯預算',
  name: '名稱',
  namePlaceholder: '例:餐飲、交通…',
  amount: '預算金額',
  period: '週期',
  startDate: '起始日',
  applyCategory: '套用分類',
  allExpenses: '全部支出',
  allExpensesHint: '選擇分類後,只計算該分類的支出;選「全部支出」則涵蓋所有支出交易。',
  weekly: '每週',
  monthly: '每月',
  yearly: '每年',
  errorNameEmpty: '請輸入預算名稱',
  errorAmountPositive: '金額必須大於 0',
};

// expense-type categories — emulated from CategoryManagement / CategoryType
const EXPENSE_CATEGORIES = [
  { id: 'c1', name: '餐飲',     emoji: '🍜', color: '#FF6B6B' },
  { id: 'c2', name: '交通',     emoji: '🚇', color: '#0A84FF' },
  { id: 'c3', name: '購物',     emoji: '🛒', color: '#E8835A' },
  { id: 'c4', name: '居家',     emoji: '🏠', color: '#1B5E8E' },
  { id: 'c5', name: '娛樂',     emoji: '🎮', color: '#A66BF0' },
  { id: 'c6', name: '健康醫療', emoji: '🩺', color: '#34C759' },
  { id: 'c7', name: '訂閱服務', emoji: '📺', color: '#5E5CE6' },
];

const PERIODS = [
  { id: 'weekly',  label: BL.weekly  },
  { id: 'monthly', label: BL.monthly },
  { id: 'yearly',  label: BL.yearly  },
];

// Display helpers
function fmtMoney2(n) {
  if (!n && n !== 0) return '';
  return Number(n).toLocaleString('en-US');
}

function periodSuffix(p) {
  return { weekly: '週', monthly: '月', yearly: '年' }[p];
}

// Per-period breakdown text
function periodBreakdown(amount, period) {
  if (!amount || amount <= 0) return null;
  if (period === 'monthly') {
    const perDay = Math.round(amount / 30);
    return `≈ NT$${fmtMoney2(perDay)} / 天 · 約 NT$${fmtMoney2(Math.round(amount / 4.33))} / 週`;
  }
  if (period === 'weekly') {
    const perDay = Math.round(amount / 7);
    return `≈ NT$${fmtMoney2(perDay)} / 天`;
  }
  if (period === 'yearly') {
    const perMonth = Math.round(amount / 12);
    return `≈ NT$${fmtMoney2(perMonth)} / 月`;
  }
  return null;
}

// ─── Atoms ───────────────────────────────────────────────────
function BFormNavBar({ dark, title, canSave }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const accent = ACC_COLORS.warm;
  return (
    <div style={{
      padding: '8px 16px 10px',
      display: 'grid', gridTemplateColumns: '1fr auto 1fr', alignItems: 'center',
      borderBottom: `0.5px solid ${dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)'}`,
    }}>
      <button style={{ background: 'transparent', border: 'none', padding: '4px 0', justifySelf: 'start', color: accent, fontSize: 16, fontFamily: ACC_FONTS.body, cursor: 'pointer' }}>{BL.cancel}</button>
      <div style={{ fontSize: 17, fontWeight: 600, color: fg, letterSpacing: -0.2, fontFamily: ACC_FONTS.display }}>{title}</div>
      <button disabled={!canSave} style={{
        background: 'transparent', border: 'none', padding: '4px 0', justifySelf: 'end',
        color: !canSave ? (dark ? 'rgba(235,235,245,0.3)' : 'rgba(60,60,67,0.3)') : accent,
        fontSize: 16, fontWeight: 600, fontFamily: ACC_FONTS.body, cursor: !canSave ? 'not-allowed' : 'pointer',
      }}>{BL.save}</button>
    </div>
  );
}

function BSectionHeader({ dark, children }) {
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  return (
    <div style={{ padding: '0 6px 8px', fontSize: 11, fontFamily: ACC_FONTS.mono, color: muted, letterSpacing: 1.2, textTransform: 'uppercase' }}>{children}</div>
  );
}

function BFormSection({ dark, header, footer, children }) {
  return (
    <div style={{ marginBottom: 22 }}>
      {header && <BSectionHeader dark={dark}>{header}</BSectionHeader>}
      <AccGlass dark={dark} radius={14} style={{ padding: 0, overflow: 'hidden' }}>
        {children}
      </AccGlass>
      {footer && (
        <div style={{ padding: '8px 6px 0', fontSize: 12, color: dark ? 'rgba(235,235,245,0.5)' : 'rgba(60,60,67,0.5)', lineHeight: 1.45 }}>{footer}</div>
      )}
    </div>
  );
}

// Name field
function BNameInput({ dark, value, error, focused }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.45)' : 'rgba(60,60,67,0.45)';
  const isEmpty = !value;
  return (
    <div style={{ padding: '12px 16px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <div style={{ flex: 1, fontSize: 17, color: isEmpty ? muted : fg, fontFamily: ACC_FONTS.body, letterSpacing: -0.2 }}>
          {isEmpty ? BL.namePlaceholder : value}
          {focused && <span style={{ display: 'inline-block', width: 2, height: 20, background: ACC_COLORS.warm, verticalAlign: 'middle', marginLeft: 2, animation: 'caret 1s infinite' }}/>}
        </div>
      </div>
      {error && <ErrorText dark={dark}>{error}</ErrorText>}
    </div>
  );
}

// Amount field — big-number style for emphasis (since this is the central input)
function BAmountInput({ dark, value, period, error, focused }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const isEmpty = !value;
  return (
    <div style={{ padding: '14px 16px' }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
        <span style={{ color: muted, fontFamily: ACC_FONTS.mono, fontSize: 15, fontWeight: 500, letterSpacing: 0.5 }}>NT$</span>
        <div style={{ flex: 1, fontSize: 32, fontFamily: ACC_FONTS.mono, fontWeight: 500, color: isEmpty ? muted : fg, letterSpacing: -1, fontVariantNumeric: 'tabular-nums', lineHeight: 1.1 }}>
          {isEmpty ? '0' : fmtMoney2(value)}
          {focused && <span style={{ display: 'inline-block', width: 2, height: 30, background: ACC_COLORS.warm, verticalAlign: 'middle', marginLeft: 2, animation: 'caret 1s infinite' }}/>}
        </div>
        <span style={{ color: muted, fontFamily: ACC_FONTS.body, fontSize: 14 }}>/ {periodSuffix(period)}</span>
      </div>
      {/* Breakdown helper */}
      {!isEmpty && !error && periodBreakdown(Number(value), period) && (
        <div style={{ marginTop: 6, fontSize: 12, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: -0.1 }}>
          {periodBreakdown(Number(value), period)}
        </div>
      )}
      {error && <ErrorText dark={dark}>{error}</ErrorText>}
    </div>
  );
}

function ErrorText({ children, dark }) {
  return (
    <div style={{ marginTop: 8, display: 'flex', alignItems: 'flex-start', gap: 6 }}>
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={ACC_COLORS.expense} strokeWidth="2" strokeLinecap="round" style={{ marginTop: 1 }}>
        <circle cx="12" cy="12" r="9"/>
        <path d="M12 7v6M12 16v0"/>
      </svg>
      <div style={{ fontSize: 12.5, color: ACC_COLORS.expense, lineHeight: 1.4, letterSpacing: -0.1 }}>{children}</div>
    </div>
  );
}

// iOS-style segmented picker
function PeriodSegmented({ dark, value }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  return (
    <div style={{ padding: '12px 16px' }}>
      <div style={{
        display: 'flex',
        padding: 2,
        borderRadius: 9,
        background: dark ? 'rgba(120,120,128,0.32)' : 'rgba(120,120,128,0.12)',
        gap: 2,
      }}>
        {PERIODS.map(p => {
          const active = p.id === value;
          return (
            <div key={p.id} style={{
              flex: 1,
              padding: '7px 0',
              borderRadius: 7,
              textAlign: 'center',
              background: active ? (dark ? '#3A3A3C' : '#fff') : 'transparent',
              boxShadow: active
                ? '0 3px 8px rgba(0,0,0,0.12), 0 0 0 0.5px rgba(0,0,0,0.04)'
                : 'none',
              fontFamily: ACC_FONTS.body, fontSize: 14, fontWeight: active ? 600 : 500,
              color: fg,
              cursor: 'pointer',
              transition: 'all 150ms',
            }}>{p.label}</div>
          );
        })}
      </div>
    </div>
  );
}

// DatePicker .date — iOS compact pill style
function DatePill({ dark, date }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  return (
    <div style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
      <div style={{ flex: 1, fontSize: 16, color: fg, letterSpacing: -0.1 }}>{BL.startDate}</div>
      <div style={{
        display: 'inline-flex', alignItems: 'center', gap: 6,
        padding: '6px 11px', borderRadius: 8,
        background: dark ? 'rgba(120,120,128,0.24)' : 'rgba(120,120,128,0.16)',
        fontFamily: ACC_FONTS.body, fontSize: 16, fontWeight: 400,
        color: fg, letterSpacing: -0.1,
      }}>
        <span style={{ fontFamily: ACC_FONTS.mono, fontVariantNumeric: 'tabular-nums' }}>{date}</span>
      </div>
    </div>
  );
}

// Category picker — radio-style list, since "All expenses" + N categories matters
function CategoryPicker({ dark, selected }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const items = [
    { id: null, name: BL.allExpenses, emoji: '∗', color: ACC_COLORS.warm, isAll: true },
    ...EXPENSE_CATEGORIES,
  ];
  return (
    <div>
      {items.map((it, i) => {
        const active = (selected === undefined ? null : selected) === it.id;
        return (
          <div key={String(it.id)}>
            <div style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{
                width: 32, height: 32, borderRadius: 16, flexShrink: 0,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                background: `${it.color}1F`,
                color: it.color,
                fontSize: it.isAll ? 18 : 16,
                fontFamily: it.isAll ? ACC_FONTS.display : 'system-ui',
                fontWeight: it.isAll ? 700 : 400,
              }}>{it.emoji}</div>
              <div style={{ flex: 1, fontSize: 15.5, color: fg, letterSpacing: -0.1 }}>{it.name}</div>
              {active ? (
                <AccGlyph name="check" size={20} color={ACC_COLORS.warm} stroke={2.6}/>
              ) : null}
            </div>
            {i < items.length - 1 && <div style={{ height: 0.5, marginLeft: 60, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(60,60,67,0.10)' }}/>}
          </div>
        );
      })}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 01 · Add · 預設
// ═══════════════════════════════════════════════════════════
function BudgetFormAddDefault({ dark }) {
  const state = {
    name: '', amount: '',
    period: 'monthly',
    startDate: '2026 / 05 / 15',
    categoryId: null,
  };
  return (
    <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <BFormNavBar dark={dark} title={BL.addTitle} canSave={false}/>
      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 16px 100px' }}>
        <BFormSection dark={dark} header={BL.name}>
          <BNameInput dark={dark} value="" focused/>
        </BFormSection>

        <BFormSection dark={dark} header={BL.amount}>
          <BAmountInput dark={dark} value="" period={state.period}/>
        </BFormSection>

        <BFormSection dark={dark} header={BL.period}>
          <PeriodSegmented dark={dark} value={state.period}/>
        </BFormSection>

        <BFormSection dark={dark} header={BL.startDate}>
          <DatePill dark={dark} date={state.startDate}/>
        </BFormSection>

        <BFormSection dark={dark} header={BL.applyCategory} footer={BL.allExpensesHint}>
          <CategoryPicker dark={dark} selected={null}/>
        </BFormSection>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 02 · Add · 已填寫
// ═══════════════════════════════════════════════════════════
function BudgetFormAddFilled({ dark }) {
  const state = {
    name: '餐飲',
    amount: 8000,
    period: 'monthly',
    startDate: '2026 / 05 / 01',
    categoryId: 'c1',
  };
  return (
    <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <BFormNavBar dark={dark} title={BL.addTitle} canSave={true}/>
      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 16px 100px' }}>
        <BFormSection dark={dark} header={BL.name}>
          <BNameInput dark={dark} value={state.name}/>
        </BFormSection>

        <BFormSection dark={dark} header={BL.amount}>
          <BAmountInput dark={dark} value={state.amount} period={state.period}/>
        </BFormSection>

        <BFormSection dark={dark} header={BL.period}>
          <PeriodSegmented dark={dark} value={state.period}/>
        </BFormSection>

        <BFormSection dark={dark} header={BL.startDate}>
          <DatePill dark={dark} date={state.startDate}/>
        </BFormSection>

        <BFormSection dark={dark} header={BL.applyCategory} footer={BL.allExpensesHint}>
          <CategoryPicker dark={dark} selected={state.categoryId}/>
        </BFormSection>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 03 · Edit · amount 驗證錯誤
// ═══════════════════════════════════════════════════════════
function BudgetFormEditError({ dark }) {
  const state = {
    name: '訂閱服務',
    amount: '0',  // triggers amountError
    period: 'monthly',
    startDate: '2026 / 01 / 01',
    categoryId: 'c7',
    amountError: BL.errorAmountPositive,
  };
  return (
    <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <BFormNavBar dark={dark} title={BL.editTitle} canSave={true}/>
      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 16px 100px' }}>
        <BFormSection dark={dark} header={BL.name}>
          <BNameInput dark={dark} value={state.name}/>
        </BFormSection>

        <BFormSection dark={dark} header={BL.amount}>
          <BAmountInput dark={dark} value="" period={state.period} error={state.amountError} focused/>
        </BFormSection>

        <BFormSection dark={dark} header={BL.period}>
          <PeriodSegmented dark={dark} value={state.period}/>
        </BFormSection>

        <BFormSection dark={dark} header={BL.startDate}>
          <DatePill dark={dark} date={state.startDate}/>
        </BFormSection>

        <BFormSection dark={dark} header={BL.applyCategory} footer={BL.allExpensesHint}>
          <CategoryPicker dark={dark} selected={state.categoryId}/>
        </BFormSection>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// Canvas
// ═══════════════════════════════════════════════════════════
function BudgetFormCanvas() {
  const dark = false;
  const muted = 'rgba(60,60,67,0.55)';
  const screens = [
    { id: 'add',     label: '01 / Add · Defaults',         desc: 'mode = .add · empty name & amount · Save disabled', Comp: BudgetFormAddDefault },
    { id: 'filled',  label: '02 / Add · Filled',           desc: 'NT$8,000 / 月 · 餐飲分類 · 即時換算 per-day',           Comp: BudgetFormAddFilled },
    { id: 'error',   label: '03 / Edit · Amount error',    desc: 'mode = .edit(budget) · amountError 顯示',                Comp: BudgetFormEditError },
  ];
  return (
    <div style={{ minHeight: '100vh', background: '#ECE9E2', padding: '40px 24px 80px', fontFamily: ACC_FONTS.body }}>
      <style>{`@keyframes caret { 0%, 50% { opacity: 1 } 51%, 100% { opacity: 0 } }`}</style>
      <div style={{ maxWidth: 1280, margin: '0 auto 32px' }}>
        <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.4, textTransform: 'uppercase' }}>NeuLedger · Budget › Add / Edit</div>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 40, fontWeight: 600, letterSpacing: -1, marginTop: 4 }}>新增 / 編輯預算</div>
        <div style={{ fontSize: 14, color: muted, marginTop: 6, maxWidth: 720, lineHeight: 1.55 }}>
          對應 <code style={{ fontFamily: ACC_FONTS.mono, fontSize: 13 }}>BudgetFormFeature</code> · <code style={{ fontFamily: ACC_FONTS.mono, fontSize: 13 }}>BudgetFormView</code>。
          5 個 Form section — Name(+ nameError)、Amount(NT$ prefix · 大字級 · 含 per-day 換算)、Period(segmented: 週/月/年)、Start Date、Category(可選 · 含「全部支出」選項)。
        </div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, max-content)', gap: '40px 28px', justifyContent: 'center' }}>
        {screens.map(s => (
          <div key={s.id} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 402, textAlign: 'left' }}>
              <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase' }}>{s.label}</div>
              <div style={{ fontFamily: ACC_FONTS.display, fontSize: 17, fontWeight: 600, letterSpacing: -0.3, marginTop: 2 }}>{s.desc}</div>
            </div>
            <div data-screen-label={s.label}>
              <AccPhone dark={dark}>
                <s.Comp dark={dark}/>
              </AccPhone>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<BudgetFormCanvas/>);
