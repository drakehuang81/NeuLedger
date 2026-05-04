// NeuLedger Onboarding — 3 visual directions × 3 steps
// All frames are 402×874 iPhone 17 Pro

const COLORS = {
  accent: '#FF9500',
  accentDark: '#FF9F0A',
  income: '#34C759',
  incomeDark: '#30D158',
  expense: '#FF3B30',
  expenseDark: '#FF453A',
};

const FONTS = {
  display: '"Bricolage Grotesque", -apple-system, system-ui, sans-serif',
  body: '"DM Sans", -apple-system, system-ui, sans-serif',
  mono: '"DM Mono", "SF Mono", ui-monospace, Menlo, monospace',
};

// SF Symbol-ish glyphs drawn as simple SVG (only basic shapes per guidelines)
function Glyph({ name, size = 22, color = '#000', stroke = 1.8 }) {
  const s = size;
  const sw = stroke;
  const props = { fill: 'none', stroke: color, strokeWidth: sw, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (name) {
    case 'sparkles':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24">
          <path {...props} d="M12 3l1.8 4.5L18 9l-4.2 1.5L12 15l-1.8-4.5L6 9l4.2-1.5L12 3z"/>
          <path {...props} d="M19 15l.9 2.1 2.1.9-2.1.9-.9 2.1-.9-2.1-2.1-.9 2.1-.9.9-2.1z"/>
        </svg>
      );
    case 'wallet':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24">
          <rect {...props} x="3" y="6" width="18" height="13" rx="2.5"/>
          <path {...props} d="M3 10h18M16 14h2"/>
        </svg>
      );
    case 'creditcard':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24">
          <rect {...props} x="3" y="6" width="18" height="13" rx="2.5"/>
          <path {...props} d="M3 10h18"/>
        </svg>
      );
    case 'banknote':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24">
          <rect {...props} x="3" y="7" width="18" height="11" rx="1.5"/>
          <circle {...props} cx="12" cy="12.5" r="2.5"/>
        </svg>
      );
    case 'phone':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24">
          <rect {...props} x="6" y="3" width="12" height="18" rx="2.5"/>
          <path {...props} d="M11 18h2"/>
        </svg>
      );
    case 'lock':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24">
          <rect {...props} x="5" y="11" width="14" height="9" rx="2"/>
          <path {...props} d="M8 11V8a4 4 0 018 0v3"/>
        </svg>
      );
    case 'chart':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24">
          <path {...props} d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>
        </svg>
      );
    case 'check':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24">
          <path {...props} d="M5 13l4 4L19 7"/>
        </svg>
      );
    case 'plus':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24">
          <path {...props} d="M12 5v14M5 12h14"/>
        </svg>
      );
    case 'arrow-right':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24">
          <path {...props} d="M5 12h14M13 6l6 6-6 6"/>
        </svg>
      );
    case 'mic':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24">
          <rect {...props} x="9" y="3" width="6" height="11" rx="3"/>
          <path {...props} d="M5 12a7 7 0 0014 0M12 19v3"/>
        </svg>
      );
    case 'edit':
      return (
        <svg width={s} height={s} viewBox="0 0 24 24">
          <path {...props} d="M4 20h4l10-10-4-4L4 16v4z"/>
        </svg>
      );
    default:
      return null;
  }
}

// Liquid glass primitives
function Glass({ children, dark, style, radius = 20, intensity = 1 }) {
  return (
    <div style={{
      position: 'relative',
      borderRadius: radius,
      overflow: 'hidden',
      ...style,
    }}>
      <div style={{
        position: 'absolute', inset: 0,
        backdropFilter: `blur(${20*intensity}px) saturate(180%)`,
        WebkitBackdropFilter: `blur(${20*intensity}px) saturate(180%)`,
        background: dark ? 'rgba(40,40,45,0.55)' : 'rgba(255,255,255,0.55)',
      }}/>
      <div style={{
        position: 'absolute', inset: 0,
        boxShadow: dark
          ? 'inset 0.5px 0.5px 0 rgba(255,255,255,0.12), inset -0.5px -0.5px 0 rgba(255,255,255,0.04)'
          : 'inset 0.5px 0.5px 0 rgba(255,255,255,0.85), inset -0.5px -0.5px 0 rgba(255,255,255,0.4)',
        border: dark ? '0.5px solid rgba(255,255,255,0.12)' : '0.5px solid rgba(0,0,0,0.05)',
        borderRadius: radius,
        pointerEvents: 'none',
      }}/>
      <div style={{ position: 'relative' }}>{children}</div>
    </div>
  );
}

