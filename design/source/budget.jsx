// NeuLedger — Budget / 目標
// 3 artboards: Main · Category Detail · New Budget Sheet
// Reuses AccPhone / AccGlass / AccGlyph / ACC_FONTS / ACC_COLORS / accBg from accounts.jsx

const BUDGET_DATA = {
  month: '2026 年 5 月',
  total: 38000,
  used: 24580,
  daysIn: 17,
  daysTotal: 31,
  categories: [
    { id: 'food', name: '餐飲', icon: 'cash', color: '#E8835A', budget: 8000, used: 6800, txCount: 42, trend: -3 },
    { id: 'shop', name: '購物', icon: 'card', color: '#A66BF0', budget: 5000, used: 4500, txCount: 8, trend: +18 },
    { id: 'transport', name: '交通', icon: 'phone', color: '#1B5E8E', budget: 3000, used: 1200, txCount: 14, trend: -22 },
    { id: 'fun', name: '娛樂', icon: 'star', color: '#F4B400', budget: 4000, used: 3200, txCount: 6, trend: +5 },
    { id: 'home', name: '居家', icon: 'archive', color: '#8B6F47', budget: 6000, used: 3800, txCount: 11, trend: -8 },
    { id: 'health', name: '醫療', icon: 'sparkle', color: '#34C759', budget: 2000, used: 0, txCount: 0, trend: 0 },
    { id: 'other', name: '其他', icon: 'dots', color: '#6B6B6B', budget: 2000, used: 1080, txCount: 3, trend: 0 },
  ],
};

// Daily breakdown for a single category (餐飲, 17 days)
const FOOD_DAILY = [320, 0, 480, 250, 180, 420, 0, 380, 290, 520, 200, 0, 410, 350, 280, 480, 240];

const FOOD_TXNS = [
  { id: 'f1', date: '今天', merchant: '路易莎咖啡', amount: -120, account: '玉山卡', tag: '咖啡' },
  { id: 'f2', date: '今天', merchant: '7-11', amount: -85, account: '玉山卡', tag: '便利商店' },
  { id: 'f3', date: '昨天', merchant: '一蘭拉麵', amount: -480, account: '玉山卡', tag: '午餐' },
  { id: 'f4', date: '昨天', merchant: 'Uber Eats · 麥當勞', amount: -250, account: '玉山卡', tag: '外送' },
  { id: 'f5', date: '5/13', merchant: '大苑子', amount: -65, account: '街口', tag: '飲料' },
  { id: 'f6', date: '5/13', merchant: '鼎泰豐', amount: -780, account: '玉山卡', tag: '聚餐' },
  { id: 'f7', date: '5/12', merchant: '路易莎咖啡', amount: -120, account: '玉山卡', tag: '咖啡' },
  { id: 'f8', date: '5/11', merchant: '全家', amount: -180, account: '街口', tag: '便利商店' },
];

// Format helper
function bFmt(n) {
  if (n == null) return '—';
  const abs = Math.abs(Math.round(n));
  return (n < 0 ? '−' : '') + 'NT$ ' + abs.toLocaleString('en-US');
}

// Progress ring
function ProgressRing({ value, size = 200, stroke = 14, color, trackColor, label, sublabel, dark }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const v = Math.min(value, 1);
  const offset = c * (1 - v);
  const fg = dark ? '#fff' : '#0A0A0A';
  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={size/2} cy={size/2} r={r} stroke={trackColor || (dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)')} strokeWidth={stroke} fill="none"/>
        <circle cx={size/2} cy={size/2} r={r} stroke={color} strokeWidth={stroke} fill="none" strokeDasharray={c} strokeDashoffset={offset} strokeLinecap="round" style={{ transition: 'stroke-dashoffset 0.6s ease' }}/>
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }}>
        {label && <div style={{ fontFamily: ACC_FONTS.display, fontSize: 36, fontWeight: 600, letterSpacing: -1, color: fg, fontFeatureSettings: '"tnum"' }}>{label}</div>}
        {sublabel && <div style={{ fontSize: 12, color: dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.5)', marginTop: 4, fontFamily: ACC_FONTS.mono, letterSpacing: 0.5 }}>{sublabel}</div>}
      </div>
    </div>
  );
}

