// NeuLedger Dashboard — B1 (warm) tone · 2 layout variants
// Interactive: scrollable, tappable rows, AI insight carousel, quick-add sheet

const { useState: useS, useEffect: useE, useRef: useR } = React;

// Mock data
const TXNS = [
  { id: 1, name: '星巴克 latte', cat: '飲食', icon: 'banknote', color: '#FF9500', amount: -165, account: '悠遊卡', when: 'Today · 9:42', tags: ['#morning'] },
  { id: 2, name: 'Uber 計程車', cat: '交通', icon: 'phone', color: '#5E5CE6', amount: -280, account: '玉山銀行', when: 'Today · 8:15', tags: ['#commute'] },
  { id: 3, name: '7-11 早餐', cat: '飲食', icon: 'banknote', color: '#FF9500', amount: -85, account: 'Cash', when: 'Today · 7:30', tags: [] },
  { id: 4, name: 'Salary 薪資', cat: 'Income', icon: 'wallet', color: '#34C759', amount: 65000, account: '玉山銀行', when: 'Yesterday', tags: ['#monthly'] },
  { id: 5, name: '誠品書店', cat: '購物', icon: 'creditcard', color: '#FF2D55', amount: -1250, account: 'Visa', when: 'Yesterday', tags: ['#books'] },
  { id: 6, name: '加油站 中油', cat: '交通', icon: 'phone', color: '#5E5CE6', amount: -1840, account: 'Visa', when: '23 Apr', tags: [] },
  { id: 7, name: '麥當勞', cat: '飲食', icon: 'banknote', color: '#FF9500', amount: -195, account: '悠遊卡', when: '23 Apr', tags: [] },
  { id: 8, name: 'Netflix', cat: '娛樂', icon: 'creditcard', color: '#FF2D55', amount: -390, account: 'Visa', when: '22 Apr', tags: ['#monthly'] },
];

const INSIGHTS = [
  {
    title: '飲食支出比上週多 32%',
    body: '本週 NT$ 2,140 · 上週 NT$ 1,620。三筆 latte 占了 NT$ 495。',
    metric: '+32%',
    metricColor: '#FF3B30',
    cta: '看分類細節',
  },
  {
    title: '玉山銀行週四常被刷',
    body: '過去 4 個週四,平均 NT$ 1,450。下個發薪日是 5/5。',
    metric: 'Pattern',
    metricColor: '#0A84FF',
    cta: '設定提醒',
  },
  {
    title: '本月可省下約 NT$ 4,200',
    body: '若把 latte 從 12 杯降到 6 杯 · 模型推估。',
    metric: '−NT$4,200',
    metricColor: '#34C759',
    cta: '建立目標',
  },
];

const ACCOUNT_CHIPS = [
  { name: 'Cash', amount: 3200, color: '#8E8E93', icon: 'banknote' },
  { name: '玉山', amount: 48930, color: '#0A84FF', icon: 'wallet' },
  { name: '悠遊卡', amount: 420, color: '#5E5CE6', icon: 'phone' },
  { name: 'Visa', amount: -8430, color: '#FF2D55', icon: 'creditcard' },
];

const fmt = (n) => Math.abs(n).toLocaleString();

// B1 warm bg
function dashBg(dark) {
  return dark
    ? 'radial-gradient(ellipse at 50% -20%, #4A2A0E 0%, #1a0f08 35%, #050505 70%)'
    : 'radial-gradient(ellipse at 50% -20%, #FFE4B8 0%, #FFF6E8 35%, #FAFAF7 70%)';
}

