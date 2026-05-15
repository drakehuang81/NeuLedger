// NeuLedger — iCloud Sync Settings sub-page
// Maps to SyncSettingsFeature / SyncSettingsView (drakehuang81/NeuLedger)
// State combinations:
//   01 · Off (idle, CloudKit available)      — hero enable card
//   02 · Migrating (progress 0..1)           — progress bar + %
//   03 · Off · iCloud unavailable            — red warning + disabled button
//   04 · Enabled                              — connected status rows
//
// Reuses accounts.jsx primitives (AccPhone / AccGlass / AccGlyph / ACC_FONTS / ACC_COLORS / accBg)

// ─── Localised strings (mirroring Localizable.strings keys in code) ──
const L = {
  title: 'iCloud 同步',
  enableTitle: '開啟 iCloud 同步',
  enableSubtitle: '在你的 iPhone、iPad 和 Mac 之間自動同步交易、帳戶與分類。資料以你的 Apple ID 端對端加密儲存。',
  enableButton: '開啟同步',
  retryButton: '重試',
  migrating: '正在遷移資料…',
  enabledLabel: '已開啟 iCloud 同步',
  accountActive: 'iCloud 帳號使用中',
  unavailable: '無法連線到 iCloud,請確認你已登入 Apple ID,並在「設定 › Apple ID › iCloud」中為 NeuLedger 開啟同步。',
  hint: '同步啟用後,新增交易會在所有裝置上即時顯示。離線編輯會在恢復連線時自動上傳。',
};

// ─── Small atoms ─────────────────────────────────────────────
function NavBar({ dark, title }) {
  const fg = dark ? '#fff' : '#0A0A0A';
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

function LargeTitle({ dark, children }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  return (
    <div style={{ padding: '4px 20px 18px' }}>
      <div style={{ fontFamily: ACC_FONTS.display, fontSize: 34, fontWeight: 600, letterSpacing: -0.8, color: fg, lineHeight: 1.1 }}>{children}</div>
    </div>
  );
}

// Cloud + arrow up — bigger, hero size
function CloudHero({ size = 64, color, variant = 'up' }) {
  const sw = 1.4;
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" fill="none">
      <path d="M16 42c-5.5 0-10-4.5-10-10s4.5-10 10-10c.6 0 1.2.1 1.8.2C19.6 16 25.2 11 32 11c7.8 0 14 6.2 14 14 0 .5 0 1-.1 1.5 4 .7 7.1 4.3 7.1 8.5 0 4.8-3.9 8.7-8.7 8.7H16z"
        stroke={color} strokeWidth={sw*1.6} strokeLinejoin="round" fill="none"/>
      {variant === 'up' && (
        <g stroke={color} strokeWidth={sw*1.6} strokeLinecap="round" strokeLinejoin="round" fill="none">
          <path d="M32 50V36"/>
          <path d="M26 41l6-6 6 6"/>
        </g>
      )}
      {variant === 'check' && (
        <g stroke={color} strokeWidth={sw*1.6} strokeLinecap="round" strokeLinejoin="round" fill="none">
          <path d="M26 35l4 4 8-8"/>
        </g>
      )}
      {variant === 'person' && (
        <g stroke={color} strokeWidth={sw*1.6} strokeLinecap="round" strokeLinejoin="round" fill="none">
          <circle cx="32" cy="34" r="3.5"/>
          <path d="M26 44c0-3 2.7-5 6-5s6 2 6 5"/>
        </g>
      )}
      {variant === 'slash' && (
        <g stroke={color} strokeWidth={sw*1.6} strokeLinecap="round">
          <path d="M14 14l36 36"/>
        </g>
      )}
    </svg>
  );
}

// Animated ring progress (static frame)
function ProgressBar({ value, dark }) {
  const track = dark ? 'rgba(255,255,255,0.10)' : 'rgba(0,0,0,0.06)';
  return (
    <div style={{ width: '100%', height: 6, borderRadius: 3, background: track, overflow: 'hidden' }}>
      <div style={{
        width: `${Math.round(value * 100)}%`, height: '100%',
        background: `linear-gradient(90deg, ${ACC_COLORS.warm} 0%, ${ACC_COLORS.warmDark} 100%)`,
        borderRadius: 3, transition: 'width 300ms ease',
        boxShadow: `0 0 12px ${ACC_COLORS.warm}66`,
      }}/>
    </div>
  );
}

