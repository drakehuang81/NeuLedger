// NeuLedger Flow — scripted screen components for first-run demo
// All screens take props; no internal interaction. Reuses primitives from
// onboarding-variations.jsx + onboarding-b-prototype.jsx.

const { useState: useFS, useEffect: useFE, useRef: useFR } = React;

const EASE = 'cubic-bezier(.22,.9,.32,1)';

// ─────────────────────────────────────────────────────────────
// Faux pointer/cursor
// ─────────────────────────────────────────────────────────────
function FauxPointer({ x, y, tapping, visible }) {
  return (
    <div style={{
      position: 'absolute', left: 0, top: 0,
      transform: `translate(${x}px, ${y}px)`,
      transition: `transform .85s cubic-bezier(.4,0,.2,1), opacity .25s linear`,
      pointerEvents: 'none', zIndex: 500,
      opacity: visible ? 1 : 0,
    }}>
      <div style={{
        position: 'absolute', left: -22, top: -22, width: 44, height: 44, borderRadius: 22,
        border: '2px solid rgba(255,255,255,0.85)',
        animation: tapping ? 'tapRipple .55s ease-out' : 'none',
        opacity: tapping ? 1 : 0,
      }}/>
      <div style={{
        position: 'absolute', left: -14, top: -14, width: 28, height: 28, borderRadius: 14,
        background: 'rgba(255,255,255,0.4)',
        backdropFilter: 'blur(4px)', WebkitBackdropFilter: 'blur(4px)',
        border: '2px solid rgba(255,255,255,0.9)',
        boxShadow: '0 4px 14px rgba(0,0,0,0.25), inset 1px 1px 1px rgba(255,255,255,0.6)',
      }}/>
      <div style={{
        position: 'absolute', left: -3, top: -3, width: 6, height: 6, borderRadius: 3, background: '#fff',
      }}/>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Confetti
// ─────────────────────────────────────────────────────────────
function Confetti({ visible }) {
  const pieces = React.useMemo(() => {
    const palette = ['#E8835A', '#D4623E', '#FFB068', '#34C759', '#FFD27A', '#FF8A4C'];
    return Array.from({ length: 32 }).map((_, i) => ({
      id: i, left: 6 + Math.random() * 88, delay: Math.random() * 0.4,
      size: 5 + Math.random() * 7, rotate: Math.random() * 360,
      drift: -25 + Math.random() * 50, color: palette[i % palette.length],
      shape: i % 3 === 0 ? 'circle' : (i % 3 === 1 ? 'rect' : 'tri'),
      duration: 1.6 + Math.random() * 1.4,
    }));
  }, []);
  return (
    <div style={{
      position: 'absolute', inset: 0, overflow: 'hidden', pointerEvents: 'none', zIndex: 80,
      opacity: visible ? 1 : 0,
    }}>
      {visible && pieces.map(p => (
        <div key={p.id} style={{
          position: 'absolute', top: -16, left: `${p.left}%`,
          width: p.shape === 'rect' ? p.size * 1.4 : p.size,
          height: p.shape === 'rect' ? p.size * 0.4 : p.size,
          background: p.shape !== 'tri' ? p.color : 'transparent',
          borderRadius: p.shape === 'circle' ? '50%' : 1,
          borderLeft: p.shape === 'tri' ? `${p.size/2}px solid transparent` : 'none',
          borderRight: p.shape === 'tri' ? `${p.size/2}px solid transparent` : 'none',
          borderBottom: p.shape === 'tri' ? `${p.size}px solid ${p.color}` : 'none',
          transform: `rotate(${p.rotate}deg)`,
          animation: `confettiFall ${p.duration}s ${p.delay}s ease-in forwards`,
          ['--drift']: `${p.drift}px`,
        }}/>
      ))}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// CountUp
// ─────────────────────────────────────────────────────────────
function CountUpText({ from = 0, to = 0, animate, dur = 1100 }) {
  const [n, setN] = useFS(from);
  useFE(() => {
    if (!animate) { setN(from); return; }
    let raf; const start = performance.now();
    const tick = (t) => {
      const k = Math.min(1, (t - start) / dur);
      const ease = 1 - Math.pow(1 - k, 3);
      setN(Math.round(from + (to - from) * ease));
      if (k < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [animate, to]);
  return <span>{n.toLocaleString()}</span>;
}

// ─────────────────────────────────────────────────────────────
// Step 1: Ready screen
// ─────────────────────────────────────────────────────────────
function ReadyMini({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', position: 'relative', padding: '40px 28px 32px', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', top: -40, right: -40, width: 280, height: 280, borderRadius: '50%', background: COLORS.accent, opacity: dark ? 0.22 : 0.26, filter: 'blur(80px)', pointerEvents: 'none' }}/>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', position: 'relative', zIndex: 1 }}>
        <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: muted, textTransform: 'uppercase', letterSpacing: 1.6, fontWeight: 500, marginBottom: 14 }}>Step 4 / 4</div>
        <div style={{ fontFamily: FONTS.display, fontSize: 40, fontWeight: 700, color: fg, letterSpacing: -1.2, lineHeight: 1.05, marginBottom: 14 }}>
          一切都<br/>準備好了。
        </div>
        <div style={{ fontFamily: FONTS.body, fontSize: 16, color: muted, letterSpacing: -0.2, lineHeight: 1.45, maxWidth: 280, marginBottom: 32 }}>
          現在開始記下你的第一筆。隨時用一句自然語言。
        </div>
        <Glass dark={dark} radius={20} style={{ padding: '14px 18px', marginBottom: 10 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 32, height: 32, borderRadius: 16, background: 'rgba(52,199,89,0.18)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <path d="M5 12.5l5 5L19 8" stroke={dark ? COLORS.incomeDark : COLORS.income} strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <div style={{ fontFamily: FONTS.body, fontSize: 14, color: fg, fontWeight: 500 }}>4 帳戶已連結 · NT$ 0</div>
          </div>
        </Glass>
      </div>
      <div data-target="ready-done" style={{ position: 'relative', zIndex: 1 }}>
        <div style={{ padding: '15px 20px', borderRadius: 18, background: `linear-gradient(135deg, ${accent}, #FF6A00)`, textAlign: 'center', fontFamily: FONTS.body, fontSize: 16, fontWeight: 600, color: '#fff', letterSpacing: -0.2, boxShadow: `0 10px 28px ${accent}55` }}>完成</div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Step 2 & 5: Empty / Grown dashboard
// ─────────────────────────────────────────────────────────────
function DashboardScripted({ dark, balanceTo = 0, animateBalance = false, highlightAdd = false, showFirstRow = false, showCelebration = false }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;
  const income = dark ? COLORS.incomeDark : COLORS.income;
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', top: 0, right: -80, width: 280, height: 280, borderRadius: '50%', background: COLORS.accent, opacity: dark ? 0.22 : 0.26, filter: 'blur(80px)', pointerEvents: 'none' }}/>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '8px 22px 12px', position: 'relative', zIndex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ width: 32, height: 32, borderRadius: 16, background: `linear-gradient(135deg, ${accent}, #FF6A00)`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontFamily: FONTS.body, fontWeight: 700, fontSize: 13 }}>YT</div>
          <div>
            <div style={{ fontFamily: FONTS.body, fontSize: 12, color: muted, letterSpacing: -0.1 }}>Hi, 雨庭</div>
            <div style={{ fontFamily: FONTS.display, fontSize: 16, color: fg, fontWeight: 600, letterSpacing: -0.3 }}>2026 / 4 月</div>
          </div>
        </div>
        <div style={{ width: 36, height: 36, borderRadius: 18, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(255,255,255,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Glyph name="sparkles" size={16} color={accent}/>
        </div>
      </div>
      <div style={{ flex: 1, padding: '4px 18px', position: 'relative', zIndex: 1, overflow: 'hidden' }}>
        <Glass dark={dark} radius={22} style={{ padding: '20px 22px', marginBottom: 14 }}>
          <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1.2, marginBottom: 6 }}>本月餘額</div>
          <div style={{ fontFamily: FONTS.mono, fontSize: 38, fontWeight: 500, color: fg, letterSpacing: -1.2, lineHeight: 1, display: 'flex', alignItems: 'baseline', gap: 6 }}>
            <span style={{ fontSize: 18, fontWeight: 400, color: muted }}>NT$</span>
            <CountUpText from={0} to={balanceTo} animate={animateBalance}/>
          </div>
          {animateBalance && balanceTo > 0 && (
            <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: income, fontWeight: 600, letterSpacing: -0.1, marginTop: 6, opacity: 0, animation: 'fadeIn .4s .8s ease-out forwards' }}>+ NT$ 50,000 · 收入</div>
          )}
        </Glass>
        <div style={{ display: 'flex', gap: 6, marginBottom: 14, overflow: 'hidden' }}>
          {['全部', 'Cash', '玉山', '悠遊卡', 'Visa'].map((l, i) => (
            <div key={i} style={{ padding: '6px 12px', borderRadius: 999, background: i === 0 ? accent : (dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)'), color: i === 0 ? '#fff' : fg, fontFamily: FONTS.body, fontSize: 12, fontWeight: 500, letterSpacing: -0.1, flexShrink: 0 }}>{l}</div>
          ))}
        </div>
        <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1.2, marginBottom: 8 }}>最近交易</div>
        {!showFirstRow ? (
          <Glass dark={dark} radius={22} style={{ padding: '38px 24px', textAlign: 'center' }}>
            <div style={{ width: 60, height: 60, borderRadius: 30, margin: '0 auto 14px', background: dark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.04)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none">
                <path d="M3 9l1.5 8a2 2 0 002 1.7h11a2 2 0 002-1.7L21 9M3 9V6a2 2 0 012-2h14a2 2 0 012 2v3M3 9h18M9 13h6" stroke={muted} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <div style={{ fontFamily: FONTS.display, fontSize: 18, fontWeight: 600, color: fg, letterSpacing: -0.3, marginBottom: 4 }}>尚無交易</div>
            <div style={{ fontFamily: FONTS.body, fontSize: 13, color: muted, letterSpacing: -0.1, marginBottom: 18 }}>記錄您的第一筆收支吧!</div>
            <div data-target="empty-add" style={{ display: 'inline-block', position: 'relative' }}>
              {highlightAdd && <div style={{ position: 'absolute', inset: -6, borderRadius: 999, background: accent, opacity: 0.5, animation: 'pulseRing 1.4s ease-out infinite' }}/>}
              <div style={{ position: 'relative', padding: '11px 22px', borderRadius: 999, background: `linear-gradient(135deg, ${accent}, #FF6A00)`, fontFamily: FONTS.body, fontSize: 14, fontWeight: 600, color: '#fff', letterSpacing: -0.1, boxShadow: `0 6px 18px ${accent}55` }}>記一筆</div>
            </div>
          </Glass>
        ) : (
          <Glass dark={dark} radius={20} style={{ padding: 4, transform: 'translateY(0) scale(1)', opacity: 1, animation: 'rowGrowIn .55s .25s cubic-bezier(.22,.9,.32,1) both' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 14px', position: 'relative', borderRadius: 16, animation: 'highlightFlash 1.6s 1.0s ease-out 1 both' }}>
              <div style={{ width: 40, height: 40, borderRadius: 20, background: 'rgba(52,199,89,0.20)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22 }}>💼</div>
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <div style={{ fontFamily: FONTS.body, fontSize: 15, fontWeight: 500, color: fg, letterSpacing: -0.2 }}>薪資</div>
                  <div style={{ padding: '1px 6px', borderRadius: 4, background: 'rgba(52,199,89,0.18)', color: income, fontFamily: FONTS.mono, fontSize: 9, fontWeight: 600, letterSpacing: 0.4 }}>NEW</div>
                </div>
                <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: muted, letterSpacing: -0.1, marginTop: 2 }}>玉山銀行 · 今天 · AI</div>
              </div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 17, fontWeight: 500, color: income, letterSpacing: -0.4 }}>+50,000</div>
            </div>
          </Glass>
        )}
        {showCelebration && (
          <div style={{ marginTop: 12, padding: 14, borderRadius: 18, background: dark ? `linear-gradient(135deg, ${accent}33, rgba(255,255,255,0.04))` : `linear-gradient(135deg, ${accent}22, rgba(255,255,255,0.6))`, border: dark ? '0.5px solid rgba(255,255,255,0.08)' : '0.5px solid rgba(0,0,0,0.05)', display: 'flex', alignItems: 'center', gap: 12, animation: 'celebrateIn .6s cubic-bezier(.22,.9,.32,1) both' }}>
            <div style={{ width: 36, height: 36, borderRadius: 18, background: `linear-gradient(135deg, ${accent}, #FF6A00)`, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 4px 14px ${accent}66`, animation: 'celebrateIcon 1.2s .4s ease-in-out infinite' }}>
              <span style={{ fontSize: 20 }}>🎉</span>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: FONTS.body, fontSize: 14, fontWeight: 600, color: fg, letterSpacing: -0.2, marginBottom: 2 }}>這是你的第一筆記錄!</div>
              <div style={{ fontFamily: FONTS.body, fontSize: 12, color: muted, letterSpacing: -0.1, lineHeight: 1.4 }}>記下越多,我學得越快。下次只要打一句話。</div>
            </div>
          </div>
        )}
      </div>
      <BottomBarSimple dark={dark}/>
    </div>
  );
}

function BottomBarSimple({ dark }) {
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;
  const round = (children) => (
    <div style={{ width: 56, height: 56, borderRadius: 28, background: dark ? 'rgba(255,255,255,0.10)' : 'rgba(255,255,255,0.85)', backdropFilter: 'blur(16px)', WebkitBackdropFilter: 'blur(16px)', border: dark ? '0.5px solid rgba(255,255,255,0.12)' : '0.5px solid rgba(0,0,0,0.05)', boxShadow: dark ? '0 4px 16px rgba(0,0,0,0.3)' : '0 4px 14px rgba(0,0,0,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{children}</div>
  );
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, bottom: 28, display: 'flex', justifyContent: 'space-around', alignItems: 'center', padding: '0 36px', zIndex: 5 }}>
      {round(<Glyph name="chart-pie" size={20} color={muted}/>)}
      <div style={{ width: 64, height: 64, borderRadius: 32, background: `linear-gradient(135deg, ${accent}, #FF6A00)`, boxShadow: `0 8px 24px ${accent}66, inset 1px 1px 1px rgba(255,255,255,0.4)`, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
        <div style={{ position: 'absolute', inset: -6, borderRadius: 38, border: `1px solid ${accent}44` }}/>
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none"><path d="M12 5v14M5 12h14" stroke="#fff" strokeWidth="2.4" strokeLinecap="round"/></svg>
      </div>
      {round(
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
          <circle cx="11" cy="11" r="6.5" stroke={muted} strokeWidth="1.8"/>
          <path d="M16 16l4 4" stroke={muted} strokeWidth="1.8" strokeLinecap="round"/>
        </svg>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Step 3: Add Transaction (scripted)
// ─────────────────────────────────────────────────────────────
function AddTransactionScripted({ dark, type, amount, cat, account, aiText, aiStatus, highlightSave, savePressed }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;
  const amountColor = type === 'expense' ? (dark ? COLORS.expenseDark : COLORS.expense) : (dark ? COLORS.incomeDark : COLORS.income);
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', top: -40, right: -60, width: 240, height: 240, borderRadius: '50%', background: amountColor, opacity: dark ? 0.20 : 0.22, filter: 'blur(80px)', transition: `background .35s ${EASE}`, pointerEvents: 'none' }}/>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '6px 18px 8px', position: 'relative', zIndex: 1 }}>
        <div style={{ fontFamily: FONTS.body, fontSize: 15, color: muted, fontWeight: 500, letterSpacing: -0.15 }}>取消</div>
        <div style={{ fontFamily: FONTS.display, fontSize: 17, fontWeight: 600, color: fg, letterSpacing: -0.3 }}>新增交易</div>
        <div data-target="add-save" style={{ position: 'relative' }}>
          {highlightSave && <div style={{ position: 'absolute', inset: -8, borderRadius: 12, background: accent, opacity: 0.4, animation: 'pulseRing 1.2s ease-out infinite' }}/>}
          <div style={{ position: 'relative', padding: '6px 4px', fontFamily: FONTS.body, fontSize: 15, fontWeight: 600, letterSpacing: -0.15, color: amount > 0 ? accent : muted, transform: savePressed ? 'scale(0.92)' : 'scale(1)', transition: 'transform .15s ease-out' }}>儲存</div>
        </div>
      </div>
      <div style={{ flex: 1, padding: '0 18px', position: 'relative', zIndex: 1, overflow: 'hidden' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)', borderRadius: 12, padding: 3, gap: 2, marginBottom: 14, position: 'relative' }}>
          {[
            { id: 'expense', label: '支出', color: dark ? COLORS.expenseDark : COLORS.expense },
            { id: 'income', label: '收入', color: dark ? COLORS.incomeDark : COLORS.income },
            { id: 'transfer', label: '轉帳', color: '#5E5CE6' },
          ].map(it => (
            <div key={it.id} data-target={`type-${it.id}`} style={{ padding: '8px 0', borderRadius: 10, textAlign: 'center', background: type === it.id ? (dark ? 'rgba(255,255,255,0.10)' : '#fff') : 'transparent', boxShadow: type === it.id ? '0 1px 3px rgba(0,0,0,0.08)' : 'none', fontFamily: FONTS.body, fontSize: 14, fontWeight: type === it.id ? 600 : 500, color: type === it.id ? it.color : muted, letterSpacing: -0.15, transition: `all .25s ${EASE}` }}>{it.label}</div>
          ))}
        </div>
        <Glass dark={dark} radius={22} style={{ padding: '18px 22px', marginBottom: 14 }}>
          <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1.2, marginBottom: 6 }}>金額</div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, fontFamily: FONTS.mono, fontWeight: 500, color: amount > 0 ? amountColor : muted, letterSpacing: -1.5, lineHeight: 1, transition: `color .3s ${EASE}` }}>
            <span style={{ fontSize: 18, fontWeight: 400 }}>NT$</span>
            <span style={{ fontSize: 44, transition: `transform .3s ${EASE}`, transform: amount > 0 ? 'scale(1)' : 'scale(0.95)' }}>
              {amount > 0 ? (type === 'income' ? '+' : type === 'expense' ? '−' : '') + amount.toLocaleString() : '0'}
            </span>
          </div>
        </Glass>
        <Glass dark={dark} radius={18} style={{ padding: '12px 14px', marginBottom: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
            <Glyph name="sparkles" size={13} color={accent}/>
            <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, textTransform: 'uppercase', letterSpacing: 1.2, fontWeight: 500 }}>AI Quick fill · on-device</div>
            {aiStatus === 'extracting' && (
              <div style={{ display: 'flex', gap: 3, marginLeft: 'auto' }}>
                {[0,1,2].map(i => (<div key={i} style={{ width: 5, height: 5, borderRadius: 3, background: accent, opacity: 0.4, animation: `bDot 1s ${i * 0.15}s infinite` }}/>))}
              </div>
            )}
            {aiStatus === 'filled' && (
              <div style={{ marginLeft: 'auto', padding: '2px 8px', borderRadius: 999, background: 'rgba(52,199,89,0.15)', color: dark ? COLORS.incomeDark : COLORS.income, fontFamily: FONTS.mono, fontSize: 9, fontWeight: 600, letterSpacing: 0.5 }}>FILLED</div>
            )}
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <div style={{ flex: 1, fontFamily: FONTS.body, fontSize: 14, color: fg, letterSpacing: -0.15, minHeight: 18 }}>
              {aiText || <span style={{ color: muted }}>例:咖啡 65 悠遊卡</span>}
              {aiStatus === 'typing' && (
                <span style={{ display: 'inline-block', width: 1.5, height: 16, background: accent, marginLeft: 1, verticalAlign: 'text-bottom', animation: 'bDot 1s infinite' }}/>
              )}
            </div>
            <div data-target="add-extract">
              <div style={{ padding: '6px 12px', borderRadius: 999, background: aiText ? accent : (dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.06)'), color: aiText ? '#fff' : muted, fontFamily: FONTS.body, fontSize: 12, fontWeight: 600, letterSpacing: -0.1 }}>抽取</div>
            </div>
          </div>
        </Glass>
        <Glass dark={dark} radius={18} style={{ padding: 0, overflow: 'hidden' }}>
          <ScriptedFieldRow label="分類" dark={dark} filled={!!cat}>
            {cat ? (
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{ width: 26, height: 26, borderRadius: 13, background: cat.color + '30', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14 }}>{cat.emoji}</div>
                <div style={{ fontFamily: FONTS.body, fontSize: 14, color: fg, fontWeight: 500, letterSpacing: -0.15 }}>{cat.label}</div>
              </div>
            ) : (<div style={{ fontFamily: FONTS.body, fontSize: 14, color: muted, letterSpacing: -0.15 }}>未選</div>)}
          </ScriptedFieldRow>
          <ScriptedFieldRow label="帳戶" dark={dark} filled={!!account}>
            {account ? (
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{ width: 8, height: 8, borderRadius: 4, background: account.color }}/>
                <div style={{ fontFamily: FONTS.body, fontSize: 14, color: fg, fontWeight: 500, letterSpacing: -0.15 }}>{account.label}</div>
              </div>
            ) : (<div style={{ fontFamily: FONTS.body, fontSize: 14, color: muted, letterSpacing: -0.15 }}>請選擇</div>)}
          </ScriptedFieldRow>
          <ScriptedFieldRow label="日期" dark={dark} filled>
            <div style={{ fontFamily: FONTS.body, fontSize: 14, color: fg, fontWeight: 500, letterSpacing: -0.15 }}>今天 · 4/25</div>
          </ScriptedFieldRow>
          <ScriptedFieldRow label="商家" dark={dark} isLast>
            <div style={{ fontFamily: FONTS.body, fontSize: 14, color: muted, letterSpacing: -0.15 }}>(optional)</div>
          </ScriptedFieldRow>
        </Glass>
      </div>
    </div>
  );
}

function ScriptedFieldRow({ label, children, isLast, dark, filled }) {
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '13px 14px', borderBottom: isLast ? 'none' : (dark ? '0.5px solid rgba(255,255,255,0.06)' : '0.5px solid rgba(0,0,0,0.05)'), background: filled ? (dark ? 'rgba(52,199,89,0.06)' : 'rgba(52,199,89,0.05)') : 'transparent', transition: 'background .5s ease' }}>
      <div style={{ fontFamily: FONTS.body, fontSize: 13, color: muted, letterSpacing: -0.1, width: 56, flexShrink: 0 }}>{label}</div>
      <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 8 }}>{children}</div>
      <svg width="8" height="14" viewBox="0 0 8 14" fill="none"><path d="M1 1l6 6-6 6" stroke={muted} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/></svg>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Step 4: Save success
// ─────────────────────────────────────────────────────────────
function SaveSuccessSimple({ dark, visible }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 200, background: dark ? 'rgba(0,0,0,0.6)' : 'rgba(255,255,255,0.85)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)', opacity: visible ? 1 : 0, pointerEvents: visible ? 'auto' : 'none', transition: `opacity .3s ${EASE}`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column' }}>
      <div style={{ transform: visible ? 'scale(1)' : 'scale(0.7)', opacity: visible ? 1 : 0, transition: `all .45s ${EASE}`, marginBottom: 18 }}>
        <div style={{ width: 80, height: 80, borderRadius: 40, background: `linear-gradient(135deg, ${accent}, #FF6A00)`, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 12px 40px ${accent}60` }}>
          <svg width="42" height="42" viewBox="0 0 24 24" fill="none">
            <path d="M5 12.5l5 5L19 8" stroke="#fff" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" style={{ strokeDasharray: 30, strokeDashoffset: visible ? 0 : 30, transition: 'stroke-dashoffset .55s .15s ease-out' }}/>
          </svg>
        </div>
      </div>
      <div style={{ fontFamily: FONTS.display, fontSize: 24, fontWeight: 700, color: fg, letterSpacing: -0.6, marginBottom: 6, opacity: visible ? 1 : 0, transition: `opacity .3s .2s ${EASE}` }}>已記下</div>
      <div style={{ fontFamily: FONTS.mono, fontSize: 14, color: muted, letterSpacing: -0.1, opacity: visible ? 1 : 0, transition: `opacity .3s .3s ${EASE}` }}>+NT$ 50,000 · 薪資</div>
    </div>
  );
}

Object.assign(window, { ReadyMini, DashboardScripted, AddTransactionScripted, SaveSuccessSimple, FauxPointer, Confetti, CountUpText, EASE });
