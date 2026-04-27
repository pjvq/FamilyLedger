package family

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/familyledger/server/pkg/db"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/family"
)

const (
	inviteCodeLength  = 8
	inviteCodeCharset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	inviteCodeTTL     = 7 * 24 * time.Hour
)

// permissions is the JSON representation stored in the database.
type permissions struct {
	CanView           bool `json:"can_view"`
	CanCreate         bool `json:"can_create"`
	CanEdit           bool `json:"can_edit"`
	CanDelete         bool `json:"can_delete"`
	CanManageAccounts bool `json:"can_manage_accounts"`
}

func defaultMemberPermissions() permissions {
	return permissions{
		CanView:           true,
		CanCreate:         true,
		CanEdit:           false,
		CanDelete:         false,
		CanManageAccounts: false,
	}
}

func ownerPermissions() permissions {
	return permissions{
		CanView:           true,
		CanCreate:         true,
		CanEdit:           true,
		CanDelete:         true,
		CanManageAccounts: true,
	}
}

type Service struct {
	pb.UnimplementedFamilyServiceServer
	pool db.Pool
}

func NewService(pool db.Pool) *Service {
	return &Service{pool: pool}
}

func (s *Service) CreateFamily(ctx context.Context, req *pb.CreateFamilyRequest) (*pb.CreateFamilyResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.Name == "" {
		return nil, status.Error(codes.InvalidArgument, "family name is required")
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	// Generate initial invite code
	code, err := generateInviteCode()
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to generate invite code")
	}
	expiresAt := time.Now().Add(inviteCodeTTL)

	var familyID uuid.UUID
	var createdAt, updatedAt time.Time
	err = tx.QueryRow(ctx,
		`INSERT INTO families (name, owner_id, invite_code, invite_expires_at)
		 VALUES ($1, $2, $3, $4)
		 RETURNING id, created_at, updated_at`,
		req.Name, uid, code, expiresAt,
	).Scan(&familyID, &createdAt, &updatedAt)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to create family")
	}

	// Add owner as member
	ownerPerms := ownerPermissions()
	permsJSON, _ := json.Marshal(ownerPerms)
	_, err = tx.Exec(ctx,
		`INSERT INTO family_members (family_id, user_id, role, permissions)
		 VALUES ($1, $2, 'owner', $3)`,
		familyID, uid, permsJSON,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to add owner as member")
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit transaction")
	}

	log.Printf("family: created family %s by user %s", familyID, userID)

	return &pb.CreateFamilyResponse{
		Family: &pb.Family{
			Id:              familyID.String(),
			Name:            req.Name,
			OwnerId:         userID,
			InviteCode:      code,
			InviteExpiresAt: timestamppb.New(expiresAt),
			CreatedAt:       timestamppb.New(createdAt),
			UpdatedAt:       timestamppb.New(updatedAt),
		},
	}, nil
}

