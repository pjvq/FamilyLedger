package asset

import (
	"context"
	"log"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/familyledger/server/pkg/db"
	"github.com/familyledger/server/pkg/permission"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/pkg/middleware"
	pb "github.com/familyledger/server/proto/asset"
)

type Service struct {
	pb.UnimplementedAssetServiceServer
	pool db.Pool
}

func NewService(pool db.Pool) *Service {
	return &Service{pool: pool}
}

// ── CreateAsset ─────────────────────────────────────────────────────────────

func (s *Service) CreateAsset(ctx context.Context, req *pb.CreateAssetRequest) (*pb.Asset, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.Name == "" {
		return nil, status.Error(codes.InvalidArgument, "name is required")
	}
	if req.AssetType == pb.AssetType_ASSET_TYPE_UNSPECIFIED {
		return nil, status.Error(codes.InvalidArgument, "asset_type is required")
	}
	if req.PurchasePrice <= 0 {
		return nil, status.Error(codes.InvalidArgument, "purchase_price must be positive")
	}
	if req.PurchaseDate == nil {
		return nil, status.Error(codes.InvalidArgument, "purchase_date is required")
	}

	at := assetTypeToString(req.AssetType)
	purchaseDate := req.PurchaseDate.AsTime()

	// Family permission check
	var familyID *uuid.UUID
	if req.FamilyId != "" {
		fid, err := uuid.Parse(req.FamilyId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid family_id")
		}
		familyID = &fid
		if err := permission.Check(ctx, s.pool, userID, req.FamilyId, permission.CanEdit); err != nil {
			return nil, err
		}
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	var id uuid.UUID
	var createdAt, updatedAt time.Time
	err = tx.QueryRow(ctx,
		`INSERT INTO fixed_assets (user_id, name, asset_type, purchase_price, current_value, purchase_date, description, family_id)
		 VALUES ($1, $2, $3, $4, $4, $5, $6, $7)
		 RETURNING id, created_at, updated_at`,
		userID, req.Name, at, req.PurchasePrice, purchaseDate, req.Description, familyID,
	).Scan(&id, &createdAt, &updatedAt)
	if err != nil {
		log.Printf("asset: create error: %v", err)
		return nil, status.Error(codes.Internal, "failed to create asset")
	}

	// Insert initial valuation record
	_, err = tx.Exec(ctx,
		`INSERT INTO asset_valuations (asset_id, value, source, valuation_date)
		 VALUES ($1, $2, 'manual', $3)`,
		id, req.PurchasePrice, purchaseDate,
	)
	if err != nil {
		log.Printf("asset: create initial valuation error: %v", err)
		return nil, status.Error(codes.Internal, "failed to create initial valuation")
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit")
	}

	log.Printf("asset: created %s (%s) for user %s", id, at, userID)
	return &pb.Asset{
		Id:            id.String(),
		UserId:        userID,
		Name:          req.Name,
		AssetType:     req.AssetType,
		PurchasePrice: req.PurchasePrice,
		CurrentValue:  req.PurchasePrice,
		PurchaseDate:  req.PurchaseDate,
		Description:   req.Description,
		CreatedAt:     timestamppb.New(createdAt),
		UpdatedAt:     timestamppb.New(updatedAt),
	}, nil
}

// ── GetAsset ────────────────────────────────────────────────────────────────

func (s *Service) GetAsset(ctx context.Context, req *pb.GetAssetRequest) (*pb.Asset, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.AssetId == "" {
		return nil, status.Error(codes.InvalidArgument, "asset_id is required")
	}
	return s.loadAsset(ctx, req.AssetId, userID)
}

// ── ListAssets ──────────────────────────────────────────────────────────────

func (s *Service) ListAssets(ctx context.Context, req *pb.ListAssetsRequest) (*pb.ListAssetsResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}

	var rows pgx.Rows
	if req.FamilyId != "" {
		// Verify user is a member of this family
		var isMember bool
		err = s.pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)`,
			req.FamilyId, userID,
		).Scan(&isMember)
		if err != nil {
			return nil, status.Error(codes.Internal, "failed to verify family membership")
		}
		if !isMember {
			return nil, status.Error(codes.PermissionDenied, "not a member of this family")
		}
		rows, err = s.pool.Query(ctx,
			`SELECT id, user_id, name, asset_type, purchase_price, current_value,
			        purchase_date, description, family_id, created_at, updated_at
			 FROM fixed_assets
			 WHERE family_id = $1 AND deleted_at IS NULL
			 ORDER BY purchase_date DESC`,
			req.FamilyId,
		)
	} else if req.AssetType != pb.AssetType_ASSET_TYPE_UNSPECIFIED {
		at := assetTypeToString(req.AssetType)
		rows, err = s.pool.Query(ctx,
			`SELECT id, user_id, name, asset_type, purchase_price, current_value,
			        purchase_date, description, family_id, created_at, updated_at
			 FROM fixed_assets
			 WHERE user_id = $1 AND deleted_at IS NULL AND asset_type = $2
			 ORDER BY purchase_date DESC`,
			userID, at,
		)
	} else {
		rows, err = s.pool.Query(ctx,
			`SELECT id, user_id, name, asset_type, purchase_price, current_value,
			        purchase_date, description, family_id, created_at, updated_at
			 FROM fixed_assets
			 WHERE user_id = $1 AND deleted_at IS NULL
			 ORDER BY purchase_date DESC`,
			userID,
		)
	}
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list assets: %v", err)
	}
	defer rows.Close()

	var assets []*pb.Asset
	for rows.Next() {
		a, err := scanAssetRow(rows)
		if err != nil {
			return nil, err
		}
		assets = append(assets, a)
	}
	if assets == nil {
		assets = []*pb.Asset{}
	}
	return &pb.ListAssetsResponse{Assets: assets}, nil
}

// ── UpdateAsset ─────────────────────────────────────────────────────────────

func (s *Service) UpdateAsset(ctx context.Context, req *pb.UpdateAssetRequest) (*pb.Asset, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.AssetId == "" {
		return nil, status.Error(codes.InvalidArgument, "asset_id is required")
	}

	// Check ownership or family permission
	var ownerID string
	var assetFamilyID *string
	err = s.pool.QueryRow(ctx, "SELECT user_id, family_id FROM fixed_assets WHERE id = $1 AND deleted_at IS NULL", req.AssetId).Scan(&ownerID, &assetFamilyID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "asset not found")
		}
		return nil, status.Errorf(codes.Internal, "query asset: %v", err)
	}
	if ownerID != userID {
		if assetFamilyID != nil {
			if err := permission.Check(ctx, s.pool, userID, *assetFamilyID, permission.CanEdit); err != nil {
				return nil, err
			}
		} else {
			return nil, status.Error(codes.PermissionDenied, "not your asset")
		}
	}

	tag, err := s.pool.Exec(ctx,
		`UPDATE fixed_assets SET name = COALESCE(NULLIF($1, ''), name),
		        description = $2, updated_at = NOW()
		 WHERE id = $3 AND deleted_at IS NULL`,
		req.Name, req.Description, req.AssetId,
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "update asset: %v", err)
	}
	if tag.RowsAffected() == 0 {
		return nil, status.Error(codes.NotFound, "asset not found")
	}
	return s.loadAsset(ctx, req.AssetId, userID)
}

// ── DeleteAsset ─────────────────────────────────────────────────────────────

func (s *Service) DeleteAsset(ctx context.Context, req *pb.DeleteAssetRequest) (*emptypb.Empty, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.AssetId == "" {
		return nil, status.Error(codes.InvalidArgument, "asset_id is required")
	}

	// Check ownership or family permission
	var ownerID string
	var assetFamilyID *string
	err = s.pool.QueryRow(ctx, "SELECT user_id, family_id FROM fixed_assets WHERE id = $1 AND deleted_at IS NULL", req.AssetId).Scan(&ownerID, &assetFamilyID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "asset not found")
		}
		return nil, status.Errorf(codes.Internal, "query asset: %v", err)
	}
	if ownerID != userID {
		if assetFamilyID != nil {
			if err := permission.Check(ctx, s.pool, userID, *assetFamilyID, permission.CanDelete); err != nil {
				return nil, err
			}
		} else {
			return nil, status.Error(codes.PermissionDenied, "not your asset")
		}
	}

	tag, err := s.pool.Exec(ctx,
		`UPDATE fixed_assets SET deleted_at = NOW(), updated_at = NOW()
		 WHERE id = $1 AND deleted_at IS NULL`,
		req.AssetId,
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "delete asset: %v", err)
	}
	if tag.RowsAffected() == 0 {
		return nil, status.Error(codes.NotFound, "asset not found")
	}
	log.Printf("asset: soft-deleted %s by user %s", req.AssetId, userID)
	return &emptypb.Empty{}, nil
}

// ── UpdateValuation ─────────────────────────────────────────────────────────

func (s *Service) UpdateValuation(ctx context.Context, req *pb.UpdateValuationRequest) (*pb.AssetValuation, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.AssetId == "" {
		return nil, status.Error(codes.InvalidArgument, "asset_id is required")
	}
	if req.Value <= 0 {
		return nil, status.Error(codes.InvalidArgument, "value must be positive")
	}

	source := req.Source
	if source == "" {
		source = "manual"
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	// Verify ownership
	var exists bool
	err = tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM fixed_assets WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL)`,
		req.AssetId, userID,
	).Scan(&exists)
	if err != nil || !exists {
		return nil, status.Error(codes.NotFound, "asset not found")
	}

	now := time.Now()
	var valID uuid.UUID
	err = tx.QueryRow(ctx,
		`INSERT INTO asset_valuations (asset_id, value, source, valuation_date)
		 VALUES ($1, $2, $3, $4) RETURNING id`,
		req.AssetId, req.Value, source, now,
	).Scan(&valID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "insert valuation: %v", err)
	}

	_, err = tx.Exec(ctx,
		`UPDATE fixed_assets SET current_value = $1, updated_at = NOW() WHERE id = $2`,
		req.Value, req.AssetId,
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "update current_value: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, "failed to commit")
	}

	log.Printf("asset: valuation updated for %s to %d (%s) by user %s", req.AssetId, req.Value, source, userID)
	return &pb.AssetValuation{
		Id:            valID.String(),
		AssetId:       req.AssetId,
		Value:         req.Value,
		Source:        source,
		ValuationDate: timestamppb.New(now),
	}, nil
}

