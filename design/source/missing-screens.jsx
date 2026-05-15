// NeuLedger — Missing Screens (Carrier · Recurring · Filter)
// Reuses AccPhone / AccGlass / AccGlyph / ACC_FONTS / ACC_COLORS / accBg from accounts.jsx

// ─── Extra glyphs needed ────────────────────────────────────
function MsGlyph({ name, size = 22, color = 'currentColor', stroke = 1.8 }) {
  const s = size, sw = stroke;
  switch (name) {
    case 'qr': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw}><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><path d="M14 14h3v3h-3zM18 18h3v3h-3zM14 18h2v2h-2z" fill={color} stroke="none"/></svg>);
    case 'copy': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><rect x="8" y="8" width="13" height="13" rx="2"/><path d="M16 8V5a2 2 0 00-2-2H5a2 2 0 00-2 2v9a2 2 0 002 2h3"/></svg>);
    case 'bell': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d="M6 8a6 6 0 0112 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10 21a2 2 0 004 0"/></svg>);
    case 'repeat': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d="M17 1l4 4-4 4"/><path d="M3 11V9a4 4 0 014-4h14"/><path d="M7 23l-4-4 4-4"/><path d="M21 13v2a4 4 0 01-4 4H3"/></svg>);
    case 'filter': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d="M3 5h18M6 12h12M10 19h4"/></svg>);
    case 'calendar': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>);
    case 'tag': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d="M20 12l-8 8L3 11V3h8l9 9z"/><circle cx="7.5" cy="7.5" r="1.5" fill={color}/></svg>);
    case 'warn': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d="M12 3l10 18H2L12 3z"/><path d="M12 10v5M12 18v.5"/></svg>);
    default: return AccGlyph({ name, size, color, stroke });
  }
}

// ─── Simple QR — patterned cells (decorative) ───────────────
function FakeQR({ size = 156 }) {
  const c = 25;
  const cells = [];
  // Deterministic pseudo-random
  const seed = 7;
  for (let y = 0; y < c; y++) for (let x = 0; x < c; x++) {
    const v = ((x * 31 + y * 17 + seed) * 2654435761) >>> 0;
    if (v % 100 < 48) cells.push([x, y]);
  }
  // Position markers
  const marker = (ox, oy) => (
    <g key={`m-${ox}-${oy}`}>
      <rect x={ox} y={oy} width="7" height="7" fill="#0A0A0A"/>
      <rect x={ox+1} y={oy+1} width="5" height="5" fill="#fff"/>
      <rect x={ox+2} y={oy+2} width="3" height="3" fill="#0A0A0A"/>
    </g>
  );
  // Mask out cells in marker zones
  const inMarker = (x, y) =>
    (x < 8 && y < 8) || (x > 16 && y < 8) || (x < 8 && y > 16);
  return (
    <svg viewBox="0 0 25 25" width={size} height={size} shapeRendering="crispEdges" style={{ display: 'block' }}>
      <rect width="25" height="25" fill="#fff"/>
      {cells.filter(([x,y]) => !inMarker(x,y)).map(([x,y], i) => (
        <rect key={i} x={x} y={y} width="1" height="1" fill="#0A0A0A"/>
      ))}
      {marker(0,0)}{marker(18,0)}{marker(0,18)}
    </svg>
  );
}

