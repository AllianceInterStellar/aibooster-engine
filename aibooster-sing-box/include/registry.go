package include

import (
	"context"

	box "github.com/AllianceInterStellar/aibooster-sing-box"
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter"
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/endpoint"
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/inbound"
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/outbound"
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/service"
	C "github.com/AllianceInterStellar/aibooster-sing-box/constant"
	"github.com/AllianceInterStellar/aibooster-sing-box/dns"
	"github.com/AllianceInterStellar/aibooster-sing-box/dns/transport"
	"github.com/AllianceInterStellar/aibooster-sing-box/dns/transport/fakeip"
	"github.com/AllianceInterStellar/aibooster-sing-box/dns/transport/hosts"
	"github.com/AllianceInterStellar/aibooster-sing-box/dns/transport/local"
	"github.com/AllianceInterStellar/aibooster-sing-box/dns/transport/multi"
	"github.com/AllianceInterStellar/aibooster-sing-box/log"
	"github.com/AllianceInterStellar/aibooster-sing-box/option"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/anytls"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/block"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/direct"
	protocolDNS "github.com/AllianceInterStellar/aibooster-sing-box/protocol/dns"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/group"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/group/balancer"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/hiddify/dnstt"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/hiddify/hinvalid"

	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/hiddify/xray"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/http"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/mieru"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/mixed"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/naive"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/psiphon"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/redirect"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/shadowsocks"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/shadowtls"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/socks"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/ssh"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/tor"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/trojan"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/tun"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/tunnel"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/vless"
	"github.com/AllianceInterStellar/aibooster-sing-box/protocol/vmess"
	"github.com/AllianceInterStellar/aibooster-sing-box/service/resolved"
	"github.com/AllianceInterStellar/aibooster-sing-box/service/ssmapi"
	E "github.com/sagernet/sing/common/exceptions"
)

func Context(ctx context.Context) context.Context {
	return box.Context(ctx, InboundRegistry(), OutboundRegistry(), EndpointRegistry(), DNSTransportRegistry(), ServiceRegistry())
}

func InboundRegistry() *inbound.Registry {
	registry := inbound.NewRegistry()

	tun.RegisterInbound(registry)
	redirect.RegisterRedirect(registry)
	redirect.RegisterTProxy(registry)
	direct.RegisterInbound(registry)

	socks.RegisterInbound(registry)
	http.RegisterInbound(registry)
	mixed.RegisterInbound(registry)

	shadowsocks.RegisterInbound(registry)
	vmess.RegisterInbound(registry)
	trojan.RegisterInbound(registry)
	naive.RegisterInbound(registry)
	shadowtls.RegisterInbound(registry)
	vless.RegisterInbound(registry)
	anytls.RegisterInbound(registry)
	mieru.RegisterInbound(registry)
	ssh.RegisterInbound(registry)

	registerQUICInbounds(registry)
	registerStubForRemovedInbounds(registry)

	return registry
}

func OutboundRegistry() *outbound.Registry {
	registry := outbound.NewRegistry()

	direct.RegisterOutbound(registry)

	block.RegisterOutbound(registry)
	protocolDNS.RegisterOutbound(registry)

	group.RegisterSelector(registry)
	group.RegisterURLTest(registry)

	socks.RegisterOutbound(registry)
	http.RegisterOutbound(registry)
	shadowsocks.RegisterOutbound(registry)
	vmess.RegisterOutbound(registry)
	trojan.RegisterOutbound(registry)
	registerNaiveOutbound(registry)
	tor.RegisterOutbound(registry)
	ssh.RegisterOutbound(registry)
	shadowtls.RegisterOutbound(registry)
	vless.RegisterOutbound(registry)
	psiphon.RegisterOutbound(registry)
	mieru.RegisterOutbound(registry)
	anytls.RegisterOutbound(registry)
	hinvalid.RegisterOutbound(registry)
	xray.RegisterOutbound(registry)
	dnstt.RegisterOutbound(registry)
	balancer.RegisterLoadBalance(registry)

	registerQUICOutbounds(registry)
	registerWireGuardOutbound(registry)
	registerStubForRemovedOutbounds(registry)

	return registry
}

func EndpointRegistry() *endpoint.Registry {
	registry := endpoint.NewRegistry()

	tunnel.RegisterServerEndpoint(registry)
	tunnel.RegisterClientEndpoint(registry)

	registerWireGuardEndpoint(registry)
	registerTailscaleEndpoint(registry)
	registerAwgEndpoint(registry)

	return registry
}

func DNSTransportRegistry() *dns.TransportRegistry {
	registry := dns.NewTransportRegistry()

	transport.RegisterTCP(registry)
	transport.RegisterUDP(registry)
	transport.RegisterTLS(registry)
	transport.RegisterHTTPS(registry)
	transport.RegisterSDNS(registry)

	multi.RegisterTransport(registry) //H
	hosts.RegisterTransport(registry)
	local.RegisterTransport(registry)
	fakeip.RegisterTransport(registry)
	resolved.RegisterTransport(registry)

	registerQUICTransports(registry)
	registerDHCPTransport(registry)
	registerTailscaleTransport(registry)

	return registry
}

func ServiceRegistry() *service.Registry {
	registry := service.NewRegistry()

	resolved.RegisterService(registry)
	ssmapi.RegisterService(registry)

	registerDERPService(registry)
	registerCCMService(registry)
	registerOCMService(registry)

	return registry
}

func registerStubForRemovedInbounds(registry *inbound.Registry) {
	inbound.Register[option.ShadowsocksInboundOptions](registry, C.TypeShadowsocksR, func(ctx context.Context, router adapter.Router, logger log.ContextLogger, tag string, options option.ShadowsocksInboundOptions) (adapter.Inbound, error) {
		return nil, E.New("ShadowsocksR is deprecated and removed in sing-box 1.6.0")
	})
}

func registerStubForRemovedOutbounds(registry *outbound.Registry) {
	outbound.Register[option.ShadowsocksROutboundOptions](registry, C.TypeShadowsocksR, func(ctx context.Context, router adapter.Router, logger log.ContextLogger, tag string, options option.ShadowsocksROutboundOptions) (adapter.Outbound, error) {
		return nil, E.New("ShadowsocksR is deprecated and removed in sing-box 1.6.0")
	})
}
