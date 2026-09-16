package settings

import "github.com/AllianceInterStellar/aibooster-sing-box/adapter"

type WIFIMonitor interface {
	ReadWIFIState() adapter.WIFIState
	Start() error
	Close() error
}
