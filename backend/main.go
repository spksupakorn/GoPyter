package main

import (
	"log"
	"os"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	// Load environment variables
	godotenv.Load()

	// Initialize database
	db, err := InitDB()
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer db.Close()

	// Initialize router
	router := gin.Default()

	// CORS middleware
	config := cors.DefaultConfig()
	config.AllowAllOrigins = true
	config.AllowHeaders = []string{"Origin", "Content-Length", "Content-Type", "Authorization"}
	router.Use(cors.New(config))

	// Initialize handlers
	authHandler := NewAuthHandler(db)
	jupyterHandler := NewJupyterHandler(db)

	// Public routes
	public := router.Group("/api/v1")
	{
		public.POST("/register", authHandler.Register)
		public.POST("/login", authHandler.Login)
		public.GET("/jupyter/login", jupyterHandler.AutoLogin) // SSO endpoint (accepts token as query param)
		public.GET("/health", func(c *gin.Context) {
			c.JSON(200, gin.H{"status": "ok"})
		})
	}

	// Protected routes
	protected := router.Group("/api/v1")
	protected.Use(AuthMiddleware())
	{
		protected.GET("/profile", authHandler.GetProfile)
		protected.PUT("/profile", authHandler.UpdateProfile)
		protected.POST("/jupyter/start", jupyterHandler.StartSession)
		protected.GET("/jupyter/status", jupyterHandler.GetStatus)
		protected.POST("/jupyter/stop", jupyterHandler.StopSession)
		protected.GET("/jupyter/token", jupyterHandler.GetToken)
	}

	// Admin routes
	admin := router.Group("/api/v1/admin")
	admin.Use(AuthMiddleware(), AdminMiddleware())
	{
		admin.GET("/users", authHandler.ListUsers)
		admin.PUT("/users/:id", authHandler.UpdateUser)
		admin.DELETE("/users/:id", authHandler.DeleteUser)
		admin.GET("/sessions", jupyterHandler.ListSessions)
	}

	// Start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
