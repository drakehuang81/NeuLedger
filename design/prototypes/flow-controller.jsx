// NeuLedger First-Run Flow controller
// Single linear timeline that drives ReadyMini → Empty Dashboard → Add Transaction
// → Save Success → Grown Dashboard. Auto-plays with faux pointer; Play/Pause/Restart.

const { useState: useC, useEffect: useCE, useRef: useCR, useMemo: useCM } = React;

// Timeline (ms-based, absolute t from 0):
// Each cue mutates the controller state.
const CUES = [
  // ── Step 1: Ready
  { t: 0,    s: { phase: 'ready', cursor: { x: 200, y: 600, visible: false, tap: false } } },
  { t: 600,  s: { cursor: { x: 200, y: 600, visible: true, tap: false } } },
  { t: 800,  msg: 'Final tap to enter app', cursor_to: 'ready-done' },
  { t: 1700, s: { cursor: { tap: true } } },
  { t: 2150, s: { phase: 'empty-dash', cursor: { tap: false }, balance: 0 } },

  // ── Step 2: Empty dashboard, highlight + 記一筆
  { t: 2400, msg: 'Welcome to your dashboard', s: { highlightAdd: true } },
  { t: 3300, cursor_to: 'empty-add' },
  { t: 4500, s: { cursor: { tap: true } } },
  { t: 4800, s: { phase: 'add', cursor: { tap: false, visible: false }, type: 'expense', amount: 0, aiText: '', aiStatus: 'idle' } },

  // ── Step 3: Add Transaction
  { t: 5300, msg: 'Add Transaction sheet opens' },
  { t: 5700, s: { cursor: { visible: true } }, cursor_to: 'type-income' },
  { t: 6700, s: { cursor: { tap: true } } },
  { t: 6900, s: { type: 'income', cursor: { tap: false } } },
  { t: 7400, msg: 'Try natural language: 薪資 50000 玉山' },
  { t: 7600, s: { aiStatus: 'typing' }, type: '薪資 50000 玉山' },
  { t: 9200, s: { aiStatus: 'idle' } },
  { t: 9400, cursor_to: 'add-extract' },
  { t: 10200, s: { cursor: { tap: true } } },
  { t: 10400, s: { cursor: { tap: false }, aiStatus: 'extracting' } },
  { t: 10800, msg: 'On-device extraction…' },
  { t: 11500, s: { aiStatus: 'filled', amount: 50000, cat: { emoji: '💼', label: '薪資', color: '#34C759' }, account: { label: '玉山銀行', color: '#1E5BA8' } } },
  { t: 12300, msg: 'AI filled all fields' },
  { t: 13000, cursor_to: 'add-save' },
  { t: 13800, s: { highlightSave: true } },
  { t: 14400, s: { cursor: { tap: true }, savePressed: true } },
  { t: 14600, s: { cursor: { tap: false, visible: false }, savePressed: false, phase: 'save-success' } },

  // ── Step 4: Success
  { t: 14800, msg: 'Transaction saved' },
  { t: 16200, s: { phase: 'grown-dash', balance: 50000, animateBalance: true, showFirstRow: true } },

  // ── Step 5: Grown dashboard
  { t: 16400, msg: 'Balance updates · first transaction lands' },
  { t: 17800, s: { showCelebration: true, confetti: true } },
  { t: 18400, msg: '🎉 First transaction logged' },
  { t: 21000, s: { confetti: false } },
  { t: 22000, msg: 'Demo complete — tap restart to replay', s: { done: true } },
];

const TOTAL = 22500;

const CHAPTERS = [
  { id: 'ready', label: '1 · Ready', t: 0 },
  { id: 'empty', label: '2 · Empty', t: 2400 },
  { id: 'add',   label: '3 · Add',   t: 4800 },
  { id: 'save',  label: '4 · Save',  t: 14600 },
  { id: 'grown', label: '5 · Grown', t: 16200 },
];

