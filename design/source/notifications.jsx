// NeuLedger — Notifications / Recap
// 3 artboards: Inbox · Monthly Recap · Recurring Subscriptions
// Reuses AccPhone / AccGlass / AccGlyph / ACC_FONTS / ACC_COLORS / accBg from accounts.jsx

const NOTIFICATIONS = [
  {
    section: '今天',
    items: [
      { id: 'n1', kind: 'budget-warn', title: '購物 已用 90%', body: '本月預算還剩 NT$ 500 · 距月底還有 14 天', time: '14:22', color: '#FF9500', icon: 'card', tone: 'warn' },
      { id: 'n2', kind: 'recurring', title: 'Netflix 將於 5/22 扣款', body: 'NT$ 390 · 玉山 e.Fingo · 已連續 8 個月', time: '09:00', color: '#E50914', icon: 'star', tone: 'info' },
      { id: 'n3', kind: 'ai-insight', title: '咖啡支出比上月多 18%', body: '本月已 NT$ 1,440 · 集中在路易莎與 Cama', time: '08:30', color: '#A66BF0', icon: 'sparkle', tone: 'ai' },
    ],
  },
  {
    section: '昨天',
    items: [
      { id: 'n4', kind: 'recap-ready', title: '4 月總結已準備好', body: '看看你 4 月怎麼花的 — AI 為你總結了 6 個重點', time: '20:00', color: '#E8835A', icon: 'sparkle', tone: 'recap' },
      { id: 'n5', kind: 'bill', title: '玉山 e.Fingo 5/10 截止', body: '本期應繳 NT$ 24,500 · 可設定自動扣繳', time: '18:00', color: '#7B3F00', icon: 'card', tone: 'info' },
    ],
  },
  {
    section: '本週稍早',
    items: [
      { id: 'n6', kind: 'detected', title: '偵測到新的重複扣款', body: 'Spotify · 每月 5 號 · NT$ 149 · 玉山卡', time: '5/12', color: '#1ED760', icon: 'star', tone: 'info' },
      { id: 'n7', kind: 'goal', title: '旅遊基金 已達 65%', body: '目標 NT$ 50,000 · 已存 NT$ 32,500 · 預計 9 月達成', time: '5/11', color: '#5E5CE6', icon: 'invest', tone: 'good' },
    ],
  },
];

const RECURRING = [
  { id: 'r1', name: 'Netflix', plan: '標準方案', amount: 390, cycle: '月', next: '5/22', monthsActive: 8, color: '#E50914', logo: 'N', detected: true },
  { id: 'r2', name: 'Spotify', plan: '個人', amount: 149, cycle: '月', next: '5/05', monthsActive: 14, color: '#1ED760', logo: 'S', detected: true },
  { id: 'r3', name: 'iCloud+', plan: '200GB', amount: 90, cycle: '月', next: '5/15', monthsActive: 22, color: '#0EA5E9', logo: 'iC', detected: true },
  { id: 'r4', name: 'Notion', plan: 'Plus', amount: 320, cycle: '月', next: '5/18', monthsActive: 4, color: '#000000', logo: 'N', detected: false },
  { id: 'r5', name: 'ChatGPT Plus', plan: '個人', amount: 600, cycle: '月', next: '5/28', monthsActive: 6, color: '#10A37F', logo: 'AI', detected: true },
  { id: 'r6', name: 'YouTube Premium', plan: '家庭', amount: 269, cycle: '月', next: '5/03', monthsActive: 11, color: '#FF0000', logo: 'YT', detected: true },
  { id: 'r7', name: 'Dropbox', plan: 'Plus', amount: 350, cycle: '月', next: '5/24', monthsActive: 30, color: '#0061FF', logo: 'D', detected: true },
];

const RECURRING_TOTAL = RECURRING.reduce((s, r) => s + r.amount, 0);

function nFmt(n) {
  return 'NT$ ' + Math.abs(n).toLocaleString('en-US');
}

