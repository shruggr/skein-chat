# skein-workbench

The shell and the chat loop for a [skein](https://github.com/shruggr/skein),
as one app: `run` runs a bash command in the WASI shell over a tree, and
`chat` is the turn loop that asks an inference peer and runs tool calls.
It also holds the sources of the shell's toolset. Version **0.2.0**. It is
to be split into two apps, the shell app and the chat app
(shruggr/skein#83), and archived once both are tagged.

## What it is

| box | program | what |
|---|---|---|
| `run` | `run-handler` | `{cmd, tree?, cwd?, env?}`: a bash command in the shell over a tree (no tree: `main`'s); replies in the sender's `results` box with `{exitCode, stdout, stderr, tree, replyTo}` |
| `chat` | `loop` | the turn loop: its prompt from the tree's `SOUL.md`; asks the `infer` peer; runs `bash` tool calls in the shell and `message` tool calls as a `chat` to another party; answers the opener with a `chat` reply |

The shell is the kernel's `shell` program record, built from pinned
modules: brush and coreutils plus find, xargs, diff, cmp, jq, which, grep,
tree, awk, sed, git, qjs (also `node`) and python (also `python3`). Their
sources, patches and build are here (`toolset/`, `scripts/build-toolset.sh`,
`toolset/README.md`).

| file | what |
|---|---|
| `bin/run-handler.wasm`, `bin/loop.wasm` | the two programs (wasm32-wasi, committed; `zig build bin` rewrites them) |
| `etc/app.json` | the manifest |
| `programs/run-handler/`, `programs/loop/` | their sources (Zig) |
| `toolset/`, `scripts/build-toolset.sh` | the shell's modules |

## Use it

Today skein's default genesis wires `run` → `run-handler` and `chat` →
`loop` itself, from modules skein pins (`wasm/run-handler.wasm`,
`wasm/loop.wasm` and the toolset, pinned by raw CID in
`kernel-zig/src/programs.zig`). So an instance has them without installing
anything, and installing this app into such an instance is refused: its
rows clash with the genesis's. shruggr/skein#83 removes them from the
genesis; after that the shell and the chat app are installed like any app:

```
skein-host install https://github.com/shruggr/skein-workbench --instance <handle>
```

From the client (`bin/skein` in skein):

```
bin/skein run --tree <cid> -- 'ls | head -3'
bin/skein chat --new --wait 'what is here?'
```

The manifest, `etc/app.json` (description left out):

```json
{
  "kind": "app",
  "name": "workbench",
  "version": "0.2.0",
  "programs": { "run": "bin/run-handler.wasm", "loop": "bin/loop.wasm", "shell": "shell" },
  "provides": [
    { "interface": "workbench.run/1", "functions": { "run": { "writes": true,
      "args": { "cmd": "string", "tree?": "cid", "cwd?": "string", "env?": "map" },
      "answer": { "exitCode": "int", "stdout": "string", "stderr": "string", "tree": "cid" } } } },
    { "interface": "workbench.chat/1", "functions": { "chat": { "writes": true,
      "args": { "text": "string", "tree?": "cid", "model?": "string", "replyTo?": "cid" },
      "answer": { "text": "string", "tree": "cid", "thread": "cid" } } } }
  ],
  "requires": [],
  "dispatch": [
    { "address": "run", "sender": "$owner", "program": "run" },
    { "address": "chat", "sender": "$owner", "program": "loop" }
  ]
}
```

`"shell": "shell"` names a program the instance already has by that name
(the kernel's shell record). Rows default to transport `mailbox`; both are
from the owner only.

## Build and test

Zig 0.16.0 (`mise.toml`).

```
zig build                  # zig-out/bin/run-handler.wasm, zig-out/bin/loop.wasm
zig build bin              # the same, into bin/ (reproducible)
zig build test             # the loop's tests (natively); both programs built
scripts/build-toolset.sh   # the shell's modules into out/ (needs rustup with wasm32-wasip1, curl, unzip, node; fetches wasi-sdk 34)
```

A change moves into skein with skein's `scripts/update-workbench.sh <this
checkout>`: it copies `bin/*.wasm` (and `out/*` after a toolset build),
rewrites the pins, and records this repo's commit in skein's
`wasm/WORKBENCH`. The Zig builds are reproducible; the toolset build is
reproducible on the same machine in the same checkout layout only
(`toolset/README.md`).

The behaviour is tested in skein, where the kernel runs these modules: the
shell cases (`kernel-zig/equiv/shell.ts`), git in the VM (`equiv/git.ts`),
`run` and `chat` through the host (`equiv/corpus.ts`, `boot.ts`,
`serve.ts`) and the npm suite.

## Docs

| what | where |
|---|---|
| the toolset: each module's source and patches | `toolset/README.md` |
| the shell in the VM, the clock, fuel | skein `docs/VM.md`, `kernel-zig/README.md` |
| chat between instances, the infer protocol, the turn stream | skein `docs/MESSAGES.md` |
| apps, manifests, install | skein `docs/APPS.md` |

## Versions

| | |
|---|---|
| this app | 0.2.0 (tag `v0.2.0`) |
| skein-sdk | v0.4.0, by tag tarball and hash in `build.zig.zon` |
| skein | pins the built modules by raw CID; `wasm/WORKBENCH` names the commit they came from |

0.2.0 is the manifest in the dispatch-row shape (shruggr/skein#77, #79);
the admin operations it once carried as programs are the kernel's own.

## Contributing

Work is tracked in shruggr/skein; start at issue
[#31](https://github.com/shruggr/skein/issues/31). MIT, as skein.
