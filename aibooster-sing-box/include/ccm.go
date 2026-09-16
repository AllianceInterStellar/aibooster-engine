//go:build with_ccm && (!darwin || cgo)

package include

import (
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/service"
	"github.com/AllianceInterStellar/aibooster-sing-box/service/ccm"
)

func registerCCMService(registry *service.Registry) {
	ccm.RegisterService(registry)
}