func (s *Service) JoinFamily(ctx context.Context, req *pb.JoinFamilyRequest) (*pb.JoinFamilyResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.InviteCode == "" {
		return nil, status.Error(codes.InvalidArgument, "invite code is required")
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	// Find family by invite code
	var familyID uuid.UUID
	var familyName, ownerID string
	var inviteExpiresAt *time.Time
	var createdAt, updatedAt time.Time

	err = tx.QueryRow(ctx,
		`SELECT id, name, owner_id, invite_expires_at, created_at, updated_at
		 FROM families WHERE invite_code = $1`,
		req.InviteCode,
	).Scan(&familyID, &familyName, &ownerID, &inviteExpiresAt, &createdAt, &updatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "invalid invite code")
		}
		return nil, status.Error(codes.Internal, "failed to find family")
	}

	// Check expiry
	if inviteExpiresAt != nil && inviteExpiresAt.Before(time.Now()) {
		return nil, status.Error(codes.FailedPrecondition, "invite code has expired")
	}

	// Check if already a member
	var exists bool
	err = tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)`,
		familyID, uid,
	).Scan(&exists)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to check membership")
	}
	if exists {
		return nil, status.Error(codes.AlreadyExists, "already a member of this family")
	}

	// Add member
	defaultPerms := defaultMemberPermissions()
	permsJSON, _ := json.Marshal(defaultPerms)
	_, err = tx.Exec(ctx,
		`INSERT INTO family_members (family_id, user_id, role, permissions)
		 VALUES ($1, $2, 'member', $3)`,
		familyID, uid, permsJSON,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to join family")
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit transaction")
	}

	log.Printf("family: user %s joined family %s", userID, familyID)

	return &pb.JoinFamilyResponse{
		Family: &pb.Family{
			Id:        familyID.String(),
			Name:      familyName,
			OwnerId:   ownerID,
			CreatedAt: timestamppb.New(createdAt),
			UpdatedAt: timestamppb.New(updatedAt),
		},
	}, nil
}

func (s *Service) GetFamily(ctx context.Context, req *pb.GetFamilyRequest) (*pb.GetFamilyResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.FamilyId == "" {
		return nil, status.Error(codes.InvalidArgument, "family_id is required")
	}

	familyID, err := uuid.Parse(req.FamilyId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid family_id")
	}

	// Verify caller is a member
	if err := s.requireMembership(ctx, familyID, userID); err != nil {
		return nil, err
	}

	// Get family
	var name, ownerID string
	var inviteCode *string
	var inviteExpiresAt *time.Time
	var createdAt, updatedAt time.Time

	err = s.pool.QueryRow(ctx,
		`SELECT name, owner_id, invite_code, invite_expires_at, created_at, updated_at
		 FROM families WHERE id = $1`,
		familyID,
	).Scan(&name, &ownerID, &inviteCode, &inviteExpiresAt, &createdAt, &updatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "family not found")
		}
		return nil, status.Error(codes.Internal, "failed to get family")
	}

	family := &pb.Family{
		Id:        familyID.String(),
		Name:      name,
		OwnerId:   ownerID,
		CreatedAt: timestamppb.New(createdAt),
		UpdatedAt: timestamppb.New(updatedAt),
	}
	if inviteCode != nil {
		family.InviteCode = *inviteCode
	}
	if inviteExpiresAt != nil {
		family.InviteExpiresAt = timestamppb.New(*inviteExpiresAt)
	}

	// Get members
	members, err := s.listMembers(ctx, familyID)
	if err != nil {
		return nil, err
	}

	return &pb.GetFamilyResponse{
		Family:  family,
		Members: members,
	}, nil
}

func (s *Service) GenerateInviteCode(ctx context.Context, req *pb.GenerateInviteCodeRequest) (*pb.GenerateInviteCodeResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.FamilyId == "" {
		return nil, status.Error(codes.InvalidArgument, "family_id is required")
	}

	familyID, err := uuid.Parse(req.FamilyId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid family_id")
	}

	// Only owner/admin can generate invite codes
	if err := s.requireRole(ctx, familyID, userID, "owner", "admin"); err != nil {
		return nil, err
	}

	code, err := generateInviteCode()
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to generate invite code")
	}
	expiresAt := time.Now().Add(inviteCodeTTL)

	_, err = s.pool.Exec(ctx,
		`UPDATE families SET invite_code = $1, invite_expires_at = $2, updated_at = NOW() WHERE id = $3`,
		code, expiresAt, familyID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update invite code")
	}

	log.Printf("family: generated invite code for family %s by user %s", familyID, userID)

	return &pb.GenerateInviteCodeResponse{
		InviteCode: code,
		ExpiresAt:  timestamppb.New(expiresAt),
	}, nil
}

func (s *Service) SetMemberRole(ctx context.Context, req *pb.SetMemberRoleRequest) (*pb.SetMemberRoleResponse, error) {
	callerID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.FamilyId == "" || req.UserId == "" {
		return nil, status.Error(codes.InvalidArgument, "family_id and user_id are required")
	}

	familyID, err := uuid.Parse(req.FamilyId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid family_id")
	}

	targetUID, err := uuid.Parse(req.UserId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user_id")
	}

	// Only owner/admin can set roles
	if err := s.requireRole(ctx, familyID, callerID, "owner", "admin"); err != nil {
		return nil, err
	}

	// Map proto role to DB string
	roleStr, err := protoRoleToString(req.Role)
	if err != nil {
		return nil, err
	}

	// Cannot set someone to owner (ownership transfer is separate)
	if roleStr == "owner" {
		return nil, status.Error(codes.InvalidArgument, "cannot directly set owner role; use ownership transfer")
	}

	// Cannot change the owner's role
	var currentRole string
	err = s.pool.QueryRow(ctx,
		`SELECT role FROM family_members WHERE family_id = $1 AND user_id = $2`,
		familyID, targetUID,
	).Scan(&currentRole)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "member not found")
		}
		return nil, status.Error(codes.Internal, "failed to query member")
	}
	if currentRole == "owner" {
		return nil, status.Error(codes.PermissionDenied, "cannot change the owner's role")
	}

	_, err = s.pool.Exec(ctx,
		`UPDATE family_members SET role = $1 WHERE family_id = $2 AND user_id = $3`,
		roleStr, familyID, targetUID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update role")
	}

	log.Printf("family: set role %s for user %s in family %s by %s", roleStr, req.UserId, req.FamilyId, callerID)

	return &pb.SetMemberRoleResponse{}, nil
}

func (s *Service) SetMemberPermissions(ctx context.Context, req *pb.SetMemberPermissionsRequest) (*pb.SetMemberPermissionsResponse, error) {
	callerID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.FamilyId == "" || req.UserId == "" {
		return nil, status.Error(codes.InvalidArgument, "family_id and user_id are required")
	}
	if req.Permissions == nil {
		return nil, status.Error(codes.InvalidArgument, "permissions are required")
	}

	familyID, err := uuid.Parse(req.FamilyId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid family_id")
	}

	targetUID, err := uuid.Parse(req.UserId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid user_id")
	}

	// Only owner/admin can set permissions
	if err := s.requireRole(ctx, familyID, callerID, "owner", "admin"); err != nil {
		return nil, err
	}

	perms := permissions{
		CanView:           req.Permissions.CanView,
		CanCreate:         req.Permissions.CanCreate,
		CanEdit:           req.Permissions.CanEdit,
		CanDelete:         req.Permissions.CanDelete,
		CanManageAccounts: req.Permissions.CanManageAccounts,
	}
	permsJSON, _ := json.Marshal(perms)

	tag, err := s.pool.Exec(ctx,
		`UPDATE family_members SET permissions = $1 WHERE family_id = $2 AND user_id = $3`,
		permsJSON, familyID, targetUID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update permissions")
	}
	if tag.RowsAffected() == 0 {
		return nil, status.Error(codes.NotFound, "member not found")
	}

	log.Printf("family: set permissions for user %s in family %s by %s", req.UserId, req.FamilyId, callerID)

	return &pb.SetMemberPermissionsResponse{}, nil
}

func (s *Service) ListFamilyMembers(ctx context.Context, req *pb.ListFamilyMembersRequest) (*pb.ListFamilyMembersResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.FamilyId == "" {
		return nil, status.Error(codes.InvalidArgument, "family_id is required")
	}

	familyID, err := uuid.Parse(req.FamilyId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid family_id")
	}

	if err := s.requireMembership(ctx, familyID, userID); err != nil {
		return nil, err
	}

	members, err := s.listMembers(ctx, familyID)
	if err != nil {
		return nil, err
	}

	return &pb.ListFamilyMembersResponse{
		Members: members,
	}, nil
}

func (s *Service) LeaveFamily(ctx context.Context, req *pb.LeaveFamilyRequest) (*pb.LeaveFamilyResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.FamilyId == "" {
		return nil, status.Error(codes.InvalidArgument, "family_id is required")
	}

	familyID, err := uuid.Parse(req.FamilyId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid family_id")
	}

	uid, err := uuid.Parse(userID)
	if err != nil {
		return nil, status.Error(codes.Internal, "invalid user id")
	}

	// Check current role
	var role string
	err = s.pool.QueryRow(ctx,
		`SELECT role FROM family_members WHERE family_id = $1 AND user_id = $2`,
		familyID, uid,
	).Scan(&role)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "you are not a member of this family")
		}
		return nil, status.Error(codes.Internal, "failed to check membership")
	}

	if role == "owner" {
		return nil, status.Error(codes.FailedPrecondition, "owner cannot leave the family; transfer ownership first")
	}

	_, err = s.pool.Exec(ctx,
		`DELETE FROM family_members WHERE family_id = $1 AND user_id = $2`,
		familyID, uid,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to leave family")
	}

	log.Printf("family: user %s left family %s", userID, familyID)

	return &pb.LeaveFamilyResponse{}, nil
}

func (s *Service) TransferOwnership(ctx context.Context, req *pb.TransferOwnershipRequest) (*pb.TransferOwnershipResponse, error) {
	callerID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.FamilyId == "" || req.NewOwnerId == "" {
		return nil, status.Error(codes.InvalidArgument, "family_id and new_owner_id are required")
	}

	familyID, err := uuid.Parse(req.FamilyId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid family_id")
	}

	newOwnerUID, err := uuid.Parse(req.NewOwnerId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid new_owner_id")
	}

	if err := s.requireRole(ctx, familyID, callerID, "owner"); err != nil {
		return nil, err
	}

	callerUID, _ := uuid.Parse(callerID)

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	var exists bool
	err = tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)`,
		familyID, newOwnerUID,
	).Scan(&exists)
	if err != nil || !exists {
		return nil, status.Error(codes.NotFound, "new owner is not a member of this family")
	}

	_, err = tx.Exec(ctx,
		`UPDATE family_members SET role = 'admin' WHERE family_id = $1 AND user_id = $2`,
		familyID, callerUID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to demote current owner")
	}

	ownerPerms := ownerPermissions()
	permsJSON, _ := json.Marshal(ownerPerms)
	_, err = tx.Exec(ctx,
		`UPDATE family_members SET role = 'owner', permissions = $1 WHERE family_id = $2 AND user_id = $3`,
		permsJSON, familyID, newOwnerUID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to promote new owner")
	}

	_, err = tx.Exec(ctx,
		`UPDATE families SET owner_id = $1, updated_at = NOW() WHERE id = $2`,
		newOwnerUID, familyID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to update family owner")
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit")
	}

	log.Printf("family: ownership transferred from %s to %s in family %s", callerID, req.NewOwnerId, req.FamilyId)
	return &pb.TransferOwnershipResponse{}, nil
}

