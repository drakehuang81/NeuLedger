// NeuLedger Transaction Detail — bottom sheet, half ↔ full drag, read-only
// 4 tx types × 2 variants (Spacious / Compact)
// Uses primitives from onboarding-variations.jsx + onboarding-b-prototype.jsx + dashboard-b1.jsx + add-transaction.jsx

const { useState: useTD, useEffect: useTDE, useRef: useTDRef, useMemo: useTDMemo } = React;

// ─────────────────────────────────────────────────────────────
// Sample transactions
// ─────────────────────────────────────────────────────────────
const SAMPLE_TX = {
  income_salary: {
    id: 'tx-001',
    type: 'income',
    amount: 50000,
    title: '4月薪資',
    merchant: 'Acme Studio',
    note: '月薪 + 績效獎金',
    category: { id: 'salary', label: '薪資', emoji: '💼', sub: 'Income · Primary' },
    account: { id: 'esun', name: '玉山銀行', type: 'Bank', icon: 'wallet', color: '#0A84FF' },
    dateISO: '2026-04-30T09:14:00',
    aiFilled: true,
    sourceText: '玉山銀行通知:薪資 NT$50,000 已入帳',
    tags: ['salary', 'recurring'],
    monthlyRank: '本月第 1 筆收入',
    sameCategory: { count: 4, last: 'NT$48,000' },
  },
  expense_lunch: {
    id: 'tx-002',
    type: 'expense',
    amount: 165,
    title: '鬍鬚張午餐',
    merchant: '鬍鬚張 · 信義店',
    note: '滷肉飯 + 排骨酥湯',
    category: { id: 'dining', label: '餐飲', emoji: '🍱', sub: 'Lunch' },
    account: { id: 'easycard', name: '悠遊卡', type: 'E-wallet', icon: 'phone', color: '#5E5CE6' },
    dateISO: '2026-05-05T12:42:00',
    aiFilled: false,
    tags: ['lunch'],
    monthlyRank: '本月第 12 筆餐飲',
    sameCategory: { count: 12, avg: 'NT$182' },
  },
  transfer: {
    id: 'tx-003',
    type: 'transfer',
    amount: 3000,
    title: '提領現金',
    note: '週末用',
    category: { id: 'transfer', label: '轉帳', emoji: '↔️', sub: 'Account move' },
    fromAccount: { id: 'esun', name: '玉山銀行', type: 'Bank', icon: 'wallet', color: '#0A84FF' },
    toAccount: { id: 'cash', name: 'Cash 現金', type: 'Cash', icon: 'banknote', color: '#8E8E93' },
    dateISO: '2026-05-04T16:30:00',
    aiFilled: false,
    tags: ['cash-out'],
    monthlyRank: '本月第 2 筆轉帳',
  },
  recurring_netflix: {
    id: 'tx-004',
    type: 'expense',
    amount: 390,
    title: 'Netflix 訂閱',
    merchant: 'Netflix',
    note: 'Premium · 4K · 4 螢幕',
    category: { id: 'subscription', label: '訂閱', emoji: '📺', sub: 'Streaming' },
    account: { id: 'visa', name: 'Visa 卡', type: 'Credit', icon: 'creditcard', color: '#FF2D55' },
    dateISO: '2026-04-15T03:00:00',
    nextChargeISO: '2026-05-15T03:00:00',
    recurring: { freq: 'monthly', sinceISO: '2024-08-15' },
    aiFilled: true,
    tags: ['subscription', 'recurring'],
    monthlyRank: '訂閱合計 NT$1,180 / 月',
    sameCategory: { count: 5, total: 'NT$1,180' },
  },
};

function formatDate(iso, withTime = true) {
  const d = new Date(iso);
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.getMonth()];
  const day = d.getDate();
  const hh = String(d.getHours()).padStart(2,'0');
  const mm = String(d.getMinutes()).padStart(2,'0');
  return withTime ? `${m} ${day} · ${hh}:${mm}` : `${m} ${day}, ${d.getFullYear()}`;
}
function formatDateZh(iso) {
  const d = new Date(iso);
  return `${d.getFullYear()} 年 ${d.getMonth()+1} 月 ${d.getDate()} 日`;
}
function relTime(iso) {
  const d = new Date(iso);
  const now = new Date();
  const diff = (now - d) / 86400000;
  if (diff < 1) return '今天';
  if (diff < 2) return '昨天';
  if (diff < 7) return `${Math.floor(diff)} 天前`;
  return formatDate(iso, false);
}

