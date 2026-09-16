//go:build with_dhcp

package include

import (
	"github.com/AllianceInterStellar/aibooster-sing-box/dns"
	"github.com/AllianceInterStellar/aibooster-sing-box/dns/transport/dhcp"
)

func registerDHCPTransport(registry *dns.TransportRegistry) {
	dhcp.RegisterTransport(registry)
}
