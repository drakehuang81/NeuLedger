// NeuLedger — Settings
// 3 artboards: Main · AI 智慧 sub-page · 外觀 sub-page
// Self-contained; reuses AccPhone/AccGlass/AccGlyph/ACC_FONTS/ACC_COLORS from accounts.jsx

// ─────────────────────────────────────────────────────────────
// Setting row primitives
// ─────────────────────────────────────────────────────────────
function SetGroup({ label, dark, children, footer }) {
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  return (
    <div style={{ marginBottom: 22 }}>
      {label && <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase', padding: '0 6px 8px' }}>{label}</div>}
      <AccGlass dark={dark} radius={14} style={{ padding: 4 }}>{children}</AccGlass>
      {footer && <div style={{ fontSize: 11, color: muted, padding: '8px 6px 0', lineHeight: 1.5 }}>{footer}</div>}
    </div>
  );
}

function SetRow({ icon, iconBg, label, value, dark, onTap, last, danger, accessory = 'chevron', valueColor }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const labelColor = danger ? '#FF453A' : fg;
  return (
    <React.Fragment>
      <button onClick={onTap} style={{
        display: 'flex', alignItems: 'center', gap: 12, width: '100%',
        padding: '11px 14px', background: 'transparent', border: 'none',
        cursor: onTap ? 'pointer' : 'default', textAlign: 'left', borderRadius: 10,
        transition: 'background 0.15s',
      }}
      onMouseEnter={e => onTap && (e.currentTarget.style.background = dark ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)')}
      onMouseLeave={e => onTap && (e.currentTarget.style.background = 'transparent')}
      >
        {icon && (
          <div style={{
            width: 28, height: 28, borderRadius: 8,
            background: iconBg || (dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)'),
            display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
          }}>
            <SetIcon name={icon} size={15} color="#fff" stroke={2}/>
          </div>
        )}
        <div style={{ flex: 1, minWidth: 0, fontSize: 15, color: labelColor, fontWeight: 400 }}>{label}</div>
        {value && <div style={{ fontSize: 14, color: valueColor || muted, fontFamily: typeof value === 'number' ? ACC_FONTS.mono : ACC_FONTS.body }}>{value}</div>}
        {accessory === 'chevron' && onTap && <SetIcon name="chevron-right" size={16} color={muted}/>}
        {accessory === 'check' && <SetIcon name="check" size={18} color={ACC_COLORS.warm} stroke={2.5}/>}
      </button>
      {!last && <div style={{ height: 0.5, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)', marginLeft: icon ? 54 : 14 }}/>}
    </React.Fragment>
  );
}

function SetToggle({ icon, iconBg, label, sublabel, value, onChange, dark, last }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  return (
    <React.Fragment>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 12, width: '100%',
        padding: '11px 14px',
      }}>
        {icon && (
          <div style={{
            width: 28, height: 28, borderRadius: 8,
            background: iconBg || (dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)'),
            display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
          }}>
            <SetIcon name={icon} size={15} color="#fff" stroke={2}/>
          </div>
        )}
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 15, color: fg }}>{label}</div>
          {sublabel && <div style={{ fontSize: 12, color: muted, marginTop: 2 }}>{sublabel}</div>}
        </div>
        <button onClick={() => onChange?.(!value)} style={{
          width: 51, height: 31, borderRadius: 16, border: 'none', cursor: 'pointer', padding: 0,
          background: value ? ACC_COLORS.income : (dark ? 'rgba(120,120,128,0.32)' : 'rgba(120,120,128,0.16)'),
          position: 'relative', transition: 'background 0.2s',
        }}>
          <div style={{
            position: 'absolute', top: 2,
            left: value ? 22 : 2, width: 27, height: 27, borderRadius: 14, background: '#fff',
            boxShadow: '0 2px 4px rgba(0,0,0,0.2)',
            transition: 'left 0.2s',
          }}/>
        </button>
      </div>
      {!last && <div style={{ height: 0.5, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)', marginLeft: icon ? 54 : 14 }}/>}
    </React.Fragment>
  );
}

// ─────────────────────────────────────────────────────────────
// Settings — Main
// ─────────────────────────────────────────────────────────────
function SettingsMain({ dark, onSection }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? ACC_COLORS.warmDark : ACC_COLORS.warm;
  const [notif, setNotif] = React.useState(true);

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* Title */}
      <div style={{ padding: '8px 22px 0' }}>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 32, fontWeight: 600, color: fg, letterSpacing: -0.5 }}>設定</div>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '14px 16px 60px' }}>
        {/* Profile */}
        <button onClick={() => onSection('profile')} style={{
          width: '100%', display: 'flex', alignItems: 'center', gap: 14,
          padding: '14px 16px', borderRadius: 16, marginBottom: 22,
          background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(255,255,255,0.7)',
          backdropFilter: 'blur(20px) saturate(180%)',
          border: 'none', cursor: 'pointer', textAlign: 'left',
          boxShadow: dark
            ? '0 1px 0 rgba(255,255,255,0.06) inset, 0 12px 28px rgba(0,0,0,0.35)'
            : '0 1px 0 rgba(255,255,255,0.85) inset, 0 4px 12px rgba(120,80,40,0.06), 0 0 0 0.5px rgba(0,0,0,0.04)',
        }}>
          <div style={{
            width: 56, height: 56, borderRadius: 28,
            background: `linear-gradient(135deg, ${ACC_COLORS.warm}, #FFB37D)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', fontFamily: ACC_FONTS.display, fontSize: 22, fontWeight: 600,
          }}>D</div>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: ACC_FONTS.display, fontSize: 18, fontWeight: 600, color: fg }}>Drake Huang</div>
            <div style={{ fontSize: 13, color: muted, marginTop: 2 }}>drake@neuledger.app</div>
            <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4, marginTop: 6, padding: '2px 8px', borderRadius: 6, background: dark ? 'rgba(232,131,90,0.2)' : 'rgba(232,131,90,0.12)', color: accent, fontSize: 11, fontWeight: 600, fontFamily: ACC_FONTS.mono, letterSpacing: 0.5 }}>
              <SetIcon name="sparkle" size={9} color={accent}/> NeuLedger Plus
            </div>
          </div>
          <SetIcon name="chevron-right" size={18} color={muted}/>
        </button>

        {/* AI 智慧 — top-level featured row */}
        <div onClick={() => onSection('ai')} style={{
          padding: '16px 18px', borderRadius: 16, marginBottom: 22, cursor: 'pointer',
          background: dark
            ? 'linear-gradient(135deg, rgba(166,107,240,0.18), rgba(232,131,90,0.10))'
            : 'linear-gradient(135deg, rgba(166,107,240,0.10), rgba(232,131,90,0.08))',
          border: `0.5px solid ${dark ? 'rgba(166,107,240,0.3)' : 'rgba(166,107,240,0.2)'}`,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 8 }}>
            <div style={{
              width: 36, height: 36, borderRadius: 11,
              background: `linear-gradient(135deg, ${ACC_COLORS.ai}, #D78AFF)`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <SetIcon name="sparkle" size={20} color="#fff"/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontWeight: 600, fontSize: 16, color: fg }}>AI 智慧</div>
              <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase', marginTop: 2 }}>Powered by Claude</div>
            </div>
            <SetIcon name="chevron-right" size={18} color={muted}/>
          </div>
          <div style={{ fontSize: 13, color: fg, opacity: 0.85, lineHeight: 1.5 }}>
            自然語言記帳、月度洞察、自動分類。所有資料端對端加密,僅在你授權時送出處理。
          </div>
        </div>

        {/* General */}
        <SetGroup label="偏好" dark={dark}>
          <SetRow icon="paint" iconBg="#FF9500" label="外觀" value="跟隨系統" dark={dark} onTap={() => onSection('appearance')}/>
          <SetRow icon="bell" iconBg="#FF3B30" label="通知" value="開啟" dark={dark} onTap={() => onSection('notifications')}/>
          <SetRow icon="lock" iconBg="#34C759" label="安全" value="Face ID" dark={dark} onTap={() => onSection('security')}/>
          <SetRow icon="globe" iconBg="#0A84FF" label="幣別 / 語言" value="NT$ · 中文" dark={dark} onTap={() => onSection('locale')} last/>
        </SetGroup>

        {/* Data */}
        <SetGroup label="資料" dark={dark}>
          <SetRow icon="cloud" iconBg="#5AC8FA" label="iCloud 同步" value="已開啟" valueColor={ACC_COLORS.income} dark={dark} onTap={() => onSection('icloud')}/>
          <SetRow icon="export" iconBg="#5E5CE6" label="匯出" value="CSV / JSON" dark={dark} onTap={() => onSection('export')}/>
          <SetRow icon="import" iconBg="#AF52DE" label="從其他 app 匯入" dark={dark} onTap={() => onSection('import')} last/>
        </SetGroup>

        {/* About */}
        <SetGroup label="關於" dark={dark}>
          <SetRow icon="help" iconBg="#8E8E93" label="說明 + 支援" dark={dark} onTap={() => onSection('help')}/>
          <SetRow icon="doc" iconBg="#8E8E93" label="條款 + 隱私" dark={dark} onTap={() => onSection('legal')}/>
          <SetRow label="版本" value="1.4.2 (build 318)" dark={dark} accessory="none" last/>
        </SetGroup>

        {/* Sign out */}
        <button style={{
          width: '100%', padding: '13px', borderRadius: 14,
          background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(255,255,255,0.7)',
          border: 'none', cursor: 'pointer',
          color: '#FF453A', fontWeight: 500, fontSize: 15, fontFamily: ACC_FONTS.body,
          marginBottom: 12,
        }}>登出</button>

        <div style={{ textAlign: 'center', fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1 }}>
          Made with care · Taipei
        </div>
      </div>
    </div>
  );
}

// Set-page icons. Falls back to original AccGlyph for shared names.
const _origAccGlyph_set = AccGlyph;
function SetIcon({ name, size = 16, color = '#fff', stroke = 1.8 }) {
  const s = size, sw = stroke;
  switch (name) {
    case 'paint': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d="M12 2C7 2 3 5 3 9c0 3 2 5 4 5h2v3a3 3 0 003 3 5 5 0 005-5c0-3 2-3 2-6 0-4-4-7-7-7z"/><circle cx="9" cy="9" r="1" fill={color}/><circle cx="13" cy="6" r="1" fill={color}/><circle cx="16" cy="10" r="1" fill={color}/></svg>);
    case 'bell': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d="M18 8a6 6 0 00-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a1.999 1.999 0 01-3.4 0"/></svg>);
    case 'lock': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round"><rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 018 0v4"/></svg>);
    case 'globe': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw}><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 010 18M12 3a14 14 0 000 18"/></svg>);
    case 'cloud': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d="M18 10A6 6 0 006.5 9 4 4 0 005 17h13a4 4 0 000-7z"/></svg>);
    case 'export': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d="M12 4v12M7 9l5-5 5 5"/><path d="M5 17v3h14v-3"/></svg>);
    case 'import': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d="M12 16V4M7 11l5 5 5-5"/><path d="M5 17v3h14v-3"/></svg>);
    case 'help': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round"><circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 015 0c0 1.5-2.5 2-2.5 4"/><circle cx="12" cy="17" r="0.6" fill={color}/></svg>);
    case 'doc': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><path d="M14 2v6h6M9 13h6M9 17h6"/></svg>);
    case 'tag': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d="M20 12l-8 8L4 12V4h8z"/><circle cx="8" cy="8" r="1.2" fill={color}/></svg>);
    case 'chart': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round"><rect x="4" y="13" width="3.5" height="7" rx="0.6"/><rect x="10.25" y="9" width="3.5" height="11" rx="0.6"/><rect x="16.5" y="5" width="3.5" height="15" rx="0.6"/></svg>);
    case 'repeat': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d="M17 1l4 4-4 4"/><path d="M3 11V9a4 4 0 014-4h14"/><path d="M7 23l-4-4 4-4"/><path d="M21 13v2a4 4 0 01-4 4H3"/></svg>);
    case 'brain': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><path d="M12 2a3 3 0 00-3 3 2 2 0 00-2 2 3 3 0 00-2 5 3 3 0 002 5 3 3 0 005 1 3 3 0 005-1 3 3 0 002-5 3 3 0 00-2-5 2 2 0 00-2-2 3 3 0 00-3-3z"/></svg>);
    case 'text': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round"><path d="M5 5h14M5 5v2M19 5v2M12 5v15M9 20h6"/></svg>);
    case 'motion': return (<svg width={s} height={s} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M22 12h-3M5 12H2M19 5l-2 2M7 17l-2 2M19 19l-2-2M7 7L5 5"/></svg>);
    default: return _origAccGlyph_set({ name, size, color, stroke });
  }
}

