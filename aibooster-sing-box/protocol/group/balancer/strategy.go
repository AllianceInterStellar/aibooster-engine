package balancer

import "github.com/AllianceInterStellar/aibooster-sing-box/adapter"

type Strategy interface {
	UpdateOutboundsInfo(outbounds map[string]*adapter.URLTestHistory) (changed bool)
	Select(metadata adapter.InboundContext, network string, touch bool) adapter.Outbound
	Now() string
}
