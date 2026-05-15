// NeuLedger — Add / Edit Account Form
// Maps to AddEditAccountFeature / AddEditAccountView (drakehuang81/NeuLedger)
//
// Form sections (per Swift):
//   • Name (TextField + optional nameError)
//   • Type (Picker .menu — AccountType.allCases)
//   • Icon (IconPickerRow — DesignConstants.accountIconOptions)
//   • Color (ColorSwatchPicker — DesignConstants.accountColorOptions)
//   • Preview (circle w/ icon + name)
// Toolbar: Cancel · Save
// Title: add → "新增帳戶" · edit → "編輯帳戶"
//
// 3 artboards:
//   01 · Add · defaults (cash / creditcard / blue / empty name → Save disabled)
//   02 · Add · filled  (name + custom type/icon/color, preview live)
//   03 · Edit · name conflict error (red text under name)

// ─── L10n keys ───────────────────────────────────────────────
const FL = {
  cancel: '取消',
  save: '儲存',
  addTitle: '新增帳戶',
  editTitle: '編輯帳戶',
  name: '名稱',
  namePlaceholder: '輸入帳戶名稱',
  type: '類型',
  icon: '圖示',
  color: '顏色',
  preview: '預覽',
  errorEmpty: '請輸入帳戶名稱',
  errorTaken: '此名稱已被使用,請換一個',
};

// AccountType.allCases — 6 types
const ACCOUNT_TYPES = [
  { id: 'cash',    label: '現金',     glyph: 'cash'   },
  { id: 'bank',    label: '銀行帳戶', glyph: 'bank'   },
  { id: 'credit',  label: '信用卡',   glyph: 'card'   },
  { id: 'digital', label: '電子支付', glyph: 'phone'  },
  { id: 'invest',  label: '投資',     glyph: 'invest' },
  { id: 'crypto',  label: '加密貨幣', glyph: 'crypto' },
];

// DesignConstants.accountIconOptions — emulated (we render via AccGlyph)
const ICON_OPTIONS = [
  'cash', 'bank', 'card', 'phone',
  'invest', 'crypto', 'star', 'archive',
  'arrow-up-right', 'arrow-down-left', 'sparkle', 'plus',
];

// DesignConstants.accountColorOptions
const COLOR_OPTIONS = [
  '#3478F6', // default blue
  '#1B5E8E', '#0A84FF', '#5E5CE6', '#A66BF0',
  '#34C759', '#30D158', '#FF9500', '#FF6A00',
  '#E8835A', '#FF453A', '#FF6B6B',
  '#7B3F00', '#9B7E5F', '#000000',
];

// ─── Small atoms ─────────────────────────────────────────────
function FormNavBar({ dark, title, canSave }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const accent = ACC_COLORS.warm;
  const disabled = !canSave;
  return (
    <div style={{
      padding: '8px 16px 10px',
      display: 'grid', gridTemplateColumns: '1fr auto 1fr', alignItems: 'center',
      borderBottom: `0.5px solid ${dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.06)'}`,
    }}>
      <button style={{ background: 'transparent', border: 'none', padding: '4px 0', justifySelf: 'start', color: accent, fontSize: 16, fontFamily: ACC_FONTS.body, cursor: 'pointer' }}>{FL.cancel}</button>
      <div style={{ fontSize: 17, fontWeight: 600, color: fg, letterSpacing: -0.2, fontFamily: ACC_FONTS.display }}>{title}</div>
      <button disabled={disabled} style={{
        background: 'transparent', border: 'none', padding: '4px 0', justifySelf: 'end',
        color: disabled ? (dark ? 'rgba(235,235,245,0.3)' : 'rgba(60,60,67,0.3)') : accent,
        fontSize: 16, fontWeight: 600, fontFamily: ACC_FONTS.body, cursor: disabled ? 'not-allowed' : 'pointer',
      }}>{FL.save}</button>
    </div>
  );
}

function FormSectionHeader({ dark, children }) {
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  return (
    <div style={{ padding: '0 6px 8px', fontSize: 11, fontFamily: ACC_FONTS.mono, color: muted, letterSpacing: 1.2, textTransform: 'uppercase' }}>{children}</div>
  );
}

