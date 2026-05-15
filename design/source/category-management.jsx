// NeuLedger — Category Management
// 2 artboards: List (with segmented) + Add/Edit form
// Reuses AccPhone / AccGlass / AccGlyph / ACC_FONTS / ACC_COLORS from accounts.jsx

const CATEGORIES = {
  expense: [
    { id: 'food', name: '餐飲', icon: 'cash', color: '#E8835A', isDefault: true },
    { id: 'transport', name: '交通', icon: 'phone', color: '#1B5E8E', isDefault: true },
    { id: 'shop', name: '購物', icon: 'card', color: '#A66BF0', isDefault: true },
    { id: 'fun', name: '娛樂', icon: 'star', color: '#F4B400', isDefault: false },
    { id: 'home', name: '居家', icon: 'archive', color: '#8B6F47', isDefault: false },
    { id: 'health', name: '醫療', icon: 'sparkle', color: '#34C759', isDefault: true },
    { id: 'edu', name: '教育', icon: 'edit', color: '#5E5CE6', isDefault: false },
  ],
  income: [
    { id: 'salary', name: '薪資', icon: 'arrow-down-left', color: '#34C759', isDefault: true },
    { id: 'bonus', name: '獎金', icon: 'sparkle', color: '#F4B400', isDefault: false },
    { id: 'invest-in', name: '投資收益', icon: 'invest', color: '#5E5CE6', isDefault: false },
  ],
};

const ICON_LIBRARY = ['cash','card','bank','phone','star','archive','sparkle','edit','invest','crypto','plus','check','arrow-up-right','arrow-down-left','dots','trash'];
const COLOR_LIBRARY = ['#E8835A','#1B5E8E','#A66BF0','#F4B400','#8B6F47','#34C759','#5E5CE6','#FF6B6B','#7B3F00','#0A84FF','#FF453A','#9B7E5F'];

