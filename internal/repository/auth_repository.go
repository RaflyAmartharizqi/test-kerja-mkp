package repository

import (
	"test-kerja-mkp/internal/entity"

	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

type AuthRepository struct {
	Repository[entity.Admin]
	Log *logrus.Logger
}

func NewAuthRepository(log *logrus.Logger) *AuthRepository {
	return &AuthRepository{
		Log: log,
	}
}

func (r *AuthRepository) FindByToken(db *gorm.DB, admin *entity.Admin, token string) error {
	return db.Where("token = ?", token).First(admin).Error
}

func (r *AuthRepository) FindByUsername(db *gorm.DB, admin *entity.Admin, username string) error {
	return db.Where("username = ?", username).First(admin).Error
}

