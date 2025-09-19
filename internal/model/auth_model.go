package model
import (
	"time"
)
type LoginAdminRequest struct {
	Username string `json:"username" validate:"required,min=3,max=100"`
	Password string `json:"password" validate:"required,min=6,max=100"`
}

type LoginAdminResponse struct {
	Token *TokenResponse `json:"token"`
	Admin *AdminResponse `json:"admin,omitempty"`
}

type GetAdminRequest struct {
	ID string `json:"id" validate:"required,max=100"`
}

type AdminResponse struct {
	ID       int64 `json:"id,omitempty"`
	Name     string `json:"name,omitempty"`
	Email    string `json:"email,omitempty"`
	RememberToken    string `json:"remember_token,omitempty"`
	CreatedAt time.Time  `json:"created_at,omitempty"`
	UpdatedAt time.Time  `json:"updated_at,omitempty"`
}

type VerifyAdminRequest struct {
	Token string `validate:"required"`
}

type TokenResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn   int64  `json:"expires_in"`
}

type AuthAdmin struct {
	ID int64
}