func (s *Service) DeleteFamily(ctx context.Context, req *pb.DeleteFamilyRequest) (*pb.DeleteFamilyResponse, error) {
	callerID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.FamilyId == "" {
		return nil, status.Error(codes.InvalidArgument, "family_id is required")
	}

	familyID, err := uuid.Parse(req.FamilyId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid family_id")
	}

	if err := s.requireRole(ctx, familyID, callerID, "owner"); err != nil {
		return nil, err
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, `DELETE FROM family_members WHERE family_id = $1`, familyID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to delete members")
	}

	_, err = tx.Exec(ctx, `DELETE FROM families WHERE id = $1`, familyID)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to delete family")
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit")
	}

	log.Printf("family: deleted family %s by owner %s", req.FamilyId, callerID)
	return &pb.DeleteFamilyResponse{}, nil
}

// ── GetAuditLog ─────────────────────────────────────────────────────────────────

func (s *Service) GetAuditLog(ctx context.Context, req *pb.GetAuditLogRequest) (*pb.GetAuditLogResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	if req.FamilyId == "" {
		return nil, status.Error(codes.InvalidArgument, "family_id is required")
	}

	familyID, err := uuid.Parse(req.FamilyId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid family_id")
	}

	// Verify membership
	if err := s.requireMembership(ctx, familyID, userID); err != nil {
		return nil, err
	}

	pageSize := int32(20)
	if req.PageSize > 0 && req.PageSize <= 100 {
		pageSize = req.PageSize
	}

	// Parse page_token as offset
	offset := int32(0)
	if req.PageToken != "" {
		if parsed, err := parseOffset(req.PageToken); err == nil {
			offset = parsed
		}
	}

	var rows pgx.Rows
	if req.EntityType != "" {
		rows, err = s.pool.Query(ctx,
			`SELECT al.id, al.user_id, COALESCE(u.email, ''), al.action, al.entity_type, al.entity_id, COALESCE(al.changes::text, ''), al.created_at
			 FROM audit_logs al
			 LEFT JOIN users u ON u.id = al.user_id
			 WHERE al.family_id = $1 AND al.entity_type = $2
			 ORDER BY al.created_at DESC
			 LIMIT $3 OFFSET $4`,
			familyID, req.EntityType, pageSize+1, offset,
		)
	} else {
		rows, err = s.pool.Query(ctx,
			`SELECT al.id, al.user_id, COALESCE(u.email, ''), al.action, al.entity_type, al.entity_id, COALESCE(al.changes::text, ''), al.created_at
			 FROM audit_logs al
			 LEFT JOIN users u ON u.id = al.user_id
			 WHERE al.family_id = $1
			 ORDER BY al.created_at DESC
			 LIMIT $2 OFFSET $3`,
			familyID, pageSize+1, offset,
		)
	}
	if err != nil {
		return nil, status.Errorf(codes.Internal, "query audit logs: %v", err)
	}
	defer rows.Close()

	var entries []*pb.AuditEntry
	for rows.Next() {
		var id, uid uuid.UUID
		var userName, action, entityType, entityID, changesJSON string
		var createdAt time.Time

		if err := rows.Scan(&id, &uid, &userName, &action, &entityType, &entityID, &changesJSON, &createdAt); err != nil {
			return nil, status.Errorf(codes.Internal, "scan audit log: %v", err)
		}

		entries = append(entries, &pb.AuditEntry{
			Id:          id.String(),
			UserId:      uid.String(),
			UserName:    userName,
			Action:      action,
			EntityType:  entityType,
			EntityId:    entityID,
			ChangesJson: changesJSON,
			CreatedAt:   createdAt.Unix(),
		})
	}

	var nextPageToken string
	if int32(len(entries)) > pageSize {
		entries = entries[:pageSize]
		nextPageToken = fmt.Sprintf("%d", offset+pageSize)
	}

	if entries == nil {
		entries = []*pb.AuditEntry{}
	}

	return &pb.GetAuditLogResponse{
		Entries:       entries,
		NextPageToken: nextPageToken,
	}, nil
}

