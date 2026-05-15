// NeuLedger Onboarding — B Prototype (Interactive)
// 3-step clickable flow with entrance animation, custom-account sheet,
// and live try-it AI extraction. Sub-variants via `tone` prop.

const { useState, useEffect, useRef, useMemo } = React;

// ─────────────────────────────────────────────────────────────
// Tone palette — sub-variants for B direction
// ─────────────────────────────────────────────────────────────
const TONES = {
  warm: {  // default — orange/peach
    accent: '#FF9500', accentDark: '#FF9F0A',
    bgLight: ['#FFE4B8','#FFF6E8','#FAFAF7'],
    bgDark: ['#4A2A0E','#1a0f08','#050505'],
    orb1: '#FF9500', orb2: '#34C759',
  },
  cool: {  // teal/blue
    accent: '#0A84FF', accentDark: '#409CFF',
    bgLight: ['#CDE8FF','#EAF4FF','#F6F8FB'],
    bgDark: ['#0E2A4A','#070F1A','#040608'],
    orb1: '#5E5CE6', orb2: '#0A84FF',
  },
  neutral: {  // off-white minimal
    accent: '#FF9500', accentDark: '#FF9F0A',
    bgLight: ['#F2F0EC','#F5F3EE','#FAFAF7'],
    bgDark: ['#1A1A1C','#101012','#050505'],
    orb1: '#A8A8AA', orb2: '#8E8E93',
  },
};

function getTonePalette(tone, dark) {
  const t = TONES[tone] || TONES.warm;
  const stops = dark ? t.bgDark : t.bgLight;
  return { ...t, stops };
}

// ─────────────────────────────────────────────────────────────
// Animated entrance hook
// ─────────────────────────────────────────────────────────────
function useEnter(deps = []) {
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    setVisible(false);
    const t = setTimeout(() => setVisible(true), 30);
    return () => clearTimeout(t);
  }, deps);
  return visible;
}

const EASE = 'cubic-bezier(.22,.9,.32,1)';

function Reveal({ delay = 0, dir = 'up', distance = 24, visible, children, style }) {
  const t = {
    up: `translateY(${distance}px)`,
    down: `translateY(-${distance}px)`,
    left: `translateX(${distance}px)`,
    right: `translateX(-${distance}px)`,
    scale: 'scale(0.94)',
    none: 'none',
  }[dir];
  return (
    <div style={{
      opacity: visible ? 1 : 0,
      transform: visible ? 'none' : t,
      transition: `opacity .55s ${EASE} ${delay}ms, transform .65s ${EASE} ${delay}ms`,
      ...style,
    }}>{children}</div>
  );
}