function FlowController({ dark = false }) {
  const [t, setT] = useC(0);
  const [playing, setPlaying] = useC(true);
  const [state, setState] = useC({
    phase: 'ready',
    cursor: { x: 200, y: 600, visible: false, tap: false },
    type: 'expense', amount: 0, aiText: '', aiStatus: 'idle',
    cat: null, account: null, highlightSave: false, savePressed: false,
    highlightAdd: false, balance: 0, animateBalance: false,
    showFirstRow: false, showCelebration: false, confetti: false,
    msg: '',
  });
  const stageRef = useCR(null);
  const lastCueIdx = useCR(-1);
  const rafRef = useCR(null);
  const startRef = useCR(null);

  // Apply cues up to time tNow
  useCE(() => {
    let cur = { ...state };
    let lastIdx = -1;
    let msg = state.msg;
    for (let i = 0; i < CUES.length; i++) {
      if (CUES[i].t <= t) {
        const c = CUES[i];
        if (c.s) {
          cur = { ...cur, ...c.s, cursor: c.s.cursor ? { ...cur.cursor, ...c.s.cursor } : cur.cursor };
        }
        if (c.msg) msg = c.msg;
        if (c.cursor_to && stageRef.current) {
          const tgt = stageRef.current.querySelector(`[data-target="${c.cursor_to}"]`);
          if (tgt) {
            const sb = stageRef.current.getBoundingClientRect();
            const tb = tgt.getBoundingClientRect();
            cur.cursor = { ...cur.cursor, visible: true, x: (tb.left - sb.left) + tb.width / 2, y: (tb.top - sb.top) + tb.height / 2 };
          }
        }
        if (c.type !== undefined) {
          // typing animation handled in useEffect below
          cur._typeTarget = c.type;
          cur._typeStartT = c.t;
        }
        lastIdx = i;
      }
    }
    cur.msg = msg;
    setState(cur);
    lastCueIdx.current = lastIdx;
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [t]);

  // Typing simulation for aiText
  useCE(() => {
    if (!state._typeTarget || !state._typeStartT) return;
    const target = state._typeTarget;
    const elapsed = t - state._typeStartT;
    const charDur = 90;
    const n = Math.min(target.length, Math.max(0, Math.floor(elapsed / charDur)));
    const newText = target.slice(0, n);
    if (newText !== state.aiText) {
      setState(s => ({ ...s, aiText: newText }));
    }
  }, [t, state._typeTarget, state._typeStartT]);

  // RAF loop
  useCE(() => {
    if (!playing) return;
    let last = performance.now();
    const tick = (now) => {
      const dt = now - last; last = now;
      setT(prev => {
        const next = prev + dt;
        if (next >= TOTAL) { setPlaying(false); return TOTAL; }
        return next;
      });
      rafRef.current = requestAnimationFrame(tick);
    };
    rafRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafRef.current);
  }, [playing]);

  const restart = () => { setT(0); setState({ phase: 'ready', cursor: { x: 200, y: 600, visible: false, tap: false }, type: 'expense', amount: 0, aiText: '', aiStatus: 'idle', cat: null, account: null, highlightSave: false, savePressed: false, highlightAdd: false, balance: 0, animateBalance: false, showFirstRow: false, showCelebration: false, confetti: false, msg: '' }); setPlaying(true); };
  const seek = (newT) => { setT(newT); };

  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;
  const bg = dark ? 'linear-gradient(180deg,#1A1410 0%,#0E0A08 100%)' : 'linear-gradient(180deg,#FAF7F2 0%,#F1ECE3 100%)';

  // Determine which screen to render
  const showAdd = state.phase === 'add' || state.phase === 'save-success';
  const showDash = state.phase === 'empty-dash' || state.phase === 'grown-dash';
  const showReady = state.phase === 'ready';

  return (
    <div ref={stageRef} style={{ width: 393, height: 852, position: 'relative', overflow: 'hidden', borderRadius: 50, background: bg, boxShadow: dark ? '0 30px 80px rgba(0,0,0,0.5)' : '0 30px 80px rgba(180,140,100,0.25)' }}>
      {/* All screens stacked, fade between */}
      <div style={{ position: 'absolute', inset: 0, opacity: showReady ? 1 : 0, transition: 'opacity .35s ease', display: 'flex', flexDirection: 'column', paddingTop: 50 }}>
        <ReadyMini dark={dark}/>
      </div>
      <div style={{ position: 'absolute', inset: 0, opacity: showDash ? 1 : 0, transition: 'opacity .4s ease', display: 'flex', flexDirection: 'column', paddingTop: 50 }}>
        <DashboardScripted dark={dark} balanceTo={state.balance} animateBalance={state.animateBalance} highlightAdd={state.highlightAdd} showFirstRow={state.showFirstRow} showCelebration={state.showCelebration}/>
      </div>
      <div style={{ position: 'absolute', inset: 0, opacity: showAdd ? 1 : 0, transition: 'opacity .35s ease', display: 'flex', flexDirection: 'column', paddingTop: 50 }}>
        <AddTransactionScripted dark={dark} type={state.type} amount={state.amount} cat={state.cat} account={state.account} aiText={state.aiText} aiStatus={state.aiStatus} highlightSave={state.highlightSave} savePressed={state.savePressed}/>
      </div>
      <SaveSuccessSimple dark={dark} visible={state.phase === 'save-success'}/>
      <Confetti visible={state.confetti}/>
      <FauxPointer x={state.cursor.x} y={state.cursor.y} tapping={state.cursor.tap} visible={state.cursor.visible}/>

      {/* Status bar */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 50, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 28px', fontFamily: FONTS.body, fontSize: 15, fontWeight: 600, color: fg, letterSpacing: -0.2, zIndex: 50 }}>
        <span>9:41</span>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
          <span style={{ fontSize: 13 }}>•••</span>
          <span style={{ fontSize: 13 }}>📶</span>
          <div style={{ width: 22, height: 11, borderRadius: 3, border: `1px solid ${fg}`, padding: 1 }}>
            <div style={{ width: '70%', height: '100%', background: fg, borderRadius: 1 }}/>
          </div>
        </div>
      </div>

      {/* Caption */}
      <div style={{ position: 'absolute', left: 16, right: 16, bottom: 8, padding: '8px 14px', borderRadius: 12, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.5)', backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)', fontFamily: FONTS.body, fontSize: 12, color: '#fff', textAlign: 'center', letterSpacing: -0.1, opacity: state.msg ? 1 : 0, transition: 'opacity .3s ease', zIndex: 60, pointerEvents: 'none' }}>
        {state.msg}
      </div>
    </div>
  );
}

