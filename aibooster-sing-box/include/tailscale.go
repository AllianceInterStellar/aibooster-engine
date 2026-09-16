//go:build with_tailscale

package include

import (
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/endpoint"
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/service"
	"github.com/AllianceInterStellar/aibooster-sing-box/dns"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/tailscale"
	"github.com/AllianceInterStellar/aibooster-sing-box/service/derp"
)

func registerTailscaleEndpoint(registry *endpoint.Registry) {
	tailscale.RegisterEndpoint(registry)
}

func registerTailscaleTransport(registry *dns.TransportRegistry) {
	tailscale.RegistryTransport(registry)
}

func registerDERPService(registry *service.Registry) {
	derp.Register(registry)
}
