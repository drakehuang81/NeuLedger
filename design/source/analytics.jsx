// NeuLedger Analytics — 3 variants × monthly report
// V1 Calm · V2 Editorial · V3 Data-rich
// Frame: 402×874 iPhone 17 Pro

const A_COLORS = {
  accent: '#FF9500',
  accentDark: '#FF9F0A',
  income: '#34C759',
  incomeDark: '#30D158',
  expense: '#FF3B30',
  expenseDark: '#FF453A',
};
const A_FONTS = {
  display: '"Bricolage Grotesque", -apple-system, system-ui, sans-serif',
  body: '"DM Sans", -apple-system, system-ui, sans-serif',
  mono: '"DM Mono", "SF Mono", ui-monospace, Menlo, monospace',
};

// ── data shared across variants ──────────────────────────
const MONTH = 'April 2026';
const TOTAL_OUT = 52600;
const TOTAL_IN = 65000;
const NET = TOTAL_IN - TOTAL_OUT;
const SAVINGS_RATE = Math.round((NET / TOTAL_IN) * 100);
const BUDGET = 60000;

// category palette — warm/earth, derived from token system
const CATS = [
  { key: '餐飲',  amount: 18400, last: 16200, color: '#E8763A', icon: 'fork' },
  { key: '居住',  amount: 12000, last: 12000, color: '#8B6F47', icon: 'home' },
  { key: '交通',  amount:  9200, last:  7800, color: '#5B8DBE', icon: 'car' },
  { key: '購物',  amount:  5800, last:  9200, color: '#B65A8E', icon: 'bag' },
  { key: '娛樂',  amount:  4500, last:  3100, color: '#7B61C9', icon: 'play' },
  { key: '其他',  amount:  2700, last:  2400, color: '#9E9E9E', icon: 'dots' },
];

// 7-day daily expense (matches sum)
const DAILY = [1800, 3400, 1200, 4200, 2800, 5100, 2300]; // last 7 days
const DAILY_LABELS = ['M','T','W','T','F','S','S'];

// 6-month trend (most recent rightmost)
const TREND = [
  { m: 'Nov', out: 48200 },
  { m: 'Dec', out: 61500 },
  { m: 'Jan', out: 47800 },
  { m: 'Feb', out: 50100 },
  { m: 'Mar', out: 49600 },
  { m: 'Apr', out: TOTAL_OUT },
];

const fmt = (n) => Math.abs(n).toLocaleString('en-US');
const pct = (a, b) => Math.round((a / b) * 100);

// ── PRIMITIVES ───────────────────────────────────────────

function Glyph({ name, size = 18, color = '#000', stroke = 1.8 }) {
  const s = size;
  const p = { fill: 'none', stroke: color, strokeWidth: stroke, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (name) {
    case 'sparkles': return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M12 3l1.8 4.5L18 9l-4.2 1.5L12 15l-1.8-4.5L6 9l4.2-1.5L12 3z"/><path {...p} d="M19 15l.9 2.1 2.1.9-2.1.9-.9 2.1-.9-2.1-2.1-.9 2.1-.9.9-2.1z"/></svg>;
    case 'fork':  return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M7 3v8a2 2 0 002 2v8M5 3v6M9 3v6M17 3c-2 0-3 2-3 5s1 5 3 5v8"/></svg>;
    case 'home':  return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M3 11l9-8 9 8M5 9.5V20a1 1 0 001 1h4v-6h4v6h4a1 1 0 001-1V9.5"/></svg>;
    case 'car':   return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M5 13l1.5-5a2 2 0 012-1.5h7a2 2 0 012 1.5L19 13M3 13h18v5a1 1 0 01-1 1h-1a1 1 0 01-1-1v-2H6v2a1 1 0 01-1 1H4a1 1 0 01-1-1v-5z"/><circle {...p} cx="7" cy="16.5" r="1"/><circle {...p} cx="17" cy="16.5" r="1"/></svg>;
    case 'bag':   return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M5 8h14l-1 12a1 1 0 01-1 1H7a1 1 0 01-1-1L5 8zM9 8V5a3 3 0 016 0v3"/></svg>;
    case 'play':  return <svg width={s} height={s} viewBox="0 0 24 24"><circle {...p} cx="12" cy="12" r="9"/><path {...p} d="M10 9l5 3-5 3V9z"/></svg>;
    case 'dots':  return <svg width={s} height={s} viewBox="0 0 24 24"><circle {...p} cx="6" cy="12" r="1"/><circle {...p} cx="12" cy="12" r="1"/><circle {...p} cx="18" cy="12" r="1"/></svg>;
    case 'chev':  return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M9 6l6 6-6 6"/></svg>;
    case 'arrow-up': return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M12 19V5M5 12l7-7 7 7"/></svg>;
    case 'arrow-down': return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M12 5v14M5 12l7 7 7-7"/></svg>;
    case 'cal':   return <svg width={s} height={s} viewBox="0 0 24 24"><rect {...p} x="3" y="5" width="18" height="16" rx="2"/><path {...p} d="M3 9h18M8 3v4M16 3v4"/></svg>;
    default: return <svg width={s} height={s}/>;
  }
}

// Donut chart — percent slices, optional center content
function Donut({ size = 180, thickness = 22, segments, center, dark }) {
  const r = (size - thickness) / 2;
  const cx = size / 2, cy = size / 2;
  const C = 2 * Math.PI * r;
  let acc = 0;
  const total = segments.reduce((s, x) => s + x.value, 0);
  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <svg width={size} height={size}>
        <circle cx={cx} cy={cy} r={r} fill="none" stroke={dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)'} strokeWidth={thickness}/>
        {segments.map((seg, i) => {
          const frac = seg.value / total;
          const len = C * frac;
          const off = C * acc;
          acc += frac;
          return (
            <circle key={i}
              cx={cx} cy={cy} r={r} fill="none"
              stroke={seg.color} strokeWidth={thickness}
              strokeDasharray={`${len - 2} ${C - len + 2}`}
              strokeDashoffset={-off}
              transform={`rotate(-90 ${cx} ${cy})`}
              strokeLinecap="butt"
            />
          );
        })}
      </svg>
      {center && (
        <div style={{
          position: 'absolute', inset: 0,
          display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
          textAlign: 'center', padding: 12,
        }}>{center}</div>
      )}
    </div>
  );
}

