// NeuLedger — Add Transaction (Full page) for D2
// Single screen with state machine: blank / extracting / filled / picker open / saving / saved
// Native iOS numeric keyboard for amount input

const { useState: useS2, useEffect: useE2, useRef: useR2 } = React;

// ─────────────────────────────────────────────────────────────
// Categories with icons + colors
// ─────────────────────────────────────────────────────────────
const CAT_GROUPS = [
  {
    key: 'food', label: '飲食', color: '#FF9500',
    items: [
      { id: 'breakfast', label: '早餐', emoji: '🥐' },
      { id: 'lunch', label: '午餐', emoji: '🍱' },
      { id: 'dinner', label: '晚餐', emoji: '🍜' },
      { id: 'coffee', label: '咖啡', emoji: '☕' },
      { id: 'snack', label: '點心', emoji: '🍰' },
      { id: 'cvs', label: '便利店', emoji: '🏪' },
    ],
  },
  {
    key: 'transport', label: '交通', color: '#5E5CE6',
    items: [
      { id: 'mrt', label: '捷運', emoji: '🚇' },
      { id: 'bus', label: '公車', emoji: '🚌' },
      { id: 'taxi', label: '計程車', emoji: '🚕' },
      { id: 'gas', label: '加油', emoji: '⛽' },
      { id: 'parking', label: '停車', emoji: '🅿️' },
    ],
  },
  {
    key: 'shopping', label: '購物', color: '#FF2D55',
    items: [
      { id: 'clothes', label: '服飾', emoji: '👕' },
      { id: 'books', label: '書籍', emoji: '📚' },
      { id: 'electronics', label: '電子', emoji: '💻' },
      { id: 'gift', label: '禮物', emoji: '🎁' },
    ],
  },
  {
    key: 'leisure', label: '休閒', color: '#34C759',
    items: [
      { id: 'movie', label: '電影', emoji: '🎬' },
      { id: 'game', label: '遊戲', emoji: '🎮' },
      { id: 'travel', label: '旅遊', emoji: '✈️' },
      { id: 'subscription', label: '訂閱', emoji: '🎵' },
    ],
  },
  {
    key: 'health', label: '健康', color: '#0A84FF',
    items: [
      { id: 'medical', label: '醫療', emoji: '⚕️' },
      { id: 'pharmacy', label: '藥局', emoji: '💊' },
      { id: 'fitness', label: '健身', emoji: '🏋️' },
    ],
  },
  {
    key: 'home', label: '居家', color: '#FF6482',
    items: [
      { id: 'rent', label: '房租', emoji: '🏠' },
      { id: 'utilities', label: '水電瓦斯', emoji: '💡' },
      { id: 'internet', label: '網路', emoji: '📡' },
    ],
  },
];

const INCOME_CATS = [
  { id: 'salary', label: '薪資', emoji: '💼', color: '#34C759' },
  { id: 'bonus', label: '獎金', emoji: '🎉', color: '#34C759' },
  { id: 'investment', label: '投資', emoji: '📈', color: '#34C759' },
  { id: 'side', label: '副業', emoji: '💻', color: '#34C759' },
  { id: 'gift_in', label: '禮金', emoji: '🧧', color: '#34C759' },
  { id: 'refund', label: '退款', emoji: '↩️', color: '#34C759' },
];

const ACCOUNTS = [
  { id: 'cash', label: 'Cash 現金', icon: 'banknote', color: '#8E8E93', balance: 3200 },
  { id: 'esun', label: '玉山銀行', icon: 'wallet', color: '#0A84FF', balance: 48930 },
  { id: 'easycard', label: '悠遊卡', icon: 'phone', color: '#5E5CE6', balance: 420 },
  { id: 'visa', label: 'Visa 信用卡', icon: 'creditcard', color: '#FF2D55', balance: -8430 },
];

