// NeuLedger — Notification Settings sub-page
// Maps to NotificationSettingsFeature / NotificationSettingsView (drakehuang81/NeuLedger)
//
// Sections (per Swift):
//   • Permission denied banner (conditional)
//   • Daily reminder · toggle + time picker (hour/minute)
//   • Budget warning  · toggle + threshold picker (50/60/70/80/90 %)
//   • Recurring section · list w/ per-item toggle + add row
//
// 2 artboards:
//   01 · 全部開啟      — 預設快樂路徑
//   02 · 權限被拒絕     — 橘色 banner · 全部 toggle 關閉

// ─── L10n keys (mirroring code) ──────────────────────────────
const NL = {
  title: '通知',
  permissionBanner: '通知權限已關閉。前往「設定」開啟後,提醒才能送達。',
  openSettings: '前往設定',
  dailyHeader: '每日記帳提醒',
  dailyToggle: '每日提醒',
  dailyTime: '提醒時間',
  dailyDesc: '在你設定的時間提示記下今日支出,不漏記。',
  budgetHeader: '預算警示',
  budgetToggle: '接近預算上限時通知',
  budgetThreshold: '警示閾值',
  budgetDesc: '當分類預算達到設定百分比時收到提醒。',
  recurringHeader: '週期交易提醒',
  recurringDesc: '在週期交易到期前一天提醒你確認金額。可在此切換是否啟用,點擊項目可編輯。',
  recurringAdd: '新增週期提醒',
};