// ─────────────────────────────────────────────────────────────
// Step 1 — Welcome (with entrance anim)
// ─────────────────────────────────────────────────────────────
function BWelcomeI({ dark, dense, tone, bgIntensity = 1, onNext, onSkip }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const pal = getTonePalette(tone, dark);
  const visible = useEnter([tone, dark]);
  const accent = dark ? pal.accentDark : pal.accent;

  const bg = `radial-gradient(ellipse at 20% 0%, ${pal.stops[0]} 0%, ${pal.stops[1]} 50%, ${pal.stops[2]} 90%)`;

  return (
    <Phone dark={dark} bg={bg}>
      {/* orbs */}
      <div style={{ position: 'absolute', inset: 0, zIndex: 0, overflow: 'hidden', pointerEvents: 'none' }}>
        <div style={{
          position: 'absolute', top: 80, right: -40, width: 240, height: 240,
          borderRadius: '50%', background: pal.orb1,
          opacity: (dark ? 0.3 : 0.35) * bgIntensity,
          filter: 'blur(60px)',
          transform: visible ? 'scale(1)' : 'scale(0.6)',
          transition: `transform 1.2s ${EASE}, opacity .8s ${EASE}`,
        }}/>
        <div style={{
          position: 'absolute', top: 280, left: -60, width: 220, height: 220,
          borderRadius: '50%', background: pal.orb2,
          opacity: (dark ? 0.2 : 0.22) * bgIntensity,
          filter: 'blur(70px)',
          transform: visible ? 'scale(1)' : 'scale(0.6)',
          transition: `transform 1.3s ${EASE} .1s, opacity .9s ${EASE}`,
        }}/>
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: dense ? '12px 24px 20px' : '20px 24px 28px', position: 'relative', zIndex: 1 }}>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', gap: dense ? 22 : 30 }}>

          <Reveal visible={visible} delay={120} dir="scale">
            <Glass dark={dark} radius={32} style={{ padding: dense ? '24px 24px' : '28px 26px' }}>
              <div style={{ fontFamily: FONTS.body, fontSize: 13, color: muted, letterSpacing: -0.1, marginBottom: 6 }}>Total balance · 總資產</div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 44, fontWeight: 500, color: fg, letterSpacing: -1.4, lineHeight: 1, marginBottom: 14 }}>
                <span style={{ fontSize: 18, color: muted, marginRight: 6, fontWeight: 400 }}>NT$</span>
                52,550
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <div style={{ padding: '5px 10px', borderRadius: 999, background: dark ? 'rgba(48,209,88,0.18)' : 'rgba(52,199,89,0.14)', fontFamily: FONTS.mono, fontSize: 12, fontWeight: 500, color: dark ? COLORS.incomeDark : COLORS.income }}>↑ +12,400 this mo.</div>
                <div style={{ padding: '5px 10px', borderRadius: 999, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)', fontFamily: FONTS.body, fontSize: 12, color: muted }}>4 accounts</div>
              </div>
            </Glass>
          </Reveal>

          <div style={{ display: 'flex', gap: 10 }}>
            <Reveal visible={visible} delay={260} dir="up" distance={16} style={{ flex: 1 }}>
              <Glass dark={dark} radius={20} style={{ padding: '12px 14px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <div style={{ width: 32, height: 32, borderRadius: 10, background: COLORS.expense + '22', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Glyph name="banknote" size={18} color={COLORS.expense}/>
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontFamily: FONTS.body, fontSize: 13, fontWeight: 500, color: fg }}>星巴克 latte</div>
                    <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: muted }}>−NT$ 165</div>
                  </div>
                </div>
              </Glass>
            </Reveal>
            <Reveal visible={visible} delay={340} dir="up" distance={16} style={{ flex: 1 }}>
              <Glass dark={dark} radius={20} style={{ padding: '12px 14px' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <div style={{ width: 32, height: 32, borderRadius: 10, background: COLORS.income + '22', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Glyph name="wallet" size={18} color={COLORS.income}/>
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontFamily: FONTS.body, fontSize: 13, fontWeight: 500, color: fg }}>Salary</div>
                    <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: dark ? COLORS.incomeDark : COLORS.income }}>+NT$ 65,000</div>
                  </div>
                </div>
              </Glass>
            </Reveal>
          </div>

          <Reveal visible={visible} delay={460} dir="up" distance={20}>
            <div style={{ fontFamily: FONTS.display, fontSize: 44, lineHeight: 0.95, fontWeight: 700, color: fg, letterSpacing: -1.8 }}>
              Every NT$,<br/>
              <span style={{ fontStyle: 'italic', fontWeight: 500, color: accent }}>seen.</span>
            </div>
            <div style={{ fontFamily: FONTS.body, fontSize: 16, lineHeight: 1.4, color: muted, marginTop: 14, letterSpacing: -0.15, maxWidth: 320 }}>
              On-device 記帳 with Liquid Glass. Beautiful by default, private by design.
            </div>
          </Reveal>

          <Reveal visible={visible} delay={640} dir="up" distance={12}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              <PressButton accent={accent} onClick={onNext}>Get Started</PressButton>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingTop: 4 }}>
                <Dots count={3} active={0} dark={dark}/>
                <Tappable onClick={onSkip}><div style={{ fontFamily: FONTS.body, fontSize: 15, color: muted, padding: '6px 8px' }}>Skip</div></Tappable>
              </div>
            </div>
          </Reveal>
        </div>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// Step 2 — Accounts (with selection + sheet)
// ─────────────────────────────────────────────────────────────
const PRESET_ACCOUNTS = [
  { id: 'cash', name: 'Cash 現金', type: 'Cash', icon: 'banknote', color: '#8E8E93', amount: 3200 },
  { id: 'esun', name: '玉山銀行', type: 'Bank', icon: 'wallet', color: '#0A84FF', amount: 48930 },
  { id: 'easycard', name: '悠遊卡', type: 'E-wallet', icon: 'phone', color: '#5E5CE6', amount: 420 },
  { id: 'visa', name: 'Visa 卡', type: 'Credit card', icon: 'creditcard', color: '#FF2D55', amount: null },
];

