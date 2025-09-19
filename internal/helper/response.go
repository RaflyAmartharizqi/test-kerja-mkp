package helper

import (
	"test-kerja-mkp/internal/model"
	"net/http"

	"github.com/gofiber/fiber/v2"
)

func ResponseSuccess[T any](ctx *fiber.Ctx, message string, data T) error {
	resp := model.WebResponse[T]{
		Code:    fiber.StatusOK,
		Status:  http.StatusText(fiber.StatusOK),
		Message: message,
		Data:    data,
	}
	return ctx.Status(fiber.StatusOK).JSON(resp)
}

func ResponseSuccessWithoutData(ctx *fiber.Ctx, message string, data any) error {
	resp := model.WebResponse[any]{
		Code:    fiber.StatusOK,
		Status:  http.StatusText(fiber.StatusOK),
		Message: message,
		Data:    &data,
	}
	return ctx.Status(fiber.StatusOK).JSON(resp)
}

func ResponseSuccessPagination[T any](ctx *fiber.Ctx, data T, message string, paging *model.PageMetadata) error {
	resp := model.WebResponse[T]{
		Code:    200,
		Status:  "OK",
		Message: message,
		Data:    data,
		Paging:  paging,
	}
	return ctx.Status(fiber.StatusOK).JSON(resp)
}

func ResponseError(ctx *fiber.Ctx, code int, message string, errorMessages any) error {
	resp := model.WebResponse[any]{
		Code:    int64(code),
		Status:  http.StatusText(code),
		Message: message,
		Errors:  &errorMessages,
	}
	return ctx.Status(code).JSON(resp)
}

func ResponseErrorFromErr(ctx *fiber.Ctx, err error, defaultMessage string, errorDetails any) error {
	code := fiber.StatusInternalServerError
	message := defaultMessage

	if fe, ok := err.(*fiber.Error); ok {
		code = fe.Code
		if fe.Message != "" {
			message = fe.Message
		}
	}

	if message == "" {
		message = http.StatusText(code)
	}

	return ResponseError(ctx, code, message, errorDetails)
}