// ─────────────────────────────────────────────────────────────
// Top bar (avatar + greeting + ai sparkle)
// ─────────────────────────────────────────────────────────────
function DashTopBar({ dark, dense, onAi }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: dense ? '0 22px 8px' : '0 22px 12px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{
          width: 36, height: 36, borderRadius: 18,
          background: `linear-gradient(135deg, ${COLORS.accent}, #FF2D55)`,
          color: '#fff', fontFamily: FONTS.display, fontSize: 14, fontWeight: 700,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: `0 4px 12px ${COLORS.accent}40`,
        }}>D</div>
        <div>
          <div style={{ fontFamily: FONTS.body, fontSize: 12, color: muted, letterSpacing: -0.1 }}>Friday · 25 Apr</div>
          <div style={{ fontFamily: FONTS.display, fontSize: 17, fontWeight: 600, color: fg, letterSpacing: -0.4 }}>Hi, Drake</div>
        </div>
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        <Tappable onClick={onAi}>
          <Glass dark={dark} radius={20} style={{ width: 40, height: 40, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Glyph name="sparkles" size={18} color={dark ? COLORS.accentDark : COLORS.accent}/>
          </Glass>
        </Tappable>
        <Glass dark={dark} radius={20} style={{ width: 40, height: 40, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
            <circle cx="11" cy="11" r="7" stroke={fg} strokeWidth="2"/>
            <path d="M20 20l-4-4" stroke={fg} strokeWidth="2" strokeLinecap="round"/>
          </svg>
        </Glass>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Account chip strip (horizontal)
// ─────────────────────────────────────────────────────────────
function AccountChips({ dark, active, setActive }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  return (
    <div style={{ display: 'flex', gap: 8, padding: '8px 22px 0', overflowX: 'auto' }}>
      <Tappable onClick={() => setActive('all')}>
        <div style={{
          padding: '6px 12px', borderRadius: 999, whiteSpace: 'nowrap',
          background: active === 'all' ? COLORS.accent : (dark ? 'rgba(255,255,255,0.06)' : 'rgba(255,255,255,0.55)'),
          backdropFilter: 'blur(10px)',
          color: active === 'all' ? '#fff' : fg,
          fontFamily: FONTS.body, fontSize: 13, fontWeight: 500, letterSpacing: -0.1,
          border: active === 'all' ? 'none' : (dark ? '0.5px solid rgba(255,255,255,0.1)' : '0.5px solid rgba(0,0,0,0.05)'),
        }}>All accounts</div>
      </Tappable>
      {ACCOUNT_CHIPS.map((a, i) => (
        <Tappable key={i} onClick={() => setActive(a.name)}>
          <div style={{
            padding: '6px 12px', borderRadius: 999, whiteSpace: 'nowrap',
            background: active === a.name ? a.color : (dark ? 'rgba(255,255,255,0.06)' : 'rgba(255,255,255,0.55)'),
            backdropFilter: 'blur(10px)',
            color: active === a.name ? '#fff' : fg,
            fontFamily: FONTS.body, fontSize: 13, fontWeight: 500, letterSpacing: -0.1,
            display: 'flex', alignItems: 'center', gap: 6,
            border: active === a.name ? 'none' : (dark ? '0.5px solid rgba(255,255,255,0.1)' : '0.5px solid rgba(0,0,0,0.05)'),
          }}>
            <div style={{ width: 6, height: 6, borderRadius: 3, background: active === a.name ? '#fff' : a.color }}/>
            {a.name}
            <span style={{ fontFamily: FONTS.mono, fontSize: 11, opacity: 0.85 }}>
              {a.amount < 0 ? '−' : ''}{fmt(a.amount)}
            </span>
          </div>
        </Tappable>
      ))}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Hero balance card (spacious version)
// ─────────────────────────────────────────────────────────────
function HeroBalance({ dark, accent, big = true, empty = false }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const bars = [38, 52, 28, 64, 70, 46, 58]; // sparkline-ish weekly spend
  const max = Math.max(...bars);
  return (
    <Glass dark={dark} radius={28} style={{ padding: big ? '20px 22px' : '16px 18px', margin: '0 22px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
        <div>
          <div style={{ fontFamily: FONTS.body, fontSize: 12, color: muted, letterSpacing: -0.1, marginBottom: 4 }}>{empty ? '總資產 · 尚未開始' : 'Total balance · April'}</div>
          <div style={{ fontFamily: FONTS.mono, fontSize: big ? 40 : 32, fontWeight: 500, color: fg, letterSpacing: -1.2, lineHeight: 1 }}>
            <span style={{ fontSize: big ? 16 : 14, color: muted, marginRight: 5, fontWeight: 400 }}>NT$</span>
            {empty ? '0' : '44,120'}
          </div>
        </div>
        {!empty && (
          <div style={{ textAlign: 'right' }}>
            <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1.2, marginBottom: 4 }}>Net</div>
            <div style={{
              padding: '4px 10px', borderRadius: 999,
              background: dark ? 'rgba(48,209,88,0.18)' : 'rgba(52,199,89,0.14)',
              color: dark ? COLORS.incomeDark : COLORS.income,
              fontFamily: FONTS.mono, fontSize: 12, fontWeight: 600, letterSpacing: -0.1,
            }}>↑ +NT$ 12,400</div>
          </div>
        )}
      </div>

      {!empty && (
        <div style={{ display: 'flex', gap: 12, marginTop: big ? 18 : 14, alignItems: 'flex-end' }}>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', gap: 12 }}>
            <div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 9, color: muted, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 2 }}>In</div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 14, fontWeight: 500, color: dark ? COLORS.incomeDark : COLORS.income, letterSpacing: -0.2 }}>+65,000</div>
            </div>
            <div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 9, color: muted, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 2 }}>Out</div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 14, fontWeight: 500, color: dark ? COLORS.expenseDark : COLORS.expense, letterSpacing: -0.2 }}>−52,600</div>
            </div>
          </div>
        </div>
        {/* sparkline bars */}
        <div style={{ display: 'flex', gap: 3, alignItems: 'flex-end', height: 30 }}>
          {bars.map((b, i) => (
            <div key={i} style={{
              width: 5, height: (b / max) * 30, borderRadius: 2,
              background: i === bars.length - 1 ? accent : (dark ? 'rgba(255,255,255,0.25)' : 'rgba(0,0,0,0.18)'),
            }}/>
          ))}
        </div>
      </div>
      )}
    </Glass>
  );
}

