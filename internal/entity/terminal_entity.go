package entity

import "time"

type Terminal struct {
	IDTerminal int64     `json:"id_terminal" gorm:"primaryKey;autoIncrement;column:id_terminal"`
	Name       string    `json:"name" gorm:"column:name;type:nvarchar(100);not null" validate:"required,max=100"`
	Location   string    `json:"location" gorm:"column:location;type:nvarchar(100);not null" validate:"required,max=100"`
	CreatedAt  time.Time `json:"created_at" gorm:"column:created_at;autoCreateTime"`
	UpdatedAt  time.Time `json:"updated_at" gorm:"column:updated_at;autoUpdateTime"`
}

// TableName overrides the table name used by Terminal to `terminal`
func (Terminal) TableName() string {
	return "terminal"
}

		