// Inline field (label + value side-by-side, iOS Form style)
function FormFieldRow({ dark, children, divider }) {
  return (
    <div>
      <div style={{ padding: '14px 16px', minHeight: 48, display: 'flex', alignItems: 'center', gap: 12 }}>{children}</div>
      {divider && <div style={{ height: 0.5, marginLeft: 16, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(60,60,67,0.12)' }}/>}
    </div>
  );
}

function TextInputRow({ dark, placeholder, value, error, focused }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.45)' : 'rgba(60,60,67,0.45)';
  const isEmpty = !value;
  return (
    <div style={{ padding: '12px 16px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <div style={{ flex: 1, fontSize: 17, color: isEmpty ? muted : fg, fontFamily: ACC_FONTS.body, letterSpacing: -0.2, lineHeight: 1.3, position: 'relative' }}>
          {isEmpty ? placeholder : value}
          {focused && (
            <span style={{
              display: 'inline-block', width: 2, height: 20, background: ACC_COLORS.warm,
              verticalAlign: 'middle', marginLeft: 2, animation: 'caret 1s infinite',
            }}/>
          )}
        </div>
        {!isEmpty && (
          <button style={{ background: dark ? 'rgba(120,120,128,0.5)' : 'rgba(120,120,128,0.3)', border: 'none', borderRadius: 99, width: 20, height: 20, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', color: '#fff' }}>
            <AccGlyph name="close" size={11} color={dark ? '#0A0A0A' : '#fff'} stroke={2.5}/>
          </button>
        )}
      </div>
      {error && (
        <div style={{ marginTop: 8, display: 'flex', alignItems: 'flex-start', gap: 6 }}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={ACC_COLORS.expense} strokeWidth="2" strokeLinecap="round" style={{ marginTop: 1 }}>
            <circle cx="12" cy="12" r="9"/>
            <path d="M12 7v6M12 16v0"/>
          </svg>
          <div style={{ fontSize: 12.5, color: ACC_COLORS.expense, lineHeight: 1.4, letterSpacing: -0.1 }}>{error}</div>
        </div>
      )}
    </div>
  );
}

function TypeMenuRow({ dark, type }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  return (
    <div style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
      <div style={{ flex: 1, fontSize: 16, color: fg, letterSpacing: -0.1 }}>{FL.type}</div>
      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: muted, fontSize: 16 }}>
        <span style={{ color: fg }}>{type.label}</span>
        <svg width="12" height="20" viewBox="0 0 12 20" fill="none" stroke={muted} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" style={{ marginLeft: 2 }}>
          <path d="M3.5 8L6 5.5L8.5 8"/>
          <path d="M3.5 12L6 14.5L8.5 12"/>
        </svg>
      </div>
    </div>
  );
}

function IconGrid({ dark, selectedIcon, accentColor }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  return (
    <div style={{ padding: '12px 12px 14px', display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 8 }}>
      {ICON_OPTIONS.map(icon => {
        const selected = icon === selectedIcon;
        return (
          <div key={icon} style={{
            aspectRatio: '1 / 1',
            borderRadius: 12,
            background: selected ? `${accentColor}1F` : (dark ? 'rgba(255,255,255,0.05)' : 'rgba(255,255,255,0.55)'),
            border: selected ? `1.5px solid ${accentColor}` : `0.5px solid ${dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)'}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer',
            transition: 'all 150ms',
          }}>
            <AccGlyph name={icon} size={20} color={selected ? accentColor : (dark ? 'rgba(235,235,245,0.7)' : 'rgba(60,60,67,0.7)')} stroke={1.8}/>
          </div>
        );
      })}
    </div>
  );
}

function ColorSwatchPicker({ dark, selectedHex }) {
  return (
    <div style={{ padding: '12px', display: 'grid', gridTemplateColumns: 'repeat(8, 1fr)', gap: 8 }}>
      {COLOR_OPTIONS.map(c => {
        const selected = c === selectedHex;
        return (
          <div key={c} style={{
            aspectRatio: '1 / 1', borderRadius: '50%', background: c,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer',
            boxShadow: selected
              ? `0 0 0 2px ${dark ? '#0A0A0A' : '#FAF7F2'}, 0 0 0 4px ${c}`
              : `0 0 0 0.5px ${dark ? 'rgba(255,255,255,0.15)' : 'rgba(0,0,0,0.08)'}`,
          }}>
            {selected && <AccGlyph name="check" size={14} color="#fff" stroke={3}/>}
          </div>
        );
      })}
    </div>
  );
}

function PreviewRow({ dark, name, icon, colorHex }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.45)' : 'rgba(60,60,67,0.45)';
  const isEmpty = !name;
  return (
    <div style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 14 }}>
      <div style={{
        width: 48, height: 48, borderRadius: 24,
        background: `${colorHex}26`,
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
      }}>
        <AccGlyph name={icon} size={22} color={colorHex} stroke={1.8}/>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 17, color: isEmpty ? muted : fg, letterSpacing: -0.2, fontFamily: ACC_FONTS.body, fontWeight: 500 }}>
          {isEmpty ? FL.namePlaceholder : name}
        </div>
        <div style={{ marginTop: 2, fontSize: 12, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 0.4, textTransform: 'uppercase' }}>
          當前外觀
        </div>
      </div>
      {!isEmpty && (
        <div style={{ fontSize: 11, color: ACC_COLORS.income, fontFamily: ACC_FONTS.mono, display: 'flex', alignItems: 'center', gap: 4 }}>
          <span style={{ width: 5, height: 5, borderRadius: 3, background: ACC_COLORS.income, boxShadow: `0 0 6px ${ACC_COLORS.income}` }}/>
          LIVE
        </div>
      )}
    </div>
  );
}

// ─── Form section wrapper ────────────────────────────────────
function FormSection({ dark, header, footer, children }) {
  return (
    <div style={{ marginBottom: 22 }}>
      {header && <FormSectionHeader dark={dark}>{header}</FormSectionHeader>}
      <AccGlass dark={dark} radius={14} style={{ padding: 0, overflow: 'hidden' }}>
        {children}
      </AccGlass>
      {footer && (
        <div style={{ padding: '8px 6px 0', fontSize: 12, color: dark ? 'rgba(235,235,245,0.5)' : 'rgba(60,60,67,0.5)', lineHeight: 1.45 }}>{footer}</div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 01 · Add · defaults
// ═══════════════════════════════════════════════════════════
function AddAccountDefault({ dark }) {
  const state = {
    name: '', error: null,
    type: ACCOUNT_TYPES[0], // cash
    icon: 'card',           // "creditcard" maps to card
    colorHex: '#3478F6',
  };
  return (
    <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <FormNavBar dark={dark} title={FL.addTitle} canSave={false}/>
      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 16px 100px' }}>
        <FormSection dark={dark} header={FL.name}>
          <TextInputRow dark={dark} placeholder={FL.namePlaceholder} value="" focused/>
        </FormSection>

        <FormSection dark={dark} header={FL.type}>
          <TypeMenuRow dark={dark} type={state.type}/>
        </FormSection>

        <FormSection dark={dark} header={FL.icon}>
          <IconGrid dark={dark} selectedIcon={state.icon} accentColor={state.colorHex}/>
        </FormSection>

        <FormSection dark={dark} header={FL.color}>
          <ColorSwatchPicker dark={dark} selectedHex={state.colorHex}/>
        </FormSection>

        <FormSection dark={dark} header={FL.preview}>
          <PreviewRow dark={dark} name="" icon={state.icon} colorHex={state.colorHex}/>
        </FormSection>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 02 · Add · filled
// ═══════════════════════════════════════════════════════════
function AddAccountFilled({ dark }) {
  const state = {
    name: '永豐銀行 主帳戶',
    type: ACCOUNT_TYPES[1], // bank
    icon: 'bank',
    colorHex: '#30D158',
  };
  return (
    <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <FormNavBar dark={dark} title={FL.addTitle} canSave={true}/>
      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 16px 100px' }}>
        <FormSection dark={dark} header={FL.name}>
          <TextInputRow dark={dark} placeholder={FL.namePlaceholder} value={state.name}/>
        </FormSection>

        <FormSection dark={dark} header={FL.type}>
          <TypeMenuRow dark={dark} type={state.type}/>
        </FormSection>

        <FormSection dark={dark} header={FL.icon}>
          <IconGrid dark={dark} selectedIcon={state.icon} accentColor={state.colorHex}/>
        </FormSection>

        <FormSection dark={dark} header={FL.color}>
          <ColorSwatchPicker dark={dark} selectedHex={state.colorHex}/>
        </FormSection>

        <FormSection dark={dark} header={FL.preview}>
          <PreviewRow dark={dark} name={state.name} icon={state.icon} colorHex={state.colorHex}/>
        </FormSection>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 03 · Edit · name conflict error
// ═══════════════════════════════════════════════════════════
function EditAccountError({ dark }) {
  const state = {
    name: '玉山 Pi',  // already exists
    error: FL.errorTaken,
    type: ACCOUNT_TYPES[2], // credit
    icon: 'card',
    colorHex: '#7B3F00',
  };
  return (
    <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <FormNavBar dark={dark} title={FL.editTitle} canSave={true}/>
      <div style={{ flex: 1, overflowY: 'auto', padding: '20px 16px 100px' }}>
        <FormSection dark={dark} header={FL.name}>
          <TextInputRow dark={dark} placeholder={FL.namePlaceholder} value={state.name} error={state.error}/>
        </FormSection>

        <FormSection dark={dark} header={FL.type}>
          <TypeMenuRow dark={dark} type={state.type}/>
        </FormSection>

        <FormSection dark={dark} header={FL.icon}>
          <IconGrid dark={dark} selectedIcon={state.icon} accentColor={state.colorHex}/>
        </FormSection>

        <FormSection dark={dark} header={FL.color}>
          <ColorSwatchPicker dark={dark} selectedHex={state.colorHex}/>
        </FormSection>

        <FormSection dark={dark} header={FL.preview}>
          <PreviewRow dark={dark} name={state.name} icon={state.icon} colorHex={state.colorHex}/>
        </FormSection>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// Canvas
// ═══════════════════════════════════════════════════════════
function AddEditAccountCanvas() {
  const dark = false;
  const muted = 'rgba(60,60,67,0.55)';
  const screens = [
    { id: 'add',     label: '01 / Add · Defaults',         desc: 'mode = .add · 名稱空白 · Save disabled · 預覽顯示 placeholder', Comp: AddAccountDefault },
    { id: 'filled',  label: '02 / Add · Filled',           desc: '使用者填寫完成 · 預覽即時反映 · LIVE 指示',                       Comp: AddAccountFilled },
    { id: 'error',   label: '03 / Edit · Name taken',      desc: 'mode = .edit(account) · nameError 顯示 · 紅色 inline 訊息',     Comp: EditAccountError },
  ];
  return (
    <div style={{ minHeight: '100vh', background: '#ECE9E2', padding: '40px 24px 80px', fontFamily: ACC_FONTS.body }}>
      <style>{`@keyframes caret { 0%, 50% { opacity: 1 } 51%, 100% { opacity: 0 } }`}</style>
      <div style={{ maxWidth: 1280, margin: '0 auto 32px' }}>
        <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.4, textTransform: 'uppercase' }}>NeuLedger · Accounts › Add / Edit</div>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 40, fontWeight: 600, letterSpacing: -1, marginTop: 4 }}>新增 / 編輯帳戶</div>
        <div style={{ fontSize: 14, color: muted, marginTop: 6, maxWidth: 720, lineHeight: 1.55 }}>
          對應 <code style={{ fontFamily: ACC_FONTS.mono, fontSize: 13 }}>AddEditAccountFeature</code> · <code style={{ fontFamily: ACC_FONTS.mono, fontSize: 13 }}>AddEditAccountView</code>。
          5 個 Form section — Name(TextField + 錯誤訊息)、Type(Menu Picker)、Icon(12 圖示 grid)、Color(15 swatches)、Preview(即時)。Save 按鈕在名稱為空時 disabled。
        </div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, max-content)', gap: '40px 28px', justifyContent: 'center' }}>
        {screens.map(s => (
          <div key={s.id} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 402, textAlign: 'left' }}>
              <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.2, textTransform: 'uppercase' }}>{s.label}</div>
              <div style={{ fontFamily: ACC_FONTS.display, fontSize: 17, fontWeight: 600, letterSpacing: -0.3, marginTop: 2 }}>{s.desc}</div>
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

ReactDOM.createRoot(document.getElementById('root')).render(<AddEditAccountCanvas/>);