function ControlRail({ t, total, playing, onTogglePlay, onRestart, onSeek, chapters, dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;
  const pct = (t / total) * 100;
  return (
    <div style={{ width: 393, marginTop: 16, padding: '14px 16px', borderRadius: 18, background: dark ? 'rgba(255,255,255,0.05)' : 'rgba(255,255,255,0.7)', backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)', border: dark ? '0.5px solid rgba(255,255,255,0.08)' : '0.5px solid rgba(0,0,0,0.05)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
        <button onClick={onTogglePlay} style={{ width: 36, height: 36, borderRadius: 18, border: 'none', background: `linear-gradient(135deg, ${accent}, #FF6A00)`, color: '#fff', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 4px 12px ${accent}66` }}>
          {playing ? (<svg width="12" height="14" viewBox="0 0 12 14" fill="none"><rect x="1" y="1" width="3" height="12" rx="1" fill="#fff"/><rect x="8" y="1" width="3" height="12" rx="1" fill="#fff"/></svg>) : (<svg width="12" height="14" viewBox="0 0 12 14" fill="none"><path d="M2 1l9 6-9 6V1z" fill="#fff"/></svg>)}
        </button>
        <button onClick={onRestart} style={{ width: 36, height: 36, borderRadius: 18, border: dark ? '0.5px solid rgba(255,255,255,0.1)' : '0.5px solid rgba(0,0,0,0.08)', background: 'transparent', color: fg, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <svg width="14" height="14" viewBox="0 0 16 16" fill="none"><path d="M2 8a6 6 0 1011.5-2.5M2 8V3M2 8h5" stroke={fg} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </button>
        <div style={{ flex: 1, height: 6, borderRadius: 3, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)', position: 'relative', cursor: 'pointer' }} onClick={(e) => { const r = e.currentTarget.getBoundingClientRect(); onSeek(((e.clientX - r.left) / r.width) * total); }}>
          <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${pct}%`, borderRadius: 3, background: `linear-gradient(90deg, ${accent}, #FF6A00)` }}/>
          {chapters.map(c => (
            <div key={c.id} style={{ position: 'absolute', left: `${(c.t / total) * 100}%`, top: -3, width: 2, height: 12, background: muted, opacity: 0.6 }}/>
          ))}
        </div>
        <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: muted, letterSpacing: 0.2, minWidth: 64, textAlign: 'right' }}>
          {(t / 1000).toFixed(1)}s / {(total / 1000).toFixed(1)}s
        </div>
      </div>
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
        {chapters.map(c => {
          const active = t >= c.t && (chapters[chapters.indexOf(c) + 1] ? t < chapters[chapters.indexOf(c) + 1].t : true);
          return (
            <button key={c.id} onClick={() => onSeek(c.t)} style={{ padding: '5px 10px', borderRadius: 999, border: 'none', cursor: 'pointer', fontFamily: FONTS.body, fontSize: 11, fontWeight: 500, letterSpacing: -0.1, background: active ? accent : (dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)'), color: active ? '#fff' : fg }}>{c.label}</button>
          );
        })}
      </div>
    </div>
  );
}

function FlowDemo({ dark = false }) {
  const [t, setT] = useC(0);
  const [playing, setPlaying] = useC(true);
  const [tick, setTick] = useC(0); // force re-render of controller via key
  const [version, setVersion] = useC(0);
  const ctrlRef = useCR(null);

  // Use a single shared timeline by lifting the RAF here.
  const rafRef = useCR(null);
  useCE(() => {
    if (!playing) return;
    let last = performance.now();
    const loop = (now) => {
      const dt = now - last; last = now;
      setT(prev => {
        const next = prev + dt;
        if (next >= TOTAL) { setPlaying(false); return TOTAL; }
        return next;
      });
      rafRef.current = requestAnimationFrame(loop);
    };
    rafRef.current = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(rafRef.current);
  }, [playing, version]);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <FlowStage key={version} t={t} dark={dark}/>
      <ControlRail t={t} total={TOTAL} playing={playing} chapters={CHAPTERS} dark={dark}
        onTogglePlay={() => setPlaying(p => !p)}
        onRestart={() => { setT(0); setPlaying(true); setVersion(v => v + 1); }}
        onSeek={(nt) => { setT(Math.max(0, Math.min(TOTAL, nt))); }}
      />
    </div>
  );
}

// Pure renderer: takes t, derives state every frame from CUES
function FlowStage({ t, dark }) {
  const stageRef = useCR(null);
  const [cursorPos, setCursorPos] = useC({ x: 200, y: 600 });

  const state = useCM(() => {
    let cur = {
      phase: 'ready',
      cursor: { visible: false, tap: false },
      type: 'expense', amount: 0, aiText: '', aiStatus: 'idle',
      cat: null, account: null, highlightSave: false, savePressed: false,
      highlightAdd: false, balance: 0, animateBalance: false,
      showFirstRow: false, showCelebration: false, confetti: false,
      msg: '', cursor_to: null, _typeTarget: null, _typeStartT: 0,
    };
    for (const c of CUES) {
      if (c.t > t) break;
      if (c.s) cur = { ...cur, ...c.s, cursor: c.s.cursor ? { ...cur.cursor, ...c.s.cursor } : cur.cursor };
      if (c.msg !== undefined) cur.msg = c.msg;
      if (c.cursor_to) cur.cursor_to = c.cursor_to;
      if (c.type !== undefined) { cur._typeTarget = c.type; cur._typeStartT = c.t; }
    }
    // typing
    if (cur._typeTarget) {
      const elapsed = t - cur._typeStartT;
      const n = Math.min(cur._typeTarget.length, Math.max(0, Math.floor(elapsed / 90)));
      cur.aiText = cur._typeTarget.slice(0, n);
    }
    return cur;
  }, [t]);

  // Resolve cursor target every frame
  useCE(() => {
    if (!state.cursor_to || !stageRef.current) return;
    const tgt = stageRef.current.querySelector(`[data-target="${state.cursor_to}"]`);
    if (tgt) {
      const sb = stageRef.current.getBoundingClientRect();
      const tb = tgt.getBoundingClientRect();
      setCursorPos({ x: (tb.left - sb.left) + tb.width / 2, y: (tb.top - sb.top) + tb.height / 2 });
    }
  }, [state.cursor_to]);

  const fg = dark ? '#fff' : '#0A0A0A';
  const bg = dark ? 'linear-gradient(180deg,#1A1410 0%,#0E0A08 100%)' : 'linear-gradient(180deg,#FAF7F2 0%,#F1ECE3 100%)';

  const showAdd = state.phase === 'add' || state.phase === 'save-success';
  const showDash = state.phase === 'empty-dash' || state.phase === 'grown-dash';
  const showReady = state.phase === 'ready';

  return (
    <div ref={stageRef} style={{ width: 393, height: 852, position: 'relative', overflow: 'hidden', borderRadius: 50, background: bg, boxShadow: dark ? '0 30px 80px rgba(0,0,0,0.5)' : '0 30px 80px rgba(180,140,100,0.25)' }}>
      <div style={{ position: 'absolute', inset: 0, opacity: showReady ? 1 : 0, transition: 'opacity .35s ease', display: 'flex', flexDirection: 'column', paddingTop: 50 }}>
        <ReadyMini dark={dark}/>
      </div>
      <div style={{ position: 'absolute', inset: 0, opacity: showDash ? 1 : 0, transition: 'opacity .4s ease', display: 'flex', flexDirection: 'column', paddingTop: 50 }}>
        <DashboardScripted dark={dark} balanceTo={state.balance} animateBalance={state.animateBalance} highlightAdd={state.highlightAdd} showFirstRow={state.showFirstRow} showCelebration={state.showCelebration}/>
      </div>
      <div style={{ position: 'absolute', inset: 0, opacity: showAdd ? 1 : 0, transition: 'opacity .35s ease', display: 'flex', flexDirection: 'column', paddingTop: 50 }}>
        <AddTransactionScripted dark={dark} type={state.type} amount={state.amount} cat={state.cat} account={state.account} aiText={state.aiText} aiStatus={state.aiStatus} highlightSave={state.highlightSave} savePressed={state.savePressed}/>
      </div>
      <SaveSuccessSimple dark={dark} visible={state.phase === 'save-success'}/>
      <Confetti visible={state.confetti}/>
      <FauxPointer x={cursorPos.x} y={cursorPos.y} tapping={state.cursor.tap} visible={state.cursor.visible}/>

      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 50, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 28px', fontFamily: FONTS.body, fontSize: 15, fontWeight: 600, color: fg, letterSpacing: -0.2, zIndex: 50 }}>
        <span>9:41</span>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
          <span style={{ fontSize: 13 }}>•••</span>
          <span style={{ fontSize: 13 }}>📶</span>
          <div style={{ width: 22, height: 11, borderRadius: 3, border: `1px solid ${fg}`, padding: 1 }}>
            <div style={{ width: '70%', height: '100%', background: fg, borderRadius: 1 }}/>
          </div>
        </div>
      </div>

      <div style={{ position: 'absolute', left: 16, right: 16, bottom: 8, padding: '8px 14px', borderRadius: 12, background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)', fontFamily: FONTS.body, fontSize: 12, color: '#fff', textAlign: 'center', letterSpacing: -0.1, opacity: state.msg ? 1 : 0, transition: 'opacity .3s ease', zIndex: 60, pointerEvents: 'none' }}>
        {state.msg}
      </div>
    </div>
  );
}

Object.assign(window, { FlowDemo, FlowStage, ControlRail, CUES, TOTAL, CHAPTERS });