// ─────────────────────────────────────────────────────────────
// iOS modal sheet — full-bleed but inset from top, parent visible
// ─────────────────────────────────────────────────────────────
function StaticSheet({ open, dark, children }) {
  if (!open) return null;
  const sheetBg = dark
    ? 'linear-gradient(180deg, #2A1F18 0%, #1A1410 100%)'
    : 'linear-gradient(180deg, #FFF7EE 0%, #FAF7F2 100%)';

  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 30, pointerEvents: 'auto' }}>
      {/* dim scrim over parent */}
      <div style={{
        position: 'absolute', inset: 0,
        background: dark ? 'rgba(0,0,0,0.45)' : 'rgba(20,12,4,0.32)',
      }}/>
      {/* sheet — inset from top so parent peek is visible (iOS modal) */}
      <div style={{
        position: 'absolute', left: 0, right: 0, top: 56, bottom: 0,
        background: sheetBg,
        borderTopLeftRadius: 12, borderTopRightRadius: 12,
        boxShadow: dark ? '0 -8px 30px rgba(0,0,0,0.4)' : '0 -8px 30px rgba(120,80,40,0.18)',
        overflow: 'hidden', display: 'flex', flexDirection: 'column',
      }}>
        {/* iOS grabber */}
        <div style={{ padding: '8px 0 2px', display: 'flex', justifyContent: 'center' }}>
          <div style={{
            width: 36, height: 5, borderRadius: 3,
            background: dark ? 'rgba(255,255,255,0.20)' : 'rgba(0,0,0,0.18)',
          }}/>
        </div>
        {children}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Field row (read-only)
