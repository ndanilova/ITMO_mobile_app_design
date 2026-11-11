package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"regexp"
	"strings"
)

type operation struct {
	ID     int64  `json:"id"`
	Title  string `json:"title"`
	Note   string `json:"note"`
	Amount string `json:"amount"`
}

var operationAmount = regexp.MustCompile(`^[+−]?[0-9]{1,12}(,[0-9]{1,2})? ₽$`)

func registerOperations(mux *http.ServeMux, db *sql.DB) error {
	_, err := db.Exec(`CREATE TABLE IF NOT EXISTS operations (
		id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
		title text NOT NULL,
		note text NOT NULL,
		amount text NOT NULL
	)`)
	if err != nil {
		return err
	}

	mux.HandleFunc("GET /operations", func(w http.ResponseWriter, r *http.Request) {
		rows, err := db.QueryContext(r.Context(),
			"SELECT id, title, note, amount FROM operations ORDER BY id DESC")
		if err != nil {
			operationDBError(w, err)
			return
		}
		defer rows.Close()
		operations := make([]operation, 0)
		for rows.Next() {
			var item operation
			if err := rows.Scan(&item.ID, &item.Title, &item.Note, &item.Amount); err != nil {
				operationDBError(w, err)
				return
			}
			operations = append(operations, item)
		}
		if err := rows.Err(); err != nil {
			operationDBError(w, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string][]operation{"operations": operations})
	})
	mux.HandleFunc("POST /operations", func(w http.ResponseWriter, r *http.Request) {
		var item operation
		err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096)).Decode(&item)
		item.Title = strings.TrimSpace(item.Title)
		if err != nil || item.Title == "" || len(item.Title) > 128 ||
			len(item.Note) > 512 || !operationAmount.MatchString(item.Amount) {
			http.Error(w, "invalid operation", http.StatusBadRequest)
			return
		}
		err = db.QueryRowContext(r.Context(),
			"INSERT INTO operations (title, note, amount) VALUES ($1, $2, $3) RETURNING id",
			item.Title, item.Note, item.Amount).Scan(&item.ID)
		if err != nil {
			operationDBError(w, err)
			return
		}
		writeJSON(w, http.StatusCreated, item)
	})
	return nil
}

func operationDBError(w http.ResponseWriter, err error) {
	log.Print(err)
	http.Error(w, "database unavailable", http.StatusInternalServerError)
}
