// NeuLedger — Recurring Transaction Management List
// 2 artboards: 01 Populated List · 02 Empty State
// Maps to RecurringTransactionManagementFeature / View (drakehuang81/NeuLedger)
// Reuses accounts.jsx primitives (AccPhone / AccGlass / AccGlyph / ACC_FONTS / ACC_COLORS / accBg)

// ─── Mock data ──────────────────────────────────────────────
// RecurringTransaction → { id, amount, note, type, frequency, accountName, nextDue, isActive, accent, icon }
const RECURRINGS = [
  // Active
  { id: 'r1', note: '薪水', amount: 68000,  type: 'income',  frequency: 'monthly', accountName: '永豐銀行 主帳戶', nextDue: '5/25',  nextDueDays: 10, isActive: true, accent: '#34C759', icon: 'arrow-down-left' },
  { id: 'r2', note: '房租',      amount: 22000, type: 'expense', frequency: 'monthly', accountName: '永豐銀行 主帳戶', nextDue: '6/5',   nextDueDays: 21, isActive: true, accent: '#0A84FF', icon: 'bank' },
  { id: 'r3', note: '健身房 World Gym', amount: 1290, type: 'expense', frequency: 'monthly', accountName: '玉山 Pi', nextDue: '6/1', nextDueDays: 17, isActive: true, accent: '#E8835A', icon: 'arrow-up-right' },
  { id: 'r4', note: 'Netflix Premium', amount: 390, type: 'expense', frequency: 'monthly', accountName: 'Apple Pay', nextDue: '5/15', nextDueDays: 0,  isActive: true, accent: '#FF453A', icon: 'phone' },
  { id: 'r5', note: 'iCloud+ 200GB',   amount: 90,  type: 'expense', frequency: 'monthly', accountName: 'Apple Pay', nextDue: '5/22', nextDueDays: 7,  isActive: true, accent: '#A66BF0', icon: 'phone' },
  { id: 'r6', note: 'YouTube Premium 家庭', amount: 320, type: 'expense', frequency: 'monthly', accountName: 'Apple Pay', nextDue: '5/18', nextDueDays: 3, isActive: true, accent: '#FF6B6B', icon: 'phone' },
  { id: 'r7', note: '汽車保險',  amount: 18400, type: 'expense', frequency: 'yearly',  accountName: '中信信用卡', nextDue: '11/3', nextDueDays: 172, isActive: true, accent: '#5E5CE6', icon: 'card' },
  // Paused
  { id: 'r8', note: '蘋果日報訂閱', amount: 168, type: 'expense', frequency: 'monthly', accountName: 'Apple Pay', nextDue: '—',     nextDueDays: null, isActive: false, accent: '#8B6F47', icon: 'phone' },
  { id: 'r9', note: '通勤月票',   amount: 1280, type: 'expense', frequency: 'monthly', accountName: '悠遊卡', nextDue: '—',     nextDueDays: null, isActive: false, accent: '#34C759', icon: 'card' },
];

const FREQ_LABEL = { weekly: '週', monthly: '月', yearly: '年' };

function fmtMoney(n) {
  return n.toLocaleString('en-US');
}

// ─── Tiny components used inside this file ──────────────────
function FreqPill({ frequency, dark }) {
  const colors = {
    weekly: '#0A84FF',
    monthly: '#E8835A',
    yearly: '#A66BF0',
  };
  const c = colors[frequency];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center',
      padding: '2px 8px', borderRadius: 6,
      background: `${c}1A`,
      color: c,
      fontFamily: ACC_FONTS.mono, fontSize: 10, fontWeight: 600,
      letterSpacing: 0.5, textTransform: 'uppercase',
    }}>
      {FREQ_LABEL[frequency]}
    </span>
  );
}

function ToggleSwitch({ on, dark }) {
  return (
    <div style={{
      width: 44, height: 26, borderRadius: 13,
      background: on ? ACC_COLORS.income : (dark ? 'rgba(120,120,128,0.4)' : 'rgba(120,120,128,0.24)'),
      position: 'relative', transition: 'background 200ms', flexShrink: 0,
    }}>
      <div style={{
        position: 'absolute', top: 2, left: on ? 20 : 2,
        width: 22, height: 22, borderRadius: 11,
        background: '#fff',
        boxShadow: '0 2px 4px rgba(0,0,0,0.16), 0 1px 2px rgba(0,0,0,0.08)',
        transition: 'left 200ms',
      }}/>
    </div>
  );
}