// ─────────────────────────────────────────────────────────────
// AI 智慧 sub-page
// ─────────────────────────────────────────────────────────────
function SettingsAI({ dark, onBack }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? ACC_COLORS.warmDark : ACC_COLORS.warm;
  const [aiOn, setAiOn] = React.useState(true);
  const [autoCat, setAutoCat] = React.useState(true);
  const [insights, setInsights] = React.useState(true);
  const [recurring, setRecurring] = React.useState(true);
  const [shareData, setShareData] = React.useState(false);

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* Top bar */}
      <div style={{ padding: '8px 16px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', position: 'relative' }}>
        <button onClick={onBack} style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: accent, display: 'flex', alignItems: 'center', gap: 2, fontSize: 16, fontWeight: 500, fontFamily: ACC_FONTS.body }}>
          <SetIcon name="chevron-left" size={20} color={accent}/> 設定
        </button>
        <div style={{ position: 'absolute', left: '50%', transform: 'translateX(-50%)', fontWeight: 600, fontSize: 16, color: fg }}>AI 智慧</div>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '8px 16px 60px' }}>
        {/* Hero */}
        <div style={{ textAlign: 'center', padding: '20px 16px 24px' }}>
          <div style={{
            width: 72, height: 72, borderRadius: 22,
            background: `linear-gradient(135deg, ${ACC_COLORS.ai}, #D78AFF)`,
            display: 'inline-flex', alignItems: 'center', justifyContent: 'center', marginBottom: 12,
            boxShadow: `0 12px 28px ${ACC_COLORS.ai}40`,
          }}>
            <SetIcon name="sparkle" size={36} color="#fff"/>
          </div>
          <div style={{ fontFamily: ACC_FONTS.display, fontSize: 22, fontWeight: 600, color: fg, marginBottom: 4 }}>AI 智慧</div>
          <div style={{ fontSize: 13, color: muted, lineHeight: 1.5, maxWidth: 280, margin: '0 auto' }}>
            讓 NeuLedger 自動分類、發現規律、提供個人化洞察。所有資料端對端加密,僅在你授權時送出處理。
          </div>
        </div>

        {/* Master toggle */}
        <SetGroup dark={dark} footer="關閉後,所有 AI 功能(自動分類、洞察、自然語言輸入)會停用。已產生的資料保留。">
          <SetToggle icon="sparkle" iconBg={ACC_COLORS.ai} label="啟用 AI 智慧" sublabel="主要開關" value={aiOn} onChange={setAiOn} dark={dark} last/>
        </SetGroup>

        {/* Features */}
        <SetGroup label="功能" dark={dark}>
          <SetToggle icon="tag" iconBg="#FF9500" label="自動分類" sublabel="新交易自動歸類" value={autoCat} onChange={setAutoCat} dark={dark}/>
          <SetToggle icon="chart" iconBg="#5AC8FA" label="月度洞察" sublabel="月底自動產生 recap" value={insights} onChange={setInsights} dark={dark}/>
          <SetToggle icon="repeat" iconBg="#34C759" label="定期付款偵測" sublabel="找出 Netflix、會員費等" value={recurring} onChange={setRecurring} dark={dark} last/>
        </SetGroup>

        {/* Model */}
        <SetGroup label="模型" dark={dark} footer="進階模型在複雜分類與摘要上更準確,但耗用較多 token。">
          <SetRow icon="brain" iconBg={ACC_COLORS.ai} label="Claude Haiku" value="目前" valueColor={ACC_COLORS.income} dark={dark} accessory="check" onTap={() => {}}/>
          <SetRow icon="brain" iconBg={ACC_COLORS.ai} label="Claude Sonnet" value="進階" dark={dark} onTap={() => {}} last/>
        </SetGroup>

        {/* Privacy */}
        <SetGroup label="隱私" dark={dark} footer="預設不分享。我們從不販售你的資料。">
          <SetRow icon="lock" iconBg="#34C759" label="資料處理位置" value="本地 + Anthropic" dark={dark} onTap={() => {}}/>
          <SetToggle icon="cloud" iconBg="#5AC8FA" label="協助改善 AI" sublabel="匿名分享部分查詢" value={shareData} onChange={setShareData} dark={dark}/>
          <SetRow icon="trash" iconBg="#FF453A" label="清除 AI 學習資料" dark={dark} onTap={() => {}} last/>
        </SetGroup>

        {/* Usage */}
        <SetGroup label="本月使用" dark={dark}>
          <div style={{ padding: '14px 16px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
              <div style={{ fontSize: 13, color: muted }}>已用</div>
              <div style={{ fontFamily: ACC_FONTS.mono, fontSize: 14, color: fg, fontVariantNumeric: 'tabular-nums' }}>847 / 5,000 次</div>
            </div>
            <div style={{ height: 6, borderRadius: 3, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)', overflow: 'hidden' }}>
              <div style={{ height: '100%', width: '17%', background: `linear-gradient(90deg, ${ACC_COLORS.ai}, ${ACC_COLORS.warm})`, borderRadius: 3 }}/>
            </div>
            <div style={{ fontSize: 11, color: muted, marginTop: 8, fontFamily: ACC_FONTS.mono, letterSpacing: 0.5 }}>5/01 重置 · NeuLedger Plus 包含</div>
          </div>
        </SetGroup>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// 外觀 sub-page
// ─────────────────────────────────────────────────────────────
function SettingsAppearance({ dark, onBack }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? ACC_COLORS.warmDark : ACC_COLORS.warm;
  const [theme, setTheme] = React.useState('auto');
  const [accentColor, setAccentColor] = React.useState('warm');
  const [textSize, setTextSize] = React.useState(2);
  const [reduceMotion, setReduceMotion] = React.useState(false);

  const themes = [
    { id: 'light', label: '淺色', preview: 'light' },
    { id: 'dark', label: '深色', preview: 'dark' },
    { id: 'auto', label: '系統', preview: 'auto' },
  ];

  const accents = [
    { id: 'warm', color: '#E8835A', label: 'Warm' },
    { id: 'sky', color: '#0A84FF', label: 'Sky' },
    { id: 'lime', color: '#34C759', label: 'Lime' },
    { id: 'plum', color: '#A66BF0', label: 'Plum' },
    { id: 'graphite', color: '#3C3C43', label: 'Graphite' },
  ];

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div style={{ padding: '8px 16px 12px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', position: 'relative' }}>
        <button onClick={onBack} style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: accent, display: 'flex', alignItems: 'center', gap: 2, fontSize: 16, fontWeight: 500, fontFamily: ACC_FONTS.body }}>
          <SetIcon name="chevron-left" size={20} color={accent}/> 設定
        </button>
        <div style={{ position: 'absolute', left: '50%', transform: 'translateX(-50%)', fontWeight: 600, fontSize: 16, color: fg }}>外觀</div>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '8px 16px 60px' }}>
        {/* Theme picker */}
        <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase', padding: '0 6px 10px' }}>主題</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, marginBottom: 22 }}>
          {themes.map(t => {
            const active = theme === t.id;
            return (
              <button key={t.id} onClick={() => setTheme(t.id)} style={{
                padding: '10px', borderRadius: 14,
                background: dark ? 'rgba(255,255,255,0.04)' : 'rgba(255,255,255,0.5)',
                border: active ? `2px solid ${accent}` : `0.5px solid ${dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)'}`,
                cursor: 'pointer', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8,
                fontFamily: ACC_FONTS.body,
              }}>
                <div style={{
                  width: '100%', height: 80, borderRadius: 10, overflow: 'hidden',
                  background: t.preview === 'light' ? '#FBF1E5' : t.preview === 'dark' ? '#1a0f08' : 'linear-gradient(90deg, #FBF1E5 50%, #1a0f08 50%)',
                  position: 'relative', boxShadow: '0 1px 0 rgba(0,0,0,0.05) inset',
                }}>
                  <div style={{ position: 'absolute', top: 8, left: 8, right: 8, height: 8, borderRadius: 4, background: t.preview === 'light' ? 'rgba(0,0,0,0.08)' : 'rgba(255,255,255,0.1)' }}/>
                  <div style={{ position: 'absolute', top: 22, left: 8, width: '60%', height: 4, borderRadius: 2, background: t.preview === 'light' ? 'rgba(0,0,0,0.15)' : 'rgba(255,255,255,0.2)' }}/>
                  <div style={{ position: 'absolute', bottom: 12, left: 8, width: 16, height: 16, borderRadius: 4, background: '#E8835A' }}/>
                </div>
                <div style={{ fontSize: 13, fontWeight: 500, color: fg }}>{t.label}</div>
              </button>
            );
          })}
        </div>

        {/* Accent */}
        <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase', padding: '0 6px 10px' }}>強調色</div>
        <AccGlass dark={dark} radius={14} style={{ padding: 18, marginBottom: 22 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
            {accents.map(a => {
              const active = accentColor === a.id;
              return (
                <button key={a.id} onClick={() => setAccentColor(a.id)} style={{
                  display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
                  border: 'none', background: 'transparent', cursor: 'pointer', padding: 0, fontFamily: ACC_FONTS.body,
                }}>
                  <div style={{
                    width: 38, height: 38, borderRadius: 19, background: a.color,
                    border: active ? `2.5px solid ${dark ? '#fff' : '#0A0A0A'}` : '2.5px solid transparent',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    boxShadow: active ? `0 4px 12px ${a.color}55` : 'none',
                    transition: 'all 0.15s',
                  }}>
                    {active && <SetIcon name="check" size={16} color="#fff" stroke={2.5}/>}
                  </div>
                  <div style={{ fontSize: 11, color: active ? fg : muted, fontWeight: active ? 600 : 400, fontFamily: ACC_FONTS.mono }}>{a.label}</div>
                </button>
              );
            })}
          </div>
        </AccGlass>

        {/* Font */}
        <SetGroup label="字體" dark={dark} footer="顯示字體用於餘額、標題;內文字體用於說明文字。">
          <SetRow icon="text" iconBg="#FF9500" label="顯示字體" value="Bricolage Grotesque" dark={dark} onTap={() => {}}/>
          <SetRow icon="text" iconBg="#FF9500" label="內文字體" value="DM Sans" dark={dark} onTap={() => {}}/>
          <SetRow icon="text" iconBg="#FF9500" label="金額字體" value="DM Mono" dark={dark} onTap={() => {}} last/>
        </SetGroup>

        {/* Text size */}
        <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase', padding: '0 6px 10px' }}>文字大小</div>
        <AccGlass dark={dark} radius={14} style={{ padding: '18px 16px', marginBottom: 22 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 14, padding: '0 4px' }}>
            <div style={{ fontSize: 12, color: muted }}>A</div>
            <div style={{ fontSize: 18, color: muted }}>A</div>
          </div>
          <div style={{ position: 'relative', height: 24, display: 'flex', alignItems: 'center' }}>
            <div style={{ position: 'absolute', left: 0, right: 0, height: 4, borderRadius: 2, background: dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.08)' }}/>
            <div style={{ position: 'absolute', left: 0, right: 0, display: 'flex', justifyContent: 'space-between' }}>
              {[0,1,2,3,4].map(i => (
                <div key={i} onClick={() => setTextSize(i)} style={{
                  width: 12, height: 12, borderRadius: 6,
                  background: i === textSize ? accent : (dark ? 'rgba(255,255,255,0.4)' : 'rgba(0,0,0,0.3)'),
                  border: i === textSize ? `4px solid ${dark ? '#1a0f08' : '#FBF1E5'}` : 'none',
                  boxShadow: i === textSize ? `0 0 0 1.5px ${accent}` : 'none',
                  cursor: 'pointer', transition: 'all 0.15s',
                }}/>
              ))}
            </div>
          </div>
        </AccGlass>

        {/* Motion */}
        <SetGroup label="動態" dark={dark}>
          <SetToggle icon="motion" iconBg="#5AC8FA" label="減少動態效果" sublabel="關閉非必要動畫" value={reduceMotion} onChange={setReduceMotion} dark={dark} last/>
        </SetGroup>
      </div>
    </div>
  );
}