// ── ListValuations ──────────────────────────────────────────────────────────

func (s *Service) ListValuations(ctx context.Context, req *pb.ListValuationsRequest) (*pb.ListValuationsResponse, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.AssetId == "" {
		return nil, status.Error(codes.InvalidArgument, "asset_id is required")
	}

	// Verify ownership
	var exists bool
	err = s.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM fixed_assets WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL)`,
		req.AssetId, userID,
	).Scan(&exists)
	if err != nil || !exists {
		return nil, status.Error(codes.NotFound, "asset not found")
	}

	rows, err := s.pool.Query(ctx,
		`SELECT id, asset_id, value, source, valuation_date
		 FROM asset_valuations WHERE asset_id = $1
		 ORDER BY valuation_date DESC, created_at DESC`,
		req.AssetId,
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "list valuations: %v", err)
	}
	defer rows.Close()

	var valuations []*pb.AssetValuation
	for rows.Next() {
		var id uuid.UUID
		var assetID string
		var value int64
		var source string
		var valDate time.Time

		if err := rows.Scan(&id, &assetID, &value, &source, &valDate); err != nil {
			return nil, status.Errorf(codes.Internal, "scan valuation: %v", err)
		}
		valuations = append(valuations, &pb.AssetValuation{
			Id:            id.String(),
			AssetId:       assetID,
			Value:         value,
			Source:        source,
			ValuationDate: timestamppb.New(valDate),
		})
	}
	if valuations == nil {
		valuations = []*pb.AssetValuation{}
	}
	return &pb.ListValuationsResponse{Valuations: valuations}, nil
}

// ── SetDepreciationRule ─────────────────────────────────────────────────────

func (s *Service) SetDepreciationRule(ctx context.Context, req *pb.SetDepreciationRuleRequest) (*pb.DepreciationRule, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.AssetId == "" {
		return nil, status.Error(codes.InvalidArgument, "asset_id is required")
	}
	if req.Method == pb.DepreciationMethod_DEPRECIATION_METHOD_UNSPECIFIED {
		return nil, status.Error(codes.InvalidArgument, "method is required")
	}

	// Load asset to verify ownership and get type for presets
	var assetType string
	err = s.pool.QueryRow(ctx,
		`SELECT asset_type FROM fixed_assets WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
		req.AssetId, userID,
	).Scan(&assetType)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "asset not found")
		}
		return nil, status.Errorf(codes.Internal, "query asset: %v", err)
	}

	method := depreciationMethodToString(req.Method)
	usefulLife := int(req.UsefulLifeYears)
	salvageRate := req.SalvageRate

	// Apply presets if not specified
	if usefulLife == 0 || salvageRate == 0 {
		presetLife, presetRate := getDepreciationPreset(assetType)
		if usefulLife == 0 {
			usefulLife = presetLife
		}
		if salvageRate == 0 {
			salvageRate = presetRate
		}
	}

	if req.Method == pb.DepreciationMethod_DEPRECIATION_METHOD_NONE {
		// For "none" method, values don't matter but set reasonable defaults
		usefulLife = 0
		salvageRate = 0
	} else {
		if usefulLife <= 0 {
			return nil, status.Error(codes.InvalidArgument, "useful_life_years must be positive")
		}
		if salvageRate < 0 || salvageRate >= 1 {
			return nil, status.Error(codes.InvalidArgument, "salvage_rate must be between 0 and 1")
		}
	}

	var ruleID uuid.UUID
	var createdAt time.Time
	err = s.pool.QueryRow(ctx,
		`INSERT INTO depreciation_rules (asset_id, method, useful_life_years, salvage_rate)
		 VALUES ($1, $2, $3, $4)
		 ON CONFLICT (asset_id) DO UPDATE
		   SET method = EXCLUDED.method,
		       useful_life_years = EXCLUDED.useful_life_years,
		       salvage_rate = EXCLUDED.salvage_rate,
		       created_at = NOW()
		 RETURNING id, created_at`,
		req.AssetId, method, usefulLife, salvageRate,
	).Scan(&ruleID, &createdAt)
	if err != nil {
		log.Printf("asset: set depreciation rule error: %v", err)
		return nil, status.Error(codes.Internal, "failed to set depreciation rule")
	}

	log.Printf("asset: depreciation rule set for %s: %s, %d years, %.4f salvage", req.AssetId, method, usefulLife, salvageRate)
	return &pb.DepreciationRule{
		Id:              ruleID.String(),
		AssetId:         req.AssetId,
		Method:          req.Method,
		UsefulLifeYears: int32(usefulLife),
		SalvageRate:     salvageRate,
		CreatedAt:       timestamppb.New(createdAt),
	}, nil
}

// ── RunDepreciation ─────────────────────────────────────────────────────────

func (s *Service) RunDepreciation(ctx context.Context, req *pb.RunDepreciationRequest) (*pb.Asset, error) {
	userID, err := middleware.GetUserID(ctx)
	if err != nil {
		return nil, err
	}
	if req.AssetId == "" {
		return nil, status.Error(codes.InvalidArgument, "asset_id is required")
	}

	asset, rule, err := s.loadAssetWithRule(ctx, req.AssetId, userID)
	if err != nil {
		return nil, err
	}
	if rule == nil {
		return nil, status.Error(codes.FailedPrecondition, "no depreciation rule set for this asset")
	}
	if rule.method == "none" {
		return nil, status.Error(codes.FailedPrecondition, "depreciation method is set to none")
	}

	_, err = s.applyMonthlyDepreciation(ctx, asset, rule)
	if err != nil {
		return nil, err
	}

	return s.loadAsset(ctx, req.AssetId, userID)
}

// RunMonthlyDepreciationAll runs depreciation for all assets with rules.
// Called by the scheduler. Uses a background user context.
func (s *Service) RunMonthlyDepreciationAll(ctx context.Context) error {
	rows, err := s.pool.Query(ctx,
		`SELECT fa.id, fa.user_id, fa.purchase_price, fa.current_value, fa.purchase_date,
		        dr.method, dr.useful_life_years, dr.salvage_rate
		 FROM fixed_assets fa
		 INNER JOIN depreciation_rules dr ON fa.id = dr.asset_id
		 WHERE fa.deleted_at IS NULL AND dr.method != 'none'`,
	)
	if err != nil {
		return err
	}
	defer rows.Close()

	var count, errors int
	for rows.Next() {
		var a assetData
		var r ruleData
		if err := rows.Scan(&a.id, &a.userID, &a.purchasePrice, &a.currentValue, &a.purchaseDate,
			&r.method, &r.usefulLifeYears, &r.salvageRate); err != nil {
			log.Printf("asset: depreciation scan error: %v", err)
			errors++
			continue
		}
		r.assetID = a.id

		_, err := s.applyMonthlyDepreciation(ctx, &a, &r)
		if err != nil {
			log.Printf("asset: depreciation error for %s: %v", a.id, err)
			errors++
			continue
		}
		count++
	}

	log.Printf("asset: monthly depreciation complete — %d processed, %d errors", count, errors)
	return nil
}

