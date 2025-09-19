package model

type Terminal struct {
	ID          int64     `json:"id_terminal"`
	Name       string    `json:"name"`
	Location   string    `json:"location"`
}

type CreateTerminalRequest struct {
    Name       string                `form:"name" validate:"required"`
    Location   string                `form:"location" validate:"required"`
}

type TerminalResponse struct {
	TerminalId       int64     `json:"id_terminal"`
	Name       string    `json:"name"`
	Location   string    `json:"location"`
}