// Bar
function CatBar({ used, budget, color, dark }) {
  const v = Math.min(used / budget, 1.05);
  const over = used > budget;
  return (
    <div style={{ position: 'relative', height: 6, borderRadius: 100, background: dark ? 'rgba(255,255,255,0.07)' : 'rgba(0,0,0,0.05)', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', inset: 0, width: `${Math.min(v, 1) * 100}%`, background: color, borderRadius: 100, transition: 'width 0.5s ease' }}/>
      {over && <div style={{ position: 'absolute', right: 0, top: 0, bottom: 0, width: 3, background: ACC_COLORS.expense }}/>}
    </div>
  );
}

// ─── Budget Main ────────────────────────────────────────────
function BudgetMain({ dark, onCategory, onAdd }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.5)';
  const accent = ACC_COLORS.warm;
  const d = BUDGET_DATA;
  const pct = d.used / d.total;
  const remain = d.total - d.used;
  const dayPct = d.daysIn / d.daysTotal;
  const onPace = (pct - dayPct) * 100;
  const paceText = onPace < -3 ? `領先 ${Math.abs(onPace).toFixed(0)}%` : onPace > 3 ? `落後 ${onPace.toFixed(0)}%` : '與時間進度同步';
  const paceColor = onPace < -3 ? ACC_COLORS.income : onPace > 3 ? ACC_COLORS.expense : muted;

  return (
    <div style={{ flex: 1, overflow: 'auto', WebkitOverflowScrolling: 'touch' }}>
      {/* Header */}
      <div style={{ padding: '8px 20px 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>BUDGET</div>
          <div style={{ fontFamily: ACC_FONTS.display, fontSize: 26, fontWeight: 600, color: fg, marginTop: 2 }}>本月預算</div>
        </div>
        <button onClick={onAdd} style={{
          width: 36, height: 36, borderRadius: 18, border: 'none', cursor: 'pointer',
          background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.7)',
          backdropFilter: 'blur(20px)',
          color: fg, display: 'flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: dark ? '0 0 0 1px rgba(255,255,255,0.06)' : '0 1px 0 rgba(255,255,255,0.7) inset, 0 0 0 1px rgba(0,0,0,0.04)',
        }}>
          <AccGlyph name="plus" size={18} stroke={2}/>
        </button>
      </div>

      {/* Month picker */}
      <div style={{ padding: '0 20px 16px' }}>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '5px 10px 5px 12px', borderRadius: 100, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)', fontSize: 13, color: fg, fontWeight: 500 }}>
          {d.month}
          <AccGlyph name="chevron-down" size={14} color={muted} stroke={2}/>
        </div>
      </div>

      {/* Big ring */}
      <div style={{ padding: '16px 20px 24px', display: 'flex', justifyContent: 'center' }}>
        <ProgressRing
          value={pct}
          size={224}
          stroke={14}
          color={pct > 0.9 ? ACC_COLORS.expense : accent}
          dark={dark}
          label={bFmt(remain).replace('NT$ ', '')}
          sublabel={`還剩 · 共 ${bFmt(d.total).replace('NT$ ', '')}`}
        />
      </div>

      {/* Pace strip */}
      <div style={{ padding: '0 20px 20px' }}>
        <AccGlass dark={dark} radius={16} style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 28, height: 28, borderRadius: 14, background: `linear-gradient(135deg, ${ACC_COLORS.ai} 0%, #6B5BD6 100%)`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <AccGlyph name="sparkle" size={14} color="#fff"/>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 13, color: fg, lineHeight: 1.4 }}>
              本月已用 <span style={{ fontFamily: ACC_FONTS.mono, fontWeight: 600 }}>{(pct*100).toFixed(0)}%</span> · 時間進度 <span style={{ fontFamily: ACC_FONTS.mono, fontWeight: 600 }}>{(dayPct*100).toFixed(0)}%</span>
            </div>
            <div style={{ fontSize: 12, color: paceColor, marginTop: 2 }}>{paceText} · 預估月底會剩 NT$ 4,200</div>
          </div>
        </AccGlass>
      </div>

      {/* Section header */}
      <div style={{ padding: '4px 20px 12px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
        <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>分類</div>
        <div style={{ fontSize: 12, color: muted }}>使用 / 預算</div>
      </div>

      {/* Categories */}
      <div style={{ padding: '0 20px 100px' }}>
        <AccGlass dark={dark} radius={20} style={{ padding: '6px 0', overflow: 'hidden' }}>
          {d.categories.map((c, i) => {
            const cpct = c.used / c.budget;
            const over = c.used > c.budget;
            const last = i === d.categories.length - 1;
            return (
              <button key={c.id} onClick={() => onCategory(c)}
                style={{ width: '100%', padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12, background: 'transparent', border: 'none', cursor: 'pointer', textAlign: 'left', position: 'relative' }}
              >
                <div style={{ width: 36, height: 36, borderRadius: 10, background: c.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, boxShadow: `0 4px 10px ${c.color}40` }}>
                  <AccGlyph name={c.icon} size={18} color="#fff" stroke={2}/>
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 8, marginBottom: 6 }}>
                    <div style={{ fontSize: 15, fontWeight: 500, color: fg }}>{c.name}</div>
                    <div style={{ fontSize: 13, fontFamily: ACC_FONTS.mono, color: over ? ACC_COLORS.expense : fg, fontFeatureSettings: '"tnum"' }}>
                      {bFmt(c.used).replace('NT$ ', '')} <span style={{ color: muted }}>/ {bFmt(c.budget).replace('NT$ ', '')}</span>
                    </div>
                  </div>
                  <CatBar used={c.used} budget={c.budget} color={c.color} dark={dark}/>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginTop: 6 }}>
                    <div style={{ fontSize: 11, color: muted }}>
                      {c.txCount === 0 ? '本月未使用' : `${c.txCount} 筆`}
                      {c.trend !== 0 && c.txCount > 0 && (
                        <span style={{ marginLeft: 6, color: c.trend < 0 ? ACC_COLORS.income : c.trend > 10 ? ACC_COLORS.expense : muted }}>
                          {c.trend > 0 ? '↑' : '↓'} {Math.abs(c.trend)}%
                        </span>
                      )}
                    </div>
                    <div style={{ fontSize: 11, color: over ? ACC_COLORS.expense : muted, fontFamily: ACC_FONTS.mono }}>
                      {over ? `超出 ${bFmt(c.used - c.budget).replace('NT$ ', '')}` : `${(cpct*100).toFixed(0)}%`}
                    </div>
                  </div>
                </div>
                {!last && <div style={{ position: 'absolute', left: 64, right: 16, bottom: 0, height: 0.5, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)' }}/>}
              </button>
            );
          })}
        </AccGlass>
      </div>
    </div>
  );
}