// ════════════════════════════════════════════════════════════════════════════
// Depreciation algorithms
// ════════════════════════════════════════════════════════════════════════════

func (s *Service) applyMonthlyDepreciation(ctx context.Context, asset *assetData, rule *ruleData) (int64, error) {
	salvageValue := int64(math.Round(float64(asset.purchasePrice) * rule.salvageRate))

	if asset.currentValue <= salvageValue {
		// Already at or below salvage value, nothing to depreciate
		return asset.currentValue, nil
	}

	var monthlyDep int64

	switch rule.method {
	case "straight_line":
		monthlyDep = calcStraightLineMonthly(asset.purchasePrice, salvageValue, rule.usefulLifeYears)

	case "double_declining":
		monthlyDep = calcDoubleDecliningMonthly(asset, salvageValue, rule.usefulLifeYears)

	default:
		return asset.currentValue, status.Errorf(codes.Internal, "unknown depreciation method: %s", rule.method)
	}

	newValue := asset.currentValue - monthlyDep
	if newValue < salvageValue {
		newValue = salvageValue
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return 0, status.Error(codes.Internal, "failed to begin transaction")
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx,
		`UPDATE fixed_assets SET current_value = $1, updated_at = NOW() WHERE id = $2`,
		newValue, asset.id,
	)
	if err != nil {
		return 0, status.Errorf(codes.Internal, "update current_value: %v", err)
	}

	now := time.Now()
	_, err = tx.Exec(ctx,
		`INSERT INTO asset_valuations (asset_id, value, source, valuation_date)
		 VALUES ($1, $2, 'depreciation', $3)`,
		asset.id, newValue, now,
	)
	if err != nil {
		return 0, status.Errorf(codes.Internal, "insert depreciation valuation: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return 0, status.Error(codes.Internal, "failed to commit")
	}

	log.Printf("asset: depreciated %s from %d to %d (method=%s)", asset.id, asset.currentValue, newValue, rule.method)
	return newValue, nil
}

// calcStraightLineMonthly: 年折旧额 = (购入价 - 残值) / 使用年限, 月折旧额 = 年折旧额 / 12
func calcStraightLineMonthly(purchasePrice, salvageValue int64, usefulLifeYears int) int64 {
	annualDep := float64(purchasePrice-salvageValue) / float64(usefulLifeYears)
	monthlyDep := annualDep / 12.0
	return int64(math.Round(monthlyDep))
}

// calcDoubleDecliningMonthly:
// 年折旧率 = 2 / 使用年限
// 年折旧额 = 期初净值 × 年折旧率
// 月折旧额 = 年折旧额 / 12
// 最后两年: 改为直线法 = (期初净值 - 残值) / 2 / 12
func calcDoubleDecliningMonthly(asset *assetData, salvageValue int64, usefulLifeYears int) int64 {
	// Determine how many months have elapsed since purchase
	monthsElapsed := monthsBetween(asset.purchaseDate, time.Now())
	totalMonths := usefulLifeYears * 12
	remainingMonths := totalMonths - monthsElapsed

	// Last 2 years (24 months): switch to straight-line
	if remainingMonths <= 24 {
		if remainingMonths <= 0 {
			return 0
		}
		// (期初净值 - 残值) / 剩余月数
		// But spec says: (期初净值 - 残值) / 2 / 12 for last 2 years
		monthlyDep := float64(asset.currentValue-salvageValue) / 24.0
		if monthlyDep < 0 {
			return 0
		}
		return int64(math.Round(monthlyDep))
	}

	// Normal DDB
	annualRate := 2.0 / float64(usefulLifeYears)
	annualDep := float64(asset.currentValue) * annualRate
	monthlyDep := annualDep / 12.0
	return int64(math.Round(monthlyDep))
}

// monthsBetween calculates the number of complete months between two dates.
func monthsBetween(from time.Time, to time.Time) int {
	years := to.Year() - from.Year()
	months := int(to.Month()) - int(from.Month())
	return years*12 + months
}

// ════════════════════════════════════════════════════════════════════════════
// Internal helpers
// ════════════════════════════════════════════════════════════════════════════

type assetData struct {
	id            string
	userID        string
	purchasePrice int64
	currentValue  int64
	purchaseDate  time.Time
}

type ruleData struct {
	assetID        string
	method         string
	usefulLifeYears int
	salvageRate    float64
}

func (s *Service) loadAsset(ctx context.Context, assetID, userID string) (*pb.Asset, error) {
	var id uuid.UUID
	var uid, name, assetType string
	var purchasePrice, currentValue int64
	var purchaseDate time.Time
	var description *string
	var createdAt, updatedAt time.Time
	var familyID *uuid.UUID

	err := s.pool.QueryRow(ctx,
		`SELECT id, user_id, name, asset_type, purchase_price, current_value,
		        purchase_date, description, created_at, updated_at, family_id
		 FROM fixed_assets
		 WHERE id = $1 AND deleted_at IS NULL`,
		assetID,
	).Scan(&id, &uid, &name, &assetType, &purchasePrice, &currentValue,
		&purchaseDate, &description, &createdAt, &updatedAt, &familyID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, status.Error(codes.NotFound, "asset not found")
		}
		return nil, status.Errorf(codes.Internal, "query asset: %v", err)
	}
	if uid != userID {
		if familyID != nil {
			if err := permission.Check(ctx, s.pool, userID, familyID.String(), permission.CanView); err != nil {
				return nil, status.Error(codes.PermissionDenied, "not your asset")
			}
		} else {
			return nil, status.Error(codes.PermissionDenied, "not your asset")
		}
	}

	desc := ""
	if description != nil {
		desc = *description
	}

	asset := &pb.Asset{
		Id:            id.String(),
		UserId:        uid,
		Name:          name,
		AssetType:     stringToAssetType(assetType),
		PurchasePrice: purchasePrice,
		CurrentValue:  currentValue,
		PurchaseDate:  timestamppb.New(purchaseDate),
		Description:   desc,
		CreatedAt:     timestamppb.New(createdAt),
		UpdatedAt:     timestamppb.New(updatedAt),
	}
	if familyID != nil {
		asset.FamilyId = familyID.String()
	}
	return asset, nil
}

