//go:build with_wireguard

package include

import (
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/endpoint"
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/outbound"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/wireguard"
)

func registerWireGuardOutbound(registry *outbound.Registry) {
	wireguard.RegisterOutbound(registry)
}

func registerWireGuardEndpoint(registry *endpoint.Registry) {
	wireguard.RegisterEndpoint(registry)
	wireguard.RegisterWARPEndpoint(registry)
}
