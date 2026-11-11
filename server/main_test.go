package main

import "testing"

func TestParseReport(t *testing.T) {
	trades, err := parseReport("trade_id,amount\nfirst,12.3400\nsecond,-0.01\n")
	if err != nil || len(trades) != 2 || trades[0].Amount != "12.3400" {
		t.Fatalf("parseReport = %+v, %v", trades, err)
	}
	for _, report := range []string{
		"",
		"trade_id\n",
		"trade_id,amount\n",
		"trade_id,amount\na,1.00001\n",
		"trade_id,amount\na,1\na,2\n",
		"trade_id,amount\na\n",
	} {
		if _, err := parseReport(report); err == nil {
			t.Errorf("accepted invalid report %q", report)
		}
	}
}
