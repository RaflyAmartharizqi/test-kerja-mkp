package helper

import (
    "strings"

    "github.com/go-playground/locales/en"
    ut "github.com/go-playground/universal-translator"
    "github.com/go-playground/validator/v10"
    en_translations "github.com/go-playground/validator/v10/translations/en"

    "github.com/gofiber/fiber/v2"
)

var Validate *validator.Validate
var Trans ut.Translator

func InitValidator() {
    Validate = validator.New()

    // Pilih bahasa default (Inggris)
    enLocale := en.New()
    uni := ut.New(enLocale, enLocale)
    Trans, _ = uni.GetTranslator("en")

    // Registrasi terjemahan default
    en_translations.RegisterDefaultTranslations(Validate, Trans)
}

func ValidateStruct(ctx *fiber.Ctx, request interface{}) map[string]string {
    if err := Validate.Struct(request); err != nil {
        errors := make(map[string]string)
        for _, e := range err.(validator.ValidationErrors) {
            errors[strings.ToLower(e.Field())] = e.Translate(Trans)
        }
        return errors
    }
    return nil
}

