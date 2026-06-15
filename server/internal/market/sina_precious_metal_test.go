package market

import "testing"

func TestParseSinaPreciousMetal(t *testing.T) {
	// Real AU9999 line (price=937.52, prevClose=907.47, open=912.60, name=沪金99).
	const auLine = `var hq_str_gds_AU9999="937.52,0,938.50,939.89,943.00,909.00,15:30:01,907.47,912.60,428852,20.00,9.00,2026-06-15,沪金99";`

	q, err := parseSinaPreciousMetal("Au99.99", "AU9999", auLine)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if q.CurrentPrice != 93752 {
		t.Errorf("CurrentPrice = %d, want 93752", q.CurrentPrice)
	}
	if q.PrevClose != 90747 {
		t.Errorf("PrevClose = %d, want 90747", q.PrevClose)
	}
	// change = 937.52 - 907.47 = 30.05 -> 3005 cents
	if q.ChangeAmount != 3005 {
		t.Errorf("ChangeAmount = %d, want 3005", q.ChangeAmount)
	}
	// pct = 30.05 / 907.47 * 100 ≈ 3.311%
	if q.ChangePercent < 3.30 || q.ChangePercent > 3.32 {
		t.Errorf("ChangePercent = %.4f, want ~3.31", q.ChangePercent)
	}
	if q.Open != 91260 {
		t.Errorf("Open = %d, want 91260", q.Open)
	}
	if q.Name != "沪金99" {
		t.Errorf("Name = %q, want 沪金99", q.Name)
	}
	if q.MarketType != "precious_metal" {
		t.Errorf("MarketType = %q, want precious_metal", q.MarketType)
	}
}

func TestParseSinaPreciousMetal_Errors(t *testing.T) {
	tests := []struct {
		name string
		body string
	}{
		{"empty quote (delisted/wrong code)", `var hq_str_gds_AG9999="";`},
		{"no quotes at all", `garbage`},
		{"too few fields", `var hq_str_gds_X="1.0,2.0,3.0";`},
		{"non-positive price", `var hq_str_gds_X="0,0,0,0,0,0,00:00:00,0,0,0,0,0,2026-06-15,X";`},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if _, err := parseSinaPreciousMetal("X", "X", tt.body); err == nil {
				t.Errorf("expected error for %q, got nil", tt.body)
			}
		})
	}
}

// Guard: every supported symbol must have a Sina code, and the dropped
// Ag99.99 must NOT be present.
func TestPreciousMetalSinaCode_Coverage(t *testing.T) {
	for _, pm := range preciousMetalList {
		if _, ok := preciousMetalSinaCode[pm.Symbol]; !ok {
			t.Errorf("preciousMetalList has %q but no Sina code mapping", pm.Symbol)
		}
	}
	if _, ok := preciousMetalSinaCode["Ag99.99"]; ok {
		t.Error("Ag99.99 should have been removed (Sina has no silver spot)")
	}
}