// ─────────────────────────────────────────────────────────────
function DetailField({ label, children, dark, onEdit, dense, last }) {
  const muted = dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)';
  const border = dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.06)';
  return (
    <div style={{
      padding: dense ? '10px 0' : '14px 0',
      borderBottom: last ? 'none' : `1px solid ${border}`,
      display: 'flex', alignItems: 'center', gap: 14,
    }}>
      <div style={{
        fontFamily: FONTS.mono, fontSize: 10, fontWeight: 500,
        textTransform: 'uppercase', letterSpacing: 1.2, color: muted,
        width: 76, flexShrink: 0,
      }}>{label}</div>
      <div style={{ flex: 1, fontFamily: FONTS.body, fontSize: 14, fontWeight: 500, color: dark ? '#fff' : '#0A0A0A' }}>
        {children}
      </div>
      {onEdit ? (
        <button onClick={onEdit} style={{
          background: 'transparent', border: 'none', cursor: 'pointer',
          fontFamily: FONTS.mono, fontSize: 11, color: muted, padding: 0,
        }}>Edit</button>
      ) : null}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// AI insight card
// ─────────────────────────────────────────────────────────────
function AIInsight({ tx, dark, accent, dense }) {
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const fg = dark ? '#fff' : '#0A0A0A';

  let body;
  if (tx.type === 'income' && tx.sameCategory) {
    body = (
      <React.Fragment>
        <span style={{ color: fg, fontWeight: 600 }}>+4.2%</span> 比上月高 (上次 {tx.sameCategory.last})。<br/>
        本月共 {tx.sameCategory.count} 筆收入,目前淨值 <span style={{ color: fg, fontWeight: 600 }}>+NT$ 47,830</span>。
      </React.Fragment>
    );
  } else if (tx.type === 'expense' && tx.sameCategory && tx.sameCategory.avg) {
    const pct = Math.round(((tx.amount - 182) / 182) * 100);
    const lower = tx.amount < 182;
    body = (
      <React.Fragment>
        比{tx.category.label}平均 ({tx.sameCategory.avg}) <span style={{ color: lower ? '#34C759' : '#FF6A00', fontWeight: 600 }}>{lower ? '低' : '高'} {Math.abs(pct)}%</span>。<br/>
        本月{tx.category.label} {tx.sameCategory.count} 筆,合計 <span style={{ color: fg, fontWeight: 600 }}>NT$ 2,184</span>。
      </React.Fragment>
    );
  } else if (tx.type === 'transfer') {
    body = (
      <React.Fragment>
        <span style={{ color: fg, fontWeight: 600 }}>淨值不變</span>,只是資金搬家。<br/>
        玉山 → 現金,本月轉帳 2 筆,共 NT$ 5,500。
      </React.Fragment>
    );
  } else if (tx.recurring) {
    body = (
      <React.Fragment>
        每月固定 NT$ {tx.amount}。<br/>
        下次扣款 <span style={{ color: fg, fontWeight: 600 }}>{formatDate(tx.nextChargeISO, false)}</span> · 訂閱 21 個月。
      </React.Fragment>
    );
  } else {
    body = <React.Fragment>本月{tx.category.label}類別第 {tx.sameCategory ? tx.sameCategory.count : '—'} 筆。</React.Fragment>;
  }

  return (
    <Glass dark={dark} radius={18} style={{ padding: dense ? '12px 14px' : '14px 16px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
        <Glyph name="sparkles" size={13} color={accent}/>
        <div style={{ fontFamily: FONTS.mono, fontSize: 10, fontWeight: 500, textTransform: 'uppercase', letterSpacing: 1.2, color: muted }}>
          NeuLedger AI · On-device
        </div>
      </div>
      <div style={{ fontFamily: FONTS.body, fontSize: 13, lineHeight: 1.55, color: muted, letterSpacing: -0.1 }}>
        {body}
      </div>
    </Glass>
  );
}

// ─────────────────────────────────────────────────────────────
// Account chip
// ─────────────────────────────────────────────────────────────
function AccountChip({ acct, dark, dense }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      <div style={{
        width: dense ? 22 : 26, height: dense ? 22 : 26, borderRadius: dense ? 11 : 13,
        background: `${acct.color}25`,
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
      }}>
        <Glyph name={acct.icon} size={dense ? 12 : 14} color={acct.color}/>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column' }}>
        <div style={{ fontFamily: FONTS.body, fontSize: 14, fontWeight: 500, color: fg, letterSpacing: -0.1 }}>{acct.name}</div>
        <div style={{ fontFamily: FONTS.mono, fontSize: 9, textTransform: 'uppercase', letterSpacing: 1, color: dark ? 'rgba(235,235,245,0.5)' : 'rgba(60,60,67,0.5)' }}>{acct.type}</div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Hero amount block
// ─────────────────────────────────────────────────────────────
function TxHero({ tx, dark, accent, dense }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const sign = tx.type === 'income' ? '+' : (tx.type === 'transfer' ? '' : '−');
  const color = tx.type === 'income' ? (dark ? '#30D158' : '#34C759')
              : tx.type === 'transfer' ? (dark ? '#7D7AFF' : '#5E5CE6')
              : fg;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: dense ? 8 : 12, alignItems: 'flex-start' }}>
      {/* category pill */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: '5px 11px 5px 7px', borderRadius: 999,
        background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.7)',
        backdropFilter: 'blur(8px)',
        border: dark ? '0.5px solid rgba(255,255,255,0.1)' : '0.5px solid rgba(0,0,0,0.04)',
      }}>
        <span style={{ fontSize: 14 }}>{tx.category.emoji}</span>
        <div style={{ fontFamily: FONTS.body, fontSize: 12, fontWeight: 500, color: fg, letterSpacing: -0.1 }}>{tx.category.label}</div>
        <div style={{ fontFamily: FONTS.mono, fontSize: 9, color: muted, textTransform: 'uppercase', letterSpacing: 1, paddingLeft: 6, borderLeft: `1px solid ${dark ? 'rgba(255,255,255,0.15)' : 'rgba(0,0,0,0.1)'}` }}>{tx.category.sub}</div>
      </div>

      {/* amount */}
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 0, flexWrap: 'wrap' }}>
        <span style={{ fontFamily: FONTS.mono, fontSize: dense ? 16 : 20, fontWeight: 400, color: muted, marginRight: 6 }}>NT$</span>
        <span style={{
          fontFamily: FONTS.mono, fontSize: dense ? 40 : 52, fontWeight: 500, color: color,
          letterSpacing: -1.6, lineHeight: 1,
        }}>{sign}{tx.amount.toLocaleString()}</span>
      </div>

      {/* title + ai badge */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
        <div style={{ fontFamily: FONTS.display, fontSize: dense ? 16 : 18, fontWeight: 600, color: fg, letterSpacing: -0.3 }}>{tx.title}</div>
        {tx.aiFilled ? (
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 4,
            padding: '2px 7px 2px 5px', borderRadius: 999,
            background: dark ? 'rgba(48,209,88,0.18)' : 'rgba(52,199,89,0.15)',
          }}>
            <Glyph name="sparkles" size={9} color={dark ? '#30D158' : '#34C759'}/>
            <div style={{ fontFamily: FONTS.mono, fontSize: 9, fontWeight: 600, letterSpacing: 0.5, color: dark ? '#30D158' : '#34C759', textTransform: 'uppercase' }}>AI Filled</div>
          </div>
        ) : null}
        {tx.recurring ? (
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 4,
            padding: '2px 8px', borderRadius: 999,
            background: dark ? 'rgba(255,159,10,0.18)' : 'rgba(255,149,0,0.15)',
          }}>
            <div style={{ fontFamily: FONTS.mono, fontSize: 9, fontWeight: 600, letterSpacing: 0.5, color: accent, textTransform: 'uppercase' }}>↻ Monthly</div>
          </div>
        ) : null}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────
