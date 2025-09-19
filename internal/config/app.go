package config

import (
	"test-kerja-mkp/internal/delivery/http"
	"test-kerja-mkp/internal/delivery/http/middleware"
	"test-kerja-mkp/internal/delivery/http/route"
	"test-kerja-mkp/internal/repository"
	"test-kerja-mkp/internal/usecase"

	"github.com/go-playground/validator/v10"
	"github.com/gofiber/fiber/v2"
	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"
	"gorm.io/gorm"
)

type BootstrapConfig struct {
	DB       *gorm.DB
	App      *fiber.App
	Log      *logrus.Logger
	Validate *validator.Validate
	Config   *viper.Viper
}

func Bootstrap(config *BootstrapConfig) {
	jwtSecret := config.Config.GetString("app.jwtSecretKey")
	// setup repositories

	authAdminRepository := repository.NewAuthAdminRepository(config.Log)
	personalAccessTokenRepository := repository.NewPersonalAccessTokenRepository(config.Log)
	authStudentRepository := repository.NewAuthStudentRepository(config.Log)
	bannerRepository := repository.NewBannerRepository(config.Log, config.DB)
	attachmentRepository := repository.NewAttachmentRepository(config.Log)

	// setup use cases
	authAdminUseCase := usecase.NewAuthAdminUseCase(config.DB, config.Log, config.Validate, authAdminRepository, personalAccessTokenRepository, []byte(jwtSecret))
	authStudentUseCase := usecase.NewAuthStudentUseCase(config.DB, config.Log, config.Validate, authStudentRepository, personalAccessTokenRepository, []byte(jwtSecret))
	attachmentUseCase := usecase.NewAttachmentUseCase(config.DB, attachmentRepository, config.Log)
	bannerUseCase := usecase.NewBannerUseCase(config.Log, bannerRepository, config.DB, config.Validate, attachmentUseCase)

	// setup controller
	authAdminController := controller.NewAuthAdminController(authAdminUseCase, config.Log)
	authStudentController := controller.NewAuthStudentController(authStudentUseCase, config.Log)
	bannerController := controller.NewBannerController(bannerUseCase, config.Log)

	authAdminMiddleware := middleware.NewAuthAdmin(authAdminUseCase)

	routeConfig := route.RouteConfig{
		App:                   config.App,
		AuthAdminController:   authAdminController,
		AuthStudentController: authStudentController,
		BannerController:      bannerController,
		AuthMiddleware:        authAdminMiddleware,
	}
	routeConfig.Setup()
}