// Page indicator dots
function Dots({ count = 3, active = 0, dark }) {
  return (
    <div style={{ display: 'flex', gap: 6, justifyContent: 'center' }}>
      {Array.from({length: count}).map((_, i) => (
        <div key={i} style={{
          width: i === active ? 22 : 6, height: 6, borderRadius: 3,
          background: i === active
            ? (dark ? '#fff' : '#000')
            : (dark ? 'rgba(255,255,255,0.25)' : 'rgba(0,0,0,0.15)'),
          transition: 'all .25s',
        }}/>
      ))}
    </div>
  );
}

// Primary CTA button
function Button({ children, dark, primary = true, fullWidth = true, accent = COLORS.accent }) {
  const bg = primary ? accent : (dark ? 'rgba(120,120,128,0.32)' : 'rgba(120,120,128,0.16)');
  const fg = primary ? '#fff' : (dark ? '#fff' : '#000');
  return (
    <div style={{
      height: 52, borderRadius: 26, background: bg,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      width: fullWidth ? '100%' : 'auto', padding: fullWidth ? 0 : '0 24px',
      fontFamily: FONTS.body, fontSize: 17, fontWeight: 600, color: fg,
      letterSpacing: -0.2,
      boxShadow: primary ? `0 8px 24px ${accent}40` : 'none',
    }}>{children}</div>
  );
}

// Phone shell with status bar + home indicator (no nav bar)
function Phone({ children, dark, bg }) {
  return (
    <IOSDevice dark={dark} width={402} height={874}>
      <div style={{
        position: 'absolute', inset: 0,
        background: bg || (dark ? '#000' : '#F2F2F7'),
        zIndex: 0,
      }}/>
      <div style={{ position: 'relative', zIndex: 1, height: '100%', display: 'flex', flexDirection: 'column', paddingTop: 62 }}>
        {children}
      </div>
    </IOSDevice>
  );
}

// ════════════════════════════════════════════════════════════════════
// VARIATION A — MINIMAL / TYPOGRAPHIC
// Numerical, sparse, high-contrast. AI is invisible.
// ════════════════════════════════════════════════════════════════════

function A_Welcome({ dark, dense }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const bg = dark ? '#0A0A0A' : '#FAFAF7';
  return (
    <Phone dark={dark} bg={bg}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: dense ? '20px 28px' : '32px 28px' }}>
        {/* word-mark */}
        <div style={{
          fontFamily: FONTS.display, fontWeight: 700, fontSize: 18,
          color: fg, letterSpacing: -0.4,
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <div style={{
            width: 22, height: 22, borderRadius: 6, background: COLORS.accent,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', fontSize: 13, fontWeight: 700,
          }}>N</div>
          NeuLedger
        </div>

        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', marginTop: dense ? 32 : 64 }}>
          <div style={{
            fontFamily: FONTS.mono, fontSize: 12, color: muted,
            letterSpacing: 1.2, textTransform: 'uppercase', marginBottom: 16,
          }}>01 / 03 · WELCOME</div>

          <div style={{
            fontFamily: FONTS.display, fontSize: 56, lineHeight: 0.95,
            fontWeight: 700, color: fg, letterSpacing: -2.4,
            textWrap: 'pretty',
          }}>
            Money,<br/>
            <span style={{ color: COLORS.accent }}>quantified.</span>
          </div>

          <div style={{
            fontFamily: FONTS.body, fontSize: 17, lineHeight: 1.45,
            color: muted, marginTop: dense ? 20 : 32, letterSpacing: -0.2,
            maxWidth: 320,
          }}>
            A 記帳 app for people who think in numbers.
            On-device, fast, and quiet.
          </div>

          {/* number specimens */}
          <div style={{
            marginTop: dense ? 32 : 56,
            display: 'grid', gridTemplateColumns: '1fr 1fr',
            gap: 1, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)',
            border: dark ? '0.5px solid rgba(255,255,255,0.08)' : '0.5px solid rgba(0,0,0,0.08)',
          }}>
            {[
              {k: 'Income', v: '+128,400', c: COLORS.income},
              {k: 'Expense', v: '−87,250', c: COLORS.expense},
              {k: 'Net', v: '41,150', c: fg},
              {k: 'Saved', v: '32%', c: fg},
            ].map((cell, i) => (
              <div key={i} style={{
                background: bg, padding: '14px 14px',
              }}>
                <div style={{
                  fontFamily: FONTS.mono, fontSize: 10, color: muted,
                  textTransform: 'uppercase', letterSpacing: 1, marginBottom: 6,
                }}>{cell.k}</div>
                <div style={{
                  fontFamily: FONTS.mono, fontSize: 20, fontWeight: 500,
                  color: cell.c, letterSpacing: -0.4,
                }}>{cell.v}</div>
              </div>
            ))}
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 14, paddingBottom: 28 }}>
          <Button dark={dark}>Begin</Button>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <Dots count={3} active={0} dark={dark}/>
            <div style={{ fontFamily: FONTS.body, fontSize: 15, color: muted }}>Skip</div>
          </div>
        </div>
      </div>
    </Phone>
  );
}

