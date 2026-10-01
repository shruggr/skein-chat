# skein-workbench

The agent workbench for a [skein](https://github.com/shruggr/skein) instance,
as an app (skein `docs/APPS.md`). Split out of skein by shruggr/skein#71,
with the history of `programs/run-handler`, `programs/loop`,
`scripts/build-wasm.sh` (now `scripts/build-toolset.sh`) and the toolset's
sources under `wasm/` (now `toolset/`).

| box | program | what |
|---|---|---|
| `run` | `run-handler` | `{cmd, tree?, cwd?, env?}`: runs a bash command in the wasm shell over a tree (no tree: `main`'s), and replies in the sender's `results` box with `{exitCode, stdout, stderr, tree, replyTo}` |
| `chat` | `loop` | the turn loop. Its prompt comes from the tree's `SOUL.md`. It asks the `infer` peer, runs `bash` tool calls in the shell and `message` tool calls as a `chat` to another party, and answers the opener with a `chat` reply |
| `objects`, `head`, `subscribe` | skein's stock handlers, by CID | the install boxes. They are skein's boundary programs and stay in skein |

The shell is the kernel's stock shell program. It is brush and coreutils plus
the toolset: find, xargs, diff, cmp, jq, which, grep, tree, awk, sed, git,
qjs/node and python/python3. Its sources and build are here (`toolset/`,
`scripts/build-toolset.sh`, `toolset/README.md`).

## The tree

```
bin/run-handler.wasm        the run handler (wasm32-wasi, committed; `zig build bin` rewrites it)
bin/loop.wasm               the turn loop (likewise)
bin/{objects,head,subscribe}-handler.cid   skein's stock install handlers, by raw CID
etc/app.json                the manifest (skein docs/APPS.md §2)
programs/run-handler/, programs/loop/   their sources (Zig 0.16.0, over shruggr/skein-sdk)
toolset/                    the shell's modules: patches, first-party tools (which, grep, the qjs prelude), the git compat layer
scripts/build-toolset.sh    builds the toolset into out/
```

## What stays pinned in skein, and why

Every stock genesis wires `run` to `run-handler` and `chat` to `loop`
(skein `src/host/genesis.ts`, `STOCK_SUBSCRIPTIONS`). The kernel builds the
stock `shell` program record from its pinned modules. So skein keeps the
**built modules** of this app: `wasm/run-handler.wasm`, `wasm/loop.wasm`,
and the toolset (`wasm/brush.wasm` … `wasm/python314.zip`). They are
committed there and pinned by raw CID in `kernel-zig/src/programs.zig`. The
**sources** are here and only here.

A change is built here and moved into skein with skein's
`scripts/update-workbench.sh <this checkout>`. That script copies `bin/*.wasm`
(and `out/*`, after a toolset build), rewrites the pins, and records this
repo's commit in skein's `wasm/WORKBENCH`. The Zig builds are reproducible:
`bin/run-handler.wasm` and `bin/loop.wasm` at 0.1.0 are byte for byte the
modules skein pinned before the split
(`bafkreicd63a4ffjozgou3axes5p5tymfoi72ne2dpeqnhij33uqgvpdyle`,
`bafkreihbfmv6az4esnmf7wk5lmljvjzvt5f5xtef2b2asrtbam53bclmgy`). The toolset
build is reproducible on the same machine in the same checkout layout only
(`toolset/README.md`).

The manifest's `handler` is a map from box to program, because the
workbench serves several boxes. docs/APPS.md §2 has one `handler` for an
app's one box. The map form is a proposal for #72.

## Build and test

Zig 0.16.0 (`mise.toml`). The SDK is a URL+hash dependency in
`build.zig.zon` (`shruggr/skein-sdk`).

```
zig build          # zig-out/bin/run-handler.wasm, zig-out/bin/loop.wasm
zig build bin      # the same, into bin/
zig build test     # the loop's tests (natively); both programs built
scripts/build-toolset.sh   # the shell's modules into out/ (needs rustup with wasm32-wasip1, curl, unzip, node; fetches wasi-sdk 34)
```

The workbench's behaviour is tested end to end in skein, where the kernel
runs these modules. Those tests are the shell cases (`kernel-zig/equiv/shell.ts`),
git in the VM (`equiv/git.ts`), `run` and `chat` through the router
(`equiv/corpus.ts`, `boot.ts`, `serve.ts`) and the npm suite.

MIT, as skein.