const ICON_OPTIONS = [
  { id: 'wallet', label: 'Bank' },
  { id: 'banknote', label: 'Cash' },
  { id: 'creditcard', label: 'Credit' },
  { id: 'phone', label: 'E-wallet' },
];

const COLOR_OPTIONS = ['#FF9500','#0A84FF','#5E5CE6','#FF2D55','#34C759','#8E8E93'];

function BAccountI({ dark, dense, tone, bgIntensity = 1, accounts, setAccounts, onNext, onBack, onSkip }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const pal = getTonePalette(tone, dark);
  const accent = dark ? pal.accentDark : pal.accent;
  const visible = useEnter([tone, dark]);

  const bg = `radial-gradient(ellipse at 80% 100%, ${pal.stops[0]} 0%, ${pal.stops[1]} 50%, ${pal.stops[2]} 90%)`;

  const [sheetOpen, setSheetOpen] = useState(false);
  const [draft, setDraft] = useState({ name: '', icon: 'wallet', color: COLOR_OPTIONS[0], amount: '' });

  const selectedCount = accounts.filter(a => a.selected).length;

  const toggle = (id) => {
    setAccounts(accounts.map(a => a.id === id ? { ...a, selected: !a.selected } : a));
  };

  const addCustom = () => {
    if (!draft.name.trim()) return;
    setAccounts([
      ...accounts,
      {
        id: 'custom-' + Date.now(),
        name: draft.name,
        type: ICON_OPTIONS.find(i => i.id === draft.icon).label,
        icon: draft.icon,
        color: draft.color,
        amount: parseInt(draft.amount.replace(/[^0-9]/g, '')) || 0,
        selected: true,
        custom: true,
      },
    ]);
    setSheetOpen(false);
    setDraft({ name: '', icon: 'wallet', color: COLOR_OPTIONS[0], amount: '' });
  };

  return (
    <Phone dark={dark} bg={bg}>
      <div style={{ position: 'absolute', inset: 0, zIndex: 0, overflow: 'hidden', pointerEvents: 'none' }}>
        <div style={{
          position: 'absolute', bottom: -60, right: -60, width: 260, height: 260, borderRadius: '50%',
          background: pal.orb1, opacity: 0.18 * bgIntensity, filter: 'blur(70px)',
        }}/>
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: dense ? '12px 22px 20px' : '20px 22px 28px', position: 'relative', zIndex: 1 }}>
        <Reveal visible={visible} delay={60} dir="up" distance={12}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
            <Tappable onClick={onBack}>
              <div style={{
                width: 34, height: 34, borderRadius: 17,
                background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <svg width="9" height="14" viewBox="0 0 9 14" fill="none">
                  <path d="M7.5 1L1.5 7l6 6" stroke={fg} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
            </Tappable>
            <div style={{ fontFamily: FONTS.body, fontSize: 13, color: muted, letterSpacing: -0.1 }}>Step 02 of 03</div>
          </div>
          <div style={{ fontFamily: FONTS.display, fontSize: 32, lineHeight: 1.05, fontWeight: 700, color: fg, letterSpacing: -1.2, marginBottom: 6 }}>Pick your<br/>accounts.</div>
          <div style={{ fontFamily: FONTS.body, fontSize: 14, color: muted, letterSpacing: -0.1, marginBottom: dense ? 14 : 20 }}>Tap to add. Long-press to edit.</div>
        </Reveal>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, flex: 1, alignContent: 'flex-start' }}>
          {accounts.map((a, i) => (
            <Reveal key={a.id} visible={visible} delay={140 + i * 60} dir="up" distance={14}>
              <Tappable onClick={() => toggle(a.id)}>
                <Glass dark={dark} radius={22} style={{
                  padding: dense ? '14px 14px' : '16px 16px',
                  minHeight: dense ? 124 : 140,
                  outline: a.selected ? `2px solid ${accent}` : 'none',
                  outlineOffset: -2,
                  transition: `outline .2s ${EASE}`,
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <div style={{
                      width: 36, height: 36, borderRadius: 11, background: a.color + '22',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                    }}>
                      <Glyph name={a.icon} size={20} color={a.color}/>
                    </div>
                    <div style={{
                      width: 22, height: 22, borderRadius: 11,
                      background: a.selected ? accent : 'transparent',
                      border: a.selected ? 'none' : `1.5px solid ${muted}`,
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      transition: `background .2s ${EASE}`,
                    }}>
                      {a.selected && <Glyph name="check" size={14} color="#fff" stroke={2.5}/>}
                    </div>
                  </div>
                  <div style={{ marginTop: dense ? 16 : 22 }}>
                    <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 4 }}>{a.type}</div>
                    <div style={{ fontFamily: FONTS.body, fontSize: 15, fontWeight: 600, color: fg, letterSpacing: -0.2, marginBottom: 4 }}>{a.name}</div>
                    <div style={{ fontFamily: FONTS.mono, fontSize: 13, color: a.amount ? fg : muted, letterSpacing: -0.2 }}>
                      {a.amount != null ? <><span style={{ fontSize: 10, color: muted, marginRight: 2 }}>NT$</span>{a.amount.toLocaleString()}</> : '— add balance'}
                    </div>
                  </div>
                </Glass>
              </Tappable>
            </Reveal>
          ))}
          <Reveal visible={visible} delay={140 + accounts.length * 60} dir="up" distance={14} style={{ gridColumn: '1 / -1' }}>
            <Tappable onClick={() => setSheetOpen(true)}>
              <Glass dark={dark} radius={22} style={{
                padding: '14px 14px', display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: 60,
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: muted }}>
                  <Glyph name="plus" size={18} color={muted}/>
                  <span style={{ fontFamily: FONTS.body, fontSize: 14, fontWeight: 500 }}>Add custom account</span>
                </div>
              </Glass>
            </Tappable>
          </Reveal>
        </div>

        <Reveal visible={visible} delay={420} dir="up" distance={10}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12, marginTop: 16 }}>
            <PressButton accent={accent} onClick={onNext} disabled={selectedCount === 0}>
              Continue · {selectedCount} selected
            </PressButton>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Dots count={3} active={1} dark={dark}/>
              <Tappable onClick={onSkip}><div style={{ fontFamily: FONTS.body, fontSize: 15, color: muted, padding: '6px 8px' }}>Skip</div></Tappable>
            </div>
          </div>
        </Reveal>
      </div>

      {/* Bottom sheet */}
      <Sheet open={sheetOpen} onClose={() => setSheetOpen(false)} dark={dark}>
        <div style={{ padding: '8px 22px 28px' }}>
          <div style={{ width: 38, height: 5, borderRadius: 3, background: dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.15)', margin: '8px auto 18px' }}/>
          <div style={{ fontFamily: FONTS.display, fontSize: 24, fontWeight: 700, color: fg, letterSpacing: -0.7, marginBottom: 4 }}>新增帳戶</div>
          <div style={{ fontFamily: FONTS.body, fontSize: 13, color: muted, marginBottom: 18 }}>Name it, pick an icon and color.</div>

          <div style={{ marginBottom: 14 }}>
            <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 6 }}>Account name</div>
            <Glass dark={dark} radius={14} style={{ padding: '10px 14px' }}>
              <input
                value={draft.name}
                onChange={e => setDraft({ ...draft, name: e.target.value })}
                placeholder="e.g. 中信銀行"
                style={{
                  border: 'none', outline: 'none', background: 'transparent', width: '100%',
                  fontFamily: FONTS.body, fontSize: 16, color: fg, letterSpacing: -0.2,
                }}/>
            </Glass>
          </div>

          <div style={{ marginBottom: 14 }}>
            <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 6 }}>Type</div>
            <div style={{ display: 'flex', gap: 8 }}>
              {ICON_OPTIONS.map(opt => (
                <Tappable key={opt.id} onClick={() => setDraft({ ...draft, icon: opt.id })}>
                  <Glass dark={dark} radius={14} style={{
                    padding: '10px 12px', minWidth: 70,
                    outline: draft.icon === opt.id ? `2px solid ${accent}` : 'none', outlineOffset: -2,
                  }}>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
                      <Glyph name={opt.id} size={20} color={draft.icon === opt.id ? accent : fg}/>
                      <div style={{ fontFamily: FONTS.body, fontSize: 11, color: muted }}>{opt.label}</div>
                    </div>
                  </Glass>
                </Tappable>
              ))}
            </div>
          </div>

          <div style={{ marginBottom: 14 }}>
            <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 6 }}>Color</div>
            <div style={{ display: 'flex', gap: 10 }}>
              {COLOR_OPTIONS.map(c => (
                <Tappable key={c} onClick={() => setDraft({ ...draft, color: c })}>
                  <div style={{
                    width: 30, height: 30, borderRadius: 15, background: c,
                    border: draft.color === c ? `2px solid ${dark ? '#fff' : '#000'}` : '2px solid transparent',
                    boxShadow: draft.color === c ? `0 0 0 2px ${c}` : 'none',
                  }}/>
                </Tappable>
              ))}
            </div>
          </div>

          <div style={{ marginBottom: 18 }}>
            <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 6 }}>Starting balance · NT$</div>
            <Glass dark={dark} radius={14} style={{ padding: '10px 14px' }}>
              <input
                value={draft.amount}
                onChange={e => setDraft({ ...draft, amount: e.target.value })}
                placeholder="0"
                inputMode="numeric"
                style={{
                  border: 'none', outline: 'none', background: 'transparent', width: '100%',
                  fontFamily: FONTS.mono, fontSize: 16, color: fg, letterSpacing: -0.2,
                }}/>
            </Glass>
          </div>

          <PressButton accent={accent} onClick={addCustom} disabled={!draft.name.trim()}>Add account</PressButton>
        </div>
      </Sheet>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// Step 3 — Ready (live try-it demo)
