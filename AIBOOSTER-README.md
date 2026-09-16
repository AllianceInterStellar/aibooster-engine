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
- `hiddify-sing-box/experimental/clashapi/server.go` — the Clash API's history store is
  built explicitly rather than looked up per outbound, which is why proxy health readings
  no longer come back empty while traffic is flowing
- `hiddify-sing-box/common/monitoring/outbound_monitoring.go` — outbound monitoring changes
- `hiddify-sing-box/daemon/*`, `hiddify-sing-box/experimental/libbox/command_types.go` —
  service and command-surface changes
- `hiddify-sing-box/.gitmodules` — submodule URLs rewritten from SSH to HTTPS, so the tree
  can be cloned without credentials

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

## Licence

GPL-3.0, with upstream's additional section 7 terms — see `LICENSE.md`, which is upstream's
own and is reproduced unchanged.
