package asset

import (
	"context"
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

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/asset"
)

const testUserID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

func authedCtx() context.Context {
	return context.WithValue(context.Background(), middleware.UserIDKey, testUserID)
}

func assetCols() []string {
	return []string{"id", "user_id", "name", "asset_type", "purchase_price", "current_value",
		"purchase_date", "description", "created_at", "updated_at", "family_id"}
}

func assetRow(id uuid.UUID) []interface{} {
	now := time.Now()
	return []interface{}{id, testUserID, "MacBook Pro", "electronics",
		int64(1599900), int64(1200000), now, (*string)(nil), now, now, (*uuid.UUID)(nil)}
}

// ─── CreateAsset ────────────────────────────────────────────────────────────

func TestCreateAsset_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := NewService(mock)
	id := uuid.New()
	now := time.Now()

	mock.ExpectBegin()
	mock.ExpectQuery("INSERT INTO fixed_assets").
		WithArgs(testUserID, "MacBook", "electronics", int64(1599900),
			pgxmock.AnyArg(), pgxmock.AnyArg(), (*uuid.UUID)(nil)).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at", "updated_at"}).AddRow(id, now, now))
	mock.ExpectExec("INSERT INTO asset_valuations").
		WithArgs(id, int64(1599900), pgxmock.AnyArg()).
		WillReturnResult(pgxmock.NewResult("INSERT", 1))
	mock.ExpectCommit()

	resp, err := svc.CreateAsset(authedCtx(), &pb.CreateAssetRequest{
		Name:          "MacBook",
		AssetType:     pb.AssetType_ASSET_TYPE_ELECTRONICS,
		PurchasePrice: 1599900,
		PurchaseDate:  timestamppb.New(now),
	})
	require.NoError(t, err)
	assert.Equal(t, "MacBook", resp.Name)
	assert.Equal(t, int64(1599900), resp.PurchasePrice)
	assert.Equal(t, int64(1599900), resp.CurrentValue)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestCreateAsset_NoAuth(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.CreateAsset(context.Background(), &pb.CreateAssetRequest{})
	require.Error(t, err)
	assert.Equal(t, codes.Unauthenticated, status.Code(err))
}

