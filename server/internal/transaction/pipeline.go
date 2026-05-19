package transaction

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	db "github.com/familyledger/server/pkg/db"
	pb "github.com/familyledger/server/proto/transaction"
)

// ─── Pipeline Types ──────────────────────────────────────────────────────────

// Stage is a single step in the transaction creation pipeline.
// Each stage reads from PipelineState and may write results into it.
// Returning a non-nil error aborts the pipeline immediately.
type Stage interface {
	// Name returns a human-readable identifier for logging/debugging.
	Name() string
	// Execute performs the stage's work. ctx carries auth/timeout info.
	Execute(ctx context.Context, state *PipelineState) error
}

// PipelineState carries data between stages. Each stage reads what it needs
// and writes its outputs for downstream stages.
type PipelineState struct {
	// ─── Inputs (set before pipeline runs) ───────────────────────────────
	Pool    db.Pool
	UserID  string
	Request *pb.CreateTransactionRequest
	Hub     wsHub // optional, for notifications

	// ─── Validation outputs ──────────────────────────────────────────────
	Parsed *createRequest

	// ─── Transaction outputs ─────────────────────────────────────────────
	Tx             pgx.Tx    // opened by PersistStage, committed at end
	ResolvedCatID  uuid.UUID // after CategoryStage
	AccountMeta    *accountMeta
	BalanceDelta   int64

	// ─── Result (set by PersistStage) ────────────────────────────────────
	TxnID     uuid.UUID
	CreatedAt time.Time
	UpdatedAt time.Time

	// ─── Options ─────────────────────────────────────────────────────────
	SkipOverdraft bool // batch import mode
}

// Pipeline orchestrates an ordered chain of stages.
type Pipeline struct {
	stages []Stage
}

// NewPipeline creates a pipeline from the given stages (order matters).
func NewPipeline(stages ...Stage) *Pipeline {
	return &Pipeline{stages: stages}
}

// Run executes each stage in order. On error, if a transaction was opened
// it is rolled back. On success, the transaction is committed.
func (p *Pipeline) Run(ctx context.Context, state *PipelineState) error {
	for _, stage := range p.stages {
		if err := stage.Execute(ctx, state); err != nil {
			if state.Tx != nil {
				_ = state.Tx.Rollback(ctx)
				state.Tx = nil
			}
			return err
		}
	}
	// Commit if a transaction was opened
	if state.Tx != nil {
		if err := state.Tx.Commit(ctx); err != nil {
			return err
		}
		state.Tx = nil
	}
	return nil
}