// ─── Category Detail ─────────────────────────────────────────
function BudgetCategoryDetail({ dark, onBack, category }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.5)';
  const accent = ACC_COLORS.warm;
  const c = category || BUDGET_DATA.categories[0];
  const pct = c.used / c.budget;
  const remain = c.budget - c.used;
  const daysIn = BUDGET_DATA.daysIn;
  const dailyAvg = c.used / daysIn;
  const projected = dailyAvg * BUDGET_DATA.daysTotal;

  // Daily bars (only show for food, fallback synthetic)
  const dailyData = c.id === 'food' ? FOOD_DAILY : Array.from({ length: daysIn }, (_, i) => Math.random() * (c.used / daysIn) * 1.6);
  const maxDaily = Math.max(...dailyData, 1);

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* Nav */}
      <div style={{ padding: '8px 12px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', position: 'relative', flexShrink: 0 }}>
        <button onClick={onBack} style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: accent, display: 'flex', alignItems: 'center', gap: 2, fontSize: 16, fontWeight: 400 }}>
          <AccGlyph name="chevron-left" size={20} color={accent}/> 預算
        </button>
        <div style={{ position: 'absolute', left: '50%', transform: 'translateX(-50%)', fontWeight: 600, fontSize: 16, color: fg }}>{c.name}</div>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: accent, fontSize: 15, fontWeight: 400 }}>編輯</button>
      </div>

      <div style={{ flex: 1, overflow: 'auto', WebkitOverflowScrolling: 'touch', padding: '0 16px 100px' }}>
        {/* Hero card */}
        <AccGlass dark={dark} radius={24} style={{ padding: 22, marginTop: 8 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 18 }}>
            <div style={{ width: 44, height: 44, borderRadius: 14, background: c.color, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 8px 20px ${c.color}40` }}>
              <AccGlyph name={c.icon} size={22} color="#fff" stroke={2}/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>本月已用</div>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 2 }}>
                <span style={{ fontFamily: ACC_FONTS.display, fontSize: 32, fontWeight: 600, color: fg, letterSpacing: -1, fontFeatureSettings: '"tnum"' }}>{bFmt(c.used).replace('NT$ ', '')}</span>
                <span style={{ fontSize: 14, color: muted }}>/ {bFmt(c.budget).replace('NT$ ', '')}</span>
              </div>
            </div>
          </div>

          {/* Big bar */}
          <div style={{ position: 'relative', height: 10, borderRadius: 100, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)', overflow: 'hidden', marginBottom: 12 }}>
            <div style={{ position: 'absolute', inset: 0, width: `${Math.min(pct, 1) * 100}%`, background: c.color, borderRadius: 100 }}/>
            {/* Time marker */}
            <div style={{ position: 'absolute', top: -4, height: 18, width: 2, background: dark ? 'rgba(255,255,255,0.5)' : 'rgba(0,0,0,0.35)', left: `${(daysIn/BUDGET_DATA.daysTotal)*100}%`, borderRadius: 1 }}/>
          </div>

          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, color: muted, fontFamily: ACC_FONTS.mono, fontFeatureSettings: '"tnum"' }}>
            <span>{(pct*100).toFixed(0)}% 已用</span>
            <span>還剩 {bFmt(remain).replace('NT$ ', '')}</span>
          </div>
        </AccGlass>

        {/* Stats row */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8, marginTop: 12 }}>
          {[
            { label: '日均', val: bFmt(dailyAvg).replace('NT$ ', '') },
            { label: '預估月底', val: bFmt(projected).replace('NT$ ', ''), tone: projected > c.budget ? 'over' : 'ok' },
            { label: '筆數', val: c.txCount },
          ].map((s, i) => (
            <AccGlass key={i} dark={dark} radius={14} style={{ padding: '12px 10px' }}>
              <div style={{ fontSize: 10, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>{s.label}</div>
              <div style={{ fontFamily: ACC_FONTS.display, fontSize: 18, fontWeight: 600, color: s.tone === 'over' ? ACC_COLORS.expense : fg, marginTop: 2, fontFeatureSettings: '"tnum"' }}>{s.val}</div>
            </AccGlass>
          ))}
        </div>

        {/* AI insight */}
        <AccGlass dark={dark} radius={18} style={{ padding: 16, marginTop: 12, position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', top: -20, right: -20, width: 80, height: 80, borderRadius: 40, background: `radial-gradient(circle, ${ACC_COLORS.ai}30, transparent 70%)` }}/>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
            <AccGlyph name="sparkle" size={12} color={ACC_COLORS.ai}/>
            <div style={{ fontSize: 10, color: ACC_COLORS.ai, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase', fontWeight: 600 }}>AI 觀察</div>
          </div>
          <div style={{ fontSize: 14, color: fg, lineHeight: 1.5 }}>
            {c.id === 'food' ? '本月你在「咖啡」上花了 NT$ 1,440,佔餐飲類別 21%,比上月多 18%。' :
             c.id === 'shop' ? '本月有 3 筆超過 NT$ 1,000 的支出,主要在 5/13 — 來自 SHOPLINE。' :
             c.trend < 0 ? `本月支出比上月減少 ${Math.abs(c.trend)}%,持續這個節奏會省下 NT$ 600。` :
             '本月支出趨勢平穩,符合過去三個月的平均。'}
          </div>
        </AccGlass>

        {/* Daily bars */}
        <div style={{ marginTop: 20, padding: '0 4px' }}>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase', marginBottom: 12 }}>每日支出</div>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height: 80, padding: '0 0 4px' }}>
            {dailyData.map((v, i) => (
              <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
                <div style={{ width: '100%', height: `${Math.max((v / maxDaily) * 64, v > 0 ? 4 : 2)}px`, background: v > 0 ? c.color : (dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)'), borderRadius: 3, opacity: v > 0 ? 0.85 : 1 }}/>
                {(i + 1) % 5 === 0 && <div style={{ fontSize: 9, color: muted, fontFamily: ACC_FONTS.mono }}>{i + 1}</div>}
              </div>
            ))}
          </div>
        </div>

        {/* Recent txns (only for food) */}
        {c.id === 'food' && (
          <div style={{ marginTop: 20 }}>
            <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '0 4px 12px' }}>
              <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>最近交易</div>
              <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: accent, fontSize: 12 }}>查看全部</button>
            </div>
            <AccGlass dark={dark} radius={16} style={{ padding: '4px 0', overflow: 'hidden' }}>
              {FOOD_TXNS.slice(0, 5).map((t, i) => (
                <div key={t.id} style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 10, borderBottom: i < 4 ? `0.5px solid ${dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)'}` : 'none' }}>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 14, color: fg, fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{t.merchant}</div>
                    <div style={{ fontSize: 11, color: muted, marginTop: 2 }}>{t.date} · {t.account} · {t.tag}</div>
                  </div>
                  <div style={{ fontSize: 14, fontFamily: ACC_FONTS.mono, color: fg, fontFeatureSettings: '"tnum"' }}>{bFmt(t.amount)}</div>
                </div>
              ))}
            </AccGlass>
          </div>
        )}
      </div>
    </div>
  );
}