// ─────────────────────────────────────────────────────────────
const TRY_PROMPTS = [
  { input: '咖啡 65', amount: 65, cat: '飲食 · Coffee', acc: 'Cash', merchant: 'Coffee shop', tags: ['#morning'], type: 'expense' },
  { input: '7-11 三明治 45', amount: 45, cat: '飲食 · Convenience', acc: 'Cash', merchant: '7-11', tags: ['#breakfast'], type: 'expense' },
  { input: '計程車回家 280', amount: 280, cat: '交通 · Taxi', acc: '玉山銀行', merchant: 'Uber', tags: ['#night'], type: 'expense' },
  { input: '薪水 65000', amount: 65000, cat: 'Salary · 薪資', acc: '玉山銀行', merchant: 'Employer', tags: ['#monthly'], type: 'income' },
];

function BReadyI({ dark, dense, tone, bgIntensity = 1, onFinish }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const pal = getTonePalette(tone, dark);
  const accent = dark ? pal.accentDark : pal.accent;
  const visible = useEnter([tone, dark]);

  const bg = `radial-gradient(ellipse at 50% 30%, ${pal.stops[0]} 0%, ${pal.stops[1]} 40%, ${pal.stops[2]} 90%)`;

  const [promptIdx, setPromptIdx] = useState(0);
  const [extracted, setExtracted] = useState(null);
  const [extracting, setExtracting] = useState(false);
  const [ringFill, setRingFill] = useState(0);

  const prompt = TRY_PROMPTS[promptIdx];

  const tryIt = () => {
    setExtracting(true);
    setExtracted(null);
    setTimeout(() => {
      setExtracting(false);
      setExtracted(prompt);
      setRingFill(f => Math.min(100, f + 18 + Math.random() * 12));
    }, 900);
  };

  const next = () => {
    setPromptIdx((promptIdx + 1) % TRY_PROMPTS.length);
    setExtracted(null);
  };

  // Ring
  const radius = 64;
  const C = 2 * Math.PI * radius;

  return (
    <Phone dark={dark} bg={bg}>
      <div style={{ position: 'absolute', inset: 0, zIndex: 0, overflow: 'hidden', pointerEvents: 'none' }}>
        <div style={{
          position: 'absolute', top: 60, left: '50%', transform: 'translateX(-50%)',
          width: 280, height: 280, borderRadius: '50%',
          background: pal.orb1, opacity: 0.22 * bgIntensity, filter: 'blur(80px)',
        }}/>
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: dense ? '12px 22px 20px' : '20px 22px 28px', position: 'relative', zIndex: 1 }}>

        <Reveal visible={visible} delay={60} dir="up" distance={10}>
          <div style={{ fontFamily: FONTS.body, fontSize: 13, color: muted, letterSpacing: -0.1, textAlign: 'center' }}>Step 03 of 03</div>
          <div style={{ fontFamily: FONTS.display, fontSize: 30, lineHeight: 1, fontWeight: 700, color: fg, letterSpacing: -1.1, textAlign: 'center', marginTop: 4 }}>
            Try your first one.
          </div>
        </Reveal>

        {/* Mini ring + balance */}
        <Reveal visible={visible} delay={180} dir="scale">
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, padding: dense ? '14px 0' : '20px 0', justifyContent: 'center' }}>
            <div style={{ position: 'relative', width: 150, height: 150 }}>
              <svg width="150" height="150" viewBox="0 0 150 150">
                <circle cx="75" cy="75" r={radius} fill="none"
                  stroke={dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)'} strokeWidth="14"/>
                <circle cx="75" cy="75" r={radius} fill="none"
                  stroke={accent} strokeWidth="14"
                  strokeDasharray={`${(ringFill/100) * C} ${C}`}
                  strokeLinecap="round"
                  transform="rotate(-90 75 75)"
                  style={{ transition: `stroke-dasharray .6s ${EASE}` }}
                />
              </svg>
              <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
                <div style={{ fontFamily: FONTS.mono, fontSize: 9, color: muted, textTransform: 'uppercase', letterSpacing: 1.5 }}>Tracked</div>
                <div style={{ fontFamily: FONTS.mono, fontSize: 22, fontWeight: 500, color: fg, letterSpacing: -0.5, marginTop: 2 }}>
                  {Math.round(ringFill)}%
                </div>
                <div style={{ fontFamily: FONTS.body, fontSize: 10, color: muted, marginTop: 2 }}>{extracted ? 'Logged ✓' : 'Tap to try'}</div>
              </div>
            </div>
          </div>
        </Reveal>

        {/* Prompt selector */}
        <Reveal visible={visible} delay={300} dir="up" distance={10}>
          <div style={{ display: 'flex', gap: 6, marginBottom: 10, overflowX: 'auto' }}>
            {TRY_PROMPTS.map((p, i) => (
              <Tappable key={i} onClick={() => { setPromptIdx(i); setExtracted(null); }}>
                <div style={{
                  padding: '6px 12px', borderRadius: 999, whiteSpace: 'nowrap',
                  background: i === promptIdx
                    ? accent
                    : (dark ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.6)'),
                  fontFamily: FONTS.body, fontSize: 12, fontWeight: 500,
                  color: i === promptIdx ? '#fff' : fg,
                  letterSpacing: -0.1,
                  border: i !== promptIdx ? (dark ? '0.5px solid rgba(255,255,255,0.1)' : '0.5px solid rgba(0,0,0,0.06)') : 'none',
                }}>{p.input}</div>
              </Tappable>
            ))}
          </div>
        </Reveal>

        {/* Try-it card */}
        <Reveal visible={visible} delay={380} dir="up" distance={10}>
          <Tappable onClick={tryIt}>
            <Glass dark={dark} radius={20} style={{ padding: '14px 16px', minHeight: 64 }}>
              {extracting ? (
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <Glyph name="sparkles" size={16} color={accent}/>
                  <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: muted, textTransform: 'uppercase', letterSpacing: 1.2, fontWeight: 500 }}>
                    Extracting on-device…
                  </div>
                  <div style={{ display: 'flex', gap: 4, marginLeft: 'auto' }}>
                    {[0,1,2].map(i => (
                      <div key={i} style={{
                        width: 6, height: 6, borderRadius: 3, background: accent,
                        opacity: 0.4,
                        animation: `bDot 1s ${i * 0.15}s infinite`,
                      }}/>
                    ))}
                  </div>
                </div>
              ) : extracted ? (
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 10 }}>
                    <Glyph name="sparkles" size={12} color={accent}/>
                    <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1.2, fontWeight: 500 }}>
                      Extracted · 0.{Math.floor(3 + Math.random() * 5)}s
                    </div>
                    <div style={{ marginLeft: 'auto', fontFamily: FONTS.mono, fontSize: 11, color: COLORS.income, display: 'flex', alignItems: 'center', gap: 4 }}>
                      <Glyph name="check" size={11} color={COLORS.income} stroke={2.5}/> Logged
                    </div>
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 10 }}>
                    {[
                      { k: 'Amount', v: 'NT$ ' + extracted.amount.toLocaleString(), mono: true, c: extracted.type === 'income' ? COLORS.income : COLORS.expense },
                      { k: 'Category', v: extracted.cat },
                      { k: 'Account', v: extracted.acc },
                      { k: 'Merchant', v: extracted.merchant },
                    ].map((f, i) => (
                      <div key={i}>
                        <div style={{ fontFamily: FONTS.mono, fontSize: 9, color: muted, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 3 }}>{f.k}</div>
                        <div style={{ fontFamily: f.mono ? FONTS.mono : FONTS.body, fontSize: 13, fontWeight: 500, color: f.c || fg, letterSpacing: -0.1 }}>{f.v}</div>
                      </div>
                    ))}
                  </div>
                  <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                    {extracted.tags.map((t, i) => (
                      <div key={i} style={{
                        padding: '3px 9px', borderRadius: 999,
                        background: dark ? `${accent}30` : `${accent}1f`,
                        fontFamily: FONTS.mono, fontSize: 10, color: accent, fontWeight: 500,
                      }}>{t}</div>
                    ))}
                  </div>
                </div>
              ) : (
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <div style={{
                    width: 32, height: 32, borderRadius: 16, background: accent,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    boxShadow: `0 4px 12px ${accent}50`,
                  }}>
                    <Glyph name="sparkles" size={16} color="#fff"/>
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontFamily: FONTS.body, fontSize: 14, fontWeight: 600, color: fg, letterSpacing: -0.1 }}>Tap to extract</div>
                    <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: muted, marginTop: 2 }}>"{prompt.input}" → on-device</div>
                  </div>
                  <Glyph name="arrow-right" size={16} color={muted} stroke={2}/>
                </div>
              )}
            </Glass>
          </Tappable>
        </Reveal>

        <div style={{ flex: 1 }}/>

        {/* Helper line */}
        <Reveal visible={visible} delay={500} dir="up" distance={8}>
          <div style={{ fontFamily: FONTS.body, fontSize: 12, color: muted, textAlign: 'center', marginBottom: 14, letterSpacing: -0.1 }}>
            {extracted
              ? 'Nice. Try another, or open NeuLedger.'
              : 'Pick a phrase above, then tap the card.'}
          </div>
        </Reveal>

        <Reveal visible={visible} delay={580} dir="up" distance={8}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {extracted ? (
              <PressButton accent={accent} onClick={onFinish}>Open NeuLedger</PressButton>
            ) : (
              <PressButton accent={accent} onClick={tryIt}>
                <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <Glyph name="sparkles" size={16} color="#fff"/>
                  Try extraction
                </span>
              </PressButton>
            )}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Tappable onClick={next}>
                <div style={{ fontFamily: FONTS.body, fontSize: 13, color: muted, padding: '6px 8px' }}>Next phrase →</div>
              </Tappable>
              <Dots count={3} active={2} dark={dark}/>
              <Tappable onClick={onFinish}>
                <div style={{ fontFamily: FONTS.body, fontSize: 13, color: muted, padding: '6px 8px' }}>Skip</div>
              </Tappable>
            </div>
          </div>
        </Reveal>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// Done screen — celebratory