// ═══════════════════════════════════════════════════════════
// Category List
// ═══════════════════════════════════════════════════════════
function CategoryList({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? ACC_COLORS.warmDark : ACC_COLORS.warm;
  const [type, setType] = React.useState('expense');
  const list = CATEGORIES[type];

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* Nav */}
      <div style={{ padding: '8px 12px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: accent, fontSize: 15, fontWeight: 500 }}>編輯</button>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 17, fontWeight: 600, color: fg }}>類別管理</div>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: accent }}>
          <AccGlyph name="plus" size={22} color={accent} stroke={2}/>
        </button>
      </div>

      {/* Segmented */}
      <div style={{ padding: '8px 16px 16px' }}>
        <div style={{ display: 'flex', padding: 3, borderRadius: 9, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)' }}>
          {[{k:'expense',l:'支出'},{k:'income',l:'收入'}].map(t => {
            const active = type === t.k;
            return (
              <button key={t.k} onClick={() => setType(t.k)} style={{
                flex: 1, padding: '7px 0', textAlign: 'center', borderRadius: 7,
                background: active ? (dark ? 'rgba(255,255,255,0.14)' : '#fff') : 'transparent',
                boxShadow: active ? '0 1px 3px rgba(0,0,0,0.08)' : 'none',
                color: active ? fg : muted,
                fontSize: 13, fontWeight: 600, fontFamily: ACC_FONTS.body, border: 'none', cursor: 'pointer',
              }}>{t.l}</button>
            );
          })}
        </div>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '0 16px 100px' }}>
        <AccGlass dark={dark} radius={18} style={{ padding: 0, overflow: 'hidden' }}>
          {list.map((c, i) => (
            <React.Fragment key={c.id}>
              <div style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer' }}>
                {/* drag handle */}
                <div style={{ width: 20, color: muted, display: 'flex', flexDirection: 'column', gap: 2, alignItems: 'center', cursor: 'grab' }}>
                  <div style={{ width: 14, height: 1.5, background: muted, borderRadius: 1 }}/>
                  <div style={{ width: 14, height: 1.5, background: muted, borderRadius: 1 }}/>
                  <div style={{ width: 14, height: 1.5, background: muted, borderRadius: 1 }}/>
                </div>
                <div style={{ width: 40, height: 40, borderRadius: 20, background: c.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                  <AccGlyph name={c.icon} size={18} color="#fff" stroke={2}/>
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 15, fontWeight: 600, color: fg }}>{c.name}</div>
                  {c.isDefault && (
                    <div style={{ display: 'inline-block', marginTop: 3, fontSize: 10, fontFamily: ACC_FONTS.mono, color: muted, padding: '1px 7px', borderRadius: 5, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)', letterSpacing: 0.5, textTransform: 'uppercase' }}>系統預設</div>
                  )}
                </div>
                {!c.isDefault && <AccGlyph name="chevron-right" size={14} color={muted} stroke={2}/>}
              </div>
              {i < list.length - 1 && <div style={{ height: 0.5, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)', marginLeft: 88 }}/>}
            </React.Fragment>
          ))}
        </AccGlass>
        <div style={{ marginTop: 10, padding: '0 6px', fontSize: 11, color: muted, lineHeight: 1.5 }}>
          系統預設類別無法刪除。長按拖曳可調整順序。
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// Add / Edit Category Form
// ═══════════════════════════════════════════════════════════
function CategoryForm({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? ACC_COLORS.warmDark : ACC_COLORS.warm;
  const [name, setName] = React.useState('外送');
  const [pickedIcon, setPickedIcon] = React.useState('phone');
  const [pickedColor, setPickedColor] = React.useState('#FF6B6B');
  const [type, setType] = React.useState('expense');

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0' }}>
        <div style={{ width: 36, height: 5, borderRadius: 100, background: dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.18)' }}/>
      </div>
      <div style={{ padding: '4px 16px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: accent, fontSize: 16, padding: 4 }}>取消</button>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 17, fontWeight: 600, color: fg }}>新增類別</div>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: accent, fontSize: 16, fontWeight: 700, padding: 4 }}>儲存</button>
      </div>

      <div style={{ flex: 1, overflow: 'auto', padding: '0 16px 100px' }}>
        {/* Live preview */}
        <div style={{ display: 'flex', justifyContent: 'center', padding: '16px 0 22px' }}>
          <div style={{ textAlign: 'center' }}>
            <div style={{
              width: 80, height: 80, borderRadius: 40, background: pickedColor,
              display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: `0 12px 32px ${pickedColor}40`, marginBottom: 10,
            }}>
              <AccGlyph name={pickedIcon} size={36} color="#fff" stroke={2}/>
            </div>
            <div style={{ fontFamily: ACC_FONTS.display, fontSize: 20, fontWeight: 600, color: fg, letterSpacing: -0.3 }}>{name || '類別名稱'}</div>
            <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase', marginTop: 3 }}>{type === 'expense' ? '支出 · Expense' : '收入 · Income'}</div>
          </div>
        </div>

        {/* Type segmented */}
        <div style={{ marginBottom: 18 }}>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase', padding: '0 6px 8px' }}>類型</div>
          <div style={{ display: 'flex', padding: 3, borderRadius: 9, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)' }}>
            {[{k:'expense',l:'支出',c:ACC_COLORS.expense},{k:'income',l:'收入',c:ACC_COLORS.income}].map(t => {
              const active = type === t.k;
              return (
                <button key={t.k} onClick={() => setType(t.k)} style={{
                  flex: 1, padding: '7px 0', textAlign: 'center', borderRadius: 7,
                  background: active ? (dark ? 'rgba(255,255,255,0.14)' : '#fff') : 'transparent',
                  boxShadow: active ? '0 1px 3px rgba(0,0,0,0.08)' : 'none',
                  color: active ? t.c : muted,
                  fontSize: 13, fontWeight: 600, border: 'none', cursor: 'pointer',
                }}>{t.l}</button>
              );
            })}
          </div>
        </div>

        {/* Name */}
        <div style={{ marginBottom: 18 }}>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase', padding: '0 6px 8px' }}>名稱</div>
          <AccGlass dark={dark} radius={14} style={{ padding: '12px 16px' }}>
            <input value={name} onChange={e => setName(e.target.value)} placeholder="輸入類別名稱"
              style={{ width: '100%', border: 'none', outline: 'none', background: 'transparent', fontSize: 16, color: fg, fontFamily: ACC_FONTS.body }}/>
          </AccGlass>
        </div>

        {/* Icon picker */}
        <div style={{ marginBottom: 18 }}>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase', padding: '0 6px 8px' }}>圖示</div>
          <AccGlass dark={dark} radius={14} style={{ padding: 12 }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 8 }}>
              {ICON_LIBRARY.map(ic => {
                const active = pickedIcon === ic;
                return (
                  <button key={ic} onClick={() => setPickedIcon(ic)} style={{
                    aspectRatio: '1 / 1', borderRadius: 12,
                    background: active ? pickedColor : (dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)'),
                    border: 'none', cursor: 'pointer',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    boxShadow: active ? `0 4px 12px ${pickedColor}50` : 'none',
                  }}>
                    <AccGlyph name={ic} size={18} color={active ? '#fff' : fg} stroke={2}/>
                  </button>
                );
              })}
            </div>
          </AccGlass>
        </div>

        {/* Color picker */}
        <div style={{ marginBottom: 18 }}>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase', padding: '0 6px 8px' }}>顏色</div>
          <AccGlass dark={dark} radius={14} style={{ padding: 14 }}>
            <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
              {COLOR_LIBRARY.map(c => {
                const active = pickedColor === c;
                return (
                  <button key={c} onClick={() => setPickedColor(c)} style={{
                    width: 32, height: 32, borderRadius: 16, background: c,
                    border: active ? `2.5px solid ${dark ? '#fff' : '#0A0A0A'}` : '2.5px solid transparent',
                    cursor: 'pointer', padding: 0,
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    boxShadow: active ? `0 2px 8px ${c}50` : 'none',
                  }}>
                    {active && <AccGlyph name="check" size={14} color="#fff" stroke={2.5}/>}
                  </button>
                );
              })}
            </div>
          </AccGlass>
        </div>
      </div>
    </div>
  );
}

function CategoryCanvas() {
  const dark = false;
  const muted = 'rgba(60,60,67,0.55)';
  const screens = [
    { id: 'list', label: '01 / Category List', desc: '支出 / 收入 segmented · 可拖曳排序 · 系統預設無法刪除', Comp: CategoryList },
    { id: 'form', label: '02 / Add / Edit Category', desc: '即時 preview · icon grid · color swatch', Comp: CategoryForm },
  ];
  return (
    <div style={{ minHeight: '100vh', background: '#ECE9E2', padding: '40px 24px 80px', fontFamily: ACC_FONTS.body }}>
      <div style={{ maxWidth: 1280, margin: '0 auto 32px' }}>
        <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.4, textTransform: 'uppercase' }}>NeuLedger · Category Management</div>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 40, fontWeight: 600, letterSpacing: -1, marginTop: 4 }}>類別管理</div>
        <div style={{ fontSize: 14, color: muted, marginTop: 6, maxWidth: 520, lineHeight: 1.5 }}>
          基於 CategoryManagementFeature / AddEditCategoryFeature。支出與收入分頁,系統預設類別保留,可拖曳排序。
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

ReactDOM.createRoot(document.getElementById('root')).render(<CategoryCanvas/>);