// Big CTA button
function PrimaryButton({ children, disabled, dark, onClick }) {
  return (
    <button onClick={onClick} disabled={disabled} style={{
      width: '100%', padding: '15px 14px', borderRadius: 14, border: 'none',
      background: disabled
        ? (dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)')
        : `linear-gradient(180deg, ${ACC_COLORS.warm} 0%, ${ACC_COLORS.warmDark} 100%)`,
      color: disabled ? (dark ? 'rgba(235,235,245,0.4)' : 'rgba(60,60,67,0.4)') : '#fff',
      fontFamily: ACC_FONTS.body, fontSize: 17, fontWeight: 600, letterSpacing: -0.1,
      boxShadow: disabled ? 'none' : `0 8px 22px ${ACC_COLORS.warm}33, inset 0 1px 0 rgba(255,255,255,0.25)`,
      cursor: disabled ? 'not-allowed' : 'pointer',
    }}>{children}</button>
  );
}

// Glass row with icon + label + trailing
function StatusRow({ icon, iconColor, label, trailing, dark, divider }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  return (
    <div>
      <div style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 14 }}>
        <div style={{
          width: 30, height: 30, borderRadius: 8, flexShrink: 0,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          background: `${iconColor}1A`,
          color: iconColor,
        }}>{icon}</div>
        <div style={{ flex: 1, fontSize: 15.5, color: fg, letterSpacing: -0.1 }}>{label}</div>
        <div>{trailing}</div>
      </div>
      {divider && <div style={{ height: 0.5, marginLeft: 60, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(60,60,67,0.12)' }}/>}
    </div>
  );
}

// SF-style icons inline (since AccGlyph doesn't have icloud)
function IconCloud({ size = 18, color, variant = 'plain' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <path d="M7 17c-2.2 0-4-1.8-4-4s1.8-4 4-4c.2 0 .5 0 .7.1C8.4 7 10.5 5.5 13 5.5c3.3 0 6 2.7 6 6 0 .2 0 .4-.1.6 1.7.3 3.1 1.8 3.1 3.7 0 2-1.6 3.7-3.7 3.7H7z"
        stroke={color} strokeWidth="1.6" strokeLinejoin="round" fill="none"/>
      {variant === 'check' && <path d="M9.5 13.5l2 2 4-4" stroke={color} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" fill="none"/>}
      {variant === 'person' && (<g stroke={color} strokeWidth="1.6" fill="none" strokeLinecap="round"><circle cx="12" cy="12.5" r="1.5"/><path d="M9.5 16c0-1.2 1.1-2 2.5-2s2.5.8 2.5 2"/></g>)}
    </svg>
  );
}

function CheckBadge({ color = ACC_COLORS.income, size = 22 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="10" fill={color}/>
      <path d="M7.5 12.5l3 3 6-6.5" stroke="#fff" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
    </svg>
  );
}

// ═══════════════════════════════════════════════════════════
// 01 · Off (idle, CloudKit available)
// ═══════════════════════════════════════════════════════════
function SyncOff({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.62)' : 'rgba(60,60,67,0.62)';
  return (
    <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <NavBar dark={dark} title="Sync"/>
      <LargeTitle dark={dark}>{L.title}</LargeTitle>
      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 100px' }}>
        <AccGlass dark={dark} radius={20} style={{ padding: 22 }}>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', paddingTop: 6, paddingBottom: 4 }}>
            {/* Soft halo behind cloud */}
            <div style={{ position: 'relative', width: 92, height: 92, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 14 }}>
              <div style={{ position: 'absolute', inset: 0, background: `radial-gradient(circle, ${ACC_COLORS.warm}22 0%, transparent 70%)`, borderRadius: '50%' }}/>
              <CloudHero size={64} color={ACC_COLORS.warm} variant="up"/>
            </div>
            <div style={{ fontFamily: ACC_FONTS.display, fontSize: 22, fontWeight: 600, letterSpacing: -0.4, color: fg, marginBottom: 8 }}>{L.enableTitle}</div>
            <div style={{ fontSize: 14, lineHeight: 1.55, color: muted, maxWidth: 300, marginBottom: 22 }}>{L.enableSubtitle}</div>
          </div>

          {/* Feature highlights */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 0, marginBottom: 20, borderRadius: 14, background: dark ? 'rgba(255,255,255,0.04)' : 'rgba(255,255,255,0.55)', overflow: 'hidden', border: `0.5px solid ${dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)'}` }}>
            {[
              { icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={ACC_COLORS.warm} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="5" width="14" height="9" rx="2"/><path d="M11 14v3"/><rect x="7" y="17" width="14" height="3" rx="1"/></svg>, label: '跨裝置即時同步' },
              { icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={ACC_COLORS.warm} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/></svg>, label: 'Apple ID 端對端加密' },
              { icon: <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={ACC_COLORS.warm} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12a9 9 0 0114-7.5"/><path d="M21 12a9 9 0 01-14 7.5"/><path d="M17 4v4h4M7 20v-4H3"/></svg>, label: '離線編輯 · 自動上傳' },
            ].map((f, i, arr) => (
              <div key={i}>
                <div style={{ padding: '11px 14px', display: 'flex', alignItems: 'center', gap: 12 }}>
                  <div style={{ width: 28, display: 'flex', justifyContent: 'center' }}>{f.icon}</div>
                  <div style={{ fontSize: 14, color: fg }}>{f.label}</div>
                </div>
                {i < arr.length - 1 && <div style={{ height: 0.5, marginLeft: 54, background: dark ? 'rgba(255,255,255,0.06)' : 'rgba(60,60,67,0.10)' }}/>}
              </div>
            ))}
          </div>

          <PrimaryButton dark={dark}>{L.enableButton}</PrimaryButton>
        </AccGlass>

        {/* Footer hint */}
        <div style={{ marginTop: 14, padding: '0 6px', fontSize: 12, lineHeight: 1.55, color: muted }}>
          {L.hint}
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 02 · Migrating (progress)
// ═══════════════════════════════════════════════════════════
function SyncMigrating({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.62)' : 'rgba(60,60,67,0.62)';
  const progress = 0.64;
  return (
    <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <NavBar dark={dark} title="Sync · Migrating"/>
      <LargeTitle dark={dark}>{L.title}</LargeTitle>
      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 100px' }}>
        <AccGlass dark={dark} radius={20} style={{ padding: 22 }}>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', paddingTop: 6, paddingBottom: 4 }}>
            <div style={{ position: 'relative', width: 92, height: 92, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 14 }}>
              <div style={{ position: 'absolute', inset: 0, background: `radial-gradient(circle, ${ACC_COLORS.warm}33 0%, transparent 70%)`, borderRadius: '50%' }}/>
              {/* Ring */}
              <svg width="92" height="92" viewBox="0 0 92 92" style={{ position: 'absolute' }}>
                <circle cx="46" cy="46" r="38" stroke={dark ? 'rgba(255,255,255,0.10)' : 'rgba(0,0,0,0.06)'} strokeWidth="3" fill="none"/>
                <circle cx="46" cy="46" r="38" stroke={ACC_COLORS.warm} strokeWidth="3" fill="none"
                  strokeDasharray={`${2 * Math.PI * 38}`} strokeDashoffset={`${2 * Math.PI * 38 * (1 - progress)}`}
                  strokeLinecap="round" transform="rotate(-90 46 46)"/>
              </svg>
              <CloudHero size={44} color={ACC_COLORS.warm} variant="up"/>
            </div>
            <div style={{ fontFamily: ACC_FONTS.display, fontSize: 22, fontWeight: 600, letterSpacing: -0.4, color: fg, marginBottom: 8 }}>{L.migrating}</div>
            <div style={{ fontSize: 14, lineHeight: 1.55, color: muted, maxWidth: 290, marginBottom: 20 }}>
              正在將 <span style={{ color: fg, fontWeight: 600 }}>1,247 筆交易</span> 與 <span style={{ color: fg, fontWeight: 600 }}>4 個帳戶</span>上傳到 iCloud。請保持 App 在前景。
            </div>
          </div>

          {/* Progress block */}
          <div style={{ padding: '14px 16px', borderRadius: 14, background: dark ? 'rgba(255,255,255,0.04)' : 'rgba(255,255,255,0.55)', border: `0.5px solid ${dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)'}` }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 8 }}>
              <div style={{ fontSize: 13, color: muted }}>遷移進度</div>
              <div style={{ fontFamily: ACC_FONTS.mono, fontSize: 15, fontWeight: 500, color: fg, fontVariantNumeric: 'tabular-nums' }}>{Math.round(progress * 100)}<span style={{ fontSize: 11, color: muted, marginLeft: 1 }}>%</span></div>
            </div>
            <ProgressBar value={progress} dark={dark}/>
            <div style={{ marginTop: 10, display: 'flex', justifyContent: 'space-between', fontFamily: ACC_FONTS.mono, fontSize: 11, color: muted, letterSpacing: 0.4 }}>
              <div>798 / 1,247 ITEMS</div>
              <div>~ 40s 剩餘</div>
            </div>
          </div>

          <div style={{ marginTop: 18, padding: '10px 12px', display: 'flex', alignItems: 'center', gap: 10, borderRadius: 10, background: `${ACC_COLORS.ai}14`, border: `0.5px solid ${ACC_COLORS.ai}33` }}>
            <AccGlyph name="sparkle" size={14} color={ACC_COLORS.ai}/>
            <div style={{ fontSize: 12, color: fg, lineHeight: 1.45 }}>
              <span style={{ color: ACC_COLORS.ai, fontWeight: 600 }}>提示 · </span>結束前不要關閉 App。中斷後重新進入可以從目前進度繼續。
            </div>
          </div>
        </AccGlass>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 03 · Off · iCloud unavailable
// ═══════════════════════════════════════════════════════════
function SyncUnavailable({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.62)' : 'rgba(60,60,67,0.62)';
  const red = ACC_COLORS.expense;
  return (
    <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <NavBar dark={dark} title="Sync · Unavailable"/>
      <LargeTitle dark={dark}>{L.title}</LargeTitle>
      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 100px' }}>
        <AccGlass dark={dark} radius={20} style={{ padding: 22 }}>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', paddingTop: 6, paddingBottom: 4 }}>
            <div style={{ position: 'relative', width: 92, height: 92, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 14 }}>
              <div style={{ position: 'absolute', inset: 0, background: `radial-gradient(circle, ${red}22 0%, transparent 70%)`, borderRadius: '50%' }}/>
              <CloudHero size={64} color={muted} variant="up"/>
              <div style={{ position: 'absolute', width: 92, height: 92, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <svg width="92" height="92" viewBox="0 0 92 92"><line x1="22" y1="22" x2="70" y2="70" stroke={red} strokeWidth="3.5" strokeLinecap="round"/></svg>
              </div>
            </div>
            <div style={{ fontFamily: ACC_FONTS.display, fontSize: 22, fontWeight: 600, letterSpacing: -0.4, color: fg, marginBottom: 8 }}>{L.enableTitle}</div>
            <div style={{ fontSize: 14, lineHeight: 1.55, color: muted, maxWidth: 300, marginBottom: 18 }}>{L.enableSubtitle}</div>
          </div>

          {/* Red warning banner */}
          <div style={{
            display: 'flex', gap: 10, padding: '12px 14px', borderRadius: 12,
            background: `${red}14`, border: `0.5px solid ${red}40`, marginBottom: 18,
          }}>
            <div style={{ flexShrink: 0, color: red, marginTop: 1 }}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={red} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M12 3L2 21h20L12 3z"/><path d="M12 10v4M12 17.5v0"/></svg>
            </div>
            <div style={{ fontSize: 13, lineHeight: 1.5, color: fg }}>
              <div style={{ fontWeight: 600, color: red, marginBottom: 2 }}>無法連線到 iCloud</div>
              {L.unavailable}
            </div>
          </div>

          <PrimaryButton dark={dark} disabled>{L.enableButton}</PrimaryButton>

          <button style={{
            marginTop: 10, width: '100%', padding: '12px 14px', borderRadius: 12, border: 'none',
            background: 'transparent', color: ACC_COLORS.warm,
            fontFamily: ACC_FONTS.body, fontSize: 15, fontWeight: 500, cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
          }}>
            前往「設定」
            <AccGlyph name="arrow-up-right" size={14} color={ACC_COLORS.warm} stroke={2}/>
          </button>
        </AccGlass>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// 04 · Enabled
// ═══════════════════════════════════════════════════════════
function SyncEnabled({ dark }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.62)' : 'rgba(60,60,67,0.62)';
  const green = ACC_COLORS.income;
  return (
    <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <NavBar dark={dark} title="Sync · Active"/>
      <LargeTitle dark={dark}>{L.title}</LargeTitle>
      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 100px' }}>
        {/* Hero status */}
        <AccGlass dark={dark} radius={20} style={{ padding: 22, marginBottom: 14 }}>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', paddingTop: 4 }}>
            <div style={{ position: 'relative', width: 92, height: 92, display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: 14 }}>
              <div style={{ position: 'absolute', inset: 0, background: `radial-gradient(circle, ${green}22 0%, transparent 70%)`, borderRadius: '50%' }}/>
              <CloudHero size={64} color={green} variant="check"/>
            </div>
            <div style={{ fontFamily: ACC_FONTS.display, fontSize: 22, fontWeight: 600, letterSpacing: -0.4, color: fg, marginBottom: 6 }}>同步運作中</div>
            <div style={{ fontSize: 13, color: muted, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ width: 6, height: 6, borderRadius: 3, background: green, boxShadow: `0 0 8px ${green}` }}/>
              最後一次同步 <span style={{ fontFamily: ACC_FONTS.mono, color: fg, fontWeight: 500 }}>· 2 分鐘前</span>
            </div>

            {/* Three quick stats */}
            <div style={{ width: '100%', display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', borderRadius: 14, background: dark ? 'rgba(255,255,255,0.04)' : 'rgba(255,255,255,0.55)', border: `0.5px solid ${dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)'}`, overflow: 'hidden' }}>
              {[
                { v: '1,247', l: '交易' },
                { v: '4', l: '帳戶' },
                { v: '18', l: '分類' },
              ].map((s, i, arr) => (
                <div key={i} style={{ padding: '14px 10px', textAlign: 'center', borderRight: i < arr.length - 1 ? `0.5px solid ${dark ? 'rgba(255,255,255,0.08)' : 'rgba(60,60,67,0.10)'}` : 'none' }}>
                  <div style={{ fontFamily: ACC_FONTS.mono, fontSize: 20, fontWeight: 500, color: fg, letterSpacing: -0.4, fontVariantNumeric: 'tabular-nums' }}>{s.v}</div>
                  <div style={{ fontSize: 11, color: muted, marginTop: 2, fontFamily: ACC_FONTS.mono, letterSpacing: 0.4, textTransform: 'uppercase' }}>{s.l}</div>
                </div>
              ))}
            </div>
          </div>
        </AccGlass>

        {/* Status rows (mirrors the enabledSection in Swift) */}
        <AccGlass dark={dark} radius={16} style={{ padding: 0, overflow: 'hidden' }}>
          <StatusRow
            dark={dark} divider
            icon={<IconCloud size={20} color={green} variant="check"/>}
            iconColor={green}
            label={L.enabledLabel}
            trailing={<CheckBadge color={green} size={20}/>}
          />
          <StatusRow
            dark={dark}
            icon={<IconCloud size={20} color={ACC_COLORS.warm} variant="person"/>}
            iconColor={ACC_COLORS.warm}
            label={L.accountActive}
            trailing={<div style={{ fontFamily: ACC_FONTS.mono, fontSize: 12, color: muted, letterSpacing: 0.3 }}>drake@…</div>}
          />
        </AccGlass>

        {/* Footer hint */}
        <div style={{ marginTop: 14, padding: '0 6px', fontSize: 12, lineHeight: 1.55, color: muted }}>
          {L.hint}
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
// Canvas
// ═══════════════════════════════════════════════════════════
function SyncSettingsCanvas() {
  const dark = false;
  const muted = 'rgba(60,60,67,0.55)';
  const screens = [
    { id: 'off',         label: '01 / Sync Off',           desc: '預設狀態 · Hero cloud + 功能 highlights + CTA',  Comp: SyncOff },
    { id: 'migrating',   label: '02 / Sync Migrating',     desc: 'migrationState = .migrating(progress) · 進度條 + 倒數', Comp: SyncMigrating },
    { id: 'unavailable', label: '03 / Sync · No iCloud',   desc: 'isCloudKitAvailable = false · 紅色警告 · 按鈕 disabled', Comp: SyncUnavailable },
    { id: 'enabled',     label: '04 / Sync Enabled',       desc: 'isSyncEnabled = true · status hero + 數據 + 兩列狀態', Comp: SyncEnabled },
  ];
  return (
    <div style={{ minHeight: '100vh', background: '#ECE9E2', padding: '40px 24px 80px', fontFamily: ACC_FONTS.body }}>
      <div style={{ maxWidth: 1280, margin: '0 auto 32px' }}>
        <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1.4, textTransform: 'uppercase' }}>NeuLedger · Settings › Sync</div>
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 40, fontWeight: 600, letterSpacing: -1, marginTop: 4 }}>iCloud 同步設定</div>
        <div style={{ fontSize: 14, color: muted, marginTop: 6, maxWidth: 660, lineHeight: 1.55 }}>
          對應 <code style={{ fontFamily: ACC_FONTS.mono, fontSize: 13 }}>SyncSettingsFeature</code> · <code style={{ fontFamily: ACC_FONTS.mono, fontSize: 13 }}>SyncSettingsView</code>。
          State 兩軸:<code style={{ fontFamily: ACC_FONTS.mono }}> isSyncEnabled</code> × <code style={{ fontFamily: ACC_FONTS.mono }}>migrationState</code>(idle / migrating / failed / completed)。下方四個 artboard 涵蓋 UI 會出現的所有組合。
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

ReactDOM.createRoot(document.getElementById('root')).render(<SyncSettingsCanvas/>);