// ─────────────────────────────────────────────────────────────
function BDone({ dark, tone, onRestart }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const pal = getTonePalette(tone, dark);
  const accent = dark ? pal.accentDark : pal.accent;
  const visible = useEnter([tone, dark]);

  const bg = `radial-gradient(ellipse at 50% 50%, ${pal.stops[0]} 0%, ${pal.stops[1]} 40%, ${pal.stops[2]} 90%)`;

  return (
    <Phone dark={dark} bg={bg}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: '24px', alignItems: 'center', justifyContent: 'center', position: 'relative', zIndex: 1 }}>
        <Reveal visible={visible} delay={50} dir="scale">
          <div style={{
            width: 88, height: 88, borderRadius: 44,
            background: accent,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: `0 12px 40px ${accent}60`,
            marginBottom: 20,
          }}>
            <Glyph name="check" size={42} color="#fff" stroke={3}/>
          </div>
        </Reveal>
        <Reveal visible={visible} delay={200} dir="up" distance={14}>
          <div style={{ fontFamily: FONTS.display, fontSize: 36, fontWeight: 700, color: fg, letterSpacing: -1.2, textAlign: 'center', marginBottom: 8 }}>
            Welcome aboard.
          </div>
          <div style={{ fontFamily: FONTS.body, fontSize: 15, color: muted, textAlign: 'center', maxWidth: 280 }}>
            Onboarding complete · launching dashboard…
          </div>
        </Reveal>
        <Reveal visible={visible} delay={400} dir="up" distance={10}>
          <Tappable onClick={onRestart}>
            <div style={{ marginTop: 32, padding: '8px 16px', fontFamily: FONTS.body, fontSize: 13, color: muted }}>↻ Restart flow</div>
          </Tappable>
        </Reveal>
      </div>
    </Phone>
  );
}

