//go:build !with_ccm

package include

import (
	"context"

	"github.com/AllianceInterStellar/aibooster-sing-box/adapter"
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/service"
	C "github.com/AllianceInterStellar/aibooster-sing-box/constant"
	"github.com/AllianceInterStellar/aibooster-sing-box/log"
	"github.com/AllianceInterStellar/aibooster-sing-box/option"
	E "github.com/sagernet/sing/common/exceptions"
)

func registerCCMService(registry *service.Registry) {
	service.Register[option.CCMServiceOptions](registry, C.TypeCCM, func(ctx context.Context, logger log.ContextLogger, tag string, options option.CCMServiceOptions) (adapter.Service, error) {
		return nil, E.New(`CCM is not included in this build, rebuild with -tags with_CCM`)
	})
}