func parseOffset(s string) (int32, error) {
	var n int32
	_, err := fmt.Sscanf(s, "%d", &n)
	return n, err
}

// ── Helpers ──────────────────────────────────────────────────────────────────

func (s *Service) requireMembership(ctx context.Context, familyID uuid.UUID, userID string) error {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return status.Error(codes.Internal, "invalid user id")
	}

	var exists bool
	err = s.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)`,
		familyID, uid,
	).Scan(&exists)
	if err != nil {
		return status.Error(codes.Internal, "failed to check membership")
	}
	if !exists {
		return status.Error(codes.PermissionDenied, "not a member of this family")
	}
	return nil
}

func (s *Service) requireRole(ctx context.Context, familyID uuid.UUID, userID string, allowedRoles ...string) error {
	uid, err := uuid.Parse(userID)
	if err != nil {
		return status.Error(codes.Internal, "invalid user id")
	}

	var role string
	err = s.pool.QueryRow(ctx,
		`SELECT role FROM family_members WHERE family_id = $1 AND user_id = $2`,
		familyID, uid,
	).Scan(&role)
	if err != nil {
		if err == pgx.ErrNoRows {
			return status.Error(codes.PermissionDenied, "not a member of this family")
		}
		return status.Error(codes.Internal, "failed to check role")
	}

	for _, allowed := range allowedRoles {
		if role == allowed {
			return nil
		}
	}

	return status.Error(codes.PermissionDenied, fmt.Sprintf("insufficient role: %s", role))
}

func (s *Service) listMembers(ctx context.Context, familyID uuid.UUID) ([]*pb.FamilyMember, error) {
	rows, err := s.pool.Query(ctx,
		`SELECT fm.id, fm.user_id, u.email, fm.role, fm.permissions, fm.joined_at
		 FROM family_members fm
		 JOIN users u ON u.id = fm.user_id
		 WHERE fm.family_id = $1
		 ORDER BY fm.joined_at ASC`,
		familyID,
	)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to query members")
	}
	defer rows.Close()

	var members []*pb.FamilyMember
	for rows.Next() {
		var id, uid uuid.UUID
		var email, roleStr string
		var permsJSON []byte
		var joinedAt time.Time

		if err := rows.Scan(&id, &uid, &email, &roleStr, &permsJSON, &joinedAt); err != nil {
			return nil, status.Error(codes.Internal, "failed to scan member")
		}

		var perms permissions
		if err := json.Unmarshal(permsJSON, &perms); err != nil {
			return nil, status.Error(codes.Internal, "failed to parse permissions")
		}

		members = append(members, &pb.FamilyMember{
			Id:     id.String(),
			UserId: uid.String(),
			Email:  email,
			Role:   stringToProtoRole(roleStr),
			Permissions: &pb.MemberPermissions{
				CanView:           perms.CanView,
				CanCreate:         perms.CanCreate,
				CanEdit:           perms.CanEdit,
				CanDelete:         perms.CanDelete,
				CanManageAccounts: perms.CanManageAccounts,
			},
			JoinedAt: timestamppb.New(joinedAt),
		})
	}

	if members == nil {
		members = []*pb.FamilyMember{}
	}

	return members, nil
}

func generateInviteCode() (string, error) {
	b := make([]byte, inviteCodeLength)
	for i := range b {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(inviteCodeCharset))))
		if err != nil {
			return "", err
		}
		b[i] = inviteCodeCharset[n.Int64()]
	}
	return string(b), nil
}

func protoRoleToString(role pb.FamilyRole) (string, error) {
	switch role {
	case pb.FamilyRole_FAMILY_ROLE_OWNER:
		return "owner", nil
	case pb.FamilyRole_FAMILY_ROLE_ADMIN:
		return "admin", nil
	case pb.FamilyRole_FAMILY_ROLE_MEMBER:
		return "member", nil
	default:
		return "", status.Error(codes.InvalidArgument, "invalid role")
	}
}

func stringToProtoRole(role string) pb.FamilyRole {
	switch role {
	case "owner":
		return pb.FamilyRole_FAMILY_ROLE_OWNER
	case "admin":
		return pb.FamilyRole_FAMILY_ROLE_ADMIN
	case "member":
		return pb.FamilyRole_FAMILY_ROLE_MEMBER
	default:
		return pb.FamilyRole_FAMILY_ROLE_UNSPECIFIED
	}
}
