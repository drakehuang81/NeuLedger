// NeuLedger Search — primitives + shared data
// Frame: 402×874 iPhone 17 Pro

const S_COLORS = {
  accent: '#FF9500',
  accentDark: '#FF9F0A',
  income: '#34C759',
  incomeDark: '#30D158',
  expense: '#FF3B30',
  expenseDark: '#FF453A',
  ai: '#A66BF0',
  aiDark: '#BF8DFF',
};
const S_FONTS = {
  display: '"Bricolage Grotesque", -apple-system, system-ui, sans-serif',
  body: '"DM Sans", -apple-system, system-ui, sans-serif',
  mono: '"DM Mono", "SF Mono", ui-monospace, Menlo, monospace',
};

// shared txn corpus — search across these
const TXNS = [
  { id: 't1',  name: '星巴克',         cat: '餐飲', sub: '咖啡',     account: '信用卡',     accountColor: '#5E5CE6', amount: 165,   when: 'Today 09:12',     date: '2026-04-25', tags: ['#早餐'],     note: '冰美式 + 司康' },
  { id: 't2',  name: '7-11',          cat: '餐飲', sub: '便利商店', account: 'Apple Pay',  accountColor: '#000',    amount: 89,    when: 'Today 13:24',     date: '2026-04-25', tags: [],            note: '飯糰' },
  { id: 't3',  name: 'Uber',          cat: '交通', sub: '計程車',   account: '信用卡',     accountColor: '#5E5CE6', amount: 280,   when: 'Yesterday',       date: '2026-04-24', tags: ['#公帳'],     note: '回家' },
  { id: 't4',  name: 'Netflix',       cat: '訂閱', sub: '影音',     account: '信用卡',     accountColor: '#5E5CE6', amount: 390,   when: 'Apr 22',          date: '2026-04-22', tags: ['#訂閱'],     note: '月費' },
  { id: 't5',  name: 'Spotify',       cat: '訂閱', sub: '音樂',     account: '信用卡',     accountColor: '#5E5CE6', amount: 149,   when: 'Apr 22',          date: '2026-04-22', tags: ['#訂閱'],     note: '月費' },
  { id: 't6',  name: 'iCloud+',       cat: '訂閱', sub: '雲端',     account: '信用卡',     accountColor: '#5E5CE6', amount: 90,    when: 'Apr 21',          date: '2026-04-21', tags: ['#訂閱'],     note: '200GB' },
  { id: 't7',  name: '誠品書店',       cat: '購物', sub: '書籍',     account: '信用卡',     accountColor: '#5E5CE6', amount: 1280,  when: 'Apr 20',          date: '2026-04-20', tags: ['#閱讀'],     note: '原子習慣 + Designing Data-Intensive' },
  { id: 't8',  name: '小確幸火鍋',     cat: '餐飲', sub: '聚餐',     account: 'Apple Pay',  accountColor: '#000',    amount: 2400,  when: 'Apr 19 (六)',     date: '2026-04-19', tags: ['#朋友','#公帳'], note: '4 人 AA' },
  { id: 't9',  name: '中油加油站',     cat: '交通', sub: '加油',     account: '信用卡',     accountColor: '#5E5CE6', amount: 1850,  when: 'Apr 18',          date: '2026-04-18', tags: [],            note: '滿油' },
  { id: 't10', name: '蝦皮 — Anker',   cat: '購物', sub: '3C',       account: '信用卡',     accountColor: '#5E5CE6', amount: 890,   when: 'Apr 17',          date: '2026-04-17', tags: [],            note: '充電線 ×2' },
  { id: 't11', name: '台電',          cat: '居住', sub: '水電',     account: '銀行轉帳',   accountColor: '#34C759', amount: 1840,  when: 'Apr 15',          date: '2026-04-15', tags: ['#房子'],     note: '雙月電費' },
  { id: 't12', name: 'Apple Music?',  cat: '未分類', sub: '',        account: '信用卡',     accountColor: '#5E5CE6', amount: 170,   when: 'Apr 14',          date: '2026-04-14', tags: [],            note: '需要確認', uncat: true },
  { id: 't13', name: '星巴克',         cat: '餐飲', sub: '咖啡',     account: '信用卡',     accountColor: '#5E5CE6', amount: 155,   when: 'Apr 12',          date: '2026-04-12', tags: ['#早餐'],     note: '拿鐵' },
  { id: 't14', name: 'Uber Eats',      cat: '餐飲', sub: '外送',     account: '信用卡',     accountColor: '#5E5CE6', amount: 420,   when: 'Apr 11 (五)',     date: '2026-04-11', tags: [],            note: '晚餐' },
  { id: 't15', name: '街口支付 — 早餐', cat: '餐飲', sub: '早餐',     account: '街口',       accountColor: '#FF6B6B', amount: 65,    when: 'Apr 11',          date: '2026-04-11', tags: [],            note: '蛋餅' },
  { id: 't16', name: '加州健身',       cat: '健康', sub: '健身',     account: '信用卡',     accountColor: '#5E5CE6', amount: 1880,  when: 'Apr 10',          date: '2026-04-10', tags: ['#訂閱'],     note: '月費 (年約)' },
  { id: 't17', name: '薪資轉入',       cat: '收入', sub: '薪資',     account: '銀行帳戶',   accountColor: '#34C759', amount: -65000,when: 'Apr 5',           date: '2026-04-05', tags: [],            note: '4 月薪資', isIncome: true },
  { id: 't18', name: 'JCB 帳單',       cat: '帳單', sub: '信用卡',   account: '銀行轉帳',   accountColor: '#34C759', amount: 28400, when: 'Apr 5',           date: '2026-04-05', tags: [],            note: '3 月帳單' },
  { id: 't19', name: '不知名扣款',     cat: '未分類', sub: '',        account: '信用卡',     accountColor: '#5E5CE6', amount: 35,    when: 'Apr 3',           date: '2026-04-03', tags: [],            note: '?需要查', uncat: true },
];

