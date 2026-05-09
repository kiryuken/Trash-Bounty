package middleware

import (
	"log"
	"net/http"
	"runtime/debug"

	"trashbounty/pkg/response"
)

func Recovery(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				log.Printf("panic recovered: %v\n%s", rec, debug.Stack())
				response.Error(w, http.StatusInternalServerError, "terjadi kesalahan pada server")
			}
		}()

		next.ServeHTTP(w, r)
	})
}