// ─────────────────────────────────────────────────────────────
// Helpers — interaction
// ─────────────────────────────────────────────────────────────
function Tappable({ children, onClick, style }) {
  const [pressed, setPressed] = useState(false);
  return (
    <div
      onMouseDown={() => setPressed(true)}
      onMouseUp={() => setPressed(false)}
      onMouseLeave={() => setPressed(false)}
      onClick={onClick}
      style={{
        cursor: 'pointer', userSelect: 'none',
        transform: pressed ? 'scale(0.97)' : 'scale(1)',
        transition: `transform .12s ${EASE}`,
        ...style,
      }}
    >{children}</div>
  );
}

function PressButton({ children, accent, onClick, disabled }) {
  const [pressed, setPressed] = useState(false);
  return (
    <div
      onMouseDown={() => !disabled && setPressed(true)}
      onMouseUp={() => setPressed(false)}
      onMouseLeave={() => setPressed(false)}
      onClick={() => !disabled && onClick && onClick()}
      style={{
        height: 52, borderRadius: 26,
        background: disabled ? '#a8a8aa' : accent,
        opacity: disabled ? 0.5 : 1,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontFamily: FONTS.body, fontSize: 17, fontWeight: 600,
        color: '#fff', letterSpacing: -0.2, cursor: disabled ? 'default' : 'pointer',
        boxShadow: disabled ? 'none' : `0 8px 24px ${accent}40`,
        transform: pressed ? 'scale(0.98)' : 'scale(1)',
        transition: `transform .12s ${EASE}, box-shadow .15s ${EASE}`,
      }}
    >{children}</div>
  );
}

