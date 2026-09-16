# AI Booster engine — corresponding source

This repository is the **complete corresponding source** for the tunnelling engine that AI
Booster distributes as `aibooster-core`. It exists so that anyone who receives one of those
binaries can rebuild it, which GPL-3.0 requires of us.

Everything builds from a clone and a Go toolchain — there are no submodules to initialise.

Where the code originally came from, what it is licensed under, and the modification notice
GPL-3.0 requires are in **[COPYRIGHT.md](COPYRIGHT.md)**, which is where those notices
belong. The commits the vendored directories were taken from are in `SUBMODULE-COMMITS.txt`.

## What we changed

- `v2/config/builder.go` — a rule-set base URL of our own, and a default balancer strategy
- `aibooster-sing-box/experimental/clashapi/server.go` — the Clash API's history store is
  built explicitly rather than looked up per outbound, which is why proxy health readings
  no longer come back empty while traffic is flowing
- `aibooster-sing-box/common/monitoring/outbound_monitoring.go` — outbound monitoring changes
- `aibooster-sing-box/daemon/*`, `aibooster-sing-box/experimental/libbox/command_types.go` —
  service and command-surface changes
- `aibooster-sing-box/.gitmodules` — submodule URLs rewritten from SSH to HTTPS, so the tree
  can be cloned without credentials

## Naming

This is a fork, so it carries our names where the names are ours to choose: **both** module
paths — this one and the vendored engine's — the engine directory, the binaries the Makefile
produces, and every string the program prints at a user.

Two things deliberately keep upstream's names, because changing them would break something
rather than rebrand it:

- **Third-party module identities.** `github.com/sagernet/...` — sing-dns, sing-tun, gvisor,
  cronet-go and the rest — are other people's modules, pulled from their own repositories. A
  module path is an identity, not a label: renaming one does not rename the project, it just
  stops Go from finding it. The one engine we vendor and modify does carry our name.
- **The descriptor blobs inside three `.pb.go` files.** Protobuf's generated descriptor is a
  string constant in which every path is preceded by a length byte, so replacing a path with
  a longer one leaves the length stale and the program panics at package init with
  `slice bounds out of range` — while compiling perfectly. Those three files are therefore
  left byte-for-byte alone; nothing imports through them, so the rename does not need them.
  Their `.proto` sources do carry our path, so a regeneration with protoc will bring the
  descriptors along; until then they still describe themselves by the old name, which is
  metadata and is not used to resolve anything at runtime.
- **Copyright headers and `LICENSE.md`.** GPL-3.0 requires they be preserved, and this
  repository exists to satisfy that licence, not to work around it.

## Building

Requires **Go 1.26.1**. Older toolchains produce a binary that panics before `main()`: a
vendored TLS package asserts at init that its own struct layout matches `crypto/tls`, and
that assertion is version-specific.

```bash
go build -trimpath -ldflags="-w -s -checklinkname=0 -buildid=" \
  -tags "with_gvisor,with_quic,with_wireguard,with_utls,with_clash_api,with_grpc,with_awg,tfogo_checklinkname0,with_conntrack,with_dhcp" \
  -o aibooster-core ./cmd/main
```

`with_naive_outbound` is omitted: it links a prebuilt `libcronet.a` using CREL relocations,
which binutils older than 2.43 cannot read. Add it back on a newer toolchain if you want the
naive protocol.

Verify the result actually starts before trusting it:

```bash
./aibooster-core version
```

## Copyright

Copyright (C) 2026 AllianceInterStellar, for the changes listed above. Upstream's copyright
notices are kept intact — see [COPYRIGHT.md](COPYRIGHT.md) for the modification notice
GPL-3.0 section 5a requires, and for what we hold and what we do not.

## Licence

GPL-3.0, with upstream's additional section 7 terms — see `LICENSE.md`, which is upstream's
own and is reproduced unchanged.
