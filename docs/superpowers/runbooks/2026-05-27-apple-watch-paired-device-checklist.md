# Apple Watch Paired-Device Verification Checklist

Run this after any change that touches `Features/Sources/Core/Adapters/Watch/`,
`Features/Sources/WatchFeatures/`, or the `WatchBridgeAdapter` / `WatchSessionDelegate`
layer on iPhone.

## Setup

- Paired physical iPhone + Apple Watch (cellular or GPS; both fine)
- iPhone has at least one account, one category, and (optionally) one active monthly budget
- Watch app installed and previously launched at least once
- Both iPhone and Watch on watchOS 26 / iOS 26 or later
- iPhone in foreground (or just-foregrounded within ~30 sec) for tests involving snapshot push

## Test plan

1. **Cold-launch iPhone app** → confirm `WatchSyncObserver` fires once on `.splashCompleted`. Open the Watch app within 30 sec; it should reflect the latest snapshot (today total, category list, account list).

2. **Record a transaction on iPhone** (any account/category/amount) → within 30 sec the Watch app's today-total updates, and the snapshot's `todayCount` matches what iPhone has for today.

3. **Record a transaction on Watch** (3-step flow, default account) → check iPhone within 30 sec for the new SwiftData row. Confirm `id` matches what the draft generated (no dedup retry).

4. **Record a transaction on Watch with long-press account override** → on iPhone, confirm the new row's `accountId` matches the chosen override, not the default.

5. **Background iPhone for 60 sec, then re-open** → confirm `WatchSyncObserver` still fires on resume (look for SwiftData save → snapshot rebuild → WC push trace).

6. **Kill iPhone app via App Switcher, record on Watch, re-launch iPhone** → confirm draft delivers (`transferUserInfo` retries until iPhone re-opens WC session). iPhone should see the transaction once the app boots and WC re-activates.

7. **Send same draft twice** (force-quit Watch app between sends — possible via Digital Crown + side button) → confirm iPhone commits exactly once (`ProcessedDraftIdsStore` dedups on `TransactionDraft.id`).

8. **Cross midnight** (run with `Settings → General → Date & Time` set just before 00:00, or wait through midnight) → confirm Watch today-total resets to 0 within the first SwiftData save of the new day, OR sooner if `WatchMidnightTimer` fires.

9. **Change default account in Settings → Apple Watch** → on Watch, record without long-press; confirm new draft uses the new default (no app restart needed). `userSettingsAdapter` returns the new value on each provider invocation.

10. **Open Settings → Apple Watch with Watch unpaired** (turn off pairing in iPhone "Watch" app or remove Watch app from the paired Watch) → confirm Settings UI shows "未配對" / "尚未安裝 Watch App" and hides the default-account picker.

## Complication families

After Phase 3 lands, also verify each Complication family renders correctly:

1. **Add a Complication to a watch face**: long-press the watch face → Edit → add a Complication slot → choose "NeuLedger" → pick "今日支出". Repeat for each of the four supported families:
   - Modular Small / Circular (`.accessoryCircular`)
   - Modular Corner (`.accessoryCorner`)
   - Modular Rectangular (`.accessoryRectangular`)
   - Modular Inline (`.accessoryInline`)
2. After step 1 above, the Complication should display "—" if no snapshot has been received yet.
3. Record a transaction on iPhone → the Complication should update within ~30 sec without the Watch app being open.
4. Cross midnight → Complication should reset to "—" or "0" depending on whether `WatchMidnightTimer` fired.

## Known limitations

- All four families of Complication aren't validated here — that's Phase 3's checklist (Complication target ships separately).
- iCloud sync of transactions written from Watch is asynchronous (a few seconds after the iPhone commit) — verify on a second paired device if available.
- Watch dictation for note input is not in MVP scope.
- `WatchMidnightTimer.fire()` requires the iPhone app to be alive at midnight; if the app is suspended/killed the fire is missed and the reset waits for the next foreground push. Acceptable for MVP.

## Output

Pass/fail per item. Any failure should reproduce on a clean install (delete Watch app, re-install via Watch app on iPhone, re-pair if needed).

For repeatable failures, capture:
- iOS / watchOS versions
- Console logs around the failing moment (filter for `WatchSync`, `transferUserInfo`, `applicationContext`)
- Whether the failure persists across iPhone app re-launch
