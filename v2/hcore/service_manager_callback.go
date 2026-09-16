package hcore

import (
	"github.com/AllianceInterStellar/aibooster-engine/v2/service_manager"
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter"
)

type hiddifyMainServiceManager struct{}

var _ adapter.LifecycleService = (*hiddifyMainServiceManager)(nil)

func (h *hiddifyMainServiceManager) Name() string { return "hiddifyMainServiceManager" }
func (h *hiddifyMainServiceManager) Start(stage adapter.StartStage) error {
	if stage == adapter.StartStateStarted {
		return service_manager.OnMainServiceStart()
	}
	return nil
}

func (h *hiddifyMainServiceManager) Close() error {
	return service_manager.OnMainServiceClose()
}
