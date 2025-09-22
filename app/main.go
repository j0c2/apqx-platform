// Sample Go web application for apqx-platform
// Provides basic HTTP endpoints with health checks

package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"runtime"
	"time"

	"github.com/gorilla/mux"
)

// AppInfo contains application metadata
type AppInfo struct {
	Name      string    `json:"name"`
	Version   string    `json:"version"`
	GoVersion string    `json:"go_version"`
	Platform  string    `json:"platform"`
	StartTime time.Time `json:"start_time"`
	Uptime    string    `json:"uptime"`
}

var (
	appName   = "sample-app"
	version   = "1.0.0"
	startTime = time.Now()
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	r := mux.NewRouter()

	// Health check endpoints
	r.HandleFunc("/health", healthHandler).Methods("GET")
	r.HandleFunc("/ready", readyHandler).Methods("GET")

	// Application endpoints
	r.HandleFunc("/", homeHandler).Methods("GET")
	r.HandleFunc("/info", infoHandler).Methods("GET")
	r.HandleFunc("/api/status", statusHandler).Methods("GET")

	// Static file serving (if needed)
	r.PathPrefix("/static/").Handler(http.StripPrefix("/static/", http.FileServer(http.Dir("./static/"))))

	log.Printf("Starting %s v%s on port %s", appName, version, port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

// healthHandler returns the health status of the application
func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(map[string]string{
		"status": "healthy",
		"time":   time.Now().Format(time.RFC3339),
	}); err != nil {
		log.Printf("Error encoding health response: %v", err)
	}
}

// readyHandler returns the readiness status of the application
func readyHandler(w http.ResponseWriter, r *http.Request) {
	// Add any readiness checks here (database connectivity, etc.)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(map[string]string{
		"status": "ready",
		"time":   time.Now().Format(time.RFC3339),
	}); err != nil {
		log.Printf("Error encoding ready response: %v", err)
	}
}

// homeHandler serves the main application page
func homeHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html")
	html := `
<!DOCTYPE html>
<html>
<head>
    <title>apqx-platform Sample App</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { 
            font-family: Arial, sans-serif; 
            max-width: 800px; 
            margin: 0 auto; 
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 { color: #333; }
        .info { 
            background-color: #e7f3ff; 
            padding: 15px; 
            border-radius: 4px; 
            margin: 20px 0;
        }
        .endpoint { 
            background-color: #f8f9fa; 
            padding: 10px; 
            margin: 10px 0; 
            border-left: 4px solid #007bff;
        }
        code { 
            background-color: #f1f1f1; 
            padding: 2px 4px; 
            border-radius: 3px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 apqx-platform Sample Application</h1>
        
        <div class="info">
            <strong>GitOps Platform Status:</strong> Running successfully!<br>
            <strong>Application:</strong> %s v%s<br>
            <strong>Started:</strong> %s<br>
            <strong>Uptime:</strong> %s
        </div>

        <h2>Available Endpoints</h2>
        <div class="endpoint">
            <strong>GET /</strong> - This homepage
        </div>
        <div class="endpoint">
            <strong>GET /health</strong> - Health check endpoint
        </div>
        <div class="endpoint">
            <strong>GET /ready</strong> - Readiness check endpoint
        </div>
        <div class="endpoint">
            <strong>GET /info</strong> - Application information (JSON)
        </div>
        <div class="endpoint">
            <strong>GET /api/status</strong> - API status endpoint (JSON)
        </div>

        <h2>Platform Components</h2>
        <ul>
            <li><strong>k3d</strong> - Lightweight Kubernetes cluster</li>
            <li><strong>Argo CD</strong> - GitOps continuous delivery</li>
            <li><strong>Kyverno</strong> - Policy management and security</li>
            <li><strong>Tailscale</strong> - Secure networking and remote access</li>
            <li><strong>Sealed Secrets</strong> - Encrypted secret management</li>
            <li><strong>Traefik</strong> - Ingress controller and load balancer</li>
        </ul>

        <p><em>This application is deployed using GitOps principles with immutable container images.</em></p>
    </div>
</body>
</html>`

	uptime := time.Since(startTime).Round(time.Second).String()
	if _, err := fmt.Fprintf(w, html, appName, version, startTime.Format(time.RFC3339), uptime); err != nil {
		log.Printf("Error writing home page response: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

// infoHandler returns detailed application information
func infoHandler(w http.ResponseWriter, r *http.Request) {
	info := AppInfo{
		Name:      appName,
		Version:   version,
		GoVersion: runtime.Version(),
		Platform:  fmt.Sprintf("%s/%s", runtime.GOOS, runtime.GOARCH),
		StartTime: startTime,
		Uptime:    time.Since(startTime).Round(time.Second).String(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(info); err != nil {
		log.Printf("Error encoding info response: %v", err)
	}
}

// statusHandler returns API status information
func statusHandler(w http.ResponseWriter, r *http.Request) {
	status := map[string]interface{}{
		"status":      "ok",
		"timestamp":   time.Now().Format(time.RFC3339),
		"application": appName,
		"version":     version,
		"endpoints": []string{
			"/health",
			"/ready",
			"/info",
			"/api/status",
		},
		"platform": map[string]string{
			"gitops":    "argocd",
			"policies":  "kyverno",
			"secrets":   "sealed-secrets",
			"ingress":   "traefik",
			"cluster":   "k3d",
			"network":   "tailscale",
		},
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(status); err != nil {
		log.Printf("Error encoding status response: %v", err)
	}
}