// AI-suggested prompts (smart, contextual)
const AI_PROMPTS = [
  { q: '上週訂閱花多少?',         hint: '4 筆 · NT$ 629', icon: 'sparkles', kind: 'ai' },
  { q: '不常見的扣款',             hint: '2 筆未分類',     icon: 'alert',    kind: 'ai' },
  { q: '這個月最貴的 3 筆',         hint: 'JCB · 火鍋 · 健身', icon: 'crown',    kind: 'ai' },
  { q: '週末和朋友一起吃飯',       hint: '#朋友 #公帳',    icon: 'group',    kind: 'ai' },
  { q: '在星巴克花了多少?',         hint: '2 筆 · NT$ 320', icon: 'recur',    kind: 'ai' },
  { q: '所有公帳交易',             hint: '可分攤的',       icon: 'split',    kind: 'ai' },
];

// quick filter chips
const QUICK_CHIPS = [
  { label: '本月',     tone: 'neutral' },
  { label: '本週',     tone: 'neutral' },
  { label: '> NT$ 500', tone: 'neutral' },
  { label: '#訂閱',    tone: 'tag' },
  { label: '#公帳',    tone: 'tag' },
  { label: '未分類',   tone: 'warn' },
  { label: '餐飲',     tone: 'cat' },
  { label: '交通',     tone: 'cat' },
];

// recent searches (history)
const RECENT = ['星巴克', '訂閱', '本月外食', 'Netflix'];

const sFmt = (n) => Math.abs(n).toLocaleString('en-US');

