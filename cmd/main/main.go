package main

import (
	"os"

	"github.com/AllianceInterStellar/aibooster-engine/cmd"
)

// type UpdateRequest struct {
// 	Description     string `json:"description,omitempty"`
// 	PrivatePods     bool   `json:"private_pods"`
// 	OperatingMode   string `json:"operating_mode,omitempty"`
// 	ActivationState string `json:"activation_state,omitempty"`
// }

func main() {
	cmd.ParseCli(os.Args[1:])
}
