package adapter

import (
	"context"

	"github.com/AllianceInterStellar/aibooster-sing-box/log"
	"github.com/AllianceInterStellar/aibooster-sing-box/option"
)

type Endpoint interface {
	Lifecycle
	Type() string
	Tag() string
	Outbound
}

type EndpointRegistry interface {
	option.EndpointOptionsRegistry
	Create(ctx context.Context, router Router, logger log.ContextLogger, tag string, endpointType string, options any) (Endpoint, error)
}

type EndpointManager interface {
	Lifecycle
	Endpoints() []Endpoint
	Get(tag string) (Endpoint, bool)
	Remove(tag string) error
	Create(ctx context.Context, router Router, logger log.ContextLogger, tag string, endpointType string, options any) error
}