func TestCreateAsset_MissingName(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.CreateAsset(authedCtx(), &pb.CreateAssetRequest{
		AssetType:     pb.AssetType_ASSET_TYPE_ELECTRONICS,
		PurchasePrice: 100,
		PurchaseDate:  timestamppb.Now(),
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestCreateAsset_InvalidPrice(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.CreateAsset(authedCtx(), &pb.CreateAssetRequest{
		Name:          "x",
		AssetType:     pb.AssetType_ASSET_TYPE_ELECTRONICS,
		PurchasePrice: -1,
		PurchaseDate:  timestamppb.Now(),
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── GetAsset ───────────────────────────────────────────────────────────────

func TestGetAsset_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM fixed_assets").
		WithArgs(id.String()).
		WillReturnRows(pgxmock.NewRows(assetCols()).AddRow(assetRow(id)...))

	resp, err := svc.GetAsset(authedCtx(), &pb.GetAssetRequest{AssetId: id.String()})
	require.NoError(t, err)
	assert.Equal(t, "MacBook Pro", resp.Name)
}

func TestGetAsset_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()

	mock.ExpectQuery("SELECT .+ FROM fixed_assets").
		WithArgs(id.String()).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.GetAsset(authedCtx(), &pb.GetAssetRequest{AssetId: id.String()})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestGetAsset_PermissionDenied(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()
	now := time.Now()

	row := []interface{}{id, uuid.New().String(), "Car", "vehicle",
		int64(300000), int64(200000), now, (*string)(nil), now, now, (*uuid.UUID)(nil)}
	mock.ExpectQuery("SELECT .+ FROM fixed_assets").
		WithArgs(id.String()).
		WillReturnRows(pgxmock.NewRows(assetCols()).AddRow(row...))

	_, err = svc.GetAsset(authedCtx(), &pb.GetAssetRequest{AssetId: id.String()})
	assert.Equal(t, codes.PermissionDenied, status.Code(err))
}

func TestGetAsset_EmptyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.GetAsset(authedCtx(), &pb.GetAssetRequest{AssetId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── ListAssets ─────────────────────────────────────────────────────────────

func TestListAssets_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	cols := []string{"id", "user_id", "name", "asset_type", "purchase_price", "current_value",
		"purchase_date", "description", "created_at", "updated_at"}
	now := time.Now()
	id1, id2 := uuid.New(), uuid.New()

	mock.ExpectQuery("SELECT .+ FROM fixed_assets.+WHERE user_id").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows(cols).
			AddRow(id1, testUserID, "MacBook", "electronics", int64(1599900), int64(1200000), now, (*string)(nil), now, now).
			AddRow(id2, testUserID, "Car", "vehicle", int64(15000000), int64(12000000), now, (*string)(nil), now, now))

	resp, err := svc.ListAssets(authedCtx(), &pb.ListAssetsRequest{})
	require.NoError(t, err)
	assert.Len(t, resp.Assets, 2)
}

func TestListAssets_FilterByType(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	cols := []string{"id", "user_id", "name", "asset_type", "purchase_price", "current_value",
		"purchase_date", "description", "created_at", "updated_at"}
	now := time.Now()

	mock.ExpectQuery("SELECT .+ FROM fixed_assets.+asset_type").
		WithArgs(testUserID, "electronics").
		WillReturnRows(pgxmock.NewRows(cols).
			AddRow(uuid.New(), testUserID, "MacBook", "electronics", int64(1599900), int64(1200000), now, (*string)(nil), now, now))

	resp, err := svc.ListAssets(authedCtx(), &pb.ListAssetsRequest{AssetType: pb.AssetType_ASSET_TYPE_ELECTRONICS})
	require.NoError(t, err)
	assert.Len(t, resp.Assets, 1)
}

func TestListAssets_Empty(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	cols := []string{"id", "user_id", "name", "asset_type", "purchase_price", "current_value",
		"purchase_date", "description", "created_at", "updated_at"}
	mock.ExpectQuery("SELECT .+ FROM fixed_assets").
		WithArgs(testUserID).
		WillReturnRows(pgxmock.NewRows(cols))

	resp, err := svc.ListAssets(authedCtx(), &pb.ListAssetsRequest{})
	require.NoError(t, err)
	assert.Empty(t, resp.Assets)
}

// ─── UpdateAsset ────────────────────────────────────────────────────────────

func TestUpdateAsset_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()

	// ownership check
	mock.ExpectQuery("SELECT user_id, family_id FROM fixed_assets").
		WithArgs(id.String()).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	// update
	mock.ExpectExec("UPDATE fixed_assets SET").
		WithArgs("New Name", "new desc", id.String()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	// loadAsset reload
	mock.ExpectQuery("SELECT .+ FROM fixed_assets").
		WithArgs(id.String()).
		WillReturnRows(pgxmock.NewRows(assetCols()).AddRow(assetRow(id)...))

	resp, err := svc.UpdateAsset(authedCtx(), &pb.UpdateAssetRequest{
		AssetId:     id.String(),
		Name:        "New Name",
		Description: "new desc",
	})
	require.NoError(t, err)
	assert.NotNil(t, resp)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUpdateAsset_EmptyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.UpdateAsset(authedCtx(), &pb.UpdateAssetRequest{AssetId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── DeleteAsset ────────────────────────────────────────────────────────────

func TestDeleteAsset_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()

	// ownership check
	mock.ExpectQuery("SELECT user_id, family_id FROM fixed_assets").
		WithArgs(id.String()).
		WillReturnRows(pgxmock.NewRows([]string{"user_id", "family_id"}).AddRow(testUserID, (*string)(nil)))
	mock.ExpectExec("UPDATE fixed_assets SET deleted_at").
		WithArgs(id.String()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))

	_, err = svc.DeleteAsset(authedCtx(), &pb.DeleteAssetRequest{AssetId: id.String()})
	require.NoError(t, err)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestDeleteAsset_NotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	id := uuid.New()

	mock.ExpectQuery("SELECT user_id, family_id FROM fixed_assets").
		WithArgs(id.String()).
		WillReturnError(pgx.ErrNoRows)

	_, err = svc.DeleteAsset(authedCtx(), &pb.DeleteAssetRequest{AssetId: id.String()})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

func TestDeleteAsset_EmptyID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.DeleteAsset(authedCtx(), &pb.DeleteAssetRequest{AssetId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── UpdateValuation ────────────────────────────────────────────────────────

func TestUpdateValuation_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	assetID := uuid.New()
	valID := uuid.New()

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(assetID.String(), testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectQuery("INSERT INTO asset_valuations").
		WithArgs(assetID.String(), int64(1300000), "manual", pgxmock.AnyArg()).
		WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(valID))
	mock.ExpectExec("UPDATE fixed_assets SET current_value").
		WithArgs(int64(1300000), assetID.String()).
		WillReturnResult(pgxmock.NewResult("UPDATE", 1))
	mock.ExpectCommit()

	resp, err := svc.UpdateValuation(authedCtx(), &pb.UpdateValuationRequest{
		AssetId: assetID.String(),
		Value:   1300000,
	})
	require.NoError(t, err)
	assert.Equal(t, int64(1300000), resp.Value)
	assert.Equal(t, "manual", resp.Source)
	assert.NoError(t, mock.ExpectationsWereMet())
}

func TestUpdateValuation_InvalidValue(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.UpdateValuation(authedCtx(), &pb.UpdateValuationRequest{
		AssetId: uuid.New().String(),
		Value:   0,
	})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

func TestUpdateValuation_AssetNotFound(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)

	mock.ExpectBegin()
	mock.ExpectQuery("SELECT EXISTS").
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(false))
	mock.ExpectRollback()

	_, err = svc.UpdateValuation(authedCtx(), &pb.UpdateValuationRequest{
		AssetId: uuid.New().String(),
		Value:   100,
	})
	assert.Equal(t, codes.NotFound, status.Code(err))
}

// ─── ListValuations ─────────────────────────────────────────────────────────

func TestListValuations_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	assetID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT EXISTS").
		WithArgs(assetID.String(), testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"exists"}).AddRow(true))
	mock.ExpectQuery("SELECT .+ FROM asset_valuations").
		WithArgs(assetID.String()).
		WillReturnRows(pgxmock.NewRows([]string{"id", "asset_id", "value", "source", "valuation_date"}).
			AddRow(uuid.New(), assetID.String(), int64(1599900), "manual", now).
			AddRow(uuid.New(), assetID.String(), int64(1300000), "depreciation", now))

	resp, err := svc.ListValuations(authedCtx(), &pb.ListValuationsRequest{AssetId: assetID.String()})
	require.NoError(t, err)
	assert.Len(t, resp.Valuations, 2)
}

func TestListValuations_EmptyAssetID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.ListValuations(authedCtx(), &pb.ListValuationsRequest{AssetId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── SetDepreciationRule ────────────────────────────────────────────────────

func TestSetDepreciationRule_Success(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	assetID := uuid.New()
	ruleID := uuid.New()
	now := time.Now()

	mock.ExpectQuery("SELECT asset_type FROM fixed_assets").
		WithArgs(assetID.String(), testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"asset_type"}).AddRow("electronics"))
	mock.ExpectQuery("INSERT INTO depreciation_rules").
		WithArgs(assetID.String(), "straight_line", 5, 0.05).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at"}).AddRow(ruleID, now))

	resp, err := svc.SetDepreciationRule(authedCtx(), &pb.SetDepreciationRuleRequest{
		AssetId:         assetID.String(),
		Method:          pb.DepreciationMethod_DEPRECIATION_METHOD_STRAIGHT_LINE,
		UsefulLifeYears: 5,
		SalvageRate:     0.05,
	})
	require.NoError(t, err)
	assert.Equal(t, int32(5), resp.UsefulLifeYears)
	assert.Equal(t, 0.05, resp.SalvageRate)
}

func TestSetDepreciationRule_Presets(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	assetID := uuid.New()
	ruleID := uuid.New()
	now := time.Now()

	// useful_life=0, salvage_rate=0 → use presets for vehicle: 5 years, 0.05
	mock.ExpectQuery("SELECT asset_type FROM fixed_assets").
		WithArgs(assetID.String(), testUserID).
		WillReturnRows(pgxmock.NewRows([]string{"asset_type"}).AddRow("vehicle"))
	mock.ExpectQuery("INSERT INTO depreciation_rules").
		WithArgs(assetID.String(), "straight_line", 5, 0.05).
		WillReturnRows(pgxmock.NewRows([]string{"id", "created_at"}).AddRow(ruleID, now))

	resp, err := svc.SetDepreciationRule(authedCtx(), &pb.SetDepreciationRuleRequest{
		AssetId: assetID.String(),
		Method:  pb.DepreciationMethod_DEPRECIATION_METHOD_STRAIGHT_LINE,
	})
	require.NoError(t, err)
	assert.Equal(t, int32(5), resp.UsefulLifeYears)
	assert.Equal(t, 0.05, resp.SalvageRate)
}

func TestSetDepreciationRule_EmptyAssetID(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()
	svc := NewService(mock)
	_, err = svc.SetDepreciationRule(authedCtx(), &pb.SetDepreciationRuleRequest{AssetId: ""})
	assert.Equal(t, codes.InvalidArgument, status.Code(err))
}

// ─── Depreciation algorithms (pure logic) ───────────────────────────────────

func TestCalcStraightLineMonthly(t *testing.T) {
	// 购入价 100万, 残值 5万, 使用年限 5 年
	// 年折旧 = (100万-5万)/5 = 19万, 月折旧 = 19万/12 ≈ 15833
	m := calcStraightLineMonthly(1000000, 50000, 5)
	assert.InDelta(t, 15833, m, 1)
}

func TestCalcDoubleDecliningMonthly_Normal(t *testing.T) {
	// 购入价 100万, 当前值 80万, 使用年限 5年
	// 年折旧率 = 2/5 = 40%, 年折旧额 = 80万*40% = 32万, 月折旧 = 32万/12 ≈ 26667
	a := &assetData{
		purchasePrice: 1000000,
		currentValue:  800000,
		purchaseDate:  time.Now().AddDate(-1, 0, 0), // 1 year ago
	}
	m := calcDoubleDecliningMonthly(a, 50000, 5)
	assert.InDelta(t, 26667, m, 1)
}

func TestCalcDoubleDecliningMonthly_LastTwoYears(t *testing.T) {
	// Purchase 4 years ago → 48 months elapsed, 60 total → 12 remaining (< 24)
	// → switch to straight-line: (currentValue - salvage) / 24
	a := &assetData{
		purchasePrice: 1000000,
		currentValue:  200000,
		purchaseDate:  time.Now().AddDate(-4, 0, 0),
	}
	m := calcDoubleDecliningMonthly(a, 50000, 5)
	// (200000 - 50000) / 24 = 6250
	assert.InDelta(t, 6250, m, 1)
}

func TestMonthsBetween(t *testing.T) {
	assert.Equal(t, 12, monthsBetween(
		time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)))
	assert.Equal(t, 3, monthsBetween(
		time.Date(2026, 1, 15, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 4, 15, 0, 0, 0, 0, time.UTC)))
	assert.Equal(t, 0, monthsBetween(
		time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(2026, 1, 31, 0, 0, 0, 0, time.UTC)))
}

// ─── Type conversions ───────────────────────────────────────────────────────

func TestAssetTypeConversions(t *testing.T) {
	types := []struct {
		str string
		val pb.AssetType
	}{
		{"real_estate", pb.AssetType_ASSET_TYPE_REAL_ESTATE},
		{"vehicle", pb.AssetType_ASSET_TYPE_VEHICLE},
		{"electronics", pb.AssetType_ASSET_TYPE_ELECTRONICS},
		{"furniture", pb.AssetType_ASSET_TYPE_FURNITURE},
		{"jewelry", pb.AssetType_ASSET_TYPE_JEWELRY},
		{"other", pb.AssetType_ASSET_TYPE_OTHER},
	}
	for _, tt := range types {
		assert.Equal(t, tt.str, assetTypeToString(tt.val))
		assert.Equal(t, tt.val, stringToAssetType(tt.str))
	}
}

func TestDepreciationMethodConversions(t *testing.T) {
	assert.Equal(t, "straight_line", depreciationMethodToString(pb.DepreciationMethod_DEPRECIATION_METHOD_STRAIGHT_LINE))
	assert.Equal(t, "double_declining", depreciationMethodToString(pb.DepreciationMethod_DEPRECIATION_METHOD_DOUBLE_DECLINING))
	assert.Equal(t, "none", depreciationMethodToString(pb.DepreciationMethod_DEPRECIATION_METHOD_NONE))
}

func TestGetDepreciationPreset(t *testing.T) {
	life, rate := getDepreciationPreset("vehicle")
	assert.Equal(t, 5, life)
	assert.Equal(t, 0.05, rate)

	life, rate = getDepreciationPreset("electronics")
	assert.Equal(t, 3, life)
	assert.Equal(t, 0.05, rate)

	life, rate = getDepreciationPreset("real_estate")
	assert.Equal(t, 10, life)
	assert.Equal(t, 0.10, rate)
}
