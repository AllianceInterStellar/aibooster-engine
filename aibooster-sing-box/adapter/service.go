package adapter

import (
	"context"

	"github.com/AllianceInterStellar/aibooster-sing-box/log"
	"github.com/AllianceInterStellar/aibooster-sing-box/option"
)

type Service interface {
	Lifecycle
	Type() string
	Tag() string
}

type ServiceRegistry interface {
	option.ServiceOptionsRegistry
	Create(ctx context.Context, logger log.ContextLogger, tag string, serviceType string, options any) (Service, error)
}

type ServiceManager interface {
	Lifecycle
	Services() []Service
	Get(tag string) (Service, bool)
	Remove(tag string) error
	Create(ctx context.Context, logger log.ContextLogger, tag string, serviceType string, options any) error
}