// ─── Tiny components ─────────────────────────────────────────
function NavBar2({ dark, title }) {
  const muted = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  return (
    <div style={{ padding: '6px 8px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <button style={{ background: 'transparent', border: 'none', display: 'flex', alignItems: 'center', gap: 2, color: ACC_COLORS.warm, padding: '6px 8px', cursor: 'pointer' }}>
        <AccGlyph name="chevron-left" size={20} color={ACC_COLORS.warm} stroke={2.2}/>
        <span style={{ fontSize: 16, fontFamily: ACC_FONTS.body }}>設定</span>
      </button>
      <div style={{ fontSize: 12, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>{title}</div>
      <div style={{ width: 52 }}/>
    </div>
  );
}

function LargeTitle2({ dark, children, subtitle }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  return (
    <div style={{ padding: '4px 20px 14px' }}>
      <div style={{ fontFamily: ACC_FONTS.display, fontSize: 34, fontWeight: 600, letterSpacing: -0.8, color: fg, lineHeight: 1.1 }}>{children}</div>
      {subtitle && <div style={{ marginTop: 6, fontSize: 13, color: muted, lineHeight: 1.45 }}>{subtitle}</div>}
    </div>
  );
}

function SectionHeader({ dark, children, eyebrow }) {
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  return (
    <div style={{ padding: '0 6px 8px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
      <div style={{ fontSize: 11.5, fontFamily: ACC_FONTS.mono, color: muted, letterSpacing: 1.2, textTransform: 'uppercase' }}>{children}</div>
      {eyebrow && <div style={{ fontSize: 11, fontFamily: ACC_FONTS.mono, color: muted, letterSpacing: 0.6 }}>{eyebrow}</div>}
    </div>
  );
}

function Toggle({ on, dark }) {
  return (
    <div style={{
      width: 51, height: 31, borderRadius: 16,
      background: on ? ACC_COLORS.income : (dark ? 'rgba(120,120,128,0.4)' : 'rgba(120,120,128,0.24)'),
      position: 'relative', transition: 'background 200ms', flexShrink: 0,
    }}>
      <div style={{
        position: 'absolute', top: 2, left: on ? 22 : 2,
        width: 27, height: 27, borderRadius: 14,
        background: '#fff',
        boxShadow: '0 3px 8px rgba(0,0,0,0.15), 0 1px 1px rgba(0,0,0,0.06)',
        transition: 'left 200ms',
      }}/>
    </div>
  );
}

function Row({ label, trailing, dark, divider, sub }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  return (
    <div>
      <div style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12, minHeight: 48 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 16, color: fg, letterSpacing: -0.1 }}>{label}</div>
          {sub && <div style={{ fontSize: 12, color: muted, marginTop: 2 }}>{sub}</div>}
        </div>
        <div style={{ flexShrink: 0 }}>{trailing}</div>
      </div>
      {divider && <div style={{ height: 0.5, marginLeft: 16, marginRight: 0, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(60,60,67,0.12)' }}/>}
    </div>
  );
}

// iOS DatePicker compact pill (HH:MM bg-tinted pill)
function TimePill({ hour, minute, dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 4,
      padding: '7px 11px', borderRadius: 8,
      background: dark ? 'rgba(120,120,128,0.24)' : 'rgba(120,120,128,0.16)',
      fontFamily: ACC_FONTS.body, fontSize: 17, fontWeight: 400,
      color: fg, fontVariantNumeric: 'tabular-nums', letterSpacing: -0.2,
    }}>
      <span>{String(hour).padStart(2, '0')}</span>
      <span style={{ opacity: 0.6 }}>:</span>
      <span>{String(minute).padStart(2, '0')}</span>
    </div>
  );
}

// iOS Picker trailing — chevrons compact menu trigger
function MenuValue({ value, dark }) {
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  return (
    <div style={{ display: 'inline-flex', alignItems: 'center', gap: 2, color: muted, fontSize: 16 }}>
      <span style={{ fontFamily: ACC_FONTS.mono, fontVariantNumeric: 'tabular-nums', fontWeight: 500 }}>{value}</span>
      <svg width="12" height="20" viewBox="0 0 12 20" fill="none" stroke={muted} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" style={{ marginLeft: 2 }}>
        <path d="M3.5 8L6 5.5L8.5 8"/>
        <path d="M3.5 12L6 14.5L8.5 12"/>
      </svg>
    </div>
  );
}

// Threshold "preview" mini-meter — visual confirmation of % choice
function ThresholdMeter({ value, dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const choices = [50, 60, 70, 80, 90];
  return (
    <div style={{ padding: '14px 16px' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
        <div style={{ fontSize: 12, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 0.5, textTransform: 'uppercase' }}>選擇閾值</div>
        <div style={{ fontFamily: ACC_FONTS.mono, fontSize: 13, color: muted }}>達 <span style={{ color: ACC_COLORS.warm, fontWeight: 600 }}>{value}%</span> 時通知</div>
      </div>
      <div style={{ display: 'flex', gap: 6 }}>
        {choices.map(c => {
          const selected = c === value;
          return (
            <div key={c} style={{
              flex: 1, padding: '10px 0',
              borderRadius: 10,
              background: selected
                ? `linear-gradient(180deg, ${ACC_COLORS.warm} 0%, ${ACC_COLORS.warmDark} 100%)`
                : (dark ? 'rgba(255,255,255,0.05)' : 'rgba(255,255,255,0.55)'),
              border: selected ? 'none' : `0.5px solid ${dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)'}`,
              textAlign: 'center',
              fontFamily: ACC_FONTS.mono,
              fontSize: 14, fontWeight: 500,
              color: selected ? '#fff' : fg,
              boxShadow: selected ? `0 4px 12px ${ACC_COLORS.warm}40` : 'none',
              letterSpacing: -0.2,
            }}>{c}%</div>
          );
        })}
      </div>
    </div>
  );
}

// Recurring item row inside the recurring section
function RecurringNotifRow({ item, dark, divider }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  return (
    <div>
      <div style={{ padding: '12px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{
          width: 36, height: 36, borderRadius: 10, flexShrink: 0,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          background: `${item.accent}1E`,
          color: item.accent,
        }}>
          <AccGlyph name={item.icon} size={18} color={item.accent} stroke={1.8}/>
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 15, color: fg, letterSpacing: -0.1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{item.note}</div>
          <div style={{ marginTop: 2, fontSize: 12, color: muted, fontFamily: ACC_FONTS.mono, fontVariantNumeric: 'tabular-nums' }}>
            NT${item.amount.toLocaleString('en-US')} <span style={{ opacity: 0.6 }}>·</span> 每{item.frequency === 'monthly' ? '月' : item.frequency === 'yearly' ? '年' : '週'} <span style={{ opacity: 0.6 }}>·</span> {item.nextDue}
          </div>
        </div>
        <Toggle on={item.isActive} dark={dark}/>
      </div>
      {divider && <div style={{ height: 0.5, marginLeft: 64, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(60,60,67,0.10)' }}/>}
    </div>
  );
}

function AddRow({ dark, divider }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  return (
    <div>
      {divider && <div style={{ height: 0.5, marginLeft: 16, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(60,60,67,0.10)' }}/>}
      <div style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ color: ACC_COLORS.warm, display: 'flex' }}>
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none">
            <circle cx="12" cy="12" r="10" fill={ACC_COLORS.warm}/>
            <path d="M12 8v8M8 12h8" stroke="#fff" strokeWidth="2" strokeLinecap="round"/>
          </svg>
        </div>
        <div style={{ fontSize: 16, color: fg, letterSpacing: -0.1 }}>{NL.recurringAdd}</div>
      </div>
    </div>
  );
}

// Permission denied banner
function PermissionBanner({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.7)' : 'rgba(60,60,67,0.7)';
  const orange = ACC_COLORS.warm;
  return (
    <AccGlass dark={dark} radius={14} style={{ padding: 14, marginBottom: 18, borderTop: `0.5px solid ${orange}55`, borderLeft: `0.5px solid ${orange}55`, background: dark ? `linear-gradient(180deg, ${orange}1F 0%, rgba(255,255,255,0.04) 100%)` : `linear-gradient(180deg, ${orange}1A 0%, rgba(255,255,255,0.7) 100%)` }}>
      <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
        <div style={{
          width: 34, height: 34, borderRadius: 10, flexShrink: 0,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          background: `${orange}26`,
          color: orange,
        }}>
          {/* bell-slash icon */}
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={orange} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
            <path d="M6 8a6 6 0 0112 0c0 2 0 5 2 7H4c1-1 1.4-2.5 1.7-4"/>
            <path d="M10 21a2 2 0 004 0"/>
            <path d="M3 3l18 18"/>
          </svg>
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: fg, letterSpacing: -0.1 }}>通知權限已關閉</div>
          <div style={{ marginTop: 2, fontSize: 12.5, color: muted, lineHeight: 1.5 }}>{NL.permissionBanner}</div>
          <button style={{
            marginTop: 10, padding: '7px 12px', borderRadius: 8, border: 'none',
            background: orange, color: '#fff',
            fontFamily: ACC_FONTS.body, fontSize: 13, fontWeight: 600, cursor: 'pointer',
            display: 'inline-flex', alignItems: 'center', gap: 4,
            boxShadow: `0 3px 8px ${orange}40`,
          }}>
            {NL.openSettings}
            <AccGlyph name="arrow-up-right" size={12} color="#fff" stroke={2.2}/>
          </button>
        </div>
      </div>
    </AccGlass>
  );
}

// ═══════════════════════════════════════════════════════════
// 01 · Default · all enabled
// ═══════════════════════════════════════════════════════════
const NOTIF_RECURRINGS = [
  { id: 'r1', note: '房租',      amount: 22000, frequency: 'monthly', nextDue: '6/5 到期',  isActive: true,  accent: '#0A84FF', icon: 'bank' },
  { id: 'r2', note: 'Netflix Premium', amount: 390, frequency: 'monthly', nextDue: '5/15 到期',  isActive: true,  accent: '#FF453A', icon: 'phone' },
  { id: 'r3', note: '健身房 World Gym', amount: 1290, frequency: 'monthly', nextDue: '6/1 到期', isActive: true, accent: '#E8835A', icon: 'arrow-up-right' },
  { id: 'r4', note: '蘋果日報訂閱', amount: 168, frequency: 'monthly', nextDue: '提醒已暫停', isActive: false, accent: '#8B6F47', icon: 'phone' },
];

function NotifSettingsActive({ dark }) {
  return (
    <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <NavBar2 dark={dark} title="Notifications"/>
      <LargeTitle2 dark={dark}>{NL.title}</LargeTitle2>
      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 100px' }}>

        {/* Daily reminder */}
        <SectionHeader dark={dark}>{NL.dailyHeader}</SectionHeader>
        <AccGlass dark={dark} radius={16} style={{ padding: 0, overflow: 'hidden', marginBottom: 8 }}>
          <Row dark={dark} divider label={NL.dailyToggle} trailing={<Toggle on={true} dark={dark}/>}/>
          <Row dark={dark} label={NL.dailyTime} trailing={<TimePill hour={21} minute={0} dark={dark}/>}/>
        </AccGlass>
        <div style={{ padding: '0 6px 22px', fontSize: 12, color: dark ? 'rgba(235,235,245,0.5)' : 'rgba(60,60,67,0.5)', lineHeight: 1.45 }}>{NL.dailyDesc}</div>

        {/* Budget warning */}
        <SectionHeader dark={dark}>{NL.budgetHeader}</SectionHeader>
        <AccGlass dark={dark} radius={16} style={{ padding: 0, overflow: 'hidden', marginBottom: 8 }}>
          <Row dark={dark} divider label={NL.budgetToggle} trailing={<Toggle on={true} dark={dark}/>}/>
          <ThresholdMeter value={80} dark={dark}/>
        </AccGlass>
        <div style={{ padding: '0 6px 22px', fontSize: 12, color: dark ? 'rgba(235,235,245,0.5)' : 'rgba(60,60,67,0.5)', lineHeight: 1.45 }}>{NL.budgetDesc}</div>

        {/* Recurring */}
        <SectionHeader dark={dark} eyebrow={`${NOTIF_RECURRINGS.filter(r => r.isActive).length} / ${NOTIF_RECURRINGS.length} 開啟`}>{NL.recurringHeader}</SectionHeader>
        <div style={{ padding: '0 6px 8px', fontSize: 12, color: dark ? 'rgba(235,235,245,0.5)' : 'rgba(60,60,67,0.5)', lineHeight: 1.45 }}>{NL.recurringDesc}</div>
        <AccGlass dark={dark} radius={16} style={{ padding: 0, overflow: 'hidden' }}>
          {NOTIF_RECURRINGS.map((item, i) => (
            <RecurringNotifRow key={item.id} item={item} dark={dark} divider={i < NOTIF_RECURRINGS.length}/>
          ))}
          <AddRow dark={dark}/>
        </AccGlass>

      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 02 · Permission denied
// ═══════════════════════════════════════════════════════════
function NotifSettingsDenied({ dark }) {
  return (
    <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <NavBar2 dark={dark} title="Notifications · Off"/>
      <LargeTitle2 dark={dark}>{NL.title}</LargeTitle2>
      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 100px' }}>

        <PermissionBanner dark={dark}/>

        {/* Daily reminder (off) */}
        <SectionHeader dark={dark}>{NL.dailyHeader}</SectionHeader>
        <AccGlass dark={dark} radius={16} style={{ padding: 0, overflow: 'hidden', marginBottom: 8 }}>
          <Row dark={dark} label={NL.dailyToggle} trailing={<Toggle on={false} dark={dark}/>}/>
        </AccGlass>
        <div style={{ padding: '0 6px 22px', fontSize: 12, color: dark ? 'rgba(235,235,245,0.5)' : 'rgba(60,60,67,0.5)', lineHeight: 1.45 }}>{NL.dailyDesc}</div>

        {/* Budget warning (off) */}
        <SectionHeader dark={dark}>{NL.budgetHeader}</SectionHeader>
        <AccGlass dark={dark} radius={16} style={{ padding: 0, overflow: 'hidden', marginBottom: 8 }}>
          <Row dark={dark} label={NL.budgetToggle} trailing={<Toggle on={false} dark={dark}/>}/>
        </AccGlass>
        <div style={{ padding: '0 6px 22px', fontSize: 12, color: dark ? 'rgba(235,235,245,0.5)' : 'rgba(60,60,67,0.5)', lineHeight: 1.45 }}>{NL.budgetDesc}</div>

        {/* Recurring — empty add row only */}
        <SectionHeader dark={dark}>{NL.recurringHeader}</SectionHeader>
        <div style={{ padding: '0 6px 8px', fontSize: 12, color: dark ? 'rgba(235,235,245,0.5)' : 'rgba(60,60,67,0.5)', lineHeight: 1.45 }}>{NL.recurringDesc}</div>
        <AccGlass dark={dark} radius={16} style={{ padding: 0, overflow: 'hidden' }}>
          <AddRow dark={dark}/>
        </AccGlass>

      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// Canvas
// ═══════════════════════════════════════════════════════════
function NotifSettingsCanvas() {
  const dark = false;
  const muted = 'rgba(60,60,67,0.55)';
  const screens = [
    { id: 'active', label: '01 / Notifications · All On',     desc: '預設快樂路徑 · 每日 21:00 提醒 · 預算 80% · 週期清單', Comp: NotifSettingsActive },
    { id: 'denied', label: '02 / Permission Denied',          desc: 'showPermissionDeniedBanner = true · 橘色 banner · 全部 off', Comp: NotifSettingsDenied },
  ];
  return (
    <div style={{ minHeight: '100vh', background: '#ECE9E2', padding: '40px 24px 80px', fontFamily: ACC_FONTS.body }}>
      <div style={{ maxWidth: 1280, margin: '0 auto 32px' }}>
        <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.4, textTransform: 'uppercase' }}>NeuLedger · Settings › Notifications</div>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 40, fontWeight: 600, letterSpacing: -1, marginTop: 4 }}>通知偏好設定</div>
        <div style={{ fontSize: 14, color: muted, marginTop: 6, maxWidth: 720, lineHeight: 1.55 }}>
          對應 <code style={{ fontFamily: ACC_FONTS.mono, fontSize: 13 }}>NotificationSettingsFeature</code>。
          三大區塊 — <strong>Daily Reminder</strong>(toggle + 時間)、<strong>Budget Warning</strong>(toggle + 50/60/70/80/90% 閾值)、<strong>Recurring</strong>(每筆 toggle + add)。
          當權限被系統拒絕,最上面會出現橘色 banner。
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

ReactDOM.createRoot(document.getElementById('root')).render(<NotifSettingsCanvas/>);
