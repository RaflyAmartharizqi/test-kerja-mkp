package http

import (
	"test-kerja-mkp/internal/constants"
	"test-kerja-mkp/internal/helper"
	"test-kerja-mkp/internal/model"
	"test-kerja-mkp/internal/usecase"

	"github.com/gofiber/fiber/v2"
	"github.com/sirupsen/logrus"
)

type AuthController struct {
	Log     *logrus.Logger
	UseCase *usecase.AuthUseCase
}

func NewAuthController(usecase *usecase.AuthUseCase, log *logrus.Logger) *AuthController {
	return &AuthController{
		Log:     log,
		UseCase: usecase,
	}
}

func (c *AuthController) Login(ctx *fiber.Ctx) error {
	request := new(model.LoginAdminRequest)

	if err := ctx.BodyParser(request); err != nil {
		c.Log.Errorf("Failed to parse request body: %v", err)
		return helper.ResponseError(ctx, fiber.StatusBadRequest, constants.InvalidRequestMessage, nil)
	}

	if err := helper.ValidateStruct(ctx, request); err != nil {
		c.Log.Errorf("Validation failed: %v", err)
		return helper.ResponseError(ctx, fiber.StatusBadRequest, constants.InvalidRequestMessage, err)
	}

	response, err := c.UseCase.LoginAdmin(ctx.Context(), request)

	if err != nil {
		c.Log.Errorf("Failed to login admin: %v", err)
		return helper.ResponseErrorFromErr(ctx, err, constants.FailedLoginMessage, nil)
	}

	return helper.ResponseSuccess(ctx, constants.SuccessLoginMessage, response)
}
