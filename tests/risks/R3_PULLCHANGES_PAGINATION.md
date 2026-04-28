# Risk Verification: R3 — PullChanges Proto Pagination

## Problem
`proto/sync.proto` `PullChangesRequest` has no `page_size`/`page_token` fields.
`PullChangesResponse` has no pagination markers.

In family mode with large data, this causes unbounded full-table scans → OOM/timeout.

## Required Proto Changes

```protobuf
message PullChangesRequest {
  int64 since = 1;              // existing
  string client_id = 2;         // existing
  string family_id = 3;         // R10: MUST ADD
  int32 page_size = 4;          // NEW: default 100, max 500
  string page_token = 5;        // NEW: opaque cursor
}

message PullChangesResponse {
  repeated SyncOperation operations = 1;  // existing
  int64 server_time = 2;                  // existing
  string next_page_token = 3;             // NEW: empty = last page
  bool has_more = 4;                      // NEW
}
```

## Impact
- Server: `service.go` PullChanges needs cursor-based pagination (keyset on id + timestamp)
- Client: `sync_engine.dart` `_pullChanges` needs pagination loop + family_id param
- Tests: S-010/S-011 need to exercise pagination boundaries

## Priority: 🔴 P0 — Must be done before W5 (family sync tests)

## Action Items
- [ ] Update `proto/sync.proto`
- [ ] Regenerate Go + Dart code (`protoc`)
- [ ] Server implementation (keyset pagination)
- [ ] Client implementation (loop until `has_more=false`)
- [ ] Add `family_id` to PullChangesRequest (R10 fix)
