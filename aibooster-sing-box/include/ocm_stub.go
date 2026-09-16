//go:build !with_ocm

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

func registerOCMService(registry *service.Registry) {
	service.Register[option.OCMServiceOptions](registry, C.TypeOCM, func(ctx context.Context, logger log.ContextLogger, tag string, options option.OCMServiceOptions) (adapter.Service, error) {
		return nil, E.New(`OCM is not included in this build, rebuild with -tags with_ocm`)
	})
}
