//go:build with_naive_outbound

package include

import (
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/outbound"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/naive"
)

func registerNaiveOutbound(registry *outbound.Registry) {
	naive.RegisterOutbound(registry)
}