function Sheet({ open, onClose, dark, children }) {
  return (
    <React.Fragment>
      <div onClick={onClose} style={{
        position: 'absolute', inset: 0, zIndex: 100,
        background: open ? 'rgba(0,0,0,0.4)' : 'transparent',
        opacity: open ? 1 : 0,
        pointerEvents: open ? 'auto' : 'none',
        transition: `opacity .25s ${EASE}`,
      }}/>
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0, zIndex: 101,
        borderTopLeftRadius: 28, borderTopRightRadius: 28,
        background: dark ? '#1C1C1E' : '#FFFFFF',
        transform: open ? 'translateY(0)' : 'translateY(110%)',
        transition: `transform .35s ${EASE}`,
        maxHeight: '85%', overflow: 'auto',
        boxShadow: '0 -8px 40px rgba(0,0,0,0.2)',
      }}>{children}</div>
    </React.Fragment>
  );
}

// ─────────────────────────────────────────────────────────────
// Main controller — owns flow state for one tone
// ─────────────────────────────────────────────────────────────
function BFlow({ dark, dense, tone, bgIntensity }) {
  const [step, setStep] = useState(0);
  const [accounts, setAccounts] = useState(
    PRESET_ACCOUNTS.map((a, i) => ({ ...a, selected: i < 3 }))
  );

  const reset = () => {
    setStep(0);
    setAccounts(PRESET_ACCOUNTS.map((a, i) => ({ ...a, selected: i < 3 })));
  };

  const props = { dark, dense, tone, bgIntensity };

  if (step === 0) return <BWelcomeI {...props} onNext={() => setStep(1)} onSkip={() => setStep(3)}/>;
  if (step === 1) return <BAccountI {...props} accounts={accounts} setAccounts={setAccounts} onBack={() => setStep(0)} onNext={() => setStep(2)} onSkip={() => setStep(2)}/>;
  if (step === 2) return <BReadyI {...props} onFinish={() => setStep(3)}/>;
  return <BDone dark={dark} tone={tone} onRestart={reset}/>;
}

Object.assign(window, {
  BFlow, BWelcomeI, BAccountI, BReadyI, BDone,
  PRESET_ACCOUNTS, TONES, getTonePalette,
  EASE, Reveal, useEnter, Tappable, PressButton, Sheet,
  Tappable, PressButton, Sheet, Reveal, useEnter,
});
