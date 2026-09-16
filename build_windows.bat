@echo off
set GOOS=windows
set GOARCH=amd64
set CC=x86_64-w64-mingw32-gcc
set CGO_ENABLED=1
go run ./cli tunnel exit
del bin\aibooster-core.dll bin\AiBoosterCli.exe
set CGO_LDFLAGS=
go build -trimpath -tags with_gvisor,with_quic,with_wireguard,with_ech,with_utls,with_clash_api,with_grpc -ldflags="-w -s" -buildmode=c-shared -o bin/aibooster-core.dll ./custom
go get github.com/akavel/rsrc
go install github.com/akavel/rsrc

rsrc  -ico .\assets\aibooster-cli.ico -o cli\bydll\cli.syso

copy bin\aibooster-core.dll .
set CGO_LDFLAGS="aibooster-core.dll"
go build  -o bin/AiBoosterCli.exe ./cli/bydll/
del aibooster-core.dll
