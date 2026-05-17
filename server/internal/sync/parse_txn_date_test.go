package sync

import (
	"testing"
	"time"
)

func TestParseTxnDate(t *testing.T) {
	cases := []struct {
		input    string
		wantTZ   bool
		wantErr  bool
		wantTime string // expected RFC3339 output, empty = don't check
	}{
		// RFC3339 with timezone
		{"2026-05-16T23:31:00Z", true, false, "2026-05-16T23:31:00Z"},
		{"2026-05-16T23:31:00+08:00", true, false, "2026-05-16T23:31:00+08:00"},
		{"2026-05-16T23:31:00-05:00", true, false, "2026-05-16T23:31:00-05:00"},

		// RFC3339Nano with timezone (fractional seconds)
		{"2026-05-16T23:31:00.000000Z", true, false, "2026-05-16T23:31:00Z"},
		{"2026-05-16T23:31:00.123456Z", true, false, ""},
		{"2026-05-16T23:31:00.123+08:00", true, false, ""},
		{"2026-05-16T23:31:00.123456+08:00", true, false, ""},

		// No timezone — parsed as UTC
		{"2026-05-16T23:31:00.000000", false, false, "2026-05-16T23:31:00Z"},
		{"2026-05-16T23:31:00.000", false, false, "2026-05-16T23:31:00Z"},
		{"2026-05-16T23:31:00", false, false, "2026-05-16T23:31:00Z"},
		{"2026-05-16", false, false, "2026-05-16T00:00:00Z"},

		// Whitespace trimming
		{"  2026-05-16T23:31:00Z  ", true, false, "2026-05-16T23:31:00Z"},
		{"  2026-05-16  ", false, false, "2026-05-16T00:00:00Z"},

		// Error cases
		{"", false, true, ""},
		{"  ", false, true, ""},
		{"not-a-date", false, true, ""},
		{"2026-13-45", false, true, ""},
		{"2026-05-16T25:99:99", false, true, ""},
		{"20260516", false, true, ""},
	}

	for _, tc := range cases {
		got, hadTZ, err := parseTxnDate(tc.input)
		if (err != nil) != tc.wantErr {
			t.Errorf("parseTxnDate(%q): err=%v, wantErr=%v", tc.input, err, tc.wantErr)
			continue
		}
		if err != nil {
			continue
		}
		if hadTZ != tc.wantTZ {
			t.Errorf("parseTxnDate(%q): hadTZ=%v, want %v", tc.input, hadTZ, tc.wantTZ)
		}
		if got.Location() != time.UTC && !hadTZ {
			t.Errorf("parseTxnDate(%q): no-tz result should be UTC, got %v", tc.input, got.Location())
		}
		if tc.wantTime != "" {
			gotStr := got.Format(time.RFC3339)
			if gotStr != tc.wantTime {
				t.Errorf("parseTxnDate(%q): got %s, want %s", tc.input, gotStr, tc.wantTime)
			}
		}
	}
}