// ─── Notification card ───────────────────────────────────────
function NotifCard({ item, dark, onTap }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.5)';
  const accent = ACC_COLORS.warm;
  const isAi = item.tone === 'ai';
  const isRecap = item.tone === 'recap';
  const isWarn = item.tone === 'warn';

  if (isRecap) {
    return (
      <button onClick={onTap} style={{
        width: '100%', padding: 0, border: 'none', cursor: 'pointer', textAlign: 'left',
        borderRadius: 20,
        background: `linear-gradient(135deg, #E8835A 0%, #C0623F 50%, #7B3F00 100%)`,
        position: 'relative', overflow: 'hidden',
        boxShadow: '0 12px 28px rgba(232,131,90,0.35)',
      }}>
        {/* Decorative blob */}
        <div style={{ position: 'absolute', right: -30, top: -30, width: 120, height: 120, borderRadius: 60, background: 'rgba(255,255,255,0.15)', filter: 'blur(20px)' }}/>
        <div style={{ position: 'absolute', left: -20, bottom: -20, width: 80, height: 80, borderRadius: 40, background: 'rgba(255,255,255,0.1)', filter: 'blur(15px)' }}/>
        <div style={{ position: 'relative', padding: 18 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 10 }}>
            <AccGlyph name="sparkle" size={12} color="rgba(255,255,255,0.85)"/>
            <span style={{ fontSize: 10, color: 'rgba(255,255,255,0.85)', fontFamily: ACC_FONTS.mono, letterSpacing: 1.5, textTransform: 'uppercase', fontWeight: 600 }}>April Recap · Ready</span>
          </div>
          <div style={{ fontFamily: ACC_FONTS.display, fontSize: 22, fontWeight: 600, color: '#fff', lineHeight: 1.15, marginBottom: 8 }}>{item.title}</div>
          <div style={{ fontSize: 13, color: 'rgba(255,255,255,0.85)', lineHeight: 1.45, marginBottom: 14 }}>{item.body}</div>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: 6, padding: '8px 14px', borderRadius: 100, background: 'rgba(255,255,255,0.2)', backdropFilter: 'blur(10px)', color: '#fff', fontSize: 13, fontWeight: 500 }}>
            開始查看 <AccGlyph name="arrow-up-right" size={12} color="#fff" stroke={2.2}/>
          </div>
        </div>
      </button>
    );
  }

  return (
    <button onClick={onTap} style={{
      width: '100%', padding: 14, border: 'none', cursor: 'pointer', textAlign: 'left',
      borderRadius: 16,
      background: dark ? 'rgba(255,255,255,0.05)' : 'rgba(255,255,255,0.7)',
      backdropFilter: 'blur(20px)',
      WebkitBackdropFilter: 'blur(20px)',
      display: 'flex', gap: 12, alignItems: 'flex-start',
      boxShadow: dark
        ? '0 1px 0 rgba(255,255,255,0.05) inset, 0 4px 12px rgba(0,0,0,0.2)'
        : '0 1px 0 rgba(255,255,255,0.85) inset, 0 2px 8px rgba(120,80,40,0.05), 0 0 0 0.5px rgba(0,0,0,0.04)',
      position: 'relative',
    }}>
      <div style={{ width: 36, height: 36, borderRadius: 10, background: item.color, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, boxShadow: `0 4px 10px ${item.color}40`, position: 'relative' }}>
        <AccGlyph name={item.icon} size={18} color="#fff" stroke={2}/>
        {isAi && (
          <div style={{ position: 'absolute', inset: -2, borderRadius: 12, border: `1.5px solid ${ACC_COLORS.ai}`, opacity: 0.4 }}/>
        )}
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 8, marginBottom: 3 }}>
          <div style={{ fontSize: 14.5, fontWeight: 600, color: fg, lineHeight: 1.3 }}>{item.title}</div>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, flexShrink: 0 }}>{item.time}</div>
        </div>
        <div style={{ fontSize: 13, color: muted, lineHeight: 1.4 }}>{item.body}</div>
        {isWarn && (
          <div style={{ marginTop: 10, padding: '6px 10px', borderRadius: 8, background: 'rgba(255,149,0,0.15)', display: 'inline-flex', alignItems: 'center', gap: 6 }}>
            <span style={{ fontSize: 11, color: '#FF9500', fontWeight: 500 }}>調整預算</span>
          </div>
        )}
      </div>
    </button>
  );
}