// Horizontal bar row (single)
function BarRow({ label, value, max, color, sub, delta, dark, fg, muted }) {
  const w = Math.max(2, Math.round((value / max) * 100));
  return (
    <div style={{ marginBottom: 14 }}>
      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 5 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 22, height: 22, borderRadius: 11, background: color + '22', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <div style={{ width: 8, height: 8, borderRadius: 4, background: color }}/>
          </div>
          <div style={{ fontFamily: A_FONTS.body, fontSize: 14, fontWeight: 500, color: fg, letterSpacing: -0.1 }}>{label}</div>
          {delta !== undefined && delta !== 0 && (
            <div style={{
              fontFamily: A_FONTS.mono, fontSize: 10, fontWeight: 500,
              color: delta > 0 ? (dark ? A_COLORS.expenseDark : A_COLORS.expense) : (dark ? A_COLORS.incomeDark : A_COLORS.income),
              padding: '1px 6px', borderRadius: 999,
              background: delta > 0
                ? (dark ? 'rgba(255,69,58,0.14)' : 'rgba(255,59,48,0.10)')
                : (dark ? 'rgba(48,209,88,0.14)' : 'rgba(52,199,89,0.10)'),
            }}>{delta > 0 ? '↑' : '↓'} {Math.abs(delta)}%</div>
          )}
        </div>
        <div style={{ fontFamily: A_FONTS.mono, fontSize: 13, fontWeight: 500, color: fg, letterSpacing: -0.2 }}>
          <span style={{ fontSize: 9, color: muted, marginRight: 2 }}>NT$</span>{fmt(value)}
        </div>
      </div>
      <div style={{ height: 6, borderRadius: 3, background: dark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.04)', overflow: 'hidden' }}>
        <div style={{ width: `${w}%`, height: '100%', background: color, borderRadius: 3 }}/>
      </div>
      {sub && <div style={{ fontFamily: A_FONTS.mono, fontSize: 10, color: muted, marginTop: 4, letterSpacing: 0.2 }}>{sub}</div>}
    </div>
  );
}

// 7-day stacked daily bar chart
function DailyBars({ data, labels, max, color, dark, fg, muted, height = 100 }) {
  const m = max || Math.max(...data);
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', height, gap: 6 }}>
      {data.map((v, i) => {
        const h = Math.max(4, Math.round((v / m) * height));
        const today = i === data.length - 1;
        return (
          <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
            <div style={{
              width: '100%', height: h, borderRadius: 3,
              background: today ? color : color + '55',
            }}/>
            <div style={{ fontFamily: A_FONTS.mono, fontSize: 9, color: today ? fg : muted, letterSpacing: 0.4, fontWeight: today ? 600 : 400 }}>{labels[i]}</div>
          </div>
        );
      })}
    </div>
  );
}

// 6-month sparkline / mini bar
function MiniMonthBars({ data, dark, fg, muted, accent }) {
  const max = Math.max(...data.map(d => d.out));
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height: 36 }}>
      {data.map((d, i) => {
        const h = Math.max(2, Math.round((d.out / max) * 36));
        const last = i === data.length - 1;
        return (
          <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3 }}>
            <div style={{
              width: '100%', height: h, borderRadius: 2,
              background: last ? accent : (dark ? 'rgba(255,255,255,0.18)' : 'rgba(0,0,0,0.14)'),
            }}/>
            <div style={{ fontFamily: A_FONTS.mono, fontSize: 8, color: last ? fg : muted, letterSpacing: 0.3 }}>{d.m}</div>
          </div>
        );
      })}
    </div>
  );
}

// Segmented pill — "本月 / 上月 / 三月平均"
function Segmented({ options, value, onChange, dark, fg, muted }) {
  return (
    <div style={{
      display: 'inline-flex', padding: 3, borderRadius: 999,
      background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)',
    }}>
      {options.map(o => {
        const sel = o === value;
        return (
          <div key={o}
            onClick={() => onChange && onChange(o)}
            style={{
              padding: '6px 14px', borderRadius: 999,
              fontFamily: A_FONTS.body, fontSize: 12, fontWeight: 500, letterSpacing: -0.1,
              color: sel ? (dark ? '#000' : '#fff') : muted,
              background: sel ? (dark ? '#fff' : '#1c1c1e') : 'transparent',
              cursor: 'pointer', userSelect: 'none', transition: 'all .2s',
            }}>{o}</div>
        );
      })}
    </div>
  );
}

// expose primitives globally for variant scripts
Object.assign(window, {
  A_COLORS, A_FONTS, MONTH, TOTAL_OUT, TOTAL_IN, NET, SAVINGS_RATE, BUDGET,
  CATS, DAILY, DAILY_LABELS, TREND, fmt, pct,
  AGlyph: Glyph, Donut, BarRow, DailyBars, MiniMonthBars, Segmented,
});
