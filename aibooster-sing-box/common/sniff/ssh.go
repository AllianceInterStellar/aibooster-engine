package sniff

import (
	"bufio"
	"context"
	"io"
	"os"

	"github.com/AllianceInterStellar/aibooster-sing-box/adapter"
	C "github.com/AllianceInterStellar/aibooster-sing-box/constant"
	E "github.com/sagernet/sing/common/exceptions"
)

func SSH(_ context.Context, metadata *adapter.InboundContext, reader io.Reader) error {
	const sshPrefix = "SSH-2.0-"
	bReader := bufio.NewReader(reader)
	prefix, err := bReader.Peek(len(sshPrefix))
	if string(prefix[:]) != sshPrefix[:len(prefix)] {
		return os.ErrInvalid
	}
	if err != nil {
		return E.Cause1(ErrNeedMoreData, err)
	}
	fistLine, _, err := bReader.ReadLine()
	if err != nil {
		return err
	}
	metadata.Protocol = C.ProtocolSSH
	metadata.Client = string(fistLine)[8:]
	return nil
}
