package usecase

import (
	"context"
	"test-kerja-mkp/internal/entity"
	"test-kerja-mkp/internal/model"
	"test-kerja-mkp/internal/repository"
	"time"

	"github.com/go-playground/validator/v10"
	"github.com/gofiber/fiber/v2"
	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

type TerminalUseCase struct {
	Log      *logrus.Logger
	DB      *gorm.DB
	Validate *validator.Validate
	TerminalRepository *repository.TerminalRepository
}

func NewTerminalUseCase(log *logrus.Logger, TerminalRepository *repository.TerminalRepository, db *gorm.DB, validate *validator.Validate) *TerminalUseCase {
	return &TerminalUseCase{
		Log:              log,
		DB:               db,
		Validate:         validate,
		TerminalRepository: TerminalRepository,
	}
}