// ─────────────────────────────────────────────────────────────
// Compact stats row (for D2)
// ─────────────────────────────────────────────────────────────
function StatsRow({ dark, accent }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const items = [
    { k: 'Today', v: '−530', c: dark ? COLORS.expenseDark : COLORS.expense },
    { k: 'This week', v: '−4,160', c: fg },
    { k: 'Saved', v: '32%', c: dark ? COLORS.incomeDark : COLORS.income },
  ];
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8, padding: '8px 22px 0' }}>
      {items.map((it, i) => (
        <Glass key={i} dark={dark} radius={16} style={{ padding: '10px 12px' }}>
          <div style={{ fontFamily: FONTS.mono, fontSize: 9, color: muted, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 2 }}>{it.k}</div>
          <div style={{ fontFamily: FONTS.mono, fontSize: 16, fontWeight: 500, color: it.c, letterSpacing: -0.3 }}>
            {it.v.startsWith('-') || it.v.startsWith('−') ? <span style={{ fontSize: 9, color: muted, marginRight: 2 }}>NT$</span> : null}
            {it.v}
          </div>
        </Glass>
      ))}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// AI insight carousel
// ─────────────────────────────────────────────────────────────
function InsightCarousel({ dark, accent, dense }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const [idx, setIdx] = useS(0);
  const ins = INSIGHTS[idx];
  return (
    <div style={{ padding: '0 22px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <Glyph name="sparkles" size={13} color={accent}/>
          <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1.2, fontWeight: 500 }}>
            On-device insight · {idx + 1}/{INSIGHTS.length}
          </div>
        </div>
        <div style={{ display: 'flex', gap: 4 }}>
          {INSIGHTS.map((_, i) => (
            <Tappable key={i} onClick={() => setIdx(i)}>
              <div style={{
                width: i === idx ? 16 : 5, height: 5, borderRadius: 3,
                background: i === idx ? accent : (dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.15)'),
                transition: 'all .25s',
              }}/>
            </Tappable>
          ))}
        </div>
      </div>
      <Glass dark={dark} radius={22} style={{ padding: dense ? '14px 16px' : '16px 18px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 6 }}>
          <div style={{ fontFamily: FONTS.display, fontSize: dense ? 16 : 17, fontWeight: 600, color: fg, letterSpacing: -0.3, lineHeight: 1.3, flex: 1, paddingRight: 8 }}>
            {ins.title}
          </div>
          <div style={{
            padding: '3px 9px', borderRadius: 999,
            background: ins.metricColor + '22',
            color: ins.metricColor,
            fontFamily: FONTS.mono, fontSize: 11, fontWeight: 600, letterSpacing: -0.1, whiteSpace: 'nowrap',
          }}>{ins.metric}</div>
        </div>
        <div style={{ fontFamily: FONTS.body, fontSize: 13, color: muted, lineHeight: 1.45, letterSpacing: -0.1, marginBottom: 12 }}>
          {ins.body}
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Tappable onClick={() => setIdx((idx + 1) % INSIGHTS.length)}>
            <div style={{
              fontFamily: FONTS.body, fontSize: 13, fontWeight: 600, color: accent,
              display: 'flex', alignItems: 'center', gap: 4,
            }}>
              {ins.cta}
              <Glyph name="arrow-right" size={14} color={accent} stroke={2}/>
            </div>
          </Tappable>
          <Tappable onClick={() => setIdx((idx + 1) % INSIGHTS.length)}>
            <div style={{ fontFamily: FONTS.body, fontSize: 12, color: muted }}>Next →</div>
          </Tappable>
        </div>
      </Glass>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Transaction row
// ─────────────────────────────────────────────────────────────
function TxnRow({ tx, dark, dense, onTap, expanded }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const isIncome = tx.amount > 0;
  const amountColor = isIncome ? (dark ? COLORS.incomeDark : COLORS.income) : fg;
  return (
    <Tappable onClick={() => onTap(tx.id)}>
      <div style={{
        padding: dense ? '10px 14px' : '14px 16px',
        borderRadius: 16,
        background: expanded ? (dark ? 'rgba(255,255,255,0.04)' : 'rgba(255,255,255,0.5)') : 'transparent',
        transition: `background .2s ${EASE}`,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: dense ? 34 : 38, height: dense ? 34 : 38, borderRadius: 11,
            background: tx.color + '22',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            flexShrink: 0,
          }}>
            <Glyph name={tx.icon} size={dense ? 17 : 19} color={tx.color}/>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 8 }}>
              <div style={{
                fontFamily: FONTS.body, fontSize: dense ? 14 : 15, fontWeight: 500, color: fg, letterSpacing: -0.15,
                whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
              }}>{tx.name}</div>
              <div style={{ fontFamily: FONTS.mono, fontSize: dense ? 14 : 15, fontWeight: 500, color: amountColor, letterSpacing: -0.2, whiteSpace: 'nowrap' }}>
                {isIncome ? '+' : '−'}<span style={{ fontSize: dense ? 9 : 10, color: muted, marginRight: 1 }}>NT$</span>{fmt(tx.amount)}
              </div>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 2, gap: 6 }}>
              <div style={{
                fontFamily: FONTS.body, fontSize: 11, color: muted,
                whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
              }}>{tx.cat} · {tx.account}</div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, letterSpacing: 0.2, whiteSpace: 'nowrap' }}>{tx.when}</div>
            </div>
          </div>
        </div>
        {expanded && (
          <div style={{
            marginTop: 10, paddingTop: 10,
            borderTop: dark ? '0.5px solid rgba(255,255,255,0.08)' : '0.5px solid rgba(0,0,0,0.06)',
            display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap',
          }}>
            {tx.tags.length > 0 && tx.tags.map((t, i) => (
              <div key={i} style={{
                padding: '3px 8px', borderRadius: 999,
                background: dark ? 'rgba(255,159,10,0.18)' : 'rgba(255,149,0,0.14)',
                fontFamily: FONTS.mono, fontSize: 10, color: dark ? COLORS.accentDark : COLORS.accent, fontWeight: 500,
              }}>{t}</div>
            ))}
            <div style={{ flex: 1 }}/>
            <div style={{ fontFamily: FONTS.body, fontSize: 11, color: muted, display: 'flex', alignItems: 'center', gap: 4 }}>
              <Glyph name="edit" size={11} color={muted} stroke={1.5}/> Edit
            </div>
          </div>
        )}
      </div>
    </Tappable>
  );
}

