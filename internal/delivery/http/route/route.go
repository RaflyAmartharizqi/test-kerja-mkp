package route

import (
	"test-kerja-mkp/internal/delivery/http"

	"github.com/gofiber/fiber/v2"
)

type RouteConfig struct {
	App                   *fiber.App
	AuthController        *http.AuthController
	TerminalController    *http.TerminalController
	AuthMiddleware        fiber.Handler
}

func (c *RouteConfig) Setup() {
	c.SetupGuestRoute()
	c.SetupAuthRoute()
}

func (c *RouteConfig) SetupGuestRoute() {
	c.App.Post("/api/admin/auth/login", c.AuthController.Login)

}

func (c *RouteConfig) SetupAuthRoute() {
	c.App.Use(c.AuthMiddleware)

	c.App.Get("/api/admin/terminal", c.TerminalController.GetAll)
	c.App.Put("/api/admin/terminal/:terminal_id", c.TerminalController.Update)
	c.App.Get("/api/admin/terminal/:terminal_id", c.TerminalController.FindById)
	c.App.Post("/api/admin/terminal", c.TerminalController.Create)
}