// ─── Notifications Inbox ─────────────────────────────────────
function NotifInbox({ dark, onRecap }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.5)';

  return (
    <div style={{ flex: 1, overflow: 'auto', WebkitOverflowScrolling: 'touch' }}>
      {/* Header */}
      <div style={{ padding: '8px 20px 18px', display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>NOTIFICATIONS</div>
          <div style={{ fontFamily: ACC_FONTS.display, fontSize: 28, fontWeight: 600, color: fg, marginTop: 2 }}>通知</div>
        </div>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: ACC_COLORS.warm, fontSize: 14 }}>全部標為已讀</button>
      </div>

      {/* Filter chips */}
      <div style={{ padding: '0 20px 16px', display: 'flex', gap: 6, overflowX: 'auto', WebkitOverflowScrolling: 'touch' }}>
        {[
          { id: 'all', name: '全部', count: 7, active: true },
          { id: 'budget', name: '預算', count: 1 },
          { id: 'recurring', name: '訂閱', count: 2 },
          { id: 'ai', name: 'AI', count: 1 },
          { id: 'recap', name: '總結', count: 1 },
        ].map(f => (
          <button key={f.id} style={{
            padding: '6px 12px', borderRadius: 100, border: 'none', cursor: 'pointer',
            background: f.active ? fg : (dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.04)'),
            color: f.active ? (dark ? '#0A0A0A' : '#fff') : fg,
            fontSize: 13, fontWeight: 500, whiteSpace: 'nowrap', flexShrink: 0,
          }}>
            {f.name} <span style={{ marginLeft: 4, opacity: 0.6, fontFamily: ACC_FONTS.mono }}>{f.count}</span>
          </button>
        ))}
      </div>

      {/* Sections */}
      <div style={{ padding: '0 16px 100px' }}>
        {NOTIFICATIONS.map(sec => (
          <div key={sec.section} style={{ marginBottom: 18 }}>
            <div style={{ padding: '4px 4px 8px', fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>{sec.section}</div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {sec.items.map(item => (
                <NotifCard key={item.id} item={item} dark={dark} onTap={() => item.kind === 'recap-ready' && onRecap()}/>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Monthly Recap (Spotify-Wrapped style) ───────────────────
function MonthlyRecap({ dark, onClose }) {
  const fg = '#fff'; // always white text on colored bg
  const muted = 'rgba(255,255,255,0.7)';

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'linear-gradient(160deg, #C0623F 0%, #7B3F00 60%, #2A1810 100%)', position: 'relative', overflow: 'hidden' }}>
      {/* Decorative blobs */}
      <div style={{ position: 'absolute', top: -50, right: -50, width: 200, height: 200, borderRadius: 100, background: 'radial-gradient(circle, rgba(232,131,90,0.4), transparent 70%)', filter: 'blur(30px)' }}/>
      <div style={{ position: 'absolute', bottom: 100, left: -80, width: 240, height: 240, borderRadius: 120, background: 'radial-gradient(circle, rgba(166,107,240,0.3), transparent 70%)', filter: 'blur(40px)' }}/>

      {/* Top bar */}
      <div style={{ padding: '8px 20px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between', position: 'relative', zIndex: 2 }}>
        <button onClick={onClose} style={{ width: 36, height: 36, borderRadius: 18, background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(10px)', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
          <AccGlyph name="close" size={16} stroke={2.2}/>
        </button>
        <div style={{ display: 'flex', gap: 4 }}>
          {[true, true, false, false, false, false].map((on, i) => (
            <div key={i} style={{ width: 18, height: 3, borderRadius: 2, background: on ? '#fff' : 'rgba(255,255,255,0.3)' }}/>
          ))}
        </div>
        <button style={{ width: 36, height: 36, borderRadius: 18, background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(10px)', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff' }}>
          <AccGlyph name="arrow-up-right" size={14} stroke={2.2}/>
        </button>
      </div>

      <div style={{ flex: 1, padding: '12px 24px 24px', display: 'flex', flexDirection: 'column', position: 'relative', zIndex: 2 }}>
        {/* Eyebrow */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 32, marginTop: 28 }}>
          <AccGlyph name="sparkle" size={14} color="#fff"/>
          <div style={{ fontSize: 11, color: '#fff', fontFamily: ACC_FONTS.mono, letterSpacing: 2, textTransform: 'uppercase', fontWeight: 600 }}>April · 2026 Recap</div>
        </div>

        {/* Big headline */}
        <div style={{ fontFamily: ACC_FONTS.display, fontSize: 44, fontWeight: 700, color: '#fff', lineHeight: 1.05, letterSpacing: -1.5, marginBottom: 20 }}>
          四月你<br/>
          花了
        </div>

        {/* Big number */}
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 32 }}>
          <span style={{ fontSize: 18, color: muted, fontFamily: ACC_FONTS.display }}>NT$</span>
          <span style={{ fontFamily: ACC_FONTS.display, fontSize: 88, fontWeight: 700, color: '#fff', letterSpacing: -3, lineHeight: 1, fontFeatureSettings: '"tnum"' }}>42,180</span>
        </div>

        {/* Subtitle */}
        <div style={{ fontSize: 15, color: muted, lineHeight: 1.5, marginBottom: 24 }}>
          比 3 月少了 <span style={{ color: '#fff', fontFamily: ACC_FONTS.mono, fontWeight: 600 }}>NT$ 3,420</span><br/>
          也比近 6 個月平均少 <span style={{ color: '#fff', fontFamily: ACC_FONTS.mono, fontWeight: 600 }}>8%</span>
        </div>

        {/* Stat pills */}
        <div style={{ display: 'flex', gap: 8, marginBottom: 28, flexWrap: 'wrap' }}>
          {[
            { label: '交易筆數', val: '184' },
            { label: '日均', val: 'NT$ 1,406' },
            { label: '最大單筆', val: 'NT$ 8,800' },
          ].map(s => (
            <div key={s.label} style={{ flex: '1 1 100px', padding: '10px 12px', borderRadius: 14, background: 'rgba(255,255,255,0.12)', backdropFilter: 'blur(10px)', border: '0.5px solid rgba(255,255,255,0.15)' }}>
              <div style={{ fontSize: 9.5, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>{s.label}</div>
              <div style={{ fontSize: 16, fontWeight: 600, color: '#fff', marginTop: 3, fontFamily: ACC_FONTS.display, fontFeatureSettings: '"tnum"' }}>{s.val}</div>
            </div>
          ))}
        </div>

        <div style={{ flex: 1 }}/>

        {/* AI commentary */}
        <div style={{ padding: 16, borderRadius: 18, background: 'rgba(0,0,0,0.25)', backdropFilter: 'blur(20px)', border: '0.5px solid rgba(255,255,255,0.12)', marginBottom: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 8 }}>
            <AccGlyph name="sparkle" size={11} color={ACC_COLORS.ai}/>
            <span style={{ fontSize: 10, color: '#D9C5FF', fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase', fontWeight: 600 }}>Claude 觀察</span>
          </div>
          <div style={{ fontSize: 14, color: '#fff', lineHeight: 1.5 }}>
            這個月你在「外食」上的支出明顯減少 — 大概是因為 4 月有 12 天在家吃飯。如果想繼續這個節奏,下個月可能再省下 <span style={{ fontWeight: 600 }}>NT$ 2,000</span>。
          </div>
        </div>

        {/* Continue CTA */}
        <button style={{
          width: '100%', padding: '14px', borderRadius: 100, border: 'none', cursor: 'pointer',
          background: '#fff', color: '#7B3F00', fontSize: 15, fontWeight: 600,
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
          fontFamily: ACC_FONTS.body,
        }}>
          繼續 <AccGlyph name="chevron-right" size={16} color="#7B3F00" stroke={2.2}/>
        </button>
      </div>
    </div>
  );
}

// ─── Recurring Subscriptions ─────────────────────────────────
function RecurringSubs({ dark, onBack }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.5)';
  const accent = ACC_COLORS.warm;
  const yearly = RECURRING_TOTAL * 12;

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* Nav */}
      <div style={{ padding: '8px 12px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', position: 'relative', flexShrink: 0 }}>
        <button onClick={onBack} style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: accent, display: 'flex', alignItems: 'center', gap: 2, fontSize: 16, fontWeight: 400 }}>
          <AccGlyph name="chevron-left" size={20} color={accent}/> 通知
        </button>
        <div style={{ position: 'absolute', left: '50%', transform: 'translateX(-50%)', fontWeight: 600, fontSize: 16, color: fg }}>定期扣款</div>
        <button style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: 8, color: accent, fontSize: 15, fontWeight: 400 }}>編輯</button>
      </div>

      <div style={{ flex: 1, overflow: 'auto', WebkitOverflowScrolling: 'touch', padding: '0 16px 100px' }}>
        {/* Total card */}
        <AccGlass dark={dark} radius={22} style={{ padding: 22, marginTop: 8, position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', top: -30, right: -30, width: 120, height: 120, borderRadius: 60, background: `radial-gradient(circle, ${ACC_COLORS.warm}30, transparent 70%)` }}/>
          <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>每月訂閱合計</div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 4 }}>
            <span style={{ fontSize: 16, color: muted, fontFamily: ACC_FONTS.display }}>NT$</span>
            <span style={{ fontFamily: ACC_FONTS.display, fontSize: 40, fontWeight: 600, color: fg, letterSpacing: -1, fontFeatureSettings: '"tnum"' }}>{RECURRING_TOTAL.toLocaleString()}</span>
            <span style={{ fontSize: 13, color: muted, marginLeft: 4 }}>/ 月</span>
          </div>
          <div style={{ display: 'flex', gap: 16, marginTop: 14 }}>
            <div>
              <div style={{ fontSize: 10, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>年度</div>
              <div style={{ fontSize: 14, color: fg, fontFamily: ACC_FONTS.mono, fontWeight: 600, marginTop: 2, fontFeatureSettings: '"tnum"' }}>NT$ {yearly.toLocaleString()}</div>
            </div>
            <div style={{ width: 0.5, background: dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)' }}/>
            <div>
              <div style={{ fontSize: 10, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>項目數</div>
              <div style={{ fontSize: 14, color: fg, fontFamily: ACC_FONTS.mono, fontWeight: 600, marginTop: 2 }}>{RECURRING.length}</div>
            </div>
            <div style={{ width: 0.5, background: dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)' }}/>
            <div>
              <div style={{ fontSize: 10, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>本月已扣</div>
              <div style={{ fontSize: 14, color: fg, fontFamily: ACC_FONTS.mono, fontWeight: 600, marginTop: 2, fontFeatureSettings: '"tnum"' }}>4</div>
            </div>
          </div>
        </AccGlass>

        {/* AI insight */}
        <AccGlass dark={dark} radius={16} style={{ padding: 14, marginTop: 12, display: 'flex', gap: 10, alignItems: 'flex-start' }}>
          <div style={{ width: 28, height: 28, borderRadius: 14, background: `linear-gradient(135deg, ${ACC_COLORS.ai} 0%, #6B5BD6 100%)`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <AccGlyph name="sparkle" size={14} color="#fff"/>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 13, color: fg, lineHeight: 1.4 }}>
              <span style={{ fontWeight: 600 }}>Notion (NT$ 320)</span> 已 4 個月沒有打開過,可能可以取消省 <span style={{ fontFamily: ACC_FONTS.mono, fontWeight: 600 }}>NT$ 3,840 / 年</span>。
            </div>
          </div>
        </AccGlass>

        {/* List */}
        <div style={{ marginTop: 20 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', padding: '0 4px 12px' }}>
            <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono, letterSpacing: 1, textTransform: 'uppercase' }}>所有訂閱</div>
            <div style={{ fontSize: 11, color: muted, fontFamily: ACC_FONTS.mono }}>下次扣款</div>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {RECURRING.map(r => (
              <AccGlass key={r.id} dark={dark} radius={14} style={{ padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12 }}>
                <div style={{
                  width: 40, height: 40, borderRadius: 10, background: r.color,
                  display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                  fontFamily: ACC_FONTS.display, fontSize: 13, fontWeight: 700, color: '#fff',
                  letterSpacing: -0.5,
                }}>{r.logo}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    <div style={{ fontSize: 14.5, fontWeight: 500, color: fg }}>{r.name}</div>
                    {r.detected && (
                      <div style={{ display: 'inline-flex', alignItems: 'center', gap: 3, padding: '1px 6px', borderRadius: 5, background: dark ? `${ACC_COLORS.ai}20` : `${ACC_COLORS.ai}15` }}>
                        <AccGlyph name="sparkle" size={8} color={ACC_COLORS.ai}/>
                        <span style={{ fontSize: 9, color: ACC_COLORS.ai, fontFamily: ACC_FONTS.mono, fontWeight: 600, letterSpacing: 0.5 }}>AI</span>
                      </div>
                    )}
                  </div>
                  <div style={{ fontSize: 11.5, color: muted, marginTop: 2 }}>{r.plan} · 已 {r.monthsActive} 個月</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontSize: 14, fontFamily: ACC_FONTS.mono, color: fg, fontWeight: 600, fontFeatureSettings: '"tnum"' }}>{nFmt(r.amount)}</div>
                  <div style={{ fontSize: 11, color: muted, marginTop: 2, fontFamily: ACC_FONTS.mono }}>{r.next}</div>
                </div>
              </AccGlass>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Top-level wrappers ──────────────────────────────────────
function NotifInboxScreen({ dark }) {
  return (
    <AccPhone dark={dark}>
      <NotifInbox dark={dark} onRecap={() => {}}/>
    </AccPhone>
  );
}

function MonthlyRecapScreen({ dark }) {
  // Recap uses its own colored bg, so wrap in a phone but override
  return (
    <div style={{
      width: 402, height: 874, borderRadius: 48, overflow: 'hidden',
      position: 'relative',
      boxShadow: '0 40px 80px rgba(0,0,0,0.18), 0 0 0 1px rgba(0,0,0,0.12)',
      WebkitFontSmoothing: 'antialiased',
      display: 'flex', flexDirection: 'column',
      fontFamily: ACC_FONTS.body,
    }}>
      <div style={{ position: 'absolute', top: 11, left: '50%', transform: 'translateX(-50%)', width: 126, height: 37, borderRadius: 24, background: '#000', zIndex: 50 }}/>
      <div style={{ height: 54, paddingTop: 18, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '18px 28px 0', flexShrink: 0, position: 'relative', zIndex: 5 }}>
        <div style={{ fontFamily: '-apple-system, system-ui', fontWeight: 600, fontSize: 16, color: '#fff' }}>9:41</div>
        <div style={{ width: 100 }}/>
        <div style={{ display: 'flex', gap: 5, alignItems: 'center', color: '#fff' }}>
          <svg width="17" height="11" viewBox="0 0 17 11"><rect x="0" y="6.5" width="3" height="4.5" rx="0.6" fill="currentColor"/><rect x="4.5" y="4.5" width="3" height="6.5" rx="0.6" fill="currentColor"/><rect x="9" y="2.5" width="3" height="8.5" rx="0.6" fill="currentColor"/><rect x="13.5" y="0" width="3" height="11" rx="0.6" fill="currentColor"/></svg>
          <svg width="24" height="11" viewBox="0 0 24 11"><rect x="0.5" y="0.5" width="20" height="10" rx="3" stroke="currentColor" strokeOpacity="0.4" fill="none"/><rect x="2" y="2" width="17" height="7" rx="1.5" fill="currentColor"/></svg>
        </div>
      </div>
      <MonthlyRecap dark={dark} onClose={() => {}}/>
      <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 60, height: 34, display: 'flex', justifyContent: 'center', alignItems: 'flex-end', paddingBottom: 8, pointerEvents: 'none' }}>
        <div style={{ width: 139, height: 5, borderRadius: 100, background: 'rgba(255,255,255,0.7)' }}/>
      </div>
    </div>
  );
}

function RecurringSubsScreen({ dark }) {
  return (
    <AccPhone dark={dark}>
      <RecurringSubs dark={dark} onBack={() => {}}/>
    </AccPhone>
  );
}

Object.assign(window, { NotifInboxScreen, MonthlyRecapScreen, RecurringSubsScreen });
