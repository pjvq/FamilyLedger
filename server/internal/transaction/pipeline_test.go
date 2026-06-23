package transaction

import (
	"context"
	"errors"
	"testing"

	pb "github.com/familyledger/server/proto/transaction"
)

// ─── Pipeline Unit Tests ─────────────────────────────────────────────────────

// testStage is a controllable stage for testing pipeline behavior.
type testStage struct {
	name   string
	err    error
	called bool
}

func (s *testStage) Name() string { return s.name }
func (s *testStage) Execute(_ context.Context, _ *PipelineState) error {
	s.called = true
	return s.err
}

func TestPipeline_RunsAllStagesInOrder(t *testing.T) {
	var order []string
	makeStage := func(name string) Stage {
		return &orderStage{name: name, order: &order}
	}

	p := NewPipeline(makeStage("a"), makeStage("b"), makeStage("c"))
	state := &PipelineState{}
	err := p.Run(context.Background(), state)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(order) != 3 || order[0] != "a" || order[1] != "b" || order[2] != "c" {
		t.Fatalf("expected [a b c], got %v", order)
	}
}

func TestPipeline_AbortsOnFirstError(t *testing.T) {
	errBoom := errors.New("boom")
	s1 := &testStage{name: "s1"}
	s2 := &testStage{name: "s2", err: errBoom}
	s3 := &testStage{name: "s3"}

	p := NewPipeline(s1, s2, s3)
	state := &PipelineState{}
	err := p.Run(context.Background(), state)

	if err != errBoom {
		t.Fatalf("expected errBoom, got %v", err)
	}
	if !s1.called {
		t.Fatal("s1 should have been called")
	}
	if !s2.called {
		t.Fatal("s2 should have been called")
	}
	if s3.called {
		t.Fatal("s3 should NOT have been called after s2 errored")
	}
}

func TestPipeline_SkipsOverdraftWhenFlagSet(t *testing.T) {
	// Verify that OverdraftStage respects BatchMode
	stage := OverdraftStage{}
	state := &PipelineState{
		BatchMode: true,
		Parsed: &createRequest{
			txnType:   "expense",
			amountCny: 9999,
		},
		AccountMeta: &accountMeta{acctType: "bank"},
	}
	// Should not error even though there's no Tx to query balance from
	err := stage.Execute(context.Background(), state)
	if err != nil {
		t.Fatalf("expected nil error with BatchMode=true, got %v", err)
	}
	if state.BalanceDelta != -9999 {
		t.Fatalf("expected BalanceDelta=-9999, got %d", state.BalanceDelta)
	}
}

func TestPipeline_IncomeDoesNotCheckOverdraft(t *testing.T) {
	stage := OverdraftStage{}
	state := &PipelineState{
		Parsed: &createRequest{
			txnType:   "income",
			amountCny: 5000,
		},
		AccountMeta: &accountMeta{acctType: "bank"},
	}
	err := stage.Execute(context.Background(), state)
	if err != nil {
		t.Fatalf("income should never check overdraft, got %v", err)
	}
	if state.BalanceDelta != 5000 {
		t.Fatalf("expected BalanceDelta=5000, got %d", state.BalanceDelta)
	}
}

func TestPipeline_OCP_CustomStageWithoutModifyingExisting(t *testing.T) {
	// Demonstrates Open-Closed Principle: adding a new concern
	// by implementing Stage interface — no existing code modified.
	var rateLimited bool
	rateLimit := &funcStage{
		name: "rate_limit",
		fn: func(_ context.Context, _ *PipelineState) error {
			rateLimited = true
			return nil
		},
	}

	// Insert rate limiter BEFORE validation
	p := NewPipeline(rateLimit, ValidateStage{})
	state := &PipelineState{
		UserID:  "00000000-0000-0000-0000-000000000001",
		Request: &pb.CreateTransactionRequest{}, // empty → ValidateStage will fail on invalid fields
	}
	_ = p.Run(context.Background(), state) // will error at ValidateStage (empty account_id)

	if !rateLimited {
		t.Fatal("custom rate_limit stage should have executed before validate")
	}
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

type orderStage struct {
	name  string
	order *[]string
}

func (s *orderStage) Name() string { return s.name }
func (s *orderStage) Execute(_ context.Context, _ *PipelineState) error {
	*s.order = append(*s.order, s.name)
	return nil
}

// funcStage wraps a function as a Stage (useful for tests).
type funcStage struct {
	name string
	fn   func(context.Context, *PipelineState) error
}

func (s *funcStage) Name() string { return s.name }
func (s *funcStage) Execute(ctx context.Context, state *PipelineState) error {
	return s.fn(ctx, state)
}