function TxTopBar({ dark, onClose, snap }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '6px 18px 14px',
    }}>
      <button onClick={onClose} style={{
        background: 'transparent', border: 'none', cursor: 'pointer', padding: 0,
        fontFamily: FONTS.body, fontSize: 15, color: muted, fontWeight: 500,
      }}>取消</button>
      <div style={{
        fontFamily: FONTS.mono, fontSize: 10, fontWeight: 500,
        textTransform: 'uppercase', letterSpacing: 1.6, color: muted,
      }}>Transaction · Detail</div>
      <div style={{ width: 30 }}/>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Action button row
// ─────────────────────────────────────────────────────────────
function TxActions({ dark, onEdit, onDelete, dense }) {
  const fg = dark ? '#fff' : '#0A0A0A';
  return (
    <div style={{ display: 'flex', gap: 10, marginTop: dense ? 14 : 20 }}>
      <button onClick={onEdit} style={{
        flex: 1, height: dense ? 46 : 52,
        background: 'linear-gradient(135deg, #FF9500, #FF6A00)',
        border: 'none', borderRadius: 16, color: '#fff', cursor: 'pointer',
        fontFamily: FONTS.body, fontSize: 15, fontWeight: 600, letterSpacing: -0.1,
        boxShadow: '0 8px 22px rgba(255,149,0,0.32)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      }}>
        <Glyph name="edit" size={15} color="#fff"/>
        Edit
      </button>
      <button onClick={onDelete} style={{
        height: dense ? 46 : 52, padding: '0 18px',
        background: dark ? 'rgba(255,69,58,0.18)' : 'rgba(255,59,48,0.10)',
        border: 'none', borderRadius: 16, cursor: 'pointer',
        fontFamily: FONTS.body, fontSize: 15, fontWeight: 600, letterSpacing: -0.1,
        color: dark ? '#FF453A' : '#FF3B30',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      }}>
        Delete
      </button>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Delete confirm action sheet
// ─────────────────────────────────────────────────────────────
function DeleteConfirm({ open, dark, onCancel, onConfirm }) {
  if (!open) return null;
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 60, pointerEvents: 'auto',
      display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
      padding: 12,
      background: 'rgba(0,0,0,0.4)',
      animation: 'fadeIn .2s ease-out',
    }}>
      <div style={{
        background: dark ? 'rgba(40,32,26,0.95)' : 'rgba(255,255,255,0.92)',
        backdropFilter: 'blur(24px)',
        borderRadius: 14, overflow: 'hidden', marginBottom: 10,
      }}>
        <div style={{ padding: '18px 16px 14px', textAlign: 'center', borderBottom: `0.5px solid ${dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)'}` }}>
          <div style={{ fontFamily: FONTS.body, fontSize: 13, fontWeight: 600, color: dark ? '#fff' : '#0A0A0A', marginBottom: 4 }}>刪除這筆交易?</div>
          <div style={{ fontFamily: FONTS.body, fontSize: 12, color: dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)', lineHeight: 1.4 }}>
            此操作會立即刪除,5 秒內可 Undo。
          </div>
        </div>
        <button onClick={onConfirm} style={{
          width: '100%', padding: '14px 0', background: 'transparent', border: 'none', cursor: 'pointer',
          fontFamily: FONTS.body, fontSize: 16, fontWeight: 600, color: dark ? '#FF453A' : '#FF3B30',
        }}>Delete Transaction</button>
      </div>
      <button onClick={onCancel} style={{
        background: dark ? 'rgba(40,32,26,0.95)' : 'rgba(255,255,255,0.92)',
        backdropFilter: 'blur(24px)',
        borderRadius: 14, padding: '14px 0', border: 'none', cursor: 'pointer',
        fontFamily: FONTS.body, fontSize: 16, fontWeight: 600, color: dark ? '#fff' : '#0A0A0A',
      }}>Cancel</button>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Undo bar
// ─────────────────────────────────────────────────────────────
function UndoBar({ open, dark, onUndo, accent }) {
  if (!open) return null;
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  return (
    <div style={{
      position: 'absolute', left: 14, right: 14, bottom: 24, zIndex: 70,
      animation: 'celebrateIn .3s cubic-bezier(.22,.9,.32,1)',
    }}>
      <Glass dark={dark} radius={18} style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '12px 14px 12px 16px',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <Glyph name="check" size={14} color={dark ? '#30D158' : '#34C759'}/>
          <div style={{ fontFamily: FONTS.body, fontSize: 13, fontWeight: 500, color: dark ? '#fff' : '#0A0A0A' }}>已刪除</div>
        </div>
        <button onClick={onUndo} style={{
          background: 'transparent', border: 'none', cursor: 'pointer', padding: '4px 8px',
          fontFamily: FONTS.body, fontSize: 13, fontWeight: 600, color: accent,
        }}>Undo</button>
      </Glass>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Body content (read-only) — shared between V1 and V2
// ─────────────────────────────────────────────────────────────
function TxBody({ tx, dark, accent, dense, snap }) {
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const fg = dark ? '#fff' : '#0A0A0A';

  const isFull = snap === 'full';

  return (
    <div style={{
      flex: 1,
      overflow: 'auto',
      padding: dense ? '4px 18px 18px' : '4px 20px 20px',
      display: 'flex', flexDirection: 'column', gap: dense ? 14 : 18,
    }}>
      {/* HERO */}
      <TxHero tx={tx} dark={dark} accent={accent} dense={dense}/>

      {/* AI insight always visible */}
      <AIInsight tx={tx} dark={dark} accent={accent} dense={dense}/>

      {/* Field list */}
      <Glass dark={dark} radius={18} style={{ padding: dense ? '4px 14px' : '4px 16px' }}>
        {tx.type === 'transfer' ? (
          <React.Fragment>
            <DetailField label="From" dark={dark} dense={dense}>
              <AccountChip acct={tx.fromAccount} dark={dark} dense={dense}/>
            </DetailField>
            <DetailField label="To" dark={dark} dense={dense}>
              <AccountChip acct={tx.toAccount} dark={dark} dense={dense}/>
            </DetailField>
          </React.Fragment>
        ) : (
          <DetailField label="Account" dark={dark} dense={dense}>
            <AccountChip acct={tx.account} dark={dark} dense={dense}/>
          </DetailField>
        )}
        <DetailField label="Date" dark={dark} dense={dense}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, flexWrap: 'wrap' }}>
            <span>{formatDateZh(tx.dateISO)}</span>
            <span style={{ fontFamily: FONTS.mono, fontSize: 11, color: muted }}>
              {new Date(tx.dateISO).toTimeString().slice(0,5)} · {relTime(tx.dateISO)}
            </span>
          </div>
        </DetailField>
        {tx.merchant ? (
          <DetailField label="Merchant" dark={dark} dense={dense}>{tx.merchant}</DetailField>
        ) : null}
        {tx.note ? (
          <DetailField label="Note" dark={dark} dense={dense} last={!isFull && !tx.recurring}>{tx.note}</DetailField>
        ) : null}
        {/* Full-mode extras */}
        {isFull ? (
          <React.Fragment>
            {tx.recurring ? (
              <DetailField label="Repeat" dark={dark} dense={dense}>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                  <div>每月一次 · 自 {formatDate(tx.recurring.sinceISO, false)}</div>
                  <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: muted }}>
                    下次扣款 · {formatDate(tx.nextChargeISO, false)}
                  </div>
                </div>
              </DetailField>
            ) : null}
            {tx.tags && tx.tags.length ? (
              <DetailField label="Tags" dark={dark} dense={dense}>
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                  {tx.tags.map(t => (
                    <div key={t} style={{
                      padding: '3px 9px', borderRadius: 999,
                      background: dark ? `${accent}25` : `${accent}1f`,
                      fontFamily: FONTS.mono, fontSize: 10, color: accent, fontWeight: 500,
                    }}>#{t}</div>
                  ))}
                </div>
              </DetailField>
            ) : null}
            {tx.sourceText ? (
              <DetailField label="Source" dark={dark} dense={dense} last>
                <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: muted, fontStyle: 'italic', lineHeight: 1.5 }}>
                  「{tx.sourceText}」
                </div>
              </DetailField>
            ) : null}
          </React.Fragment>
        ) : null}
      </Glass>

      {/* Activity log — only in full mode */}
      {isFull ? (
        <div>
          <div style={{ fontFamily: FONTS.mono, fontSize: 10, fontWeight: 500, textTransform: 'uppercase', letterSpacing: 1.4, color: muted, marginBottom: 8, paddingLeft: 4 }}>Activity</div>
          <Glass dark={dark} radius={18} style={{ padding: dense ? '12px 14px' : '14px 16px' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {tx.aiFilled ? (
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <Glyph name="sparkles" size={12} color={accent}/>
                  <div style={{ flex: 1, fontFamily: FONTS.body, fontSize: 12, color: fg }}>AI 自動建立</div>
                  <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted }}>{relTime(tx.dateISO)}</div>
                </div>
              ) : (
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <div style={{ width: 12, height: 12, borderRadius: 6, background: dark ? 'rgba(235,235,245,0.3)' : 'rgba(60,60,67,0.3)' }}/>
                  <div style={{ flex: 1, fontFamily: FONTS.body, fontSize: 12, color: fg }}>手動建立</div>
                  <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted }}>{relTime(tx.dateISO)}</div>
                </div>
              )}
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={{ width: 12, height: 12, borderRadius: 6, background: dark ? 'rgba(235,235,245,0.18)' : 'rgba(60,60,67,0.18)' }}/>
                <div style={{ flex: 1, fontFamily: FONTS.body, fontSize: 12, color: muted }}>同步至 iCloud · 已加密</div>
                <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted }}>{relTime(tx.dateISO)}</div>
              </div>
            </div>
          </Glass>
        </div>
      ) : null}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Compact body — denser layout (V2)
