package repository

import (
	"gorm.io/gorm"
	"fmt"
)

type Repository[T any] struct {
	DB *gorm.DB
}

func (r *Repository[T]) Create(db *gorm.DB, entity *T) error {
	return db.Create(entity).Error
}

func (r *Repository[T]) Update(db *gorm.DB, entity *T) error {
	return db.Save(entity).Error
}

func (r *Repository[T]) Delete(db *gorm.DB, entity *T) error {
	return db.Delete(entity).Error
}

func (r *Repository[T]) CountById(db *gorm.DB, fieldName string, id any) (int64, error) {
	var total int64
	err := db.Model(new(T)).Where(fmt.Sprintf("%s = ?", fieldName), id).Count(&total).Error
	return total, err
}

func (r *Repository[T]) FindById(db *gorm.DB, entity *T, fieldName string, id any) error {
	return db.
	Where(fmt.Sprintf("%s = ?", fieldName), id).
	Take(entity).Error
}
