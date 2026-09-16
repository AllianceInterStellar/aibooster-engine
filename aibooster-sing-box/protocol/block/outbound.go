package block

import (
	"context"
	"net"
	"syscall"

	"github.com/AllianceInterStellar/aibooster-sing-box/adapter"
	"github.com/AllianceInterStellar/aibooster-sing-box/adapter/outbound"
	C "github.com/AllianceInterStellar/aibooster-sing-box/constant"
	"github.com/AllianceInterStellar/aibooster-sing-box/log"
	"github.com/AllianceInterStellar/aibooster-sing-box/option"
	"github.com/sagernet/sing/common/logger"
	M "github.com/sagernet/sing/common/metadata"
	N "github.com/sagernet/sing/common/network"
)

func RegisterOutbound(registry *outbound.Registry) {
	outbound.Register[option.StubOptions](registry, C.TypeBlock, New)
}

type Outbound struct {
	outbound.Adapter
	logger logger.ContextLogger
}

func New(ctx context.Context, router adapter.Router, logger log.ContextLogger, tag string, _ option.StubOptions) (adapter.Outbound, error) {
	return &Outbound{
		Adapter: outbound.NewAdapter(C.TypeBlock, tag, []string{N.NetworkTCP, N.NetworkUDP}, nil),
		logger:  logger,
	}, nil
}

func (h *Outbound) DialContext(ctx context.Context, network string, destination M.Socksaddr) (net.Conn, error) {
	h.logger.InfoContext(ctx, "blocked connection to ", destination)
	return nil, syscall.EPERM
}

func (h *Outbound) ListenPacket(ctx context.Context, destination M.Socksaddr) (net.PacketConn, error) {
	h.logger.InfoContext(ctx, "blocked packet connection to ", destination)
	return nil, syscall.EPERM
}
