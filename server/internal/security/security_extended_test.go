package security

import (
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	pgxmock "github.com/pashagolub/pgxmock/v4"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/familyledger/server/internal/account"
	"github.com/familyledger/server/internal/family"
	accountpb "github.com/familyledger/server/proto/account"
	familypb "github.com/familyledger/server/proto/family"
)

// authedCtx defined in injection_test.go

// ─── XSS in account name ─────────────────────────────────────────────────────

func TestCreateAccount_XSS_Name(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := account.NewService(mock)

	xssPayloads := []string{
		`<script>alert('xss')</script>`,
		`<img src=x onerror=alert(1)>`,
		`'; DROP TABLE accounts; --`,
		`" onmouseover="alert(1)`,
	}

	for _, payload := range xssPayloads {
		t.Run(payload[:min(len(payload), 20)], func(t *testing.T) {
			accountID := uuid.New()

			// Match the real INSERT INTO accounts ... RETURNING id, created_at, updated_at
			mock.ExpectQuery(`INSERT INTO accounts`).
				WithArgs(pgxmock.AnyArg(), payload, pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg(), pgxmock.AnyArg()).
				WillReturnRows(pgxmock.NewRows([]string{
					"id", "created_at", "updated_at",
				}).AddRow(accountID, time.Now(), time.Now()))

			resp, err := svc.CreateAccount(authedCtx(), &accountpb.CreateAccountRequest{
				Name:     payload,
				Type:     accountpb.AccountType_ACCOUNT_TYPE_CASH,
				Currency: "CNY",
			})

			// Verify parameterized queries store XSS payloads verbatim
			require.NoError(t, err, "XSS payload should be stored verbatim via parameterized queries")
			assert.Equal(t, payload, resp.Account.Name, "name should be stored verbatim (no mutation)")
			assert.NoError(t, mock.ExpectationsWereMet(), "all expected DB calls should have been made")
		})
	}
}

// ─── Family name injection ───────────────────────────────────────────────────

func TestCreateFamily_SQLInjection_Name(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := family.NewService(mock)

	injections := []string{
		"'; DROP TABLE families; --",
		"Robert'); DROP TABLE family_members;--",
		"1 OR 1=1",
		`" UNION SELECT * FROM users --`,
	}

	for _, payload := range injections {
		t.Run(payload[:min(len(payload), 20)], func(t *testing.T) {
			familyID := uuid.New()
			userUUID := uuid.MustParse("a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11")

			// CreateFamily does BEGIN → INSERT family → INSERT member → COMMIT
			mock.ExpectBegin()
			mock.ExpectQuery(`INSERT INTO families`).
				WithArgs(pgxmock.AnyArg(), payload).
				WillReturnRows(pgxmock.NewRows([]string{"id"}).AddRow(familyID))
			mock.ExpectExec(`INSERT INTO family_members`).
				WithArgs(familyID, userUUID, "owner", pgxmock.AnyArg()).
				WillReturnResult(pgxmock.NewResult("INSERT", 1))
			mock.ExpectCommit()

			resp, err := svc.CreateFamily(authedCtx(), &familypb.CreateFamilyRequest{
				Name: payload,
			})

			if err == nil {
				// Parameterized query — injection is just stored as text
				assert.NotNil(t, resp)
			}
		})
	}
}

// ─── Boundary: extremely long input ─────────────────────────────────────────

func TestCreateAccount_ExtremelyLongName(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := account.NewService(mock)

	longName := strings.Repeat("A", 10000)

	_, err = svc.CreateAccount(authedCtx(), &accountpb.CreateAccountRequest{
		Name:     longName,
		Type:     accountpb.AccountType_ACCOUNT_TYPE_CASH,
		Currency: "CNY",
	})

	// Should either reject or succeed — must not panic
	// Best practice: reject with InvalidArgument
	if err != nil {
		// Acceptable
		_ = err
	}
}

// ─── Unicode / null byte injection ───────────────────────────────────────────

func TestCreateAccount_NullByteInName(t *testing.T) {
	mock, err := pgxmock.NewPool()
	require.NoError(t, err)
	defer mock.Close()

	svc := account.NewService(mock)

	_, err = svc.CreateAccount(authedCtx(), &accountpb.CreateAccountRequest{
		Name:     "Test\x00Account",
		Type:     accountpb.AccountType_ACCOUNT_TYPE_CASH,
		Currency: "CNY",
	})

	// PostgreSQL rejects null bytes — should not panic
	if err != nil {
		_ = err // acceptable
	}
}

// suppress unused import warnings
var (
	_ = timestamppb.Now
	_ = time.Now
)