function A_Account({ dark, dense }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const sep = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.08)';
  const bg = dark ? '#0A0A0A' : '#FAFAF7';
  return (
    <Phone dark={dark} bg={bg}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: dense ? '20px 28px' : '32px 28px' }}>
        <div style={{
          fontFamily: FONTS.mono, fontSize: 12, color: muted,
          letterSpacing: 1.2, textTransform: 'uppercase', marginBottom: 16,
        }}>02 / 03 · ACCOUNTS</div>

        <div style={{
          fontFamily: FONTS.display, fontSize: 36, lineHeight: 1,
          fontWeight: 700, color: fg, letterSpacing: -1.4, marginBottom: 14,
        }}>Where does your money live?</div>
        <div style={{
          fontFamily: FONTS.body, fontSize: 15, color: muted,
          marginBottom: dense ? 24 : 36, letterSpacing: -0.1,
        }}>Add at least one. You can edit later.</div>

        {/* account inputs as form rows */}
        <div style={{ borderTop: `0.5px solid ${sep}` }}>
          {[
            { name: 'Cash', amount: '3,200', type: 'cash 現金', icon: 'banknote' },
            { name: '玉山銀行', amount: '48,930', type: 'bank 銀行', icon: 'wallet', filled: true },
            { name: '悠遊卡', amount: '420', type: 'e-wallet 電子', icon: 'phone' },
          ].map((row, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', padding: dense ? '14px 0' : '18px 0',
              borderBottom: `0.5px solid ${sep}`, gap: 14,
            }}>
              <div style={{
                width: 36, height: 36, borderRadius: 10,
                background: row.filled ? COLORS.accent : (dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)'),
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <Glyph name={row.icon} size={20} color={row.filled ? '#fff' : (dark ? '#fff' : '#0A0A0A')}/>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  fontFamily: FONTS.body, fontSize: 16, fontWeight: 500,
                  color: fg, letterSpacing: -0.2,
                  textOverflow: 'ellipsis', whiteSpace: 'nowrap', overflow: 'hidden',
                }}>{row.name}</div>
                <div style={{
                  fontFamily: FONTS.mono, fontSize: 11, color: muted,
                  textTransform: 'uppercase', letterSpacing: 0.8, marginTop: 2,
                }}>{row.type}</div>
              </div>
              <div style={{
                fontFamily: FONTS.mono, fontSize: 17, color: fg,
                letterSpacing: -0.3, fontWeight: 500,
              }}>
                <span style={{ color: muted, fontSize: 12, marginRight: 4 }}>NT$</span>{row.amount}
              </div>
            </div>
          ))}

          {/* add row */}
          <div style={{
            display: 'flex', alignItems: 'center', padding: dense ? '14px 0' : '18px 0',
            borderBottom: `0.5px solid ${sep}`, gap: 14, color: muted,
          }}>
            <div style={{
              width: 36, height: 36, borderRadius: 10,
              border: `1px dashed ${muted}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <Glyph name="plus" size={18} color={muted}/>
            </div>
            <div style={{ fontFamily: FONTS.body, fontSize: 16, color: muted }}>Add another</div>
          </div>
        </div>

        <div style={{ flex: 1 }}/>

        {/* total summary */}
        <div style={{
          display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
          padding: dense ? '14px 0' : '18px 0', borderTop: `0.5px solid ${sep}`,
          marginBottom: dense ? 16 : 20,
        }}>
          <div style={{
            fontFamily: FONTS.mono, fontSize: 11, color: muted,
            textTransform: 'uppercase', letterSpacing: 1,
          }}>Total balance</div>
          <div style={{
            fontFamily: FONTS.mono, fontSize: 26, fontWeight: 500,
            color: fg, letterSpacing: -0.6,
          }}>
            <span style={{ fontSize: 13, color: muted, marginRight: 4 }}>NT$</span>52,550
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 14, paddingBottom: 28 }}>
          <Button dark={dark}>Continue</Button>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <Dots count={3} active={1} dark={dark}/>
            <div style={{ fontFamily: FONTS.body, fontSize: 15, color: muted }}>Skip</div>
          </div>
        </div>
      </div>
    </Phone>
  );
}

function A_Ready({ dark, dense }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const bg = dark ? '#0A0A0A' : '#FAFAF7';
  return (
    <Phone dark={dark} bg={bg}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: dense ? '20px 28px' : '32px 28px' }}>
        <div style={{
          fontFamily: FONTS.mono, fontSize: 12, color: muted,
          letterSpacing: 1.2, textTransform: 'uppercase', marginBottom: 16,
        }}>03 / 03 · READY</div>

        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
          <div style={{
            fontFamily: FONTS.display, fontSize: 64, lineHeight: 0.95,
            fontWeight: 700, color: fg, letterSpacing: -2.6,
          }}>You're set.</div>

          <div style={{
            fontFamily: FONTS.body, fontSize: 17, lineHeight: 1.45,
            color: muted, marginTop: 20, letterSpacing: -0.2, maxWidth: 320,
          }}>
            Three ways to log your first transaction.
          </div>

          {/* numbered list of next actions */}
          <div style={{ marginTop: dense ? 32 : 48, display: 'flex', flexDirection: 'column', gap: dense ? 14 : 20 }}>
            {[
              { n: '01', label: 'Type it.', detail: 'Tap +, fill three fields.' },
              { n: '02', label: 'Speak it.', detail: '咖啡 65 元 — extracted on-device.' },
              { n: '03', label: 'Forget it.', detail: 'Insights surface when you need them.' },
            ].map((item, i) => (
              <div key={i} style={{ display: 'flex', gap: 16, alignItems: 'baseline' }}>
                <div style={{
                  fontFamily: FONTS.mono, fontSize: 12, color: COLORS.accent,
                  letterSpacing: 0.8, fontWeight: 500, width: 22, flexShrink: 0,
                }}>{item.n}</div>
                <div style={{ flex: 1 }}>
                  <div style={{
                    fontFamily: FONTS.display, fontSize: 22, fontWeight: 600,
                    color: fg, letterSpacing: -0.6, marginBottom: 2,
                  }}>{item.label}</div>
                  <div style={{
                    fontFamily: FONTS.body, fontSize: 14, color: muted,
                    letterSpacing: -0.1,
                  }}>{item.detail}</div>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 14, paddingBottom: 28 }}>
          <Button dark={dark}>Open NeuLedger</Button>
          <div style={{ display: 'flex', justifyContent: 'center' }}>
            <Dots count={3} active={2} dark={dark}/>
          </div>
        </div>
      </div>
    </Phone>
  );
}

Object.assign(window, { A_Welcome, A_Account, A_Ready, Glyph, Glass, Button, Dots, Phone, COLORS, FONTS });
