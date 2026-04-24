package permission

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// Pool is a minimal interface for database queries.
type Pool interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// Permissions represents the JSON-stored member permissions.
type Permissions struct {
	CanView           bool `json:"can_view"`
	CanCreate         bool `json:"can_create"`
	CanEdit           bool `json:"can_edit"`
	CanDelete         bool `json:"can_delete"`
	CanManageAccounts bool `json:"can_manage_accounts"`
}

// Check verifies that the user has the required permission for the given family.
// If familyID is empty, this is a personal operation and no permission check is needed.
// Returns nil if allowed, or a gRPC PermissionDenied error.
func Check(ctx context.Context, pool Pool, userID string, familyID string, required func(Permissions) bool) error {
	if familyID == "" {
		return nil // personal mode, no permission check
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return status.Error(codes.Internal, "invalid user id")
	}
	fid, err := uuid.Parse(familyID)
	if err != nil {
		return status.Error(codes.InvalidArgument, "invalid family_id")
	}

	var role string
	var permsJSON []byte
	err = pool.QueryRow(ctx,
		"SELECT role, permissions FROM family_members WHERE family_id = $1 AND user_id = $2",
		fid, uid,
	).Scan(&role, &permsJSON)
	if err != nil {
		if err == pgx.ErrNoRows {
			return status.Error(codes.PermissionDenied, "not a member of this family")
		}
		return status.Error(codes.Internal, fmt.Sprintf("failed to check permissions: %v", err))
	}

	// Owner and admin bypass permission checks
	if role == "owner" || role == "admin" {
		return nil
	}

	var perms Permissions
	if err := json.Unmarshal(permsJSON, &perms); err != nil {
		return status.Error(codes.Internal, "corrupted permissions data")
	}

	if !required(perms) {
		return status.Error(codes.PermissionDenied, "insufficient permissions for this operation")
	}

	return nil
}

// CanView checks view permission.
func CanView(p Permissions) bool { return p.CanView }

// CanCreate checks create permission.
func CanCreate(p Permissions) bool { return p.CanCreate }

// CanEdit checks edit permission.
func CanEdit(p Permissions) bool { return p.CanEdit }

// CanDelete checks delete permission.
func CanDelete(p Permissions) bool { return p.CanDelete }

// CanManageAccounts checks account management permission.
func CanManageAccounts(p Permissions) bool { return p.CanManageAccounts }