func (s *Service) loadAssetWithRule(ctx context.Context, assetID, userID string) (*assetData, *ruleData, error) {
	var a assetData
	var rMethod *string
	var rUsefulLife *int
	var rSalvageRate *float64

	err := s.pool.QueryRow(ctx,
		`SELECT fa.id, fa.user_id, fa.purchase_price, fa.current_value, fa.purchase_date,
		        dr.method, dr.useful_life_years, dr.salvage_rate
		 FROM fixed_assets fa
		 LEFT JOIN depreciation_rules dr ON fa.id = dr.asset_id
		 WHERE fa.id = $1 AND fa.deleted_at IS NULL`,
		assetID,
	).Scan(&a.id, &a.userID, &a.purchasePrice, &a.currentValue, &a.purchaseDate,
		&rMethod, &rUsefulLife, &rSalvageRate)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, nil, status.Error(codes.NotFound, "asset not found")
		}
		return nil, nil, status.Errorf(codes.Internal, "query asset with rule: %v", err)
	}
	if a.userID != userID {
		return nil, nil, status.Error(codes.PermissionDenied, "not your asset")
	}

	if rMethod == nil {
		return &a, nil, nil
	}

	r := &ruleData{
		assetID:        a.id,
		method:         *rMethod,
		usefulLifeYears: *rUsefulLife,
		salvageRate:    *rSalvageRate,
	}
	return &a, r, nil
}

