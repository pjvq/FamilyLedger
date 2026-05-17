package transaction

import (
	"testing"
	"time"

	"google.golang.org/protobuf/types/known/timestamppb"
)

func TestValidateTxnDate(t *testing.T) {
	tests := []struct {
		name    string
		ts      *timestamppb.Timestamp
		wantErr bool
	}{
		{"valid now", timestamppb.Now(), false},
		{"valid 2020", timestamppb.New(time.Date(2020, 6, 15, 12, 0, 0, 0, time.UTC)), false},
		{"valid boundary 2000-01-01", timestamppb.New(time.Date(2000, 1, 1, 0, 0, 0, 0, time.UTC)), false},
		{"too old 1999", timestamppb.New(time.Date(1999, 12, 31, 23, 59, 59, 0, time.UTC)), true},
		{"too far future", timestamppb.New(time.Now().AddDate(0, 0, 2)), true},
		{"epoch zero", timestamppb.New(time.Unix(0, 0)), true},
		{"negative seconds", &timestamppb.Timestamp{Seconds: -62135596800}, true},
		{"invalid nanos", &timestamppb.Timestamp{Seconds: time.Now().Unix(), Nanos: -1}, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := validateTxnDate(tt.ts)
			if tt.wantErr {
				if err == nil {
					t.Errorf("expected error, got time=%v", result)
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}
				if result.IsZero() {
					t.Error("expected non-zero time")
				}
			}
		})
	}
}
