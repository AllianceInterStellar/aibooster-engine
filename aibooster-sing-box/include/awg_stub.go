//go:build !with_awg

package include

import (
	"context"

	"github.com/AllianceInterStellar/aibooster-sing-box/adapter"
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/endpoint"
	C "github.com/AllianceInterStellar/aibooster-sing-box/constant"
	"github.com/AllianceInterStellar/aibooster-sing-box/log"
	"github.com/AllianceInterStellar/aibooster-sing-box/option"
	E "github.com/sagernet/sing/common/exceptions"
)

func registerAwgEndpoint(registry *endpoint.Registry) {
	endpoint.Register(registry, C.TypeAwg, func(ctx context.Context, router adapter.Router, logger log.ContextLogger, tag string, options option.AwgEndpointOptions) (adapter.Endpoint, error) {
		return nil, E.New(`Awg is not included in this build, rebuild with -tags with_awg`)
	})
}
