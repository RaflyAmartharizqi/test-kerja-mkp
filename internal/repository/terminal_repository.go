package repository

import (
	"test-kerja-mkp/internal/entity"

	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
)

type TerminalRepository struct {
	Repository[entity.Terminal]
	Log *logrus.Logger
	DB  *gorm.DB
}

func NewTerminalRepository(log *logrus.Logger, db *gorm.DB) *TerminalRepository {
	return &TerminalRepository{
		Log: log,
		DB:  db,
	}
}

func (r *TerminalRepository) FindAll(page int, size int) ([]*entity.Terminal, int64, error) {
	var terminals []*entity.Terminal
	var total int64

	if err := r.DB.Model(&entity.Terminal{}).Where("deleted_at IS NULL").Count(&total).Error; err != nil {
		r.Log.Errorf("Failed to count terminals: %v", err)
		return nil, 0, err
	}

	offset := (page - 1) * size
	err := r.DB.Preload("Attachment").
		Where("deleted_at IS NULL").
		Order("created_at desc").
		Offset(offset).
		Limit(size).
		Find(&terminals).Error

	if err != nil {
		r.Log.Errorf("Failed to find terminals: %v", err)
		return nil, 0, err
	}
	return terminals, total, nil
}
