package middleware

import (
	"strings"
	"testing"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func TestValidateEmail(t *testing.T) {
	tests := []struct {
		email string
		valid bool
	}{
		{"user@example.com", true},
		{"user@test.co", true},
		{"", false},
		{"noatsign.com", false},
		{"nodot@localhost", false},
		{strings.Repeat("a", 321), false},
	}
	for _, tt := range tests {
		err := ValidateEmail(tt.email)
		if tt.valid && err != nil {
			t.Errorf("ValidateEmail(%q) should pass, got: %v", tt.email, err)
		}
		if !tt.valid && err == nil {
			t.Errorf("ValidateEmail(%q) should fail", tt.email)
		}
	}
}

func TestValidatePassword(t *testing.T) {
	tests := []struct {
		pw    string
		valid bool
	}{
		{"Password1", true},
		{"12345678", true},
		{"short", false},
		{"", false},
		{strings.Repeat("x", 129), false},
	}
	for _, tt := range tests {
		err := ValidatePassword(tt.pw)
		if tt.valid && err != nil {
			t.Errorf("ValidatePassword(%q) should pass, got: %v", tt.pw, err)
		}
		if !tt.valid && err == nil {
			t.Errorf("ValidatePassword(%q) should fail", tt.pw)
		}
	}
}

func TestValidateStringField(t *testing.T) {
	err := ValidateStringField("hello", "name", 10)
	if err != nil {
		t.Fatalf("should pass: %v", err)
	}

	err = ValidateStringField("too long", "name", 3)
	if err == nil {
		t.Fatal("should fail")
	}
	st, _ := status.FromError(err)
	if st.Code() != codes.InvalidArgument {
		t.Fatalf("expected InvalidArgument, got %v", st.Code())
	}
}