// ─────────────────────────────────────────────────────────────
// iOS Numeric Keypad (matches IOSKeyboard glass style)
// ─────────────────────────────────────────────────────────────
function IOSNumPad({ dark, onPress, onDelete, onDone }) {
  const glyph = dark ? '#fff' : '#000';
  const keyBg = dark ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.85)';
  const keyBgDark = dark ? 'rgba(255,255,255,0.10)' : 'rgba(170,178,191,0.6)';

  const Key = ({ children, onClick, dim, fontSize = 26, fontWeight = 400 }) => (
    <Tappable onClick={onClick}>
      <div style={{
        height: 44, borderRadius: 9,
        background: dim ? keyBgDark : keyBg,
        boxShadow: '0 1px 0 rgba(0,0,0,0.075)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontFamily: '-apple-system, "SF Pro", system-ui',
        fontSize, fontWeight, color: glyph,
        userSelect: 'none',
      }}>
        {children}
      </div>
    </Tappable>
  );

  const row = (cells) => (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 6.5 }}>
      {cells}
    </div>
  );

  return (
    <div style={{
      position: 'relative', zIndex: 15, borderRadius: 27, overflow: 'hidden',
      padding: '14px 8px 4px',
      display: 'flex', flexDirection: 'column',
      boxShadow: dark
        ? '0 -2px 20px rgba(0,0,0,0.09)'
        : '0 -1px 6px rgba(0,0,0,0.018), 0 -3px 20px rgba(0,0,0,0.012)',
    }}>
      <div style={{
        position: 'absolute', inset: 0, borderRadius: 27,
        backdropFilter: 'blur(12px) saturate(180%)',
        WebkitBackdropFilter: 'blur(12px) saturate(180%)',
        background: dark ? 'rgba(120,120,128,0.14)' : 'rgba(255,255,255,0.25)',
      }}/>
      <div style={{
        position: 'absolute', inset: 0, borderRadius: 27,
        boxShadow: dark
          ? 'inset 1.5px 1.5px 1px rgba(255,255,255,0.15)'
          : 'inset 1.5px 1.5px 1px rgba(255,255,255,0.7), inset -1px -1px 1px rgba(255,255,255,0.4)',
        border: dark ? '0.5px solid rgba(255,255,255,0.15)' : '0.5px solid rgba(0,0,0,0.06)',
        pointerEvents: 'none',
      }}/>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 6.5, position: 'relative', padding: '0 4px' }}>
        {row([
          <Key key="1" onClick={() => onPress('1')}>1</Key>,
          <Key key="2" onClick={() => onPress('2')}>2</Key>,
          <Key key="3" onClick={() => onPress('3')}>3</Key>,
          <Key key="plus" onClick={() => onPress('+')} dim fontSize={22}>+</Key>,
        ])}
        {row([
          <Key key="4" onClick={() => onPress('4')}>4</Key>,
          <Key key="5" onClick={() => onPress('5')}>5</Key>,
          <Key key="6" onClick={() => onPress('6')}>6</Key>,
          <Key key="minus" onClick={() => onPress('-')} dim fontSize={22}>−</Key>,
        ])}
        {row([
          <Key key="7" onClick={() => onPress('7')}>7</Key>,
          <Key key="8" onClick={() => onPress('8')}>8</Key>,
          <Key key="9" onClick={() => onPress('9')}>9</Key>,
          <Key key="del" onClick={onDelete} dim fontSize={20}>
            <svg width="22" height="16" viewBox="0 0 23 17"><path d="M7 1h13a2 2 0 012 2v11a2 2 0 01-2 2H7l-6-7.5L7 1z" fill="none" stroke={glyph} strokeWidth="1.6" strokeLinejoin="round"/><path d="M10 5l7 7M17 5l-7 7" stroke={glyph} strokeWidth="1.6" strokeLinecap="round"/></svg>
          </Key>,
        ])}
        {row([
          <Key key="dot" onClick={() => onPress('.')}>.</Key>,
          <Key key="0" onClick={() => onPress('0')}>0</Key>,
          <Key key="000" onClick={() => onPress('000')} fontSize={20}>000</Key>,
          <Tappable key="done" onClick={onDone}>
            <div style={{
              height: 44, borderRadius: 9,
              background: COLORS.accent,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontFamily: '-apple-system, system-ui', fontSize: 17, fontWeight: 600, color: '#fff',
              boxShadow: `0 2px 8px ${COLORS.accent}55`,
            }}>完成</div>
          </Tappable>,
        ])}
      </div>

      <div style={{ height: 28, position: 'relative' }}/>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Segmented control (支出 / 收入 / 轉帳)