func scanAssetRow(rows pgx.Rows) (*pb.Asset, error) {
	var id uuid.UUID
	var uid, name, assetType string
	var purchasePrice, currentValue int64
	var purchaseDate time.Time
	var description *string
	var familyID *uuid.UUID
	var createdAt, updatedAt time.Time

	if err := rows.Scan(&id, &uid, &name, &assetType, &purchasePrice, &currentValue,
		&purchaseDate, &description, &familyID, &createdAt, &updatedAt); err != nil {
		return nil, status.Errorf(codes.Internal, "scan asset: %v", err)
	}

	desc := ""
	if description != nil {
		desc = *description
	}
	famStr := ""
	if familyID != nil {
		famStr = familyID.String()
	}

	return &pb.Asset{
		Id:            id.String(),
		UserId:        uid,
		FamilyId:      famStr,
		Name:          name,
		AssetType:     stringToAssetType(assetType),
		PurchasePrice: purchasePrice,
		CurrentValue:  currentValue,
		PurchaseDate:  timestamppb.New(purchaseDate),
		Description:   desc,
		CreatedAt:     timestamppb.New(createdAt),
		UpdatedAt:     timestamppb.New(updatedAt),
	}, nil
}

// getDepreciationPreset returns preset useful life years and salvage rate
// for known asset types.
func getDepreciationPreset(assetType string) (usefulLife int, salvageRate float64) {
	switch assetType {
	case "vehicle":
		return 5, 0.05
	case "electronics":
		return 3, 0.05
	case "furniture":
		return 5, 0.05
	case "other":
		return 5, 0.05
	default:
		// real_estate, jewelry — typically don't depreciate
		return 10, 0.10
	}
}

