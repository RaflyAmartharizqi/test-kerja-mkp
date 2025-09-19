package converter

import (
	"test-kerja-mkp/internal/entity"
	"test-kerja-mkp/internal/model"
)

func AdminToResponse(admin *entity.Admin) *model.AdminResponse {
	return &model.AdminResponse{
		ID:        admin.ID,
		Name:      admin.Name,
		Email:     admin.Email,
		CreatedAt: admin.CreatedAt,
		UpdatedAt: admin.UpdatedAt,
	}
}

func AdminToTokenResponse(admin *entity.Admin) *model.AdminResponse {
	return &model.AdminResponse{
		ID:            admin.ID,
		Name:          admin.Name,
		Email:         admin.Email,
		CreatedAt:     admin.CreatedAt,
		UpdatedAt:     admin.UpdatedAt,
		RememberToken: admin.RememberToken,
	}
}