// ─── Section header ─────────────────────────────────────────
function MsSection({ label, dark, children, action }) {
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  return (
    <div style={{ marginBottom: 18 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 6px 8px' }}>
        <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase' }}>{label}</div>
        {action}
      </div>
      {children}
    </div>
  );
}

// ─── Form row (inside AccGlass) ─────────────────────────────
function MsRow({ label, value, valueColor, mono, chevron, isLast, dark, danger, children, onClick }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const sep = dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)';
  return (
    <div onClick={onClick} style={{
      display: 'flex', alignItems: 'center', gap: 12, minHeight: 48, padding: '10px 16px',
      borderBottom: isLast ? 'none' : `0.5px solid ${sep}`,
      cursor: onClick ? 'pointer' : 'default',
    }}>
      <div style={{ flex: '0 0 auto', fontSize: 14, color: danger ? ACC_COLORS.expense : fg, fontWeight: 500 }}>{label}</div>
      <div style={{ flex: 1, minWidth: 0, textAlign: 'right', display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: 6 }}>
        {children || (
          <span style={{ fontSize: 14, color: valueColor || muted, fontFamily: mono ? ACC_FONTS.mono : ACC_FONTS.body, fontVariantNumeric: mono ? 'tabular-nums' : 'normal' }}>{value}</span>
        )}
        {chevron && <AccGlyph name="chevron-right" size={14} color={muted} stroke={2}/>}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 1. Carrier List — expanded state showing QR
// ═══════════════════════════════════════════════════════════
function CarrierList({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? ACC_COLORS.warmDark : ACC_COLORS.warm;
  const ai = ACC_COLORS.ai;

  const carriers = [
    { id: 'phone1', name: '主要手機條碼', type: '手機條碼載具', barcode: '/AB3F+92', icon: 'phone', color: '#1B5E8E', expanded: false },
    { id: 'phone2', name: '家用發票', type: '手機條碼載具', barcode: '/X9K.7M2', icon: 'qr', color: accent, expanded: true },
    { id: 'cert', name: '自然人憑證', type: 'Citizen Digital Certificate', barcode: '/PHN7842BX31QPL9KZ', icon: 'card', color: '#5E5CE6', expanded: false },
  ];

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* Top bar */}
      <div style={{ padding: '8px 22px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>SETTINGS / E-INVOICE</div>
          <div style={{ fontFamily: ACC_FONTS.display, fontSize: 30, fontWeight: 600, color: fg, letterSpacing: -0.5, marginTop: 2 }}>發票載具</div>
        </div>
        <button style={{ width: 36, height: 36, borderRadius: 18, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.04)', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: fg }}>
          <AccGlyph name="plus" size={20} color={fg}/>
        </button>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '16px 16px 100px' }}>
        {/* Hint card */}
        <AccGlass dark={dark} radius={16} style={{ padding: '12px 14px', marginBottom: 16, display: 'flex', alignItems: 'flex-start', gap: 10 }}>
          <div style={{ width: 28, height: 28, borderRadius: 8, background: `${ai}22`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <MsGlyph name="sparkle" size={14} color={ai}/>
          </div>
          <div style={{ flex: 1, fontSize: 12, color: muted, lineHeight: 1.5 }}>
            掃描發票時自動載入第一個載具,中獎發票將自動兌獎到綁定的帳戶。
          </div>
        </AccGlass>

        {/* Carriers list */}
        <AccGlass dark={dark} radius={18} style={{ padding: 0, overflow: 'hidden' }}>
          {carriers.map((c, i) => (
            <React.Fragment key={c.id}>
              <div style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer' }}>
                <div style={{ width: 40, height: 40, borderRadius: 12, background: c.color, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <MsGlyph name={c.icon} size={20} color="#fff" stroke={2}/>
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 600, fontSize: 15, color: fg }}>{c.name}</div>
                  <div style={{ fontSize: 12, color: muted, marginTop: 2 }}>{c.type}</div>
                </div>
                <AccGlyph name={c.expanded ? 'chevron-down' : 'chevron-right'} size={16} color={muted} stroke={2}/>
              </div>

              {c.expanded && (
                <div style={{ padding: '0 16px 18px', borderTop: `0.5px solid ${dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)'}` }}>
                  {/* barcode row */}
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 0 14px' }}>
                    <div style={{ fontFamily: ACC_FONTS.mono, fontSize: 15, fontWeight: 500, color: fg, letterSpacing: 0.5 }}>{c.barcode}</div>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button style={{ width: 32, height: 32, borderRadius: 9, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(232,131,90,0.12)', border: 'none', color: accent, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
                        <AccGlyph name="edit" size={14} color={accent}/>
                      </button>
                      <button style={{ width: 32, height: 32, borderRadius: 9, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(232,131,90,0.12)', border: 'none', color: accent, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
                        <MsGlyph name="copy" size={14} color={accent}/>
                      </button>
                    </div>
                  </div>
                  {/* QR */}
                  <div style={{ background: '#fff', borderRadius: 14, padding: 12, display: 'inline-flex', boxShadow: '0 4px 16px rgba(0,0,0,0.08)' }}>
                    <FakeQR size={156}/>
                  </div>
                </div>
              )}

              {i < carriers.length - 1 && !c.expanded && <div style={{ height: 0.5, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)', marginLeft: 68 }}/>}
            </React.Fragment>
          ))}
        </AccGlass>

        <div style={{ marginTop: 10, padding: '0 6px', fontSize: 11, color: muted, lineHeight: 1.5 }}>
          向左滑動可刪除。預設使用排序第一個載具。
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 2. Add / Edit Carrier — sheet form
// ═══════════════════════════════════════════════════════════
function CarrierForm({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? ACC_COLORS.warmDark : ACC_COLORS.warm;

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* Drag handle */}
      <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0' }}>
        <div style={{ width: 36, height: 5, borderRadius: 100, background: dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.18)' }}/>
      </div>
      {/* Header */}
      <div style={{ padding: '4px 16px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: accent, fontSize: 16, fontFamily: ACC_FONTS.body, padding: 4 }}>取消</button>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 17, fontWeight: 600, color: fg }}>新增載具</div>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: accent, fontSize: 16, fontWeight: 700, fontFamily: ACC_FONTS.body, padding: 4 }}>儲存</button>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '0 16px 100px' }}>
        {/* Type selector — two big glass cards (matches design language better than segmented) */}
        <MsSection label="載具類型" dark={dark}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            <AccGlass dark={dark} radius={16} style={{ padding: 14, border: `1.5px solid ${accent}`, position: 'relative' }}>
              <div style={{ width: 32, height: 32, borderRadius: 10, background: accent, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 8 }}>
                <MsGlyph name="phone" size={16} color="#fff"/>
              </div>
              <div style={{ fontSize: 13, fontWeight: 600, color: fg }}>手機條碼</div>
              <div style={{ fontSize: 11, color: muted, marginTop: 2, fontFamily: ACC_FONTS.mono }}>/XXXXXXX</div>
              <div style={{ position: 'absolute', top: 8, right: 8, width: 18, height: 18, borderRadius: 9, background: accent, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <AccGlyph name="check" size={10} color="#fff" stroke={3}/>
              </div>
            </AccGlass>
            <AccGlass dark={dark} radius={16} style={{ padding: 14, border: `1.5px solid ${dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)'}` }}>
              <div style={{ width: 32, height: 32, borderRadius: 10, background: '#5E5CE6', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 8 }}>
                <MsGlyph name="card" size={16} color="#fff"/>
              </div>
              <div style={{ fontSize: 13, fontWeight: 600, color: fg }}>自然人憑證</div>
              <div style={{ fontSize: 11, color: muted, marginTop: 2, fontFamily: ACC_FONTS.mono }}>/PXXXXXXXXXXXXXXXX</div>
            </AccGlass>
          </div>
        </MsSection>

        {/* Form fields */}
        <MsSection label="基本資料" dark={dark}>
          <AccGlass dark={dark} radius={16} style={{ padding: 0 }}>
            <MsRow label="名稱" dark={dark}>
              <span style={{ fontSize: 14, color: fg }}>家用發票</span>
            </MsRow>
            <MsRow label="條碼" dark={dark} isLast>
              <span style={{ fontFamily: ACC_FONTS.mono, fontSize: 14, color: fg, letterSpacing: 0.5 }}>/X9K.7M2</span>
            </MsRow>
          </AccGlass>
          <div style={{ marginTop: 8, padding: '0 6px', fontSize: 11, color: muted, lineHeight: 1.5 }}>
            8 碼,以 <span style={{ fontFamily: ACC_FONTS.mono, color: fg }}>/</span> 開頭,可含大寫字母、數字與 <span style={{ fontFamily: ACC_FONTS.mono, color: fg }}>+ . -</span>
          </div>
        </MsSection>

        {/* Validation error state */}
        <MsSection label="格式錯誤示意" dark={dark}>
          <AccGlass dark={dark} radius={16} style={{ padding: 0, border: `1px solid ${ACC_COLORS.expense}33` }}>
            <MsRow label="條碼" dark={dark} isLast>
              <span style={{ fontFamily: ACC_FONTS.mono, fontSize: 14, color: ACC_COLORS.expense }}>abc123</span>
            </MsRow>
          </AccGlass>
          <div style={{ marginTop: 8, padding: '0 6px', display: 'flex', gap: 6, alignItems: 'flex-start', color: ACC_COLORS.expense, fontSize: 11, lineHeight: 1.5 }}>
            <MsGlyph name="warn" size={12} color={ACC_COLORS.expense}/>
            格式不正確,請輸入 / 開頭的 8 碼識別碼
          </div>
        </MsSection>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 3. Recurring Transaction Form
// ═══════════════════════════════════════════════════════════
function RecurringForm({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? ACC_COLORS.warmDark : ACC_COLORS.warm;
  const expense = ACC_COLORS.expense;
  const income = ACC_COLORS.income;

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0' }}>
        <div style={{ width: 36, height: 5, borderRadius: 100, background: dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.18)' }}/>
      </div>
      <div style={{ padding: '4px 16px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: accent, fontSize: 16, fontFamily: ACC_FONTS.body, padding: 4 }}>取消</button>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 17, fontWeight: 600, color: fg }}>編輯週期</div>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: accent, fontSize: 16, fontWeight: 700, fontFamily: ACC_FONTS.body, padding: 4 }}>儲存</button>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '0 16px 100px' }}>
        {/* Type pills — matches AccountList aesthetic */}
        <div style={{ display: 'flex', gap: 6, marginBottom: 18, padding: 4, borderRadius: 100, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)' }}>
          {[
            { k: 'expense', l: '支出', c: expense, active: true },
            { k: 'income', l: '收入', c: income, active: false },
            { k: 'transfer', l: '轉帳', c: '#5E5CE6', active: false },
          ].map(t => (
            <div key={t.k} style={{
              flex: 1, padding: '8px 0', textAlign: 'center', borderRadius: 100,
              fontSize: 13, fontWeight: 600,
              background: t.active ? (dark ? 'rgba(255,255,255,0.12)' : '#fff') : 'transparent',
              color: t.active ? t.c : muted,
              boxShadow: t.active ? '0 1px 3px rgba(0,0,0,0.08)' : 'none',
              cursor: 'pointer',
            }}>{t.l}</div>
          ))}
        </div>

        {/* Big amount */}
        <div style={{ textAlign: 'center', padding: '4px 0 22px' }}>
          <div style={{ fontFamily: ACC_FONTS.mono, fontSize: 11, color: muted, letterSpacing: 1.2, textTransform: 'uppercase' }}>每月扣款</div>
          <div style={{ fontFamily: ACC_FONTS.display, fontSize: 48, fontWeight: 600, letterSpacing: -1.5, color: fg, fontVariantNumeric: 'tabular-nums', marginTop: 4 }}>
            <span style={{ fontSize: 24, color: muted, marginRight: 4 }}>NT$</span>169
          </div>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, marginTop: 8, padding: '4px 10px', borderRadius: 8, background: `${accent}1F`, color: accent, fontSize: 12, fontWeight: 600 }}>
            <MsGlyph name="repeat" size={11} color={accent}/> Spotify 家庭方案
          </div>
        </div>

        {/* Details */}
        <MsSection label="明細" dark={dark}>
          <AccGlass dark={dark} radius={16} style={{ padding: 0 }}>
            <MsRow label="備註" dark={dark}>
              <span style={{ fontSize: 14, color: fg }}>Spotify 家庭方案</span>
            </MsRow>
            <MsRow label="類別" dark={dark} chevron>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <div style={{ width: 22, height: 22, borderRadius: 6, background: '#A66BF0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <AccGlyph name="star" size={11} color="#fff"/>
                </div>
                <span style={{ fontSize: 14, color: fg }}>訂閱</span>
              </div>
            </MsRow>
            <MsRow label="帳戶" dark={dark} chevron isLast>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <div style={{ width: 22, height: 22, borderRadius: 6, background: '#7B3F00', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <AccGlyph name="card" size={11} color="#fff"/>
                </div>
                <span style={{ fontSize: 14, color: fg }}>玉山 e.Fingo</span>
              </div>
            </MsRow>
          </AccGlass>
        </MsSection>

        {/* Frequency */}
        <MsSection label="週期" dark={dark}>
          <div style={{ display: 'flex', gap: 6, marginBottom: 8, padding: 4, borderRadius: 12, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)' }}>
            {['每週','每月','每年'].map((f, i) => (
              <div key={f} style={{
                flex: 1, padding: '8px 0', textAlign: 'center', borderRadius: 9,
                fontSize: 13, fontWeight: 600,
                background: i === 1 ? (dark ? 'rgba(255,255,255,0.12)' : '#fff') : 'transparent',
                color: i === 1 ? fg : muted,
                boxShadow: i === 1 ? '0 1px 3px rgba(0,0,0,0.08)' : 'none',
                cursor: 'pointer',
              }}>{f}</div>
            ))}
          </div>
          <AccGlass dark={dark} radius={16} style={{ padding: 0 }}>
            <MsRow label="通知時間" dark={dark} isLast>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <MsGlyph name="bell" size={13} color={accent}/>
                <span style={{ fontFamily: ACC_FONTS.mono, fontSize: 14, color: fg }}>25 日 09:00</span>
              </div>
            </MsRow>
          </AccGlass>
          <div style={{ marginTop: 8, padding: '0 6px', fontSize: 11, color: muted, lineHeight: 1.5 }}>
            下次扣款 · <span style={{ fontFamily: ACC_FONTS.mono, color: fg }}>2026/05/25 09:00</span> · 系統將排程通知
          </div>
        </MsSection>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 4. Filter Form (sheet)
// ═══════════════════════════════════════════════════════════
function FilterForm({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? ACC_COLORS.warmDark : ACC_COLORS.warm;

  const Chip = ({ label, active, color, icon }) => (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '7px 12px', borderRadius: 100,
      background: active ? (color ? `${color}22` : `${accent}22`) : (dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)'),
      border: active ? `1px solid ${color || accent}` : `1px solid transparent`,
      color: active ? (color || accent) : (dark ? 'rgba(255,255,255,0.8)' : '#0A0A0A'),
      fontSize: 13, fontWeight: 500, cursor: 'pointer',
    }}>
      {icon && <span style={{ width: 16, height: 16, borderRadius: 4, background: color, display: 'inline-flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>{icon}</span>}
      {label}
      {active && !icon && <AccGlyph name="check" size={12} color={color || accent} stroke={2.5}/>}
    </div>
  );

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0' }}>
        <div style={{ width: 36, height: 5, borderRadius: 100, background: dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.18)' }}/>
      </div>
      <div style={{ padding: '4px 16px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: ACC_COLORS.expense, fontSize: 15, fontFamily: ACC_FONTS.body, padding: 4 }}>清除全部</button>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ fontFamily: ACC_FONTS.display, fontSize: 17, fontWeight: 600, color: fg }}>篩選</div>
          <div style={{ minWidth: 22, height: 22, padding: '0 6px', borderRadius: 11, background: accent, color: '#fff', fontSize: 12, fontWeight: 700, fontFamily: ACC_FONTS.mono, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>3</div>
        </div>
        <button style={{ background: accent, border: 'none', cursor: 'pointer', color: '#fff', fontSize: 14, fontWeight: 700, fontFamily: ACC_FONTS.body, padding: '6px 14px', borderRadius: 100 }}>套用</button>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '0 16px 100px' }}>
        {/* Type */}
        <MsSection label="類型" dark={dark}>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            <Chip label="支出" active color={ACC_COLORS.expense}/>
            <Chip label="收入" color={ACC_COLORS.income}/>
            <Chip label="轉帳" color="#5E5CE6"/>
          </div>
        </MsSection>

        {/* Category */}
        <MsSection label="分類" dark={dark} action={<div style={{ fontSize: 11, color: accent, fontWeight: 600, cursor: 'pointer' }}>顯示全部 12 個</div>}>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            <Chip label="餐飲" active color="#E8835A"/>
            <Chip label="交通" color="#1B5E8E"/>
            <Chip label="娛樂" active color="#A66BF0"/>
            <Chip label="購物" color="#FF6B6B"/>
            <Chip label="居家" color="#8B6F47"/>
            <Chip label="醫療" color="#34C759"/>
          </div>
        </MsSection>

        {/* Account */}
        <MsSection label="帳戶" dark={dark}>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            <Chip label="玉山 e.Fingo" active color="#7B3F00"/>
            <Chip label="永豐銀行" color="#1B5E8E"/>
            <Chip label="現金" color="#9B7E5F"/>
            <Chip label="街口" color="#FF6B6B"/>
          </div>
        </MsSection>

        {/* Tags */}
        <MsSection label="標籤" dark={dark}>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            <Chip label="#咖啡" color={accent}/>
            <Chip label="#午餐" color={accent}/>
            <Chip label="#家庭" color={accent}/>
            <Chip label="#旅行" color={accent}/>
          </div>
        </MsSection>

        {/* Date range */}
        <MsSection label="日期區間" dark={dark} action={<div style={{ fontSize: 11, color: ACC_COLORS.expense, fontWeight: 600, cursor: 'pointer' }}>清除</div>}>
          <AccGlass dark={dark} radius={16} style={{ padding: 0 }}>
            <MsRow label="開始" dark={dark}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <MsGlyph name="calendar" size={13} color={muted}/>
                <span style={{ fontFamily: ACC_FONTS.mono, fontSize: 14, color: fg }}>2026/04/01</span>
              </div>
            </MsRow>
            <MsRow label="結束" dark={dark} isLast>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <MsGlyph name="calendar" size={13} color={muted}/>
                <span style={{ fontFamily: ACC_FONTS.mono, fontSize: 14, color: fg }}>2026/04/30</span>
              </div>
            </MsRow>
          </AccGlass>
          <div style={{ display: 'flex', gap: 6, marginTop: 10 }}>
            {['本月','上月','本季','全年'].map((q, i) => (
              <div key={q} style={{
                flex: 1, padding: '7px 0', textAlign: 'center',
                borderRadius: 100, fontSize: 12, fontWeight: 600,
                background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)',
                color: muted, cursor: 'pointer',
              }}>{q}</div>
            ))}
          </div>
        </MsSection>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// Canvas
// ═══════════════════════════════════════════════════════════
function MissingScreensCanvas() {
  const dark = false;
  const screens = [
    { id: 'carrier-list', label: '01 / Carrier List', desc: '電子發票載具 · 展開顯示 QR 與條碼', Comp: CarrierList },
    { id: 'carrier-form', label: '02 / Add / Edit Carrier', desc: '類型切換 + 即時 regex 驗證', Comp: CarrierForm },
    { id: 'recurring-form', label: '03 / Recurring Form', desc: '週期交易編輯,綁定通知排程', Comp: RecurringForm },
    { id: 'filter-form', label: '04 / Transactions Filter', desc: '對應 TransactionFilter struct,多選 chip', Comp: FilterForm },
  ];
  const muted = 'rgba(60,60,67,0.55)';

  return (
    <div style={{ minHeight: '100vh', background: '#ECE9E2', padding: '40px 24px 80px', fontFamily: ACC_FONTS.body }}>
      <div style={{ maxWidth: 1280, margin: '0 auto 32px' }}>
        <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.4, textTransform: 'uppercase' }}>NeuLedger · Missing Screens</div>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 40, fontWeight: 600, letterSpacing: -1, marginTop: 4 }}>四個補上的畫面</div>
        <div style={{ fontSize: 14, color: muted, marginTop: 6, maxWidth: 520, lineHeight: 1.5 }}>
          基於 GitHub repo 的 TCA Reducer 還原。沿用 Accounts / Budget 既有的 AccPhone + AccGlass + 暖色徑向背景。
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

ReactDOM.createRoot(document.getElementById('root')).render(<MissingScreensCanvas/>);