// ── Type conversions ────────────────────────────────────────────────────────

func assetTypeToString(at pb.AssetType) string {
	switch at {
	case pb.AssetType_ASSET_TYPE_REAL_ESTATE:
		return "real_estate"
	case pb.AssetType_ASSET_TYPE_VEHICLE:
		return "vehicle"
	case pb.AssetType_ASSET_TYPE_ELECTRONICS:
		return "electronics"
	case pb.AssetType_ASSET_TYPE_FURNITURE:
		return "furniture"
	case pb.AssetType_ASSET_TYPE_JEWELRY:
		return "jewelry"
	case pb.AssetType_ASSET_TYPE_OTHER:
		return "other"
	default:
		return "unspecified"
	}
}

func stringToAssetType(s string) pb.AssetType {
	switch s {
	case "real_estate":
		return pb.AssetType_ASSET_TYPE_REAL_ESTATE
	case "vehicle":
		return pb.AssetType_ASSET_TYPE_VEHICLE
	case "electronics":
		return pb.AssetType_ASSET_TYPE_ELECTRONICS
	case "furniture":
		return pb.AssetType_ASSET_TYPE_FURNITURE
	case "jewelry":
		return pb.AssetType_ASSET_TYPE_JEWELRY
	case "other":
		return pb.AssetType_ASSET_TYPE_OTHER
	default:
		return pb.AssetType_ASSET_TYPE_UNSPECIFIED
	}
}

func depreciationMethodToString(m pb.DepreciationMethod) string {
	switch m {
	case pb.DepreciationMethod_DEPRECIATION_METHOD_STRAIGHT_LINE:
		return "straight_line"
	case pb.DepreciationMethod_DEPRECIATION_METHOD_DOUBLE_DECLINING:
		return "double_declining"
	case pb.DepreciationMethod_DEPRECIATION_METHOD_NONE:
		return "none"
	default:
		return "unspecified"
	}
}