// ─── New Budget Sheet ────────────────────────────────────────
function NewBudgetSheet({ dark, onClose }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.5)';
  const accent = ACC_COLORS.warm;
  const [picked, setPicked] = React.useState('food');
  const [amount, setAmount] = React.useState('5000');

  const cats = [
    { id: 'food', name: '餐飲', icon: 'cash', color: '#E8835A' },
    { id: 'shop', name: '購物', icon: 'card', color: '#A66BF0' },
    { id: 'transport', name: '交通', icon: 'phone', color: '#1B5E8E' },
    { id: 'fun', name: '娛樂', icon: 'star', color: '#F4B400' },
    { id: 'home', name: '居家', icon: 'archive', color: '#8B6F47' },
    { id: 'health', name: '醫療', icon: 'sparkle', color: '#34C759' },
    { id: 'travel', name: '旅遊', icon: 'invest', color: '#5E5CE6' },
    { id: 'edu', name: '學習', icon: 'edit', color: '#0EA5E9' },
  ];

  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 100, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', pointerEvents: 'auto' }}>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.4)', backdropFilter: 'blur(2px)' }} onClick={onClose}/>
      <div style={{ position: 'relative', background: dark ? '#1a1410' : '#FBF1E5', borderTopLeftRadius: 28, borderTopRightRadius: 28, paddingBottom: 34, boxShadow: '0 -20px 60px rgba(0,0,0,0.3)' }}>
        {/* Drag handle */}
        <div style={{ display: 'flex', justifyContent: 'center', padding: '10px 0 4px' }}>
          <div style={{ width: 38, height: 4, borderRadius: 2, background: dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.15)' }}/>
        </div>

        {/* Header */}
        <div style={{ padding: '8px 20px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button onClick={onClose} style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: accent, fontSize: 16 }}>取消</button>
          <div style={{ fontFamily: ACC_FONTS.display, fontSize: 17, fontWeight: 600, color: fg }}>新增預算</div>
          <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: accent, fontSize: 16, fontWeight: 600 }}>儲存</button>
        </div>

        {/* Amount */}
        <div style={{ padding: '8px 20px 24px', textAlign: 'center' }}>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase', marginBottom: 8 }}>每月金額</div>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'center', gap: 6 }}>
            <span style={{ fontSize: 28, color: muted, fontFamily: ACC_FONTS.display }}>NT$</span>
            <span style={{ fontFamily: ACC_FONTS.display, fontSize: 56, fontWeight: 600, color: fg, letterSpacing: -2, fontFeatureSettings: '"tnum"' }}>{Number(amount || 0).toLocaleString('en-US')}</span>
          </div>
          {/* AI suggestion chip */}
          <div style={{ marginTop: 12, display: 'inline-flex', alignItems: 'center', gap: 6, padding: '5px 12px', borderRadius: 100, background: dark ? `${ACC_COLORS.ai}20` : `${ACC_COLORS.ai}15`, border: `0.5px solid ${ACC_COLORS.ai}50` }}>
            <AccGlyph name="sparkle" size={11} color={ACC_COLORS.ai}/>
            <span style={{ fontSize: 12, color: ACC_COLORS.ai, fontWeight: 500 }}>AI 建議 NT$ 5,500 (3 個月平均)</span>
          </div>
        </div>

        {/* Category grid */}
        <div style={{ padding: '0 20px 20px' }}>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase', marginBottom: 10 }}>選擇分類</div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
            {cats.map(c => {
              const active = picked === c.id;
              return (
                <button key={c.id} onClick={() => setPicked(c.id)} style={{
                  padding: '14px 6px',
                  borderRadius: 14,
                  background: active ? c.color : (dark ? 'rgba(255,255,255,0.05)' : 'rgba(255,255,255,0.6)'),
                  border: 'none', cursor: 'pointer',
                  display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
                  boxShadow: active ? `0 8px 20px ${c.color}50` : (dark ? '0 0 0 0.5px rgba(255,255,255,0.05)' : '0 0 0 0.5px rgba(0,0,0,0.04)'),
                  transition: 'all 0.15s',
                }}>
                  <AccGlyph name={c.icon} size={20} color={active ? '#fff' : (dark ? '#fff' : '#0A0A0A')} stroke={2}/>
                  <div style={{ fontSize: 11, fontWeight: 500, color: active ? '#fff' : fg }}>{c.name}</div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Quick chips */}
        <div style={{ padding: '8px 20px 20px' }}>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase', marginBottom: 10 }}>快速金額</div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {[2000, 3000, 5000, 8000, 10000].map(v => (
              <button key={v} onClick={() => setAmount(String(v))} style={{
                padding: '8px 14px',
                borderRadius: 100,
                background: amount === String(v) ? accent : (dark ? 'rgba(255,255,255,0.06)' : 'rgba(255,255,255,0.7)'),
                color: amount === String(v) ? '#fff' : fg,
                border: 'none', cursor: 'pointer',
                fontSize: 13, fontFamily: ACC_FONTS.mono, fontWeight: 500,
              }}>{v.toLocaleString()}</button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Top-level wrappers ──────────────────────────────────────
function BudgetMainScreen({ dark }) {
  const [showSheet, setShowSheet] = React.useState(false);
  return (
    <AccPhone dark={dark}>
      <BudgetMain dark={dark} onCategory={() => {}} onAdd={() => setShowSheet(true)}/>
      {showSheet && <NewBudgetSheet dark={dark} onClose={() => setShowSheet(false)}/>}
    </AccPhone>
  );
}

function BudgetDetailScreen({ dark }) {
  return (
    <AccPhone dark={dark}>
      <BudgetCategoryDetail dark={dark} onBack={() => {}} category={BUDGET_DATA.categories[0]}/>
    </AccPhone>
  );
}

function BudgetSheetScreen({ dark }) {
  return (
    <AccPhone dark={dark}>
      <BudgetMain dark={dark} onCategory={() => {}} onAdd={() => {}}/>
      <NewBudgetSheet dark={dark} onClose={() => {}}/>
    </AccPhone>
  );
}

Object.assign(window, { BudgetMainScreen, BudgetDetailScreen, BudgetSheetScreen, BUDGET_DATA });
