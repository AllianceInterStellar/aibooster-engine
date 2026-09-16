# AI Booster engine — corresponding source

This repository is the **complete corresponding source** for the tunnelling engine that AI
Booster distributes as `aibooster-core`. It exists so that anyone who receives one of those
binaries can rebuild it, which GPL-3.0 requires of us.

It is not upstream. It is upstream **plus our changes**, and it is published under the same
licence as the code it derives from.

## Where it comes from

- [hiddify-core](https://github.com/hiddify/hiddify-core) v4.1.0 — GPL-3.0 with additional
  terms under section 7
- [hiddify-sing-box](https://github.com/hiddify/hiddify-sing-box) at `0a02b772`, itself
  derived from [sing-box](https://github.com/SagerNet/sing-box) — GPL-3.0-or-later

Submodules are checked in as plain directories rather than left as git submodules, so that
this tree builds with nothing but a clone and a Go toolchain. The submodule commits the
tree was taken from are recorded in `SUBMODULE-COMMITS.txt`.

## Our changes

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

This is a fork, so it carries our names where the names are ours to choose: the Go module
path, the vendored engine directory, the binaries the Makefile produces, and every string
the program prints at a user.

Three things deliberately keep upstream's names, because changing them would break
something rather than rebrand it:

- **`github.com/sagernet/...` import paths** (5,955 of them). That is another project's
  module identity, not a label — the code resolves those imports through a `replace`
  directive pointing at the vendored directory. Renaming them would mean hard-forking
  sing-box's own module, and nothing would compile until every last one matched.
- **Protobuf-generated `.pb.go` files must never be text-substituted.** Their descriptor is
  a string constant in which every path is preceded by a length byte; replacing a path with
  a longer one leaves the length behind and the program panics at package init with
  `slice bounds out of range`. To change a path that appears in one, edit `option go_package`
  in the `.proto` and regenerate with protoc. This is why the vendored engine's module path
  is still `github.com/sagernet/sing-box`: the rename compiles, but three generated files
  need regenerating before the binary will start.
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
