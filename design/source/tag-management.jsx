// NeuLedger — Tag Management
// 2 artboards: List + Add/Edit form
// Reuses accounts.jsx primitives

const TAGS = [
  { id: 't1', name: '咖啡', color: '#7B3F00', usageCount: 28 },
  { id: 't2', name: '午餐', color: '#E8835A', usageCount: 42 },
  { id: 't3', name: '家庭', color: '#A66BF0', usageCount: 18 },
  { id: 't4', name: '旅行', color: '#0A84FF', usageCount: 12 },
  { id: 't5', name: '訂閱', color: '#5E5CE6', usageCount: 24 },
  { id: 't6', name: '公帳', color: '#34C759', usageCount: 9 },
  { id: 't7', name: '緊急', color: '#FF453A', usageCount: 3 },
  { id: 't8', name: '禮物', color: '#FF6B6B', usageCount: 7 },
];

const TAG_COLORS = ['#3478F6','#E8835A','#7B3F00','#A66BF0','#0A84FF','#5E5CE6','#34C759','#FF453A','#FF6B6B','#F4B400','#8B6F47','#9B7E5F'];

// ═══════════════════════════════════════════════════════════
// Tag List
// ═══════════════════════════════════════════════════════════
function TagList({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? ACC_COLORS.warmDark : ACC_COLORS.warm;

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div style={{ padding: '8px 12px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ width: 60 }}/>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 17, fontWeight: 600, color: fg }}>標籤管理</div>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: accent }}>
          <AccGlyph name="plus" size={22} color={accent} stroke={2}/>
        </button>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '20px 16px 100px' }}>
        {/* Quick chip overview */}
        <div style={{ marginBottom: 18 }}>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase', padding: '0 6px 10px' }}>所有標籤 · {TAGS.length}</div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            {TAGS.map(t => (
              <div key={t.id} style={{
                display: 'inline-flex', alignItems: 'center', gap: 6,
                padding: '7px 12px', borderRadius: 100,
                background: `${t.color}22`,
                border: `1px solid ${t.color}55`,
                color: t.color,
                fontSize: 13, fontWeight: 600,
              }}>
                <span style={{ width: 8, height: 8, borderRadius: 4, background: t.color }}/>
                #{t.name}
              </div>
            ))}
          </div>
        </div>

        {/* Detailed list with usage */}
        <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase', padding: '0 6px 8px' }}>使用次數</div>
        <AccGlass dark={dark} radius={18} style={{ padding: 0, overflow: 'hidden' }}>
          {TAGS.sort((a, b) => b.usageCount - a.usageCount).map((t, i) => (
            <React.Fragment key={t.id}>
              <div style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer' }}>
                <div style={{ width: 36, height: 36, borderRadius: 18, background: `${t.color}22`, border: `1.5px solid ${t.color}`, display: 'flex', alignItems: 'center', justifyContent: 'center', color: t.color, fontFamily: ACC_FONTS.body, fontWeight: 600, fontSize: 14 }}>#</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 15, fontWeight: 600, color: fg }}>{t.name}</div>
                  <div style={{ fontSize: 11, color: muted, marginTop: 2, fontFamily: ACC_FONTS.mono, letterSpacing: 0.3 }}>{t.color.toUpperCase()}</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontFamily: ACC_FONTS.mono, fontSize: 13, color: fg, fontWeight: 600, fontVariantNumeric: 'tabular-nums' }}>{t.usageCount}</div>
                  <div style={{ fontSize: 10, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 0.5, textTransform: 'uppercase' }}>txns</div>
                </div>
                <AccGlyph name="chevron-right" size={14} color={muted} stroke={2}/>
              </div>
              {i < TAGS.length - 1 && <div style={{ height: 0.5, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)', marginLeft: 64 }}/>}
            </React.Fragment>
          ))}
        </AccGlass>

        <div style={{ marginTop: 10, padding: '0 6px', fontSize: 11, color: muted, lineHeight: 1.5 }}>
          刪除標籤會同時從交易中移除。向左滑動可刪除。
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// Tag Form
// ═══════════════════════════════════════════════════════════
function TagForm({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? ACC_COLORS.warmDark : ACC_COLORS.warm;
  const [name, setName] = React.useState('週末聚餐');
  const [color, setColor] = React.useState('#A66BF0');

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0' }}>
        <div style={{ width: 36, height: 5, borderRadius: 100, background: dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.18)' }}/>
      </div>
      <div style={{ padding: '4px 16px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: accent, fontSize: 16, padding: 4 }}>取消</button>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 17, fontWeight: 600, color: fg }}>新增標籤</div>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: accent, fontSize: 16, fontWeight: 700, padding: 4 }}>儲存</button>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '0 16px 100px' }}>
        {/* Live preview chip */}
        <div style={{ display: 'flex', justifyContent: 'center', padding: '24px 0 28px' }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 8,
            padding: '11px 20px', borderRadius: 100,
            background: `${color}22`,
            border: `1.5px solid ${color}`,
            color: color,
            fontSize: 17, fontWeight: 700,
            boxShadow: `0 8px 24px ${color}30`,
            transition: 'all 220ms',
          }}>
            <span style={{ width: 10, height: 10, borderRadius: 5, background: color }}/>
            #{name || '標籤名稱'}
          </div>
        </div>

        {/* Name */}
        <div style={{ marginBottom: 18 }}>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase', padding: '0 6px 8px' }}>名稱</div>
          <AccGlass dark={dark} radius={14} style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ color: muted, fontSize: 16, fontWeight: 600, fontFamily: ACC_FONTS.body }}>#</span>
            <input value={name} onChange={e => setName(e.target.value)} placeholder="輸入標籤名稱"
              style={{ flex: 1, border: 'none', outline: 'none', background: 'transparent', fontSize: 16, color: fg, fontFamily: ACC_FONTS.body }}/>
          </AccGlass>
        </div>

        {/* Color picker — bigger swatches than category */}
        <div style={{ marginBottom: 18 }}>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase', padding: '0 6px 8px' }}>顏色</div>
          <AccGlass dark={dark} radius={14} style={{ padding: 14 }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12 }}>
              {TAG_COLORS.map(c => {
                const active = color === c;
                return (
                  <button key={c} onClick={() => setColor(c)} style={{
                    aspectRatio: '1 / 1', borderRadius: '50%', background: c,
                    border: active ? `3px solid ${dark ? '#fff' : '#0A0A0A'}` : '3px solid transparent',
                    cursor: 'pointer', padding: 0,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    boxShadow: active ? `0 4px 12px ${c}60` : 'none',
                  }}>
                    {active && <AccGlyph name="check" size={14} color="#fff" stroke={2.5}/>}
                  </button>
                );
              })}
            </div>
          </AccGlass>
        </div>

        <div style={{ padding: '0 6px', fontSize: 11, color: muted, lineHeight: 1.5 }}>
          標籤用於跨類別的交易標記,例如「週末」「公帳」「報帳」。
        </div>
      </div>
    </div>
  );
}

function TagCanvas() {
  const dark = false;
  const muted = 'rgba(60,60,67,0.55)';
  const screens = [
    { id: 'list', label: '01 / Tag List', desc: '所有標籤 chip 全覽 · 使用次數列表', Comp: TagList },
    { id: 'form', label: '02 / Add / Edit Tag', desc: '即時 chip preview · 12 色 swatch grid', Comp: TagForm },
  ];
  return (
    <div style={{ minHeight: '100vh', background: '#ECE9E2', padding: '40px 24px 80px', fontFamily: ACC_FONTS.body }}>
      <div style={{ maxWidth: 1280, margin: '0 auto 32px' }}>
        <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.4, textTransform: 'uppercase' }}>NeuLedger · Tag Management</div>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 40, fontWeight: 600, letterSpacing: -1, marginTop: 4 }}>標籤管理</div>
        <div style={{ fontSize: 14, color: muted, marginTop: 6, maxWidth: 520, lineHeight: 1.5 }}>
          基於 TagManagementFeature。簡單的 name + color,無 type 概念。雙視圖:chip 全覽 + 使用統計列表。
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

ReactDOM.createRoot(document.getElementById('root')).render(<TagCanvas/>);
