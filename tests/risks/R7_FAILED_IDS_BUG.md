# Risk Verification: R7 — markSyncOpsUploaded includes failedIds

## Problem
`sync_engine.dart:111-114` uses `allProcessedIds` (includes failed) to call `markSyncOpsUploaded`.
Failed operations are permanently marked as uploaded → never retried → **data loss**.

## Current Code (Bug)
```dart
final allProcessedIds = [...succeededIds, ...failedIds];
await _db.markSyncOpsUploaded(allProcessedIds);
```

## Required Fix
```dart
// Only mark succeeded operations as uploaded
await _db.markSyncOpsUploaded(succeededIds);
// Failed ops remain in pending state for next Push cycle
if (failedIds.isNotEmpty) {
  log.warning('Push: ${failedIds.length} ops failed, will retry next cycle');
}
```

## Test Cases
- **S-025** (@expectedFailure before fix): Push returns failed_ids=[id3] → id3 marked uploaded (bug)
- **S-025b** (@must_pass after fix): Push returns failed_ids=[id3] → id3 stays pending → next Push retries

## Priority: 🔴 P0 Bug — Fix before W4

## Action Items
- [ ] Fix `sync_engine.dart` line 111-114
- [ ] Add retry counter (max 3 retries per op before dead-letter)
- [ ] Add test for retry behavior
- [ ] Verify no regression on succeeded ops marking