// ─────────────────────────────────────────────────────────────
function TxBodyCompact({ tx, dark, accent, snap }) {
  const muted = dark ? 'rgba(235,235,245,0.65)' : 'rgba(60,60,67,0.65)';
  const fg = dark ? '#fff' : '#0A0A0A';
  const isFull = snap === 'full';

  return (
    <div style={{
      flex: 1, overflow: 'auto',
      padding: '4px 16px 16px',
      display: 'flex', flexDirection: 'column', gap: 12,
    }}>
      <TxHero tx={tx} dark={dark} accent={accent} dense={true}/>

      {/* meta row — quick scan */}
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        {tx.type === 'transfer' ? (
          <React.Fragment>
            <Glass dark={dark} radius={12} style={{ padding: '8px 12px', flex: 1, minWidth: 130 }}>
              <div style={{ fontFamily: FONTS.mono, fontSize: 9, textTransform: 'uppercase', letterSpacing: 1, color: muted, marginBottom: 4 }}>From</div>
              <AccountChip acct={tx.fromAccount} dark={dark} dense/>
            </Glass>
            <Glass dark={dark} radius={12} style={{ padding: '8px 12px', flex: 1, minWidth: 130 }}>
              <div style={{ fontFamily: FONTS.mono, fontSize: 9, textTransform: 'uppercase', letterSpacing: 1, color: muted, marginBottom: 4 }}>To</div>
              <AccountChip acct={tx.toAccount} dark={dark} dense/>
            </Glass>
          </React.Fragment>
        ) : (
          <Glass dark={dark} radius={12} style={{ padding: '8px 12px', flex: 1, minWidth: 130 }}>
            <div style={{ fontFamily: FONTS.mono, fontSize: 9, textTransform: 'uppercase', letterSpacing: 1, color: muted, marginBottom: 4 }}>Account</div>
            <AccountChip acct={tx.account} dark={dark} dense/>
          </Glass>
        )}
        <Glass dark={dark} radius={12} style={{ padding: '8px 12px', flex: 1, minWidth: 130 }}>
          <div style={{ fontFamily: FONTS.mono, fontSize: 9, textTransform: 'uppercase', letterSpacing: 1, color: muted, marginBottom: 4 }}>Date</div>
          <div style={{ fontFamily: FONTS.body, fontSize: 13, fontWeight: 500, color: fg }}>{formatDate(tx.dateISO)}</div>
          <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted, marginTop: 1 }}>{relTime(tx.dateISO)}</div>
        </Glass>
      </div>

      {/* details + AI side-by-side in compact */}
      <Glass dark={dark} radius={14} style={{ padding: '4px 14px' }}>
        {tx.merchant ? <DetailField label="Merchant" dark={dark} dense>{tx.merchant}</DetailField> : null}
        {tx.note ? <DetailField label="Note" dark={dark} dense last={!isFull}>{tx.note}</DetailField> : null}
        {isFull && tx.recurring ? (
          <DetailField label="Repeat" dark={dark} dense>
            每月 · 下次 {formatDate(tx.nextChargeISO, false)}
          </DetailField>
        ) : null}
        {isFull && tx.tags && tx.tags.length ? (
          <DetailField label="Tags" dark={dark} dense last={!tx.sourceText}>
            <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap' }}>
              {tx.tags.map(t => (
                <div key={t} style={{
                  padding: '2px 7px', borderRadius: 999,
                  background: dark ? `${accent}25` : `${accent}1f`,
                  fontFamily: FONTS.mono, fontSize: 10, color: accent, fontWeight: 500,
                }}>#{t}</div>
              ))}
            </div>
          </DetailField>
        ) : null}
        {isFull && tx.sourceText ? (
          <DetailField label="Source" dark={dark} dense last>
            <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: muted, fontStyle: 'italic', lineHeight: 1.4 }}>「{tx.sourceText}」</div>
          </DetailField>
        ) : null}
      </Glass>

      <AIInsight tx={tx} dark={dark} accent={accent} dense/>

      {isFull ? (
        <Glass dark={dark} radius={14} style={{ padding: '12px 14px' }}>
          <div style={{ fontFamily: FONTS.mono, fontSize: 9, textTransform: 'uppercase', letterSpacing: 1.2, color: muted, marginBottom: 8 }}>Activity</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              {tx.aiFilled
                ? <Glyph name="sparkles" size={11} color={accent}/>
                : <div style={{ width: 10, height: 10, borderRadius: 5, background: muted }}/>}
              <div style={{ flex: 1, fontFamily: FONTS.body, fontSize: 12, color: fg }}>{tx.aiFilled ? 'AI 自動建立' : '手動建立'}</div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted }}>{relTime(tx.dateISO)}</div>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <div style={{ width: 10, height: 10, borderRadius: 5, background: dark ? 'rgba(235,235,245,0.18)' : 'rgba(60,60,67,0.18)' }}/>
              <div style={{ flex: 1, fontFamily: FONTS.body, fontSize: 12, color: muted }}>iCloud · 已加密同步</div>
              <div style={{ fontFamily: FONTS.mono, fontSize: 10, color: muted }}>{relTime(tx.dateISO)}</div>
            </div>
          </div>
        </Glass>
      ) : null}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Detail screen container (V1 / V2)
