//go:build darwin && with_dhcp

package local

import (
	"context"

	"github.com/AllianceInterStellar/aibooster-sing-box/dns"
	"github.com/AllianceInterStellar/aibooster-sing-box/dns/transport/dhcp"
	"github.com/AllianceInterStellar/aibooster-sing-box/log"
	N "github.com/sagernet/sing/common/network"
)

func newDHCPTransport(transportAdapter dns.TransportAdapter, ctx context.Context, dialer N.Dialer, logger log.ContextLogger) dhcpTransport {
	return dhcp.NewRawTransport(transportAdapter, ctx, dialer, logger)
}
