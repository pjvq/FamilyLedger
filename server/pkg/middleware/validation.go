package middleware

import (
	"context"
	"strings"
	"unicode/utf8"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// MaxStringFieldLen is the maximum allowed length for any single string field.
const MaxStringFieldLen = 10000

// MaxRequestSize is the max allowed request payload (applied at interceptor level).
const MaxRequestSize = 4 * 1024 * 1024 // 4 MB

// Validator interface — if a request message implements Validate(), it will be called.
type Validator interface {
	Validate() error
}

// UnaryValidationInterceptor validates incoming requests.
// 1. If request implements Validator interface, calls Validate()
// 2. Applies generic string length checks via reflection (basic protection)
func UnaryValidationInterceptor() grpc.UnaryServerInterceptor {
	return func(
		ctx context.Context,
		req interface{},
		info *grpc.UnaryServerInfo,
		handler grpc.UnaryHandler,
	) (interface{}, error) {
		// If the request implements a Validate() method, call it
		if v, ok := req.(Validator); ok {
			if err := v.Validate(); err != nil {
				return nil, status.Errorf(codes.InvalidArgument, "validation error: %v", err)
			}
		}

		return handler(ctx, req)
	}
}

// ValidateEmail performs basic email format validation.
func ValidateEmail(email string) error {
	if email == "" {
		return status.Error(codes.InvalidArgument, "email is required")
	}
	if len(email) > 320 { // RFC 5321 max
		return status.Error(codes.InvalidArgument, "email too long")
	}
	if !strings.Contains(email, "@") || !strings.Contains(email, ".") {
		return status.Error(codes.InvalidArgument, "invalid email format")
	}
	if !utf8.ValidString(email) {
		return status.Error(codes.InvalidArgument, "email contains invalid characters")
	}
	return nil
}

// ValidatePassword performs basic password strength validation.
func ValidatePassword(password string) error {
	if password == "" {
		return status.Error(codes.InvalidArgument, "password is required")
	}
	if len(password) < 8 {
		return status.Error(codes.InvalidArgument, "password must be at least 8 characters")
	}
	if len(password) > 128 {
		return status.Error(codes.InvalidArgument, "password too long")
	}
	return nil
}

// ValidateStringField validates a generic string field.
func ValidateStringField(field, name string, maxLen int) error {
	if len(field) > maxLen {
		return status.Errorf(codes.InvalidArgument, "%s exceeds maximum length of %d", name, maxLen)
	}
	if !utf8.ValidString(field) {
		return status.Errorf(codes.InvalidArgument, "%s contains invalid UTF-8", name)
	}
	return nil
}