// ─────────────────────────────────────────────────────────────
function TxDetailScreen({ tx, variant, dark }) {
  const accent = dark ? '#FF9F0A' : '#FF9500';
  const snap = 'full';
  const [confirmOpen, setConfirmOpen] = useTD(false);
  const [undoOpen, setUndoOpen] = useTD(false);
  const [showEdit, setShowEdit] = useTD(false);
  const [closed, setClosed] = useTD(false);

  // Background: dim "ledger" view behind sheet
  const bg = dark
    ? 'radial-gradient(ellipse at 50% 30%, #4A2A0E 0%, #1a0f08 50%, #050505 90%)'
    : 'radial-gradient(ellipse at 20% 0%, #FFE4B8 0%, #FFF6E8 50%, #FAFAF7 90%)';

  const onDelete = () => setConfirmOpen(true);
  const onConfirmDelete = () => {
    setConfirmOpen(false);
    setUndoOpen(true);
    setTimeout(() => setUndoOpen(false), 5000);
  };
  const onUndo = () => setUndoOpen(false);

  const dense = variant === 'compact';

  return (
    <Phone dark={dark}>
      <div style={{
        flex: 1, position: 'relative', overflow: 'hidden',
        background: bg,
      }}>
        {/* Parent screen peek — dimmed transactions list visible above sheet */}
        <div style={{
          position: 'absolute', inset: 0, padding: '20px 18px 0',
          opacity: 0.85,
        }}>
          {/* Title row */}
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
            <div style={{ fontFamily: FONTS.display, fontSize: 22, fontWeight: 600, color: dark ? '#fff' : '#0A0A0A', letterSpacing: -0.4 }}>本月交易</div>
            <div style={{ fontFamily: FONTS.mono, fontSize: 11, color: dark ? 'rgba(235,235,245,0.55)' : 'rgba(60,60,67,0.55)' }}>May 2026</div>
          </div>
          {/* Just a couple rows visible behind sheet top */}
          {[1,2].map(i => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 12, padding: '10px 0',
              borderBottom: `0.5px solid ${dark ? 'rgba(255,255,255,0.06)' : 'rgba(0,0,0,0.05)'}`,
            }}>
              <div style={{ width: 32, height: 32, borderRadius: 16, background: dark ? 'rgba(255,255,255,0.10)' : 'rgba(0,0,0,0.06)' }}/>
              <div style={{ flex: 1 }}>
                <div style={{ height: 9, width: '55%', borderRadius: 4, background: dark ? 'rgba(255,255,255,0.14)' : 'rgba(0,0,0,0.10)', marginBottom: 4 }}/>
                <div style={{ height: 6, width: '32%', borderRadius: 3, background: dark ? 'rgba(255,255,255,0.08)' : 'rgba(0,0,0,0.05)' }}/>
              </div>
              <div style={{ height: 10, width: 56, borderRadius: 4, background: dark ? 'rgba(255,255,255,0.10)' : 'rgba(0,0,0,0.07)' }}/>
            </div>
          ))}
        </div>

        {/* Sheet — iOS modal-style, inset from top */}
        <StaticSheet open={!closed} dark={dark}>
          <TxTopBar dark={dark} onClose={() => { setClosed(true); setTimeout(() => setClosed(false), 600); }} snap={snap}/>

          {variant === 'compact'
            ? <TxBodyCompact tx={tx} dark={dark} accent={accent} snap={snap}/>
            : <TxBody tx={tx} dark={dark} accent={accent} dense={dense} snap={snap}/>
          }

          <div style={{ padding: dense ? '0 16px 18px' : '0 20px 22px' }}>
            <TxActions dark={dark} dense={dense} onEdit={() => setShowEdit(true)} onDelete={onDelete}/>
          </div>
        </StaticSheet>

        {/* Delete confirm */}
        <DeleteConfirm open={confirmOpen} dark={dark} onCancel={() => setConfirmOpen(false)} onConfirm={onConfirmDelete}/>

        {/* Undo bar */}
        <UndoBar open={undoOpen} dark={dark} onUndo={onUndo} accent={accent}/>

        {/* Edit overlay (reuse Add Transaction) */}
        <AddTransactionOverlay
          open={showEdit}
          dark={dark}
          onClose={() => setShowEdit(false)}
          onSave={() => setShowEdit(false)}
        />
      </div>
    </Phone>
  );
}

Object.assign(window, {
  TxDetailScreen, SAMPLE_TX,
});