function RecurRow({ item, dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const isIncome = item.type === 'income';
  const sign = isIncome ? '+' : '−';
  const amtColor = !item.isActive ? muted : (isIncome ? ACC_COLORS.income : fg);
  const dueTone = item.nextDueDays === 0 ? ACC_COLORS.warm : (item.nextDueDays != null && item.nextDueDays <= 3 ? ACC_COLORS.warm : muted);

  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '13px 14px',
      opacity: item.isActive ? 1 : 0.62,
    }}>
      {/* Icon block */}
      <div style={{
        width: 38, height: 38, borderRadius: 11,
        background: `${item.accent}1A`,
        border: `0.5px solid ${item.accent}33`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        flexShrink: 0,
        color: item.accent,
      }}>
        <AccGlyph name={item.icon} size={18} color={item.accent} stroke={2}/>
      </div>

      {/* Middle: note + meta */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <div style={{ fontSize: 15, fontWeight: 600, color: fg, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {item.note}
          </div>
          <FreqPill frequency={item.frequency} dark={dark}/>
        </div>
        <div style={{ fontSize: 11.5, color: muted, marginTop: 3, display: 'flex', alignItems: 'center', gap: 5, fontFamily: ACC_FONTS.body }}>
          {item.isActive ? (
            <>
              <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.accountName}</span>
              <span style={{ opacity: 0.4 }}>·</span>
              <span style={{ color: dueTone, fontFamily: ACC_FONTS.mono, letterSpacing: 0.2 }}>
                {item.nextDueDays === 0 ? '今天' : `下次 ${item.nextDue}`}
              </span>
            </>
          ) : (
            <span style={{ fontFamily: ACC_FONTS.mono, letterSpacing: 0.5, textTransform: 'uppercase', fontSize: 10 }}>已暫停</span>
          )}
        </div>
      </div>

      {/* Right: amount + toggle */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexShrink: 0 }}>
        <div style={{
          fontFamily: ACC_FONTS.mono, fontSize: 14, fontWeight: 600,
          color: amtColor, fontVariantNumeric: 'tabular-nums',
          textAlign: 'right',
        }}>
          {sign}NT$ {fmtMoney(item.amount)}
        </div>
        <ToggleSwitch on={item.isActive} dark={dark}/>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 01 / Recurring List — Populated
// ═══════════════════════════════════════════════════════════
function RecurringList({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? ACC_COLORS.warmDark : ACC_COLORS.warm;
  const divider = dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)';

  const active = RECURRINGS.filter(r => r.isActive);
  const paused = RECURRINGS.filter(r => !r.isActive);

  // Monthly commitment math (only monthly frequency active expenses)
  const monthlyOut = active.filter(r => r.type === 'expense' && r.frequency === 'monthly').reduce((s, r) => s + r.amount, 0);
  const monthlyIn  = active.filter(r => r.type === 'income'  && r.frequency === 'monthly').reduce((s, r) => s + r.amount, 0);

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* Nav */}
      <div style={{ padding: '8px 12px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: accent, display: 'flex', alignItems: 'center', gap: 2, fontSize: 16, fontWeight: 500, fontFamily: ACC_FONTS.body }}>
          <AccGlyph name="chevron-left" size={20} color={accent}/> 設定
        </button>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 17, fontWeight: 600, color: fg }}>週期交易</div>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: accent }}>
          <AccGlyph name="plus" size={22} color={accent} stroke={2}/>
        </button>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '14px 16px 100px' }}>
        {/* Summary card — this month's commitment */}
        <AccGlass dark={dark} radius={20} style={{ padding: '18px 20px', marginBottom: 18 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: muted, fontSize: 11, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase' }}>
            <AccGlyph name="sparkle" size={11} color={accent}/> This Month · 固定收支
          </div>

          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 8 }}>
            <span style={{ fontFamily: ACC_FONTS.mono, fontSize: 12, color: muted, fontWeight: 500 }}>淨額</span>
            <span style={{ fontFamily: ACC_FONTS.display, fontSize: 34, fontWeight: 600, color: fg, letterSpacing: -1, lineHeight: 1.05, fontVariantNumeric: 'tabular-nums' }}>
              +NT$ {fmtMoney(monthlyIn - monthlyOut)}
            </span>
          </div>

          <div style={{ display: 'flex', gap: 14, marginTop: 14, paddingTop: 14, borderTop: `0.5px solid ${divider}` }}>
            <div style={{ flex: 1 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 10, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 0.8, textTransform: 'uppercase' }}>
                <AccGlyph name="arrow-down-left" size={10} color={ACC_COLORS.income}/> 收入
              </div>
              <div style={{ fontFamily: ACC_FONTS.mono, fontSize: 15, fontWeight: 600, color: ACC_COLORS.income, marginTop: 2, fontVariantNumeric: 'tabular-nums' }}>
                +NT$ {fmtMoney(monthlyIn)}
              </div>
            </div>
            <div style={{ width: 0.5, background: divider }}/>
            <div style={{ flex: 1 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 10, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 0.8, textTransform: 'uppercase' }}>
                <AccGlyph name="arrow-up-right" size={10} color={muted}/> 支出
              </div>
              <div style={{ fontFamily: ACC_FONTS.mono, fontSize: 15, fontWeight: 600, color: fg, marginTop: 2, fontVariantNumeric: 'tabular-nums' }}>
                −NT$ {fmtMoney(monthlyOut)}
              </div>
            </div>
            <div style={{ width: 0.5, background: divider }}/>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 10, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 0.8, textTransform: 'uppercase' }}>項目</div>
              <div style={{ fontFamily: ACC_FONTS.mono, fontSize: 15, fontWeight: 600, color: fg, marginTop: 2, fontVariantNumeric: 'tabular-nums' }}>
                {active.length} <span style={{ fontSize: 10, color: muted, fontWeight: 500 }}>/ {RECURRINGS.length}</span>
              </div>
            </div>
          </div>
        </AccGlass>

        {/* Section: Active */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 6px 8px' }}>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase' }}>
            進行中 · Active · {active.length}
          </div>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 0.5 }}>
            依下次扣款排序
          </div>
        </div>
        <AccGlass dark={dark} radius={18} style={{ padding: 0, overflow: 'hidden', marginBottom: 18 }}>
          {active.map((item, i) => (
            <React.Fragment key={item.id}>
              <RecurRow item={item} dark={dark}/>
              {i < active.length - 1 && <div style={{ height: 0.5, background: divider, marginLeft: 64 }}/>}
            </React.Fragment>
          ))}
        </AccGlass>

        {/* Section: Paused */}
        {paused.length > 0 && (
          <>
            <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase', padding: '0 6px 8px' }}>
              已暫停 · Paused · {paused.length}
            </div>
            <AccGlass dark={dark} radius={18} style={{ padding: 0, overflow: 'hidden' }}>
              {paused.map((item, i) => (
                <React.Fragment key={item.id}>
                  <RecurRow item={item} dark={dark}/>
                  {i < paused.length - 1 && <div style={{ height: 0.5, background: divider, marginLeft: 64 }}/>}
                </React.Fragment>
              ))}
            </AccGlass>
          </>
        )}

        <div style={{ marginTop: 12, padding: '0 6px', fontSize: 11, color: muted, lineHeight: 1.5 }}>
          切換開關可暫停 / 啟用通知提醒。向左滑動可刪除。點擊任一項目進入編輯。
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 02 / Recurring List — Empty State
// ═══════════════════════════════════════════════════════════
function RecurringEmpty({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? ACC_COLORS.warmDark : ACC_COLORS.warm;
  const divider = dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)';

  // Suggested templates — represents a "smart suggestions" enhancement on top of the bare ContentUnavailableView
  const SUGGESTIONS = [
    { icon: 'phone', label: 'Netflix · 訂閱', sub: '每月 NT$ 390', accent: '#FF453A' },
    { icon: 'bank',  label: '房租 · 固定支出', sub: '每月 NT$ —',  accent: '#0A84FF' },
    { icon: 'arrow-down-left', label: '薪水 · 收入', sub: '每月 NT$ —', accent: '#34C759' },
    { icon: 'phone', label: 'iCloud · 訂閱',  sub: '每月 NT$ 90',  accent: '#A66BF0' },
  ];

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div style={{ padding: '8px 12px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: accent, display: 'flex', alignItems: 'center', gap: 2, fontSize: 16, fontWeight: 500, fontFamily: ACC_FONTS.body }}>
          <AccGlyph name="chevron-left" size={20} color={accent}/> 設定
        </button>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 17, fontWeight: 600, color: fg }}>週期交易</div>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: accent }}>
          <AccGlyph name="plus" size={22} color={accent} stroke={2}/>
        </button>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '40px 20px 100px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        {/* Hero: animated-looking clockwise icon in a glass disc */}
        <div style={{
          width: 96, height: 96, borderRadius: 48,
          background: dark ? 'rgba(232,131,90,0.14)' : 'rgba(232,131,90,0.12)',
          border: `0.5px solid ${dark ? 'rgba(232,131,90,0.25)' : 'rgba(232,131,90,0.22)'}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: accent,
          boxShadow: dark ? '0 0 60px rgba(232,131,90,0.18)' : '0 0 50px rgba(232,131,90,0.16)',
          marginTop: 8, marginBottom: 22,
        }}>
          <svg width={48} height={48} viewBox="0 0 24 24" fill="none" stroke={accent} strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round">
            <path d="M21 12a9 9 0 11-3.2-6.9"/>
            <path d="M21 3v6h-6"/>
          </svg>
        </div>

        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 22, fontWeight: 600, color: fg, letterSpacing: -0.4, textAlign: 'center' }}>
          尚無週期交易
        </div>
        <div style={{ fontSize: 13.5, color: muted, marginTop: 8, lineHeight: 1.55, textAlign: 'center', maxWidth: 280 }}>
          房租、訂閱、薪水…<br/>建立一次,讓 NeuLedger 在每次到期時提醒你。
        </div>

        <button style={{
          marginTop: 22,
          padding: '13px 28px', borderRadius: 14,
          background: accent, color: '#fff', border: 'none', cursor: 'pointer',
          fontFamily: ACC_FONTS.body, fontSize: 15, fontWeight: 600,
          display: 'inline-flex', alignItems: 'center', gap: 6,
          boxShadow: `0 8px 20px ${accent}55`,
        }}>
          <AccGlyph name="plus" size={16} color="#fff" stroke={2.5}/> 新增週期交易
        </button>

        {/* Smart suggestions */}
        <div style={{ width: '100%', marginTop: 36 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase', padding: '0 6px 10px' }}>
            <AccGlyph name="sparkle" size={11} color={ACC_COLORS.ai}/> 從常見項目開始
          </div>
          <AccGlass dark={dark} radius={18} style={{ padding: 0, overflow: 'hidden' }}>
            {SUGGESTIONS.map((s, i) => (
              <React.Fragment key={i}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 14px', cursor: 'pointer' }}>
                  <div style={{
                    width: 36, height: 36, borderRadius: 10,
                    background: `${s.accent}1A`, border: `0.5px solid ${s.accent}33`,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    color: s.accent, flexShrink: 0,
                  }}>
                    <AccGlyph name={s.icon} size={17} color={s.accent} stroke={2}/>
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 14, fontWeight: 600, color: fg }}>{s.label}</div>
                    <div style={{ fontSize: 11, color: muted, marginTop: 2, fontFamily: ACC_FONTS.mono, letterSpacing: 0.3 }}>{s.sub}</div>
                  </div>
                  <AccGlyph name="plus" size={16} color={accent} stroke={2}/>
                </div>
                {i < SUGGESTIONS.length - 1 && <div style={{ height: 0.5, background: divider, marginLeft: 62 }}/>}
              </React.Fragment>
            ))}
          </AccGlass>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// Canvas
// ═══════════════════════════════════════════════════════════
function RecurringCanvas() {
  const dark = false;
  const muted = 'rgba(60,60,67,0.55)';
  const screens = [
    { id: 'list',  label: '01 / Recurring List · Populated', desc: '月固定收支摘要 · Active / Paused 分段 · 倒數高亮今天到期', Comp: RecurringList },
    { id: 'empty', label: '02 / Recurring List · Empty',     desc: 'ContentUnavailableView · CTA + 常見項目 quick-add 建議', Comp: RecurringEmpty },
  ];
  return (
    <div style={{ minHeight: '100vh', background: '#ECE9E2', padding: '40px 24px 80px', fontFamily: ACC_FONTS.body }}>
      <div style={{ maxWidth: 1280, margin: '0 auto 32px' }}>
        <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.4, textTransform: 'uppercase' }}>NeuLedger · Recurring Transactions</div>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 40, fontWeight: 600, letterSpacing: -1, marginTop: 4 }}>週期交易管理</div>
        <div style={{ fontSize: 14, color: muted, marginTop: 6, maxWidth: 620, lineHeight: 1.55 }}>
          對應 <code style={{ fontFamily: ACC_FONTS.mono, fontSize: 13 }}>RecurringTransactionManagementFeature</code>。
          列表頁 — 顯示所有 recurring,可切換 active/paused、點擊進入編輯、左滑刪除。表單頁已在 Missing Screens v1 設計過。
        </div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, max-content)', gap: '40px 32px', justifyContent: 'center' }}>
        {screens.map(s => (
          <div key={s.id} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 402, textAlign: 'left' }}>
              <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase' }}>{s.label}</div>
              <div style={{ fontFamily: ACC_FONTS.display, fontSize: 18, fontWeight: 600, letterSpacing: -0.3, marginTop: 2 }}>{s.desc}</div>
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

ReactDOM.createRoot(document.getElementById('root')).render(<RecurringCanvas/>);
