package http

import (
	"test-kerja-mkp/internal/constants"
	"test-kerja-mkp/internal/helper"
	"test-kerja-mkp/internal/model"
	"test-kerja-mkp/internal/usecase"
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/sirupsen/logrus"
)

type TerminalController struct {
	Log     *logrus.Logger
	UseCase *usecase.TerminalUseCase
}

func NewTerminalController(usecase *usecase.TerminalUseCase, log *logrus.Logger) *TerminalController {
	return &TerminalController{
		Log:     log,
		UseCase: usecase,
	}
}

func (c *TerminalController) Create(ctx *fiber.Ctx) error {
	request := &model.CreateTerminalRequest{
		Name:      ctx.FormValue("name"),
		Location:  ctx.FormValue("location"),
	}

	if errors := helper.ValidateStruct(ctx, request); errors != nil {
		c.Log.Warnf("Validation failed: %v", errors)
		return helper.ResponseError(ctx, fiber.StatusBadRequest, constants.InvalidRequestMessage, errors)
	}

	response, err := c.UseCase.Create(ctx.Context(), request)
	if err != nil {
		c.Log.Warnf("Failed to create Terminal: %v", err)
		return helper.ResponseErrorFromErr(ctx, err, constants.FailedCreateMessage, nil)
	}

	return helper.ResponseSuccess(ctx, constants.SuccessCreateMessage, response)
}

func (c *TerminalController) GetAll(ctx *fiber.Ctx) error {
	page, _ := strconv.Atoi(ctx.Query("page", "1"))
	size, _ := strconv.Atoi(ctx.Query("size", "10"))

	Terminals, paging, err := c.UseCase.FindAll(ctx.Context(), page, size)
	if err != nil {
		return helper.ResponseErrorFromErr(ctx, err, constants.FailedGetDataMessage, nil)
	}

	return helper.ResponseSuccessPagination(ctx, Terminals, constants.SuccessGetDataMessage, paging)
}