// ─────────────────────────────────────────────────────────────
// Tab bar — 3 separated round icons (per reference)
// Left: Ledger · Center: + FAB (larger) · Right: Search
// ─────────────────────────────────────────────────────────────
function SeparatedTabBar({ dark, active = 'ledger', onAdd, onTab }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;

  const RoundBtn = ({ children, onClick, isActive, size = 52 }) => (
    <Tappable onClick={onClick}>
      <Glass dark={dark} radius={size / 2} style={{
        width: size, height: size,
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column',
        boxShadow: dark ? '0 6px 20px rgba(0,0,0,0.4)' : '0 6px 20px rgba(0,0,0,0.10)',
        background: isActive
          ? (dark ? 'rgba(255,159,10,0.18)' : 'rgba(255,149,0,0.14)')
          : (dark ? 'rgba(28,28,30,0.85)' : 'rgba(255,255,255,0.82)'),
        border: isActive
          ? (dark ? '0.5px solid rgba(255,159,10,0.35)' : '0.5px solid rgba(255,149,0,0.3)')
          : (dark ? '0.5px solid rgba(255,255,255,0.08)' : '0.5px solid rgba(0,0,0,0.05)'),
      }}>
        {children}
      </Glass>
    </Tappable>
  );

  return (
    <div style={{
      position: 'absolute', bottom: 22, left: 0, right: 0, zIndex: 30,
      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      padding: '0 30px',
      pointerEvents: 'none',
    }}>
      <div style={{ pointerEvents: 'auto' }}>
        <RoundBtn isActive={active === 'ledger'} onClick={() => onTab && onTab('ledger')} size={52}>
          {/* Pie/ledger icon */}
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
            <path d="M12 3a9 9 0 109 9h-9V3z" fill={active === 'ledger' ? accent : 'none'} stroke={active === 'ledger' ? accent : muted} strokeWidth="1.8" strokeLinejoin="round"/>
            <path d="M12 3a9 9 0 019 9" stroke={active === 'ledger' ? accent : muted} strokeWidth="1.8" strokeLinecap="round"/>
          </svg>
          <div style={{
            fontFamily: FONTS.body, fontSize: 9, fontWeight: 600, marginTop: 1,
            color: active === 'ledger' ? accent : muted, letterSpacing: -0.1,
          }}>Ledger</div>
        </RoundBtn>
      </div>

      <div style={{ pointerEvents: 'auto' }}>
        <Tappable onClick={onAdd}>
          <div style={{
            width: 64, height: 64, borderRadius: 32,
            background: `linear-gradient(135deg, ${accent}, #FF6A00)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: `0 8px 22px ${accent}60, 0 0 0 4px ${dark ? 'rgba(0,0,0,0.4)' : 'rgba(255,255,255,0.6)'}`,
          }}>
            <Glyph name="plus" size={26} color="#fff" stroke={2.6}/>
          </div>
        </Tappable>
      </div>

      <div style={{ pointerEvents: 'auto' }}>
        <RoundBtn isActive={active === 'search'} onClick={() => onTab && onTab('search')} size={52}>
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
            <circle cx="11" cy="11" r="7" stroke={active === 'search' ? accent : (dark ? '#fff' : '#0A0A0A')} strokeWidth="2"/>
            <path d="M20 20l-4-4" stroke={active === 'search' ? accent : (dark ? '#fff' : '#0A0A0A')} strokeWidth="2" strokeLinecap="round"/>
          </svg>
        </RoundBtn>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Empty state — 尚無交易 (per reference)
// ─────────────────────────────────────────────────────────────
function EmptyTransactions({ dark, onAdd }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;
  return (
    <div style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center',
      padding: '28px 22px 20px',
    }}>
      {/* Archive / inbox icon in circle */}
      <div style={{
        width: 72, height: 72, borderRadius: 36,
        background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        marginBottom: 14,
        border: dark ? '0.5px solid rgba(255,255,255,0.08)' : '0.5px solid rgba(0,0,0,0.05)',
      }}>
        {/* Archive box: trapezoid lid + body with handle slot */}
        <svg width="34" height="34" viewBox="0 0 32 32" fill="none">
          <rect x="4" y="6" width="24" height="6" rx="2" stroke={muted} strokeWidth="1.8"/>
          <path d="M6 12v12a2 2 0 002 2h16a2 2 0 002-2V12" stroke={muted} strokeWidth="1.8" strokeLinejoin="round"/>
          <path d="M12 17h8" stroke={muted} strokeWidth="1.8" strokeLinecap="round"/>
        </svg>
      </div>
      <div style={{
        fontFamily: FONTS.display, fontSize: 17, fontWeight: 600,
        color: fg, letterSpacing: -0.3, marginBottom: 4,
      }}>尚無交易</div>
      <div style={{
        fontFamily: FONTS.body, fontSize: 13, color: muted, letterSpacing: -0.1, marginBottom: 16,
      }}>記錄您的第一筆花費吧!</div>
      <Tappable onClick={onAdd}>
        <div style={{
          padding: '11px 26px', borderRadius: 22,
          background: accent,
          color: '#fff',
          fontFamily: FONTS.body, fontSize: 14, fontWeight: 600, letterSpacing: -0.15,
          boxShadow: `0 6px 16px ${accent}55`,
        }}>記一筆</div>
      </Tappable>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Quick add sheet
// ─────────────────────────────────────────────────────────────
function QuickAddSheet({ open, onClose, dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;
  const [text, setText] = useS('');
  const [extracting, setExtracting] = useS(false);
  const [result, setResult] = useS(null);

  const run = () => {
    if (!text.trim()) return;
    setExtracting(true); setResult(null);
    setTimeout(() => {
      setExtracting(false);
      const m = text.match(/\d+/);
      const amt = m ? parseInt(m[0]) : 100;
      setResult({
        amount: amt,
        cat: text.includes('咖啡') || text.includes('latte') ? '飲食 · Coffee' : (text.includes('車') || text.includes('Uber') ? '交通' : '購物'),
        account: '悠遊卡',
        merchant: text.split(/\s+/)[0] || 'Unknown',
      });
    }, 700);
  };

  useE(() => {
    if (!open) { setText(''); setResult(null); setExtracting(false); }
  }, [open]);

  return (
    <Sheet open={open} onClose={onClose} dark={dark}>
      <div style={{ padding: '8px 22px 28px' }}>
        <div style={{ width: 38, height: 5, borderRadius: 3, background: dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.15)', margin: '8px auto 18px' }}/>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
          <Glyph name="sparkles" size={16} color={accent}/>
          <div style={{ fontFamily: FONTS.display, fontSize: 22, fontWeight: 700, color: fg, letterSpacing: -0.6 }}>Quick add</div>
        </div>
        <div style={{ fontFamily: FONTS.body, fontSize: 13, color: muted, marginBottom: 16, letterSpacing: -0.1 }}>
          Type or speak. AI fills the rest.
        </div>

        <Glass dark={dark} radius={20} style={{ padding: '14px 16px', marginBottom: 12 }}>
          <input
            value={text}
            onChange={e => setText(e.target.value)}
            placeholder="e.g. 星巴克 latte 165 元 用悠遊卡"
            style={{
              border: 'none', outline: 'none', background: 'transparent', width: '100%',
              fontFamily: FONTS.body, fontSize: 16, color: fg, letterSpacing: -0.2,
            }}/>
        </Glass>

        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 16 }}>
          {['咖啡 65', 'Uber 280', '7-11 早餐 45', '誠品 1250'].map((p, i) => (
            <Tappable key={i} onClick={() => setText(p)}>
              <div style={{
                padding: '6px 11px', borderRadius: 999,
                background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)',
                fontFamily: FONTS.body, fontSize: 12, color: fg, fontWeight: 500,
              }}>{p}</div>
            </Tappable>
          ))}
        </div>

        {extracting && (
          <Glass dark={dark} radius={16} style={{ padding: '12px 14px', marginBottom: 14 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <Glyph name="sparkles" size={14} color={accent}/>
              <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: muted, textTransform: 'uppercase', letterSpacing: 1, fontWeight: 500 }}>Extracting…</div>
              <div style={{ display: 'flex', gap: 4, marginLeft: 'auto' }}>
                {[0,1,2].map(i => (
                  <div key={i} style={{
                    width: 6, height: 6, borderRadius: 3, background: accent,
                    opacity: 0.4, animation: `bDot 1s ${i * 0.15}s infinite`,
                  }}/>
                ))}
              </div>
            </div>
          </Glass>
        )}

        {result && (
          <Glass dark={dark} radius={20} style={{ padding: '14px 16px', marginBottom: 14 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 10 }}>
              <Glyph name="sparkles" size={12} color={accent}/>
              <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1, fontWeight: 500 }}>Extracted</div>
              <div style={{ marginLeft: 'auto', fontFamily: FONTS.mono, fontSize: 11, color: muted }}>0.4s</div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
              {[
                { k: 'Amount', v: 'NT$ ' + result.amount.toLocaleString(), c: COLORS.expense },
                { k: 'Category', v: result.cat },
                { k: 'Account', v: result.account },
                { k: 'Merchant', v: result.merchant },
              ].map((f, i) => (
                <div key={i}>
                  <div style={{ fontFamily: FONTS.mono, fontSize: 9, color: muted, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 3 }}>{f.k}</div>
                  <div style={{ fontFamily: FONTS.body, fontSize: 14, fontWeight: 500, color: f.c || fg, letterSpacing: -0.1 }}>{f.v}</div>
                </div>
              ))}
            </div>
          </Glass>
        )}

        <PressButton accent={accent} onClick={result ? onClose : run} disabled={!text.trim() && !result}>
          {result ? 'Save transaction' : 'Extract with AI'}
        </PressButton>
      </div>
    </Sheet>
  );
}

// ─────────────────────────────────────────────────────────────
// Variant 1 — Spacious / Focused
// ─────────────────────────────────────────────────────────────
function DashSpacious({ dark, dense }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;
  const visible = useEnter([dark]);
  const [active, setActive] = useS('all');
  const [openTx, setOpenTx] = useS(null);
  const [addOpen, setAddOpen] = useS(false);
  const [aiSheetOpen, setAiSheetOpen] = useS(false);

  return (
    <Phone dark={dark} bg={dashBg(dark)}>
      {/* orbs */}
      <div style={{ position: 'absolute', inset: 0, zIndex: 0, overflow: 'hidden', pointerEvents: 'none' }}>
        <div style={{
          position: 'absolute', top: 60, right: -60, width: 240, height: 240, borderRadius: '50%',
          background: COLORS.accent, opacity: dark ? 0.28 : 0.32, filter: 'blur(70px)',
        }}/>
        <div style={{
          position: 'absolute', top: 280, left: -60, width: 220, height: 220, borderRadius: '50%',
          background: COLORS.income, opacity: dark ? 0.18 : 0.2, filter: 'blur(80px)',
        }}/>
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', position: 'relative', zIndex: 1, overflow: 'hidden' }}>
        <Reveal visible={visible} delay={50} dir="down" distance={10}>
          <DashTopBar dark={dark} dense={dense} onAi={() => setAiSheetOpen(true)}/>
        </Reveal>

        <div style={{ flex: 1, overflow: 'auto', paddingBottom: 28 }}>
          <Reveal visible={visible} delay={120} dir="up" distance={14}>
            <HeroBalance dark={dark} accent={accent} big={!dense}/>
          </Reveal>

          <Reveal visible={visible} delay={200} dir="up" distance={12}>
            <AccountChips dark={dark} active={active} setActive={setActive}/>
          </Reveal>

          <div style={{ marginTop: dense ? 14 : 18 }}>
            <Reveal visible={visible} delay={280} dir="up" distance={12}>
              <InsightCarousel dark={dark} accent={accent} dense={dense}/>
            </Reveal>
          </div>

          <div style={{ marginTop: dense ? 14 : 20, padding: '0 22px' }}>
            <Reveal visible={visible} delay={360} dir="up" distance={10}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
                <div style={{ fontFamily: FONTS.display, fontSize: 18, fontWeight: 600, color: fg, letterSpacing: -0.4 }}>Recent</div>
                <div style={{ fontFamily: FONTS.body, fontSize: 13, color: accent, fontWeight: 500 }}>See all</div>
              </div>
            </Reveal>
            <Reveal visible={visible} delay={420} dir="up" distance={10}>
              <Glass dark={dark} radius={22} style={{ padding: '4px 4px' }}>
                {TXNS.slice(0, 6).map((tx, i) => (
                  <React.Fragment key={tx.id}>
                    <TxnRow tx={tx} dark={dark} dense={dense} expanded={openTx === tx.id} onTap={(id) => setOpenTx(openTx === id ? null : id)}/>
                    {i < 5 && <div style={{
                      height: 0.5, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)',
                      margin: '0 14px',
                    }}/>}
                  </React.Fragment>
                ))}
              </Glass>
            </Reveal>
          </div>
        </div>

      </div>

      <QuickAddSheet open={addOpen} onClose={() => setAddOpen(false)} dark={dark}/>
      <AiInsightSheet open={aiSheetOpen} onClose={() => setAiSheetOpen(false)} dark={dark}/>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// Variant 2 — Compact / Data-rich
// ─────────────────────────────────────────────────────────────
function DashCompact({ dark, dense, empty = false }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;
  const visible = useEnter([dark]);
  const [active, setActive] = useS('all');
  const [openTx, setOpenTx] = useS(null);
  const [addOpen, setAddOpen] = useS(false);
  const [aiSheetOpen, setAiSheetOpen] = useS(false);

  return (
    <Phone dark={dark} bg={dashBg(dark)}>
      <div style={{ position: 'absolute', inset: 0, zIndex: 0, overflow: 'hidden', pointerEvents: 'none' }}>
        <div style={{
          position: 'absolute', top: 0, right: -80, width: 280, height: 280, borderRadius: '50%',
          background: COLORS.accent, opacity: dark ? 0.22 : 0.26, filter: 'blur(80px)',
        }}/>
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', position: 'relative', zIndex: 1, overflow: 'hidden' }}>
        <Reveal visible={visible} delay={50} dir="down" distance={10}>
          <DashTopBar dark={dark} dense={true} onAi={() => setAiSheetOpen(true)}/>
        </Reveal>

        <div style={{ flex: 1, overflow: 'auto', paddingBottom: 28 }}>
          <Reveal visible={visible} delay={120} dir="up" distance={14}>
            <HeroBalance dark={dark} accent={accent} big={false} empty={empty}/>
          </Reveal>

          {!empty && (
            <Reveal visible={visible} delay={180} dir="up" distance={12}>
              <StatsRow dark={dark} accent={accent}/>
            </Reveal>
          )}

          <Reveal visible={visible} delay={240} dir="up" distance={12}>
            <AccountChips dark={dark} active={active} setActive={setActive}/>
          </Reveal>

          {!empty && (
            <div style={{ marginTop: 14 }}>
              <Reveal visible={visible} delay={300} dir="up" distance={10}>
                <InsightCarousel dark={dark} accent={accent} dense={true}/>
              </Reveal>
            </div>
          )}

          <div style={{ marginTop: 14, padding: '0 22px' }}>
            <Reveal visible={visible} delay={360} dir="up" distance={10}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
                <div style={{ fontFamily: FONTS.display, fontSize: 17, fontWeight: 600, color: fg, letterSpacing: -0.4 }}>
                  {empty ? '最近交易' : 'Today · 3 transactions'}
                </div>
                {!empty && <div style={{ fontFamily: FONTS.body, fontSize: 13, color: accent, fontWeight: 500 }}>See all</div>}
              </div>
            </Reveal>

            {empty ? (
              <Reveal visible={visible} delay={420} dir="up" distance={10}>
                <Glass dark={dark} radius={22} style={{ padding: '8px 0' }}>
                  <EmptyTransactions dark={dark} onAdd={() => setAddOpen(true)}/>
                </Glass>
              </Reveal>
            ) : (
              <React.Fragment>
                {/* Group: Today */}
                <Reveal visible={visible} delay={420} dir="up" distance={8}>
                  <Glass dark={dark} radius={20} style={{ padding: '4px 4px', marginBottom: 10 }}>
                    {TXNS.slice(0, 3).map((tx, i) => (
                      <React.Fragment key={tx.id}>
                        <TxnRow tx={tx} dark={dark} dense={true} expanded={openTx === tx.id} onTap={(id) => setOpenTx(openTx === id ? null : id)}/>
                        {i < 2 && <div style={{ height: 0.5, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)', margin: '0 14px' }}/>}
                      </React.Fragment>
                    ))}
                  </Glass>
                </Reveal>

                {/* Group: Yesterday */}
                <Reveal visible={visible} delay={480} dir="up" distance={8}>
                  <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1.2, marginBottom: 6, marginTop: 6 }}>
                    Yesterday
                  </div>
                  <Glass dark={dark} radius={20} style={{ padding: '4px 4px', marginBottom: 10 }}>
                    {TXNS.slice(3, 5).map((tx, i) => (
                      <React.Fragment key={tx.id}>
                        <TxnRow tx={tx} dark={dark} dense={true} expanded={openTx === tx.id} onTap={(id) => setOpenTx(openTx === id ? null : id)}/>
                        {i < 1 && <div style={{ height: 0.5, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)', margin: '0 14px' }}/>}
                      </React.Fragment>
                    ))}
                  </Glass>
                </Reveal>

                <Reveal visible={visible} delay={540} dir="up" distance={8}>
                  <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1.2, marginBottom: 6, marginTop: 6 }}>
                    Earlier
                  </div>
                  <Glass dark={dark} radius={20} style={{ padding: '4px 4px' }}>
                    {TXNS.slice(5).map((tx, i) => (
                      <React.Fragment key={tx.id}>
                        <TxnRow tx={tx} dark={dark} dense={true} expanded={openTx === tx.id} onTap={(id) => setOpenTx(openTx === id ? null : id)}/>
                        {i < TXNS.slice(5).length - 1 && <div style={{ height: 0.5, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)', margin: '0 14px' }}/>}
                      </React.Fragment>
                    ))}
                  </Glass>
                </Reveal>
              </React.Fragment>
            )}
          </div>
        </div>

      </div>

      <AddTransactionOverlay open={addOpen} dark={dark} onClose={() => setAddOpen(false)} onSave={() => {}}/>
      <AiInsightSheet open={aiSheetOpen} onClose={() => setAiSheetOpen(false)} dark={dark}/>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// AI insight sheet (full)
// ─────────────────────────────────────────────────────────────
function AiInsightSheet({ open, onClose, dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;

  return (
    <Sheet open={open} onClose={onClose} dark={dark}>
      <div style={{ padding: '8px 22px 28px' }}>
        <div style={{ width: 38, height: 5, borderRadius: 3, background: dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.15)', margin: '8px auto 18px' }}/>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
          <Glyph name="sparkles" size={16} color={accent}/>
          <div style={{ fontFamily: FONTS.display, fontSize: 22, fontWeight: 700, color: fg, letterSpacing: -0.6 }}>Insights</div>
        </div>
        <div style={{ fontFamily: FONTS.body, fontSize: 13, color: muted, marginBottom: 16, letterSpacing: -0.1 }}>
          On-device · Apple Foundation Models
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {INSIGHTS.map((ins, i) => (
            <Glass key={i} dark={dark} radius={18} style={{ padding: '14px 16px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 6 }}>
                <div style={{ fontFamily: FONTS.display, fontSize: 16, fontWeight: 600, color: fg, letterSpacing: -0.3, flex: 1, paddingRight: 8 }}>
                  {ins.title}
                </div>
                <div style={{
                  padding: '3px 9px', borderRadius: 999,
                  background: ins.metricColor + '22', color: ins.metricColor,
                  fontFamily: FONTS.mono, fontSize: 11, fontWeight: 600, letterSpacing: -0.1,
                }}>{ins.metric}</div>
              </div>
              <div style={{ fontFamily: FONTS.body, fontSize: 13, color: muted, lineHeight: 1.45, letterSpacing: -0.1 }}>
                {ins.body}
              </div>
            </Glass>
          ))}
        </div>
      </div>
    </Sheet>
  );
}

Object.assign(window, { DashSpacious, DashCompact });