// ── Glyph ─────────────────────────────────────────────────
function SGlyph({ name, size = 18, color = '#000', stroke = 1.8 }) {
  const s = size;
  const p = { fill: 'none', stroke: color, strokeWidth: stroke, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (name) {
    case 'search':   return <svg width={s} height={s} viewBox="0 0 24 24"><circle {...p} cx="11" cy="11" r="7"/><path {...p} d="M20 20l-3.5-3.5"/></svg>;
    case 'sparkles': return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M12 3l1.8 4.5L18 9l-4.2 1.5L12 15l-1.8-4.5L6 9l4.2-1.5L12 3z"/><path {...p} d="M19 15l.9 2.1 2.1.9-2.1.9-.9 2.1-.9-2.1-2.1-.9 2.1-.9.9-2.1z"/></svg>;
    case 'mic':      return <svg width={s} height={s} viewBox="0 0 24 24"><rect {...p} x="9" y="3" width="6" height="12" rx="3"/><path {...p} d="M5 11a7 7 0 0014 0M12 18v3"/></svg>;
    case 'close':    return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M6 6l12 12M18 6L6 18"/></svg>;
    case 'plus':     return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M12 5v14M5 12h14"/></svg>;
    case 'filter':   return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M4 5h16l-6 8v6l-4-2v-4L4 5z"/></svg>;
    case 'sliders':  return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M4 7h10M4 17h6"/><circle {...p} cx="17" cy="7" r="2.2"/><circle {...p} cx="13" cy="17" r="2.2"/><path {...p} d="M19 7h1M15 17h5"/></svg>;
    case 'chev':     return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M9 6l6 6-6 6"/></svg>;
    case 'chev-d':   return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M6 9l6 6 6-6"/></svg>;
    case 'arrow-up': return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M12 19V5M5 12l7-7 7 7"/></svg>;
    case 'arrow-r':  return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M5 12h14M13 6l6 6-6 6"/></svg>;
    case 'clock':    return <svg width={s} height={s} viewBox="0 0 24 24"><circle {...p} cx="12" cy="12" r="9"/><path {...p} d="M12 7v5l3 2"/></svg>;
    case 'crown':    return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M3 8l4 4 5-7 5 7 4-4-1.5 11h-15L3 8z"/></svg>;
    case 'alert':    return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M12 4l10 17H2L12 4z"/><path {...p} d="M12 10v5M12 18v.5"/></svg>;
    case 'recur':    return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M4 9V5h4M20 15v4h-4"/><path {...p} d="M4 9c2-3 5-5 9-5 4 0 7 2 9 5M20 15c-2 3-5 5-9 5-4 0-7-2-9-5"/></svg>;
    case 'group':    return <svg width={s} height={s} viewBox="0 0 24 24"><circle {...p} cx="9" cy="9" r="3.5"/><circle {...p} cx="17" cy="11" r="2.5"/><path {...p} d="M3 19c1-3 3.5-4.5 6-4.5s5 1.5 6 4.5M14 19c.5-2 1.5-3 3-3s2.5 1 3 3"/></svg>;
    case 'split':    return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M6 4v6c0 4 12 4 12 10v0M6 4l-2 2M6 4l2 2M18 20l-2-2M18 20l2-2"/></svg>;
    case 'tag':      return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M3 3h8l10 10-8 8L3 11V3z"/><circle {...p} cx="7.5" cy="7.5" r="1"/></svg>;
    case 'cmd':      return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M9 6a3 3 0 10-3 3v6a3 3 0 103-3V9h6v3a3 3 0 103-3 3 3 0 00-3 3H9V9a3 3 0 00-3-3 3 3 0 003 3"/></svg>;
    case 'enter':    return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M20 6v6a2 2 0 01-2 2H5M9 10l-4 4 4 4"/></svg>;
    case 'globe':    return <svg width={s} height={s} viewBox="0 0 24 24"><circle {...p} cx="12" cy="12" r="9"/><path {...p} d="M3 12h18M12 3a14 14 0 010 18M12 3a14 14 0 000 18"/></svg>;
    case 'home':     return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M3 11l9-8 9 8M5 9.5V20a1 1 0 001 1h4v-6h4v6h4a1 1 0 001-1V9.5"/></svg>;
    case 'chart':    return <svg width={s} height={s} viewBox="0 0 24 24"><path {...p} d="M4 19h16M7 16V9M12 16V5M17 16v-7"/></svg>;
    case 'wallet':   return <svg width={s} height={s} viewBox="0 0 24 24"><rect {...p} x="3" y="6" width="18" height="13" rx="2.5"/><path {...p} d="M3 10h18M16 14h2"/></svg>;
    default: return <svg width={s} height={s}/>;
  }
}

// ── Bottom tab bar ────────────────────────────────────────
function TabBar({ active = 'search', dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.45)' : 'rgba(60,60,67,0.45)';
  const accent = dark ? S_COLORS.accentDark : S_COLORS.accent;
  const items = [
    { id: 'home',   label: 'Ledger',  icon: 'wallet' },
    { id: 'analytics', label: 'Analytics', icon: 'chart' },
    { id: 'add',    label: '',     icon: 'plus', isFab: true },
    { id: 'search', label: 'Search', icon: 'search' },
    { id: 'me',     label: 'Me',     icon: 'globe' },
  ];
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0,
      paddingBottom: 28, paddingTop: 8,
      background: dark ? 'rgba(20,20,22,0.85)' : 'rgba(255,255,255,0.85)',
      backdropFilter: 'blur(24px) saturate(180%)',
      WebkitBackdropFilter: 'blur(24px) saturate(180%)',
      borderTop: dark ? '0.5px solid rgba(255,255,255,0.08)' : '0.5px solid rgba(0,0,0,0.06)',
      display: 'flex', alignItems: 'center', justifyContent: 'space-around',
      zIndex: 5,
    }}>
      {items.map(it => {
        const isActive = it.id === active;
        const c = isActive ? accent : muted;
        if (it.isFab) {
          return (
            <div key={it.id} style={{
              width: 48, height: 48, borderRadius: 24,
              background: `linear-gradient(135deg, ${accent}, #FF6B35)`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: `0 4px 14px ${accent}55`,
              marginTop: -16,
            }}>
              <SGlyph name="plus" size={22} color="#fff" stroke={2.4}/>
            </div>
          );
        }
        return (
          <div key={it.id} style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
            padding: '4px 12px',
          }}>
            <SGlyph name={it.icon} size={20} color={c} stroke={isActive ? 2 : 1.6}/>
            <div style={{ fontFamily: S_FONTS.body, fontSize: 9, fontWeight: 600, color: c, letterSpacing: -0.1 }}>{it.label}</div>
          </div>
        );
      })}
    </div>
  );
}

// expose globally
Object.assign(window, {
  S_COLORS, S_FONTS, TXNS, AI_PROMPTS, QUICK_CHIPS, RECENT, sFmt,
  SGlyph, TabBar,
});
