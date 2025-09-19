package middleware

import (
	"test-kerja-mkp/internal/constants"
	"test-kerja-mkp/internal/helper"
	"test-kerja-mkp/internal/model"
	"test-kerja-mkp/internal/usecase"

	"github.com/gofiber/fiber/v2"
)

func NewAuthAdmin(authUseCase *usecase.AuthUseCase) fiber.Handler {
	return func(ctx *fiber.Ctx) error {
		request := &model.VerifyAdminRequest{Token: ctx.Get("Authorization", "NOT_FOUND")}
		authUseCase.Log.Debugf("Authorization : %s", request.Token)

		auth, err := authUseCase.Verify(ctx.UserContext(), request)
		if err != nil {
			authUseCase.Log.Warnf("Failed find user by token : %+v", err)
			return helper.ResponseError(ctx, fiber.StatusUnauthorized, constants.InvalidToken, nil)
		}

		authUseCase.Log.Debugf("User : %+v", auth.ID)
		ctx.Locals("auth", auth)
		return ctx.Next()
	}
}
