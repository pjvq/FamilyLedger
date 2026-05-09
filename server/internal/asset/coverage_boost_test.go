package asset

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	pb "github.com/familyledger/server/proto/asset"
)

// ═══════════════════════════════════════════════════════════════════════════
// CreateAsset — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_CreateAsset_MissingType(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.CreateAsset(authedCtx(), &pb.CreateAssetRequest{
		Name: "test", PurchasePrice: 100, PurchaseDate: timestamppb.Now(),
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_CreateAsset_MissingDate(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.CreateAsset(authedCtx(), &pb.CreateAssetRequest{
		Name: "test", AssetType: pb.AssetType_ASSET_TYPE_VEHICLE, PurchasePrice: 100,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_CreateAsset_InvalidFamilyID(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.CreateAsset(authedCtx(), &pb.CreateAssetRequest{
		Name: "test", AssetType: pb.AssetType_ASSET_TYPE_VEHICLE, PurchasePrice: 100,
		PurchaseDate: timestamppb.Now(), FamilyId: "not-a-uuid",
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_CreateAsset_BeginFail(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectBegin().WillReturnError(errors.New("conn fail"))
	_, err := svc.CreateAsset(authedCtx(), &pb.CreateAssetRequest{
		Name: "test", AssetType: pb.AssetType_ASSET_TYPE_VEHICLE, PurchasePrice: 100,
		PurchaseDate: timestamppb.Now(),
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_CreateAsset_InsertFail(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO fixed_assets").
		WithArgs(testUserID, "test", "vehicle", int64(100), pgxmock.AnyArg(), pgxmock.AnyArg(), (*uuid.UUID)(nil)).
		WillReturnError(errors.New("db error"))
	mock.ExpectRollback()
	_, err := svc.CreateAsset(authedCtx(), &pb.CreateAssetRequest{
		Name: "test", AssetType: pb.AssetType_ASSET_TYPE_VEHICLE, PurchasePrice: 100,
		PurchaseDate: timestamppb.Now(),
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_CreateAsset_ValuationInsertFail(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()
	now := time.Now()
	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO fixed_assets").
		WithArgs(testUserID, "test", "vehicle", int64(100), pgxmock.AnyArg(), pgxmock.AnyArg(), (*uuid.UUID)(nil)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(id, now, now))
	mock.ExpectExec("INSERT INTO asset_valuations").
		WithArgs(id, int64(100), pgxmock.AnyArg()).
		WillReturnError(errors.New("valuation insert fail"))
	mock.ExpectRollback()
	_, err := svc.CreateAsset(authedCtx(), &pb.CreateAssetRequest{
		Name: "test", AssetType: pb.AssetType_ASSET_TYPE_VEHICLE, PurchasePrice: 100,
		PurchaseDate: timestamppb.Now(),
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_CreateAsset_CommitFail(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()
	now := time.Now()
	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO fixed_assets").
		WithArgs(testUserID, "test", "vehicle", int64(100), pgxmock.AnyArg(), pgxmock.AnyArg(), (*uuid.UUID)(nil)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(id, now, now))
	mock.ExpectExec("INSERT INTO asset_valuations").
		WithArgs(id, int64(100), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit().WillReturnError(errors.New("commit fail"))
	mock.ExpectRollback()
	_, err := svc.CreateAsset(authedCtx(), &pb.CreateAssetRequest{
		Name: "test", AssetType: pb.AssetType_ASSET_TYPE_VEHICLE, PurchasePrice: 100,
		PurchaseDate: timestamppb.Now(),
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_CreateAsset_WithFamilyPermission(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)

	familyID := uuid.New()
	id := uuid.New()
	now := time.Now()

	// permission.Check
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(familyID, pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))
	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO fixed_assets").
		WithArgs(testUserID, "Family Car", "vehicle", int64(200000), pgxmock.AnyArg(), pgxmock.AnyArg(), &familyID).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(id, now, now))
	mock.ExpectExec("INSERT INTO asset_valuations").
		WithArgs(id, int64(200000), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit()

	resp, err := svc.CreateAsset(authedCtx(), &pb.CreateAssetRequest{
		Name: "Family Car", AssetType: pb.AssetType_ASSET_TYPE_VEHICLE, PurchasePrice: 200000,
		PurchaseDate: timestamppb.Now(), FamilyId: familyID.String(),
	})
	require.NoError(t, err)
	assert.Equal(t, "Family Car", resp.Name)
}

// ═══════════════════════════════════════════════════════════════════════════
// ListAssets — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_ListAssets_NoAuth(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.ListAssets(context.Background(), &pb.ListAssetsRequest{})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCB_ListAssets_FamilyMode_Success(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	familyID := uuid.New()
	assetID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(familyID.String(), testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	listCols := []string{"id", "user_id", "name", "asset_type", "purchase_price", "current_value",
		"purchase_date", "description", "family_id", "created_at", "updated_at"}
	mock.ExpectQuery("SELECT id, user_id, name").
		WithArgs(familyID.String()).
		WillReturnRows(pgxmock.NewRows(listCols).AddRow(
			assetID, testUserID, "Car", "vehicle", int64(100000), int64(80000),
			now, (*string)(nil), (*uuid.UUID)(nil), now, now,
		))
	resp, err := svc.ListAssets(authedCtx(), &pb.ListAssetsRequest{FamilyId: familyID.String()})
	require.NoError(t, err)
	assert.Len(t, resp.Assets, 1)
}

func TestCB_ListAssets_FamilyMode_NotMember(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	familyID := uuid.New()
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(familyID.String(), testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))
	_, err := svc.ListAssets(authedCtx(), &pb.ListAssetsRequest{FamilyId: familyID.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestCB_ListAssets_FamilyMode_MemberQueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	familyID := uuid.New()
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(familyID.String(), testUserID).
		WillReturnError(errors.New("db fail"))
	_, err := svc.ListAssets(authedCtx(), &pb.ListAssetsRequest{FamilyId: familyID.String()})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_ListAssets_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT id, user_id, name").
		WithArgs(testUserID).
		WillReturnError(errors.New("query fail"))
	_, err := svc.ListAssets(authedCtx(), &pb.ListAssetsRequest{})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// UpdateAsset — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_UpdateAsset_NoAuth(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.UpdateAsset(context.Background(), &pb.UpdateAssetRequest{AssetId: "test"})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCB_UpdateAsset_NotFound(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM fixed_assets").
		WithArgs("some-id").
		WillReturnError(pgx.ErrNoRows)
	_, err := svc.UpdateAsset(authedCtx(), &pb.UpdateAssetRequest{AssetId: "some-id", Name: "new"})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestCB_UpdateAsset_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM fixed_assets").
		WithArgs("some-id").
		WillReturnError(errors.New("db err"))
	_, err := svc.UpdateAsset(authedCtx(), &pb.UpdateAssetRequest{AssetId: "some-id", Name: "new"})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_UpdateAsset_NotOwner_NoFamily(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM fixed_assets").
		WithArgs("some-id").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow("other-user", (*string)(nil)))
	_, err := svc.UpdateAsset(authedCtx(), &pb.UpdateAssetRequest{AssetId: "some-id", Name: "new"})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestCB_UpdateAsset_NotOwner_FamilyPermCheck(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	familyID := uuid.New().String()

	mock.ExpectQuery("SELECT user_id, family_id FROM fixed_assets").
		WithArgs("some-id").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow("other-user", &familyID))
	// permission.Check
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))
	mock.ExpectExec("UPDATE fixed_assets SET").
		WithArgs("new", pgxmock.AnyArg(), "some-id").
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// loadAsset after update — return same owner so it triggers permission check
	assetID := uuid.New()
	now := time.Now()
	famUID := uuid.MustParse(familyID)
	mock.ExpectQuery("SELECT id, user_id, name").
		WithArgs("some-id").
		WillReturnRows(pgxmock.NewRows(assetCols()).AddRow(
			assetID, "other-user", "Updated", "vehicle", int64(100), int64(80),
			now, (*string)(nil), &famUID, now, now,
		))
	// loadAsset permission.Check for family
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))

	resp, err := svc.UpdateAsset(authedCtx(), &pb.UpdateAssetRequest{AssetId: "some-id", Name: "new"})
	require.NoError(t, err)
	assert.Equal(t, "Updated", resp.Name)
}

func TestCB_UpdateAsset_ExecError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM fixed_assets").
		WithArgs("some-id").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectExec("UPDATE fixed_assets SET").
		WithArgs("new", pgxmock.AnyArg(), "some-id").
		WillReturnError(errors.New("exec fail"))
	_, err := svc.UpdateAsset(authedCtx(), &pb.UpdateAssetRequest{AssetId: "some-id", Name: "new"})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_UpdateAsset_ZeroRowsAffected(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM fixed_assets").
		WithArgs("some-id").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectExec("UPDATE fixed_assets SET").
		WithArgs("new", pgxmock.AnyArg(), "some-id").
		WillReturnResult(pgxmock.NewResult("UPDATE", 0))
	_, err := svc.UpdateAsset(authedCtx(), &pb.UpdateAssetRequest{AssetId: "some-id", Name: "new"})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// DeleteAsset — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_DeleteAsset_NoAuth(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.DeleteAsset(context.Background(), &pb.DeleteAssetRequest{AssetId: "test"})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCB_DeleteAsset_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM fixed_assets").
		WithArgs("some-id").
		WillReturnError(errors.New("db err"))
	_, err := svc.DeleteAsset(authedCtx(), &pb.DeleteAssetRequest{AssetId: "some-id"})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_DeleteAsset_NotOwner_NoFamily(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM fixed_assets").
		WithArgs("some-id").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow("other-user", (*string)(nil)))
	_, err := svc.DeleteAsset(authedCtx(), &pb.DeleteAssetRequest{AssetId: "some-id"})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestCB_DeleteAsset_NotOwner_FamilyPerm(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	familyID := uuid.New().String()
	mock.ExpectQuery("SELECT user_id, family_id FROM fixed_assets").
		WithArgs("some-id").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow("other-user", &familyID))
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))
	mock.ExpectExec("UPDATE fixed_assets SET deleted_at").
		WithArgs("some-id").
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	resp, err := svc.DeleteAsset(authedCtx(), &pb.DeleteAssetRequest{AssetId: "some-id"})
	require.NoError(t, err)
	assert.NotNil(t, resp)
}

func TestCB_DeleteAsset_ExecError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT user_id, family_id FROM fixed_assets").
		WithArgs("some-id").
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectExec("UPDATE fixed_assets SET deleted_at").
		WithArgs("some-id").
		WillReturnError(errors.New("exec fail"))
	_, err := svc.DeleteAsset(authedCtx(), &pb.DeleteAssetRequest{AssetId: "some-id"})
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// RunDepreciation
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_RunDepreciation_NoAuth(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.RunDepreciation(context.Background(), &pb.RunDepreciationRequest{AssetId: "x"})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCB_RunDepreciation_EmptyID(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.RunDepreciation(authedCtx(), &pb.RunDepreciationRequest{AssetId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_RunDepreciation_NotFound(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT fa.id, fa.user_id").
		WithArgs("some-id").
		WillReturnError(pgx.ErrNoRows)
	_, err := svc.RunDepreciation(authedCtx(), &pb.RunDepreciationRequest{AssetId: "some-id"})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestCB_RunDepreciation_NoRule(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	now := time.Now()
	cols := []string{"id", "user_id", "purchase_price", "current_value", "purchase_date",
		"method", "useful_life_years", "salvage_rate"}
	mock.ExpectQuery("SELECT fa.id, fa.user_id").
		WithArgs("asset-1").
		WillReturnRows(pgxmock.NewRows(cols).AddRow(
			"asset-1", testUserID, int64(100000), int64(80000), now,
			(*string)(nil), (*int)(nil), (*float64)(nil),
		))
	_, err := svc.RunDepreciation(authedCtx(), &pb.RunDepreciationRequest{AssetId: "asset-1"})
	assert.Equal(t, codes.FailedPrecondition, status.Code(err))
}

func TestCB_RunDepreciation_MethodNone(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	now := time.Now()
	method := "none"
	usefulLife := 5
	salvageRate := 0.05
	cols := []string{"id", "user_id", "purchase_price", "current_value", "purchase_date",
		"method", "useful_life_years", "salvage_rate"}
	mock.ExpectQuery("SELECT fa.id, fa.user_id").
		WithArgs("asset-1").
		WillReturnRows(pgxmock.NewRows(cols).AddRow(
			"asset-1", testUserID, int64(100000), int64(80000), now,
			&method, &usefulLife, &salvageRate,
		))
	_, err := svc.RunDepreciation(authedCtx(), &pb.RunDepreciationRequest{AssetId: "asset-1"})
	assert.Equal(t, codes.FailedPrecondition, status.Code(err))
}

func TestCB_RunDepreciation_StraightLine(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	purchaseDate := time.Now().AddDate(-1, 0, 0)
	method := "straight_line"
	usefulLife := 5
	salvageRate := 0.05
	cols := []string{"id", "user_id", "purchase_price", "current_value", "purchase_date",
		"method", "useful_life_years", "salvage_rate"}
	mock.ExpectQuery("SELECT fa.id, fa.user_id").
		WithArgs("asset-1").
		WillReturnRows(pgxmock.NewRows(cols).AddRow(
			"asset-1", testUserID, int64(100000), int64(80000), purchaseDate,
			&method, &usefulLife, &salvageRate,
		))
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE fixed_assets SET current_value").
		WithArgs(pgxmock.AnyArg(), "asset-1").
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("INSERT INTO asset_valuations").
		WithArgs("asset-1", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit()
	// loadAsset after
	assetID := uuid.New()
	now := time.Now()
	mock.ExpectQuery("SELECT id, user_id, name").
		WithArgs("asset-1").
		WillReturnRows(pgxmock.NewRows(assetCols()).AddRow(
			assetID, testUserID, "MacBook", "electronics", int64(100000), int64(78417),
			purchaseDate, (*string)(nil), (*uuid.UUID)(nil), now, now,
		))
	resp, err := svc.RunDepreciation(authedCtx(), &pb.RunDepreciationRequest{AssetId: "asset-1"})
	require.NoError(t, err)
	assert.NotNil(t, resp)
}

func TestCB_RunDepreciation_DoubleDeclining(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	purchaseDate := time.Now().AddDate(-1, 0, 0)
	method := "double_declining"
	usefulLife := 5
	salvageRate := 0.05
	cols := []string{"id", "user_id", "purchase_price", "current_value", "purchase_date",
		"method", "useful_life_years", "salvage_rate"}
	mock.ExpectQuery("SELECT fa.id, fa.user_id").
		WithArgs("asset-1").
		WillReturnRows(pgxmock.NewRows(cols).AddRow(
			"asset-1", testUserID, int64(100000), int64(80000), purchaseDate,
			&method, &usefulLife, &salvageRate,
		))
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE fixed_assets SET current_value").
		WithArgs(pgxmock.AnyArg(), "asset-1").
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("INSERT INTO asset_valuations").
		WithArgs("asset-1", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit()
	assetID := uuid.New()
	now := time.Now()
	mock.ExpectQuery("SELECT id, user_id, name").
		WithArgs("asset-1").
		WillReturnRows(pgxmock.NewRows(assetCols()).AddRow(
			assetID, testUserID, "MacBook", "electronics", int64(100000), int64(77333),
			purchaseDate, (*string)(nil), (*uuid.UUID)(nil), now, now,
		))
	resp, err := svc.RunDepreciation(authedCtx(), &pb.RunDepreciationRequest{AssetId: "asset-1"})
	require.NoError(t, err)
	assert.NotNil(t, resp)
}

func TestCB_RunDepreciation_PermissionDenied(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	now := time.Now()
	method := "straight_line"
	usefulLife := 5
	salvageRate := 0.05
	cols := []string{"id", "user_id", "purchase_price", "current_value", "purchase_date",
		"method", "useful_life_years", "salvage_rate"}
	mock.ExpectQuery("SELECT fa.id, fa.user_id").
		WithArgs("asset-1").
		WillReturnRows(pgxmock.NewRows(cols).AddRow(
			"asset-1", "other-user", int64(100000), int64(80000), now,
			&method, &usefulLife, &salvageRate,
		))
	_, err := svc.RunDepreciation(authedCtx(), &pb.RunDepreciationRequest{AssetId: "asset-1"})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// RunMonthlyDepreciationAll
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_RunMonthlyDepreciationAll_Success(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	purchaseDate := time.Now().AddDate(-1, 0, 0)
	cols := []string{"id", "user_id", "purchase_price", "current_value", "purchase_date",
		"method", "useful_life_years", "salvage_rate"}
	mock.ExpectQuery("SELECT fa.id, fa.user_id").
		WillReturnRows(pgxmock.NewRows(cols).AddRow(
			"asset-1", testUserID, int64(100000), int64(80000), purchaseDate,
			"straight_line", 5, 0.05,
		))
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE fixed_assets SET current_value").
		WithArgs(pgxmock.AnyArg(), "asset-1").
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("INSERT INTO asset_valuations").
		WithArgs("asset-1", pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit()
	err := svc.RunMonthlyDepreciationAll(context.Background())
	require.NoError(t, err)
}

func TestCB_RunMonthlyDepreciationAll_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT fa.id, fa.user_id").WillReturnError(errors.New("db fail"))
	err := svc.RunMonthlyDepreciationAll(context.Background())
	assert.Error(t, err)
}

func TestCB_RunMonthlyDepreciationAll_Empty(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	cols := []string{"id", "user_id", "purchase_price", "current_value", "purchase_date",
		"method", "useful_life_years", "salvage_rate"}
	mock.ExpectQuery("SELECT fa.id, fa.user_id").WillReturnRows(pgxmock.NewRows(cols))
	err := svc.RunMonthlyDepreciationAll(context.Background())
	assert.NoError(t, err)
}

// ═══════════════════════════════════════════════════════════════════════════
// applyMonthlyDepreciation — edge cases
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_ApplyMonthlyDepreciation_AlreadyAtSalvage(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	asset := &assetData{id: "a1", purchasePrice: 100000, currentValue: 5000, purchaseDate: time.Now().AddDate(-5, 0, 0)}
	rule := &ruleData{method: "straight_line", usefulLifeYears: 5, salvageRate: 0.05}
	val, err := svc.applyMonthlyDepreciation(context.Background(), asset, rule)
	require.NoError(t, err)
	assert.Equal(t, int64(5000), val)
}

func TestCB_ApplyMonthlyDepreciation_UnknownMethod(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	asset := &assetData{id: "a1", purchasePrice: 100000, currentValue: 80000, purchaseDate: time.Now().AddDate(-1, 0, 0)}
	rule := &ruleData{method: "unknown_method", usefulLifeYears: 5, salvageRate: 0.05}
	_, err := svc.applyMonthlyDepreciation(context.Background(), asset, rule)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_ApplyMonthlyDepreciation_BeginFail(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	asset := &assetData{id: "a1", purchasePrice: 100000, currentValue: 80000, purchaseDate: time.Now().AddDate(-1, 0, 0)}
	rule := &ruleData{method: "straight_line", usefulLifeYears: 5, salvageRate: 0.05}
	mock.ExpectBegin().WillReturnError(errors.New("begin fail"))
	_, err := svc.applyMonthlyDepreciation(context.Background(), asset, rule)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_ApplyMonthlyDepreciation_UpdateFail(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	asset := &assetData{id: "a1", purchasePrice: 100000, currentValue: 80000, purchaseDate: time.Now().AddDate(-1, 0, 0)}
	rule := &ruleData{method: "straight_line", usefulLifeYears: 5, salvageRate: 0.05}
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE fixed_assets SET current_value").
		WithArgs(pgxmock.AnyArg(), "a1").WillReturnError(errors.New("update fail"))
	mock.ExpectRollback()
	_, err := svc.applyMonthlyDepreciation(context.Background(), asset, rule)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_ApplyMonthlyDepreciation_InsertValuationFail(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	asset := &assetData{id: "a1", purchasePrice: 100000, currentValue: 80000, purchaseDate: time.Now().AddDate(-1, 0, 0)}
	rule := &ruleData{method: "straight_line", usefulLifeYears: 5, salvageRate: 0.05}
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE fixed_assets SET current_value").
		WithArgs(pgxmock.AnyArg(), "a1").WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("INSERT INTO asset_valuations").
		WithArgs("a1", pgxmock.AnyArg(), pgxmock.AnyArg()).WillReturnError(errors.New("insert fail"))
	mock.ExpectRollback()
	_, err := svc.applyMonthlyDepreciation(context.Background(), asset, rule)
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_ApplyMonthlyDepreciation_CommitFail(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	asset := &assetData{id: "a1", purchasePrice: 100000, currentValue: 80000, purchaseDate: time.Now().AddDate(-1, 0, 0)}
	rule := &ruleData{method: "straight_line", usefulLifeYears: 5, salvageRate: 0.05}
	mock.ExpectBegin()
	mock.ExpectExec("UPDATE fixed_assets SET current_value").
		WithArgs(pgxmock.AnyArg(), "a1").WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectExec("INSERT INTO asset_valuations").
		WithArgs("a1", pgxmock.AnyArg(), pgxmock.AnyArg()).WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit().WillReturnError(errors.New("commit fail"))
	mock.ExpectRollback()
	_, err := svc.applyMonthlyDepreciation(context.Background(), asset, rule)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// loadAssetWithRule
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_LoadAssetWithRule_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT fa.id, fa.user_id").WithArgs("a1").WillReturnError(errors.New("db fail"))
	_, _, err := svc.loadAssetWithRule(context.Background(), "a1", testUserID)
	assert.Equal(t, codes.Internal, status.Code(err))
}

// ═══════════════════════════════════════════════════════════════════════════
// calcDoubleDecliningMonthly — edge cases
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_CalcDoubleDeclining_LastTwoYears_NegativeDep(t *testing.T) {
	asset := &assetData{purchasePrice: 100000, currentValue: 3000, purchaseDate: time.Now().AddDate(-4, 0, 0)}
	result := calcDoubleDecliningMonthly(asset, 5000, 5)
	assert.Equal(t, int64(0), result)
}

func TestCB_CalcDoubleDeclining_RemainingZero(t *testing.T) {
	asset := &assetData{purchasePrice: 100000, currentValue: 80000, purchaseDate: time.Now().AddDate(-6, 0, 0)}
	result := calcDoubleDecliningMonthly(asset, 5000, 5)
	assert.Equal(t, int64(0), result)
}

// ═══════════════════════════════════════════════════════════════════════════
// Type conversion — remaining branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_AssetTypeToString_AllTypes(t *testing.T) {
	tests := []struct {
		input pb.AssetType
		want  string
	}{
		{pb.AssetType_ASSET_TYPE_REAL_ESTATE, "real_estate"},
		{pb.AssetType_ASSET_TYPE_VEHICLE, "vehicle"},
		{pb.AssetType_ASSET_TYPE_ELECTRONICS, "electronics"},
		{pb.AssetType_ASSET_TYPE_FURNITURE, "furniture"},
		{pb.AssetType_ASSET_TYPE_JEWELRY, "jewelry"},
		{pb.AssetType_ASSET_TYPE_OTHER, "other"},
		{pb.AssetType_ASSET_TYPE_UNSPECIFIED, "unspecified"},
		{pb.AssetType(999), "unspecified"},
	}
	for _, tt := range tests {
		assert.Equal(t, tt.want, assetTypeToString(tt.input))
	}
}

func TestCB_StringToAssetType_AllTypes(t *testing.T) {
	tests := []struct {
		input string
		want  pb.AssetType
	}{
		{"real_estate", pb.AssetType_ASSET_TYPE_REAL_ESTATE},
		{"vehicle", pb.AssetType_ASSET_TYPE_VEHICLE},
		{"electronics", pb.AssetType_ASSET_TYPE_ELECTRONICS},
		{"furniture", pb.AssetType_ASSET_TYPE_FURNITURE},
		{"jewelry", pb.AssetType_ASSET_TYPE_JEWELRY},
		{"other", pb.AssetType_ASSET_TYPE_OTHER},
		{"unknown", pb.AssetType_ASSET_TYPE_UNSPECIFIED},
	}
	for _, tt := range tests {
		assert.Equal(t, tt.want, stringToAssetType(tt.input))
	}
}

func TestCB_DepreciationMethodToString_AllTypes(t *testing.T) {
	tests := []struct {
		input pb.DepreciationMethod
		want  string
	}{
		{pb.DepreciationMethod_DEPRECIATION_METHOD_STRAIGHT_LINE, "straight_line"},
		{pb.DepreciationMethod_DEPRECIATION_METHOD_DOUBLE_DECLINING, "double_declining"},
		{pb.DepreciationMethod_DEPRECIATION_METHOD_NONE, "none"},
		{pb.DepreciationMethod_DEPRECIATION_METHOD_UNSPECIFIED, "unspecified"},
		{pb.DepreciationMethod(999), "unspecified"},
	}
	for _, tt := range tests {
		assert.Equal(t, tt.want, depreciationMethodToString(tt.input))
	}
}

func TestCB_GetDepreciationPreset_AllTypes(t *testing.T) {
	tests := []struct {
		assetType string
		wantLife  int
		wantRate  float64
	}{
		{"vehicle", 5, 0.05},
		{"electronics", 3, 0.05},
		{"furniture", 5, 0.05},
		{"other", 5, 0.05},
		{"real_estate", 10, 0.10},
		{"jewelry", 10, 0.10},
		{"unknown", 10, 0.10},
	}
	for _, tt := range tests {
		life, rate := getDepreciationPreset(tt.assetType)
		assert.Equal(t, tt.wantLife, life, "life for %s", tt.assetType)
		assert.Equal(t, tt.wantRate, rate, "rate for %s", tt.assetType)
	}
}

// ═══════════════════════════════════════════════════════════════════════════
// SetDepreciationRule — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_SetDepreciationRule_NoAuth(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.SetDepreciationRule(context.Background(), &pb.SetDepreciationRuleRequest{AssetId: "x"})
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCB_SetDepreciationRule_MethodUnspecified(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	_, err := svc.SetDepreciationRule(authedCtx(), &pb.SetDepreciationRuleRequest{AssetId: "x"})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_SetDepreciationRule_NotFound(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT asset_type FROM fixed_assets").
		WithArgs("x", testUserID).WillReturnError(pgx.ErrNoRows)
	_, err := svc.SetDepreciationRule(authedCtx(), &pb.SetDepreciationRuleRequest{
		AssetId: "x", Method: pb.DepreciationMethod_DEPRECIATION_METHOD_STRAIGHT_LINE,
	})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestCB_SetDepreciationRule_QueryError(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT asset_type FROM fixed_assets").
		WithArgs("x", testUserID).WillReturnError(errors.New("db fail"))
	_, err := svc.SetDepreciationRule(authedCtx(), &pb.SetDepreciationRuleRequest{
		AssetId: "x", Method: pb.DepreciationMethod_DEPRECIATION_METHOD_STRAIGHT_LINE,
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_SetDepreciationRule_MethodNone(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT asset_type FROM fixed_assets").
		WithArgs("x", testUserID).WillReturnRows(pgxmock.NewRows([]string{"asset_type"}).AddRow("vehicle"))
	ruleID := uuid.New()
	now := time.Now()
	mock.ExpectQuery("INSERT INTO depreciation_rules").
		WithArgs("x", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at"}).AddRow(ruleID, now))
	resp, err := svc.SetDepreciationRule(authedCtx(), &pb.SetDepreciationRuleRequest{
		AssetId: "x", Method: pb.DepreciationMethod_DEPRECIATION_METHOD_NONE,
	})
	require.NoError(t, err)
	assert.Equal(t, int32(0), resp.UsefulLifeYears)
}

func TestCB_SetDepreciationRule_InvalidSalvageRate(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT asset_type FROM fixed_assets").
		WithArgs("x", testUserID).WillReturnRows(pgxmock.NewRows([]string{"asset_type"}).AddRow("vehicle"))
	_, err := svc.SetDepreciationRule(authedCtx(), &pb.SetDepreciationRuleRequest{
		AssetId: "x", Method: pb.DepreciationMethod_DEPRECIATION_METHOD_STRAIGHT_LINE,
		UsefulLifeYears: 5, SalvageRate: 1.5,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCB_SetDepreciationRule_InsertFail(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT asset_type FROM fixed_assets").
		WithArgs("x", testUserID).WillReturnRows(pgxmock.NewRows([]string{"asset_type"}).AddRow("vehicle"))
	mock.ExpectQuery("INSERT INTO depreciation_rules").
		WithArgs("x", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnError(errors.New("insert fail"))
	_, err := svc.SetDepreciationRule(authedCtx(), &pb.SetDepreciationRuleRequest{
		AssetId: "x", Method: pb.DepreciationMethod_DEPRECIATION_METHOD_STRAIGHT_LINE,
		UsefulLifeYears: 5, SalvageRate: 0.05,
	})
	assert.Equal(t, codes.Internal, status.Code(err))
}

func TestCB_SetDepreciationRule_WithPresets(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	mock.ExpectQuery("SELECT asset_type FROM fixed_assets").
		WithArgs("x", testUserID).WillReturnRows(pgxmock.NewRows([]string{"asset_type"}).AddRow("electronics"))
	ruleID := uuid.New()
	now := time.Now()
	mock.ExpectQuery("INSERT INTO depreciation_rules").
		WithArgs("x", pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at"}).AddRow(ruleID, now))
	resp, err := svc.SetDepreciationRule(authedCtx(), &pb.SetDepreciationRuleRequest{
		AssetId: "x", Method: pb.DepreciationMethod_DEPRECIATION_METHOD_STRAIGHT_LINE,
	})
	require.NoError(t, err)
	assert.Equal(t, int32(3), resp.UsefulLifeYears)
	assert.Equal(t, float64(0.05), resp.SalvageRate)
}

// ═══════════════════════════════════════════════════════════════════════════
// loadAsset — additional branches
// ═══════════════════════════════════════════════════════════════════════════

func TestCB_LoadAsset_WithDescription(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	assetID := uuid.New()
	now := time.Now()
	desc := "A nice car"
	mock.ExpectQuery("SELECT id, user_id, name").
		WithArgs(assetID.String()).
		WillReturnRows(pgxmock.NewRows(assetCols()).AddRow(
			assetID, testUserID, "Car", "vehicle", int64(200000), int64(150000),
			now, &desc, (*uuid.UUID)(nil), now, now,
		))
	resp, err := svc.loadAsset(context.Background(), assetID.String(), testUserID)
	require.NoError(t, err)
	assert.Equal(t, "A nice car", resp.Description)
}

func TestCB_LoadAsset_WithFamilyPermission(t *testing.T) {
	mock, _ := pgxmock.NewPool()
	defer mock.Close()
	svc := NewService(mock)
	assetID := uuid.New()
	familyID := uuid.New()
	now := time.Now()
	mock.ExpectQuery("SELECT id, user_id, name").
		WithArgs(assetID.String()).
		WillReturnRows(pgxmock.NewRows(assetCols()).AddRow(
			assetID, "other-user", "Car", "vehicle", int64(200000), int64(150000),
			now, (*string)(nil), &familyID, now, now,
		))
	uid, _ := uuid.Parse(testUserID)
	mock.ExpectQuery("SELECT role, permissions FROM family_members").
		WithArgs(familyID, uid).
		WillReturnRows(pgxmock.NewRows([]string{"role", "permissions"}).AddRow("owner", []byte(`{}`)))
	resp, err := svc.loadAsset(context.Background(), assetID.String(), testUserID)
	require.NoError(t, err)
	assert.Equal(t, familyID.String(), resp.FamilyId)
}