// ─────────────────────────────────────────────────────────────
function TypeSegmented({ value, onChange, dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const items = [
    { id: 'expense', label: '支出', color: COLORS.expense },
    { id: 'income', label: '收入', color: COLORS.income },
    { id: 'transfer', label: '轉帳', color: '#5E5CE6' },
  ];
  return (
    <div style={{
      display: 'grid', gridTemplateColumns: '1fr 1fr 1fr',
      background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)',
      borderRadius: 12, padding: 3, gap: 2, position: 'relative',
    }}>
      {items.map(it => (
        <Tappable key={it.id} onClick={() => onChange(it.id)}>
          <div style={{
            padding: '8px 0', borderRadius: 10, textAlign: 'center',
            background: value === it.id ? (dark ? 'rgba(255,255,255,0.10)' : '#fff') : 'transparent',
            boxShadow: value === it.id ? '0 1px 3px rgba(0,0,0,0.08)' : 'none',
            fontFamily: FONTS.body, fontSize: 14,
            fontWeight: value === it.id ? 600 : 500,
            color: value === it.id ? it.color : muted,
            letterSpacing: -0.15,
            transition: `all .2s ${EASE}`,
          }}>{it.label}</div>
        </Tappable>
      ))}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// AI extraction strip
// ─────────────────────────────────────────────────────────────
function AIExtractStrip({ dark, status, onRun, value, setValue, onClear }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;

  return (
    <Glass dark={dark} radius={18} style={{ padding: '12px 14px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
        <Glyph name="sparkles" size={13} color={accent}/>
        <div style={{
          fontFamily: FONTS.mono, fontSize: 10, color: muted,
          textTransform: 'uppercase', letterSpacing: 1.2, fontWeight: 500,
        }}>AI Quick fill · on-device</div>
        {status === 'extracting' && (
          <div style={{ display: 'flex', gap: 3, marginLeft: 'auto' }}>
            {[0,1,2].map(i => (
              <div key={i} style={{
                width: 5, height: 5, borderRadius: 3, background: accent,
                opacity: 0.4, animation: `bDot 1s ${i * 0.15}s infinite`,
              }}/>
            ))}
          </div>
        )}
        {status === 'filled' && (
          <div style={{
            marginLeft: 'auto',
            padding: '2px 8px', borderRadius: 999,
            background: 'rgba(52,199,89,0.15)',
            color: dark ? COLORS.incomeDark : COLORS.income,
            fontFamily: FONTS.mono, fontSize: 9, fontWeight: 600, letterSpacing: 0.5,
          }}>FILLED</div>
        )}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <input
          value={value}
          onChange={e => setValue(e.target.value)}
          onKeyDown={e => { if (e.key === 'Enter') onRun(); }}
          placeholder="例:咖啡 65 悠遊卡"
          style={{
            border: 'none', outline: 'none', background: 'transparent', flex: 1, minWidth: 0,
            fontFamily: FONTS.body, fontSize: 14, color: fg, letterSpacing: -0.15,
          }}/>
        {value && status !== 'extracting' && (
          <Tappable onClick={onClear}>
            <div style={{
              width: 18, height: 18, borderRadius: 9,
              background: dark ? 'rgba(255,255,255,0.15)' : 'rgba(0,0,0,0.1)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: dark ? '#fff' : '#000', fontSize: 12, lineHeight: 1,
            }}>×</div>
          </Tappable>
        )}
        <Tappable onClick={onRun}>
          <div style={{
            padding: '6px 12px', borderRadius: 999,
            background: value.trim() ? accent : (dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.06)'),
            color: value.trim() ? '#fff' : muted,
            fontFamily: FONTS.body, fontSize: 12, fontWeight: 600, letterSpacing: -0.1,
          }}>抽取</div>
        </Tappable>
      </div>
    </Glass>
  );
}

// ─────────────────────────────────────────────────────────────
// Field row (label + value, tappable)
// ─────────────────────────────────────────────────────────────
function FieldRow({ label, children, onTap, dark, isLast, danger }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  return (
    <Tappable onClick={onTap}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 10,
        padding: '13px 14px',
        borderBottom: isLast ? 'none' : (dark ? '0.5px solid rgba(255,255,255,0.06)' : '0.5px solid rgba(0,0,0,0.05)'),
      }}>
        <div style={{
          fontFamily: FONTS.body, fontSize: 13, color: muted, letterSpacing: -0.1,
          width: 56, flexShrink: 0,
        }}>{label}</div>
        <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center', gap: 8 }}>
          {children}
        </div>
        {onTap && (
          <svg width="8" height="14" viewBox="0 0 8 14" fill="none">
            <path d="M1 1l6 6-6 6" stroke={muted} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        )}
      </div>
    </Tappable>
  );
}

// ─────────────────────────────────────────────────────────────
// Category picker sheet
// ─────────────────────────────────────────────────────────────
function CategorySheet({ open, onClose, dark, type, onPick, current }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;

  return (
    <Sheet open={open} onClose={onClose} dark={dark}>
      <div style={{ padding: '8px 0 28px' }}>
        <div style={{ width: 38, height: 5, borderRadius: 3, background: dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.15)', margin: '8px auto 14px' }}/>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 22px 12px' }}>
          <div style={{ fontFamily: FONTS.display, fontSize: 20, fontWeight: 700, color: fg, letterSpacing: -0.5 }}>
            選擇分類
          </div>
          <Tappable onClick={onClose}>
            <div style={{ fontFamily: FONTS.body, fontSize: 14, color: accent, fontWeight: 500 }}>取消</div>
          </Tappable>
        </div>

        {type === 'income' ? (
          <div style={{ padding: '0 16px' }}>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
              {INCOME_CATS.map(c => (
                <CategoryTile key={c.id} cat={c} selected={current?.id === c.id} onClick={() => onPick(c)} dark={dark}/>
              ))}
            </div>
          </div>
        ) : (
          <div style={{ padding: '0 16px' }}>
            {CAT_GROUPS.map((g, gi) => (
              <div key={g.key} style={{ marginBottom: gi < CAT_GROUPS.length - 1 ? 14 : 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '0 6px 8px' }}>
                  <div style={{ width: 6, height: 6, borderRadius: 3, background: g.color }}/>
                  <div style={{
                    fontFamily: FONTS.mono, fontSize: 10, color: muted,
                    textTransform: 'uppercase', letterSpacing: 1.2, fontWeight: 500,
                  }}>{g.label}</div>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
                  {g.items.map(c => (
                    <CategoryTile
                      key={c.id}
                      cat={{ ...c, color: g.color, group: g.label }}
                      selected={current?.id === c.id}
                      onClick={() => onPick({ ...c, color: g.color, group: g.label })}
                      dark={dark}
                    />
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </Sheet>
  );
}

function CategoryTile({ cat, selected, onClick, dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  return (
    <Tappable onClick={onClick}>
      <div style={{
        padding: '10px 4px',
        borderRadius: 14,
        background: selected ? cat.color + '22' : (dark ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)'),
        border: selected ? `1px solid ${cat.color}` : (dark ? '0.5px solid rgba(255,255,255,0.06)' : '0.5px solid rgba(0,0,0,0.04)'),
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
        transition: `all .15s ${EASE}`,
      }}>
        <div style={{
          width: 38, height: 38, borderRadius: 19,
          background: cat.color + (selected ? '33' : '20'),
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 22,
        }}>{cat.emoji}</div>
        <div style={{
          fontFamily: FONTS.body, fontSize: 11, fontWeight: selected ? 600 : 500,
          color: selected ? cat.color : fg, letterSpacing: -0.1, textAlign: 'center',
        }}>{cat.label}</div>
      </div>
    </Tappable>
  );
}

// ─────────────────────────────────────────────────────────────
// Account picker sheet
// ─────────────────────────────────────────────────────────────
function AccountSheet({ open, onClose, dark, onPick, current, label = '選擇帳戶' }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;
  return (
    <Sheet open={open} onClose={onClose} dark={dark}>
      <div style={{ padding: '8px 0 28px' }}>
        <div style={{ width: 38, height: 5, borderRadius: 3, background: dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.15)', margin: '8px auto 14px' }}/>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 22px 12px' }}>
          <div style={{ fontFamily: FONTS.display, fontSize: 20, fontWeight: 700, color: fg, letterSpacing: -0.5 }}>{label}</div>
          <Tappable onClick={onClose}>
            <div style={{ fontFamily: FONTS.body, fontSize: 14, color: accent, fontWeight: 500 }}>取消</div>
          </Tappable>
        </div>
        <div style={{ padding: '0 16px' }}>
          {ACCOUNTS.map((a, i) => {
            const isSel = current?.id === a.id;
            return (
              <Tappable key={a.id} onClick={() => onPick(a)}>
                <div style={{
                  display: 'flex', alignItems: 'center', gap: 12,
                  padding: '14px 12px',
                  borderRadius: 14,
                  marginBottom: 8,
                  background: isSel ? a.color + '18' : (dark ? 'rgba(255,255,255,0.04)' : 'rgba(0,0,0,0.03)'),
                  border: isSel ? `1px solid ${a.color}55` : (dark ? '0.5px solid rgba(255,255,255,0.06)' : '0.5px solid rgba(0,0,0,0.04)'),
                }}>
                  <div style={{
                    width: 38, height: 38, borderRadius: 11,
                    background: a.color + '22',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }}>
                    <Glyph name={a.icon} size={19} color={a.color}/>
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontFamily: FONTS.body, fontSize: 15, fontWeight: 500, color: fg, letterSpacing: -0.15 }}>{a.label}</div>
                    <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: muted, letterSpacing: -0.1, marginTop: 1 }}>
                      {a.balance < 0 ? '−' : ''}NT$ {Math.abs(a.balance).toLocaleString()}
                    </div>
                  </div>
                  {isSel && (
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                      <circle cx="12" cy="12" r="10" fill={a.color}/>
                      <path d="M7 12.5l3.5 3.5L17 9" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                  )}
                </div>
              </Tappable>
            );
          })}
        </div>
      </div>
    </Sheet>
  );
}

// ─────────────────────────────────────────────────────────────
// Date picker sheet (simple month calendar)
// ─────────────────────────────────────────────────────────────
function DateSheet({ open, onClose, dark, value, onPick }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;

  // Build April 2026 mock calendar (matches "today: 25 Apr")
  const days = [];
  const firstDay = 3; // Wed = 3 (April 1, 2026)
  const lastDate = 30;
  for (let i = 0; i < firstDay; i++) days.push(null);
  for (let d = 1; d <= lastDate; d++) days.push(d);

  const today = 25;
  const sel = value ? value.day : today;

  return (
    <Sheet open={open} onClose={onClose} dark={dark}>
      <div style={{ padding: '8px 0 28px' }}>
        <div style={{ width: 38, height: 5, borderRadius: 3, background: dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.15)', margin: '8px auto 14px' }}/>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 22px 12px' }}>
          <div style={{ fontFamily: FONTS.display, fontSize: 20, fontWeight: 700, color: fg, letterSpacing: -0.5 }}>選擇日期</div>
          <Tappable onClick={onClose}>
            <div style={{ fontFamily: FONTS.body, fontSize: 14, color: accent, fontWeight: 500 }}>取消</div>
          </Tappable>
        </div>

        <div style={{ display: 'flex', gap: 8, padding: '0 22px 14px' }}>
          {[
            { label: '今天', d: 25 },
            { label: '昨天', d: 24 },
            { label: '前天', d: 23 },
          ].map(p => (
            <Tappable key={p.label} onClick={() => onPick({ day: p.d, label: `${p.label} · 4/${p.d}` })}>
              <div style={{
                padding: '7px 14px', borderRadius: 999,
                background: sel === p.d ? accent : (dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)'),
                color: sel === p.d ? '#fff' : fg,
                fontFamily: FONTS.body, fontSize: 13, fontWeight: 500, letterSpacing: -0.1,
              }}>{p.label}</div>
            </Tappable>
          ))}
        </div>

        <div style={{ padding: '0 16px' }}>
          <div style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'center',
            padding: '0 8px 10px',
          }}>
            <div style={{ fontFamily: FONTS.display, fontSize: 17, fontWeight: 600, color: fg, letterSpacing: -0.3 }}>
              April 2026
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <div style={{
                width: 28, height: 28, borderRadius: 14,
                background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <svg width="8" height="14" viewBox="0 0 8 14" fill="none">
                  <path d="M7 1L1 7l6 6" stroke={muted} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
              <div style={{
                width: 28, height: 28, borderRadius: 14,
                background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <svg width="8" height="14" viewBox="0 0 8 14" fill="none">
                  <path d="M1 1l6 6-6 6" stroke={muted} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </div>
            </div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 4 }}>
            {['S','M','T','W','T','F','S'].map((d, i) => (
              <div key={i} style={{
                fontFamily: FONTS.mono, fontSize: 10, textAlign: 'center', padding: '4px 0',
                color: muted, textTransform: 'uppercase', letterSpacing: 0.5,
              }}>{d}</div>
            ))}
            {days.map((d, i) => (
              <Tappable key={i} onClick={() => d && onPick({ day: d, label: `4/${d}` })}>
                <div style={{
                  height: 38, borderRadius: 10,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  background: d === sel ? accent : (d === today && d !== sel ? (dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)') : 'transparent'),
                  color: d === sel ? '#fff' : (d ? fg : 'transparent'),
                  fontFamily: FONTS.mono, fontSize: 14,
                  fontWeight: d === sel || d === today ? 600 : 400,
                  letterSpacing: -0.2,
                  border: d === today && d !== sel ? `1px solid ${accent}` : 'none',
                }}>{d || ''}</div>
              </Tappable>
            ))}
          </div>
        </div>
      </div>
    </Sheet>
  );
}

// ─────────────────────────────────────────────────────────────
// Tag chip + add
// ─────────────────────────────────────────────────────────────
const TAG_SUGGESTIONS = ['#morning', '#commute', '#monthly', '#books', '#date', '#work'];

function TagsField({ tags, setTags, dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;
  const [picking, setPicking] = useS2(false);
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, alignItems: 'center', flex: 1 }}>
      {tags.length === 0 && !picking && (
        <Tappable onClick={() => setPicking(true)}>
          <div style={{
            fontFamily: FONTS.body, fontSize: 14, color: muted, letterSpacing: -0.15,
          }}>加標籤</div>
        </Tappable>
      )}
      {tags.map((t, i) => (
        <Tappable key={i} onClick={() => setTags(tags.filter(x => x !== t))}>
          <div style={{
            padding: '3px 9px', borderRadius: 999,
            background: dark ? 'rgba(255,159,10,0.18)' : 'rgba(255,149,0,0.12)',
            color: accent,
            fontFamily: FONTS.mono, fontSize: 11, fontWeight: 500, letterSpacing: -0.1,
            display: 'flex', alignItems: 'center', gap: 4,
          }}>
            {t}
            <span style={{ fontSize: 10, opacity: 0.7 }}>×</span>
          </div>
        </Tappable>
      ))}
      {picking && (
        <React.Fragment>
          {TAG_SUGGESTIONS.filter(t => !tags.includes(t)).slice(0, 4).map(t => (
            <Tappable key={t} onClick={() => { setTags([...tags, t]); setPicking(false); }}>
              <div style={{
                padding: '3px 9px', borderRadius: 999,
                background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)',
                color: fg,
                fontFamily: FONTS.mono, fontSize: 11, fontWeight: 500, letterSpacing: -0.1,
                border: `1px dashed ${accent}66`,
              }}>{t}</div>
            </Tappable>
          ))}
        </React.Fragment>
      )}
      {tags.length > 0 && !picking && (
        <Tappable onClick={() => setPicking(true)}>
          <div style={{
            padding: '3px 8px', borderRadius: 999,
            border: `1px dashed ${dark ? 'rgba(255,255,255,0.2)' : 'rgba(0,0,0,0.15)'}`,
            color: muted,
            fontFamily: FONTS.mono, fontSize: 11, letterSpacing: -0.1,
          }}>+</div>
        </Tappable>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Success overlay (saving → saved)
// ─────────────────────────────────────────────────────────────
function SaveSuccess({ visible, dark, onDone, txn }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;

  useE2(() => {
    if (!visible) return;
    const t = setTimeout(onDone, 1400);
    return () => clearTimeout(t);
  }, [visible, onDone]);

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 200,
      background: dark ? 'rgba(0,0,0,0.6)' : 'rgba(255,255,255,0.85)',
      backdropFilter: 'blur(20px)',
      WebkitBackdropFilter: 'blur(20px)',
      opacity: visible ? 1 : 0,
      pointerEvents: visible ? 'auto' : 'none',
      transition: `opacity .25s ${EASE}`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      flexDirection: 'column', padding: '0 30px',
    }}>
      <div style={{
        transform: visible ? 'scale(1)' : 'scale(0.7)',
        opacity: visible ? 1 : 0,
        transition: `all .4s ${EASE}`,
        marginBottom: 18,
      }}>
        <div style={{
          width: 80, height: 80, borderRadius: 40,
          background: `linear-gradient(135deg, ${accent}, #FF6A00)`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: `0 12px 40px ${accent}60`,
        }}>
          <svg width="42" height="42" viewBox="0 0 24 24" fill="none">
            <path d="M5 12.5l5 5L19 8" stroke="#fff" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </div>
      </div>
      <div style={{
        fontFamily: FONTS.display, fontSize: 24, fontWeight: 700,
        color: fg, letterSpacing: -0.6, marginBottom: 6,
        opacity: visible ? 1 : 0,
        transition: `opacity .3s .15s ${EASE}`,
      }}>已記下</div>
      {txn && (
        <div style={{
          fontFamily: FONTS.mono, fontSize: 14, color: muted, letterSpacing: -0.1,
          opacity: visible ? 1 : 0,
          transition: `opacity .3s .25s ${EASE}`,
          textAlign: 'center',
        }}>
          {txn.type === 'income' ? '+' : '−'}NT$ {(txn.amount || 0).toLocaleString()} · {txn.cat?.label || '未分類'}
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Main: AddTransactionInner (full-page content, no Phone wrapper)
// ─────────────────────────────────────────────────────────────
function AddTransactionInner({ dark, onClose, onSave }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const accent = dark ? COLORS.accentDark : COLORS.accent;

  const [type, setType] = useS2('expense');
  const [amount, setAmount] = useS2('');
  const [cat, setCat] = useS2(null);
  const [account, setAccount] = useS2(ACCOUNTS[0]);
  const [accountTo, setAccountTo] = useS2(ACCOUNTS[1]);
  const [date, setDate] = useS2({ day: 25, label: '今天 · 4/25' });
  const [merchant, setMerchant] = useS2('');
  const [note, setNote] = useS2('');
  const [tags, setTags] = useS2([]);

  const [aiText, setAiText] = useS2('');
  const [aiStatus, setAiStatus] = useS2('idle'); // idle | extracting | filled
  const [showNum, setShowNum] = useS2(true);
  const [sheet, setSheet] = useS2(null); // 'cat' | 'account' | 'accountTo' | 'date' | null
  const [saving, setSaving] = useS2(false);

  const visible = useEnter([dark]);

  const amountColor = type === 'expense' ? (dark ? COLORS.expenseDark : COLORS.expense)
                    : type === 'income' ? (dark ? COLORS.incomeDark : COLORS.income)
                    : '#5E5CE6';

  // Amount evaluation (supports +/-)
  const evalAmount = (s) => {
    if (!s) return 0;
    try {
      const cleaned = s.replace(/[^\d+\-.]/g, '');
      // eslint-disable-next-line no-new-func
      const v = Function(`"use strict"; return (${cleaned || '0'})`)();
      return isNaN(v) ? 0 : v;
    } catch { return 0; }
  };
  const amountValue = evalAmount(amount);

  const runAI = () => {
    if (!aiText.trim()) return;
    setAiStatus('extracting');
    setShowNum(false);
    setTimeout(() => {
      // Mock parse
      const m = aiText.match(/\d+/);
      const amt = m ? m[0] : '';
      const lower = aiText.toLowerCase();
      let pickedCat = CAT_GROUPS[0].items[3]; // coffee default
      let pickedColor = CAT_GROUPS[0].color;
      let pickedGroup = CAT_GROUPS[0].label;
      if (lower.includes('uber') || aiText.includes('車') || aiText.includes('計程')) {
        pickedCat = CAT_GROUPS[1].items[2];
        pickedColor = CAT_GROUPS[1].color;
        pickedGroup = CAT_GROUPS[1].label;
      } else if (aiText.includes('7-11') || aiText.includes('全家') || aiText.includes('便利')) {
        pickedCat = CAT_GROUPS[0].items[5];
        pickedColor = CAT_GROUPS[0].color;
        pickedGroup = CAT_GROUPS[0].label;
      } else if (aiText.includes('書')) {
        pickedCat = CAT_GROUPS[2].items[1];
        pickedColor = CAT_GROUPS[2].color;
        pickedGroup = CAT_GROUPS[2].label;
      } else if (aiText.includes('咖啡') || lower.includes('latte') || lower.includes('coffee') || lower.includes('starbucks') || aiText.includes('星巴克')) {
        pickedCat = CAT_GROUPS[0].items[3];
        pickedColor = CAT_GROUPS[0].color;
        pickedGroup = CAT_GROUPS[0].label;
      }
      let pickedAcc = ACCOUNTS[0];
      if (aiText.includes('悠遊')) pickedAcc = ACCOUNTS[2];
      else if (aiText.includes('玉山') || aiText.includes('銀行')) pickedAcc = ACCOUNTS[1];
      else if (aiText.includes('卡') || lower.includes('visa')) pickedAcc = ACCOUNTS[3];

      setAmount(amt);
      setCat({ ...pickedCat, color: pickedColor, group: pickedGroup });
      setAccount(pickedAcc);
      setMerchant(aiText.split(/\s+/)[0] || '');
      setAiStatus('filled');
    }, 750);
  };

  const clearAI = () => {
    setAiText(''); setAiStatus('idle');
  };

  const canSave = amountValue > 0 && (type === 'transfer' || cat);

  const save = () => {
    if (!canSave) return;
    setSaving(true);
  };

  const onSaveDone = () => {
    onSave && onSave({ type, amount: amountValue, cat, account, date, merchant, note, tags });
    setSaving(false);
    onClose();
  };

  // bg
  const bg = dark
    ? 'radial-gradient(ellipse at 50% -10%, #4A2A0E 0%, #1a0f08 30%, #050505 60%)'
    : 'radial-gradient(ellipse at 50% -10%, #FFE4B8 0%, #FFF6E8 30%, #FAFAF7 60%)';

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: bg,
      display: 'flex', flexDirection: 'column',
      paddingTop: 54, // status bar height
    }}>
      {/* orb */}
      <div style={{ position: 'absolute', inset: 0, zIndex: 0, overflow: 'hidden', pointerEvents: 'none' }}>
        <div style={{
          position: 'absolute', top: -40, right: -60, width: 240, height: 240, borderRadius: '50%',
          background: amountColor, opacity: dark ? 0.20 : 0.22, filter: 'blur(80px)',
          transition: `background .3s ${EASE}`,
        }}/>
      </div>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', position: 'relative', zIndex: 1, overflow: 'hidden' }}>
        {/* Top bar: cancel + title + save */}
        <Reveal visible={visible} delay={50} dir="down" distance={10}>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '0 18px 8px',
          }}>
            <Tappable onClick={onClose}>
              <div style={{
                fontFamily: FONTS.body, fontSize: 15, color: muted, fontWeight: 500, letterSpacing: -0.15,
                padding: '8px 4px',
              }}>取消</div>
            </Tappable>
            <div style={{ fontFamily: FONTS.display, fontSize: 17, fontWeight: 600, color: fg, letterSpacing: -0.3 }}>
              新增交易
            </div>
            <Tappable onClick={save}>
              <div style={{
                fontFamily: FONTS.body, fontSize: 15, fontWeight: 600, letterSpacing: -0.15,
                padding: '8px 4px',
                color: canSave ? accent : muted,
                opacity: canSave ? 1 : 0.5,
              }}>儲存</div>
            </Tappable>
          </div>
        </Reveal>

        {/* Scrollable content */}
        <div style={{ flex: 1, overflow: 'auto', padding: '0 18px' }}>
          {/* Type segmented */}
          <Reveal visible={visible} delay={120} dir="up" distance={12}>
            <div style={{ marginBottom: 14 }}>
              <TypeSegmented value={type} onChange={(v) => { setType(v); setCat(null); }} dark={dark}/>
            </div>
          </Reveal>

          {/* Amount hero */}
          <Reveal visible={visible} delay={180} dir="up" distance={14}>
            <Tappable onClick={() => setShowNum(true)}>
              <Glass dark={dark} radius={22} style={{ padding: '18px 22px', marginBottom: 14 }}>
                <div style={{
                  fontFamily: FONTS.mono, fontSize: 10, color: muted,
                  textTransform: 'uppercase', letterSpacing: 1.2, marginBottom: 6,
                }}>金額</div>
                <div style={{
                  display: 'flex', alignItems: 'baseline', gap: 6,
                  fontFamily: FONTS.mono, fontWeight: 500,
                  color: amount ? amountColor : muted,
                  letterSpacing: -1.5, lineHeight: 1,
                }}>
                  <span style={{ fontSize: 18, fontWeight: 400 }}>NT$</span>
                  <span style={{ fontSize: 44 }}>
                    {type === 'expense' && amount ? '−' : type === 'income' && amount ? '+' : ''}
                    {amount ? amountValue.toLocaleString() : '0'}
                  </span>
                  {showNum && (
                    <span style={{
                      width: 2, height: 36, background: amountColor,
                      animation: 'bDot 1s infinite', marginLeft: 2,
                    }}/>
                  )}
                </div>
                {amount && amount.match(/[+\-]/) && (
                  <div style={{
                    fontFamily: FONTS.mono, fontSize: 11, color: muted,
                    marginTop: 6, letterSpacing: -0.1,
                  }}>= {amount}</div>
                )}
              </Glass>
            </Tappable>
          </Reveal>

          {/* AI extraction */}
          <Reveal visible={visible} delay={240} dir="up" distance={12}>
            <div style={{ marginBottom: 14 }}>
              <AIExtractStrip
                dark={dark}
                status={aiStatus}
                value={aiText}
                setValue={setAiText}
                onRun={runAI}
                onClear={clearAI}
              />
            </div>
          </Reveal>

          {/* Field group */}
          <Reveal visible={visible} delay={300} dir="up" distance={10}>
            <Glass dark={dark} radius={18} style={{ marginBottom: 14, overflow: 'hidden', padding: 0 }}>
              {type !== 'transfer' && (
                <FieldRow label="分類" dark={dark} onTap={() => { setShowNum(false); setSheet('cat'); }}>
                  {cat ? (
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <div style={{
                        width: 26, height: 26, borderRadius: 13,
                        background: cat.color + '30',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        fontSize: 14,
                      }}>{cat.emoji}</div>
                      <div style={{ fontFamily: FONTS.body, fontSize: 14, color: fg, fontWeight: 500, letterSpacing: -0.15 }}>
                        {cat.label}
                      </div>
                      {cat.group && (
                        <div style={{ fontFamily: FONTS.body, fontSize: 12, color: muted, letterSpacing: -0.1 }}>
                          · {cat.group}
                        </div>
                      )}
                    </div>
                  ) : (
                    <div style={{ fontFamily: FONTS.body, fontSize: 14, color: muted, letterSpacing: -0.15 }}>未選</div>
                  )}
                </FieldRow>
              )}
              <FieldRow label={type === 'transfer' ? '從' : '帳戶'} dark={dark} onTap={() => { setShowNum(false); setSheet('account'); }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <div style={{ width: 8, height: 8, borderRadius: 4, background: account.color }}/>
                  <div style={{ fontFamily: FONTS.body, fontSize: 14, color: fg, fontWeight: 500, letterSpacing: -0.15 }}>
                    {account.label}
                  </div>
                  <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: muted, letterSpacing: -0.1 }}>
                    · {account.balance < 0 ? '−' : ''}{Math.abs(account.balance).toLocaleString()}
                  </div>
                </div>
              </FieldRow>
              {type === 'transfer' && (
                <FieldRow label="到" dark={dark} onTap={() => { setShowNum(false); setSheet('accountTo'); }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{ width: 8, height: 8, borderRadius: 4, background: accountTo.color }}/>
                    <div style={{ fontFamily: FONTS.body, fontSize: 14, color: fg, fontWeight: 500, letterSpacing: -0.15 }}>
                      {accountTo.label}
                    </div>
                  </div>
                </FieldRow>
              )}
              <FieldRow label="日期" dark={dark} onTap={() => { setShowNum(false); setSheet('date'); }}>
                <div style={{ fontFamily: FONTS.body, fontSize: 14, color: fg, fontWeight: 500, letterSpacing: -0.15 }}>
                  {date.label}
                </div>
              </FieldRow>
              <FieldRow label="商家" dark={dark}>
                <input
                  value={merchant}
                  onChange={e => setMerchant(e.target.value)}
                  onFocus={() => setShowNum(false)}
                  placeholder="(optional)"
                  style={{
                    border: 'none', outline: 'none', background: 'transparent', flex: 1,
                    fontFamily: FONTS.body, fontSize: 14, color: fg, letterSpacing: -0.15,
                  }}/>
              </FieldRow>
              <FieldRow label="備註" dark={dark}>
                <input
                  value={note}
                  onChange={e => setNote(e.target.value)}
                  onFocus={() => setShowNum(false)}
                  placeholder="(optional)"
                  style={{
                    border: 'none', outline: 'none', background: 'transparent', flex: 1,
                    fontFamily: FONTS.body, fontSize: 14, color: fg, letterSpacing: -0.15,
                  }}/>
              </FieldRow>
              <FieldRow label="標籤" dark={dark} isLast>
                <TagsField tags={tags} setTags={setTags} dark={dark}/>
              </FieldRow>
            </Glass>
          </Reveal>

          {/* Bottom spacer to clear the keypad */}
          <div style={{ height: showNum ? 320 : 80 }}/>
        </div>

        {/* Numeric keypad */}
        <div style={{
          position: 'absolute', left: 0, right: 0, bottom: 0, zIndex: 50,
          transform: showNum ? 'translateY(0)' : 'translateY(110%)',
          transition: `transform .3s ${EASE}`,
        }}>
          <IOSNumPad
            dark={dark}
            onPress={(c) => {
              setAmount(prev => {
                if (c === '.') {
                  if (prev.includes('.') && !/[+\-]/.test(prev.split('.').pop() || '')) return prev;
                }
                return (prev + c);
              });
            }}
            onDelete={() => setAmount(prev => prev.slice(0, -1))}
            onDone={() => setShowNum(false)}
          />
        </div>

        {/* Sheets */}
        <CategorySheet
          open={sheet === 'cat'}
          onClose={() => setSheet(null)}
          dark={dark}
          type={type}
          current={cat}
          onPick={(c) => { setCat(c); setSheet(null); }}
        />
        <AccountSheet
          open={sheet === 'account'}
          onClose={() => setSheet(null)}
          dark={dark}
          current={account}
          label={type === 'transfer' ? '從哪個帳戶' : '選擇帳戶'}
          onPick={(a) => { setAccount(a); setSheet(null); }}
        />
        <AccountSheet
          open={sheet === 'accountTo'}
          onClose={() => setSheet(null)}
          dark={dark}
          current={accountTo}
          label="到哪個帳戶"
          onPick={(a) => { setAccountTo(a); setSheet(null); }}
        />
        <DateSheet
          open={sheet === 'date'}
          onClose={() => setSheet(null)}
          dark={dark}
          value={date}
          onPick={(d) => { setDate(d); setSheet(null); }}
        />

        <SaveSuccess
          visible={saving}
          dark={dark}
          onDone={onSaveDone}
          txn={{ type, amount: amountValue, cat }}
        />
      </div>
    </div>
  );
}

// Standalone artboard wrapper: full Phone shell
function AddTransactionFull({ dark, onClose, onSave }) {
  const bg = dark
    ? 'radial-gradient(ellipse at 50% -10%, #4A2A0E 0%, #1a0f08 30%, #050505 60%)'
    : 'radial-gradient(ellipse at 50% -10%, #FFE4B8 0%, #FFF6E8 30%, #FAFAF7 60%)';
  return (
    <Phone dark={dark} bg={bg}>
      <AddTransactionInner
        dark={dark}
        onClose={onClose || (() => {})}
        onSave={onSave}
      />
    </Phone>
  );
}

// Overlay slide-up version (sits inside an existing Phone shell)
function AddTransactionOverlay({ open, dark, onClose, onSave }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 100,
      transform: open ? 'translateY(0)' : 'translateY(100%)',
      transition: `transform .35s ${EASE}`,
      pointerEvents: open ? 'auto' : 'none',
      borderRadius: open ? 0 : 32,
      overflow: 'hidden',
    }}>
      <AddTransactionInner dark={dark} onClose={onClose} onSave={onSave}/>
    </div>
  );
}

Object.assign(window, { AddTransactionFull, AddTransactionInner, AddTransactionOverlay });
