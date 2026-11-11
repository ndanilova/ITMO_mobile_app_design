package main

import (
	"crypto/sha256"
	"database/sql"
	_ "embed"
	"encoding/csv"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"log"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
)

//go:embed sample.csv
var sampleReport []byte

type trade struct {
	ID     string `json:"id"`
	Amount string `json:"amount"`
}

var amountPattern = regexp.MustCompile(`^-?[0-9]{1,14}(\.[0-9]{1,4})?$`)

func parseReport(data string) ([]trade, error) {
	reader := csv.NewReader(strings.NewReader(data))
	reader.FieldsPerRecord = 2
	header, err := reader.Read()
	if err != nil || header[0] != "trade_id" || header[1] != "amount" {
		return nil, errors.New("expected trade_id,amount header")
	}
	var trades []trade
	seen := make(map[string]bool)
	for {
		row, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil || strings.TrimSpace(row[0]) == "" || !amountPattern.MatchString(row[1]) || seen[row[0]] {
			return nil, errors.New("invalid or duplicate trade")
		}
		seen[row[0]] = true
		trades = append(trades, trade{ID: row[0], Amount: row[1]})
	}
	if len(trades) == 0 {
		return nil, errors.New("report has no trades")
	}
	return trades, nil
}

func writeJSON(w http.ResponseWriter, code int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(value)
}

func main() {
	db, err := sql.Open("pgx", os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()
	if _, err := db.Exec(`CREATE TABLE IF NOT EXISTS report_imports (
		id text PRIMARY KEY,
		trades jsonb NOT NULL,
		confirmed boolean NOT NULL DEFAULT false
	)`); err != nil {
		log.Fatal(err)
	}

	mux := http.NewServeMux()
	if err := registerOperations(mux, db); err != nil {
		log.Fatal(err)
	}
	mux.HandleFunc("GET /sample.csv", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/csv")
		w.Header().Set("Content-Disposition", `attachment; filename="sample.csv"`)
		w.Write(sampleReport)
	})
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		if err := db.PingContext(r.Context()); err != nil {
			http.Error(w, "database unavailable", http.StatusServiceUnavailable)
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("GET /portfolio/trades", func(w http.ResponseWriter, r *http.Request) {
		var trades json.RawMessage
		err := db.QueryRowContext(r.Context(), `
			SELECT COALESCE(jsonb_agg(item.trade ORDER BY imports.id, item.position), '[]'::jsonb)
			FROM report_imports AS imports
			CROSS JOIN LATERAL jsonb_array_elements(imports.trades)
				WITH ORDINALITY AS item(trade, position)
			WHERE imports.confirmed
		`).Scan(&trades)
		if err != nil {
			log.Print(err)
			http.Error(w, "database unavailable", http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusOK, map[string]json.RawMessage{"trades": trades})
	})
	mux.HandleFunc("POST /imports", func(w http.ResponseWriter, r *http.Request) {
		data, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 1<<20))
		if err != nil {
			http.Error(w, "could not read report (limit 1 MiB)", http.StatusBadRequest)
			return
		}
		trades, err := parseReport(string(data))
		if err != nil {
			http.Error(w, err.Error(), http.StatusUnprocessableEntity)
			return
		}
		digest := sha256.Sum256(data)
		id := hex.EncodeToString(digest[:])
		payload, _ := json.Marshal(trades)
		var confirmed bool
		err = db.QueryRowContext(r.Context(), `INSERT INTO report_imports (id, trades)
			VALUES ($1, $2::jsonb) ON CONFLICT (id) DO UPDATE SET id = EXCLUDED.id
			RETURNING confirmed`, id, string(payload)).Scan(&confirmed)
		if err != nil {
			log.Print(err)
			http.Error(w, "database unavailable", http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"id": id, "trades": trades, "confirmed": confirmed})
	})
	mux.HandleFunc("POST /imports/{id}/confirm", func(w http.ResponseWriter, r *http.Request) {
		result, err := db.ExecContext(r.Context(), "UPDATE report_imports SET confirmed = true WHERE id = $1", r.PathValue("id"))
		if err != nil {
			log.Print(err)
			http.Error(w, "database unavailable", http.StatusInternalServerError)
			return
		}
		if count, _ := result.RowsAffected(); count == 0 {
			http.NotFound(w, r)
			return
		}
		writeJSON(w, http.StatusOK, map[string]bool{"confirmed": true})
	})
	addr := os.Getenv("LISTEN_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8080"
	}
	server := &http.Server{
		Addr: addr, Handler: mux, ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout: 15 * time.Second, WriteTimeout: 15 * time.Second,
	}
	log.Fatal(server.ListenAndServe())
}
