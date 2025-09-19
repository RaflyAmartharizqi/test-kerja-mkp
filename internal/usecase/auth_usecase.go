package usecase

import (
	"context"
	"test-kerja-mkp/internal/entity"
	"test-kerja-mkp/internal/model"
	"test-kerja-mkp/internal/repository"
	"strings"
	"time"

	"github.com/go-playground/validator/v10"
	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/sirupsen/logrus"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type AuthUseCase struct {
	DB                            *gorm.DB
	Log                           *logrus.Logger
	Validate                      *validator.Validate
	AuthRepository                 *repository.AuthRepository
	JwtSecret                     []byte
}

func NewAuthUseCase(db *gorm.DB, logger *logrus.Logger, validate *validator.Validate, AuthRepository *repository.AuthRepository, jwtSecret []byte) *AuthUseCase {
	return &AuthUseCase{
		DB:                            db,
		Log:                           logger,
		Validate:                      validate,
		AuthRepository:           AuthRepository,
		JwtSecret:                     jwtSecret,
	}
}

func (c *AuthUseCase) LoginAdmin(ctx context.Context, request *model.LoginAdminRequest) (*model.LoginAdminResponse, error) {
	tx := c.DB.WithContext(ctx).Begin()
	defer tx.Rollback()

	if err := c.Validate.Struct(request); err != nil {
		c.Log.Warnf("Invalid request body: %v", err)
		return nil, fiber.ErrBadRequest
	}

	admin := new(entity.Admin)
	if err := c.AuthRepository.FindByUsername(tx, admin, request.Username); err != nil {
		c.Log.Warnf("Failed find user by username: %v", err)
		return nil, &fiber.Error{
			Code:    fiber.StatusUnauthorized,
		}
	}

	if err := bcrypt.CompareHashAndPassword([]byte(admin.Password), []byte(request.Password)); err != nil {
		c.Log.Warnf("Failed to compare user password with bcrypt hash: %v", err)
		return nil, &fiber.Error{
			Code:    fiber.StatusUnauthorized,
		}
	}

	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"uid":  admin.ID,
		"name": admin.Name,
		"type": "access",
		"exp":  time.Now().Add(time.Minute * 10).Unix(),
	})

	refreshToken := uuid.New().String()

	accessTokenStr, err := accessToken.SignedString(c.JwtSecret)
	if err != nil {
		return nil, err
	}

	expiresAt := time.Now().Add(time.Hour * 24 * 7)

	if err := tx.Commit().Error; err != nil {
		c.Log.Warnf("Failed commit transaction : %+v", err)
		return nil, fiber.ErrInternalServerError
	}

	return &model.LoginAdminResponse{
		Token: &model.TokenResponse{
			AccessToken:  accessTokenStr,
			RefreshToken: refreshToken,
			ExpiresIn:    600,
		},
		Admin: converter.AdminToResponse(admin),
	}, nil
}

func (c *AuthUseCase) Verify(ctx context.Context, request *model.VerifyAdminRequest) (*model.AuthAdmin, error) {
	if err := c.Validate.Struct(request); err != nil {
		c.Log.Warnf("Invalid request body: %+v", err)
		return nil, fiber.ErrBadRequest
	}

	tokenStr := strings.TrimSpace(strings.TrimPrefix(request.Token, "Bearer "))
	token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fiber.ErrUnauthorized
		}
		return c.JwtSecret, nil
	})
	if err != nil || !token.Valid {
		c.Log.Warnf("Invalid JWT token: %+v", err)
		return nil, fiber.ErrUnauthorized
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		c.Log.Warnf("Invalid JWT claims")
		return nil, err
	}

	if exp, ok := claims["exp"].(float64); ok {
		if time.Unix(int64(exp), 0).Before(time.Now()) {
			c.Log.Warn("Token expired")
			return nil, err
		}
	}

	adminID, ok := claims["uid"].(float64)
	if !ok {
		c.Log.Warn("Token claims: %+v", claims)
		return nil, err
	}

	admin := new(entity.Admin)
	if err := c.AuthRepository.FindById(c.DB.WithContext(ctx), admin, "id", uint64(adminID)); err != nil {
		print(admin)
		c.Log.Warnf("Failed to find admin by ID: %+v ", err)
		return nil, err
	}
	return &model.AuthAdmin{ID: int64(admin.ID)}, nil
}