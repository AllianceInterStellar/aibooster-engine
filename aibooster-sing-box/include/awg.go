//go:build with_awg

package include

import (
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/endpoint"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/awg"
)

func registerAwgEndpoint(registry *endpoint.Registry) {
	awg.RegisterEndpoint(registry)
}
