//go:build with_ocm

package include

import (
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/service"
	"github.com/AllianceInterStellar/aibooster-sing-box/service/ocm"
)

func registerOCMService(registry *service.Registry) {
	ocm.RegisterService(registry)
}
