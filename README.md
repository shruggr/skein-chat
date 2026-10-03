# skein-chat

The chat app for a [skein](https://github.com/shruggr/skein): `chat` is the
turn loop that asks an inference peer, keeps every turn, and runs the
model's tool calls. Version **0.1.0**. A skein has no chat loop of its own:
an instance chats once this app is installed (shruggr/skein#83).

## What it is

| box | program | what |
|---|---|---|
| `chat` | `loop` | the turn loop: its prompt from the tree's `SOUL.md`; asks the `infer` peer; runs `bash` tool calls in the shell and `message` tool calls as a `chat` to another party; answers the opener with a `chat` reply. From the owner, and from anyone (another agent's `message`) |

`bash` runs in the shell app's shell (shruggr/skein-shell): the loop reads
the app record at the head `shell/app` and launches its `shell` program.
This app requires nothing: on an instance without the shell app a `bash`
call's result is exit 127, "the shell app is not installed", and the
conversation goes on. An agent's skein can have the chat loop and no shell.

| file | what |
|---|---|
| `bin/loop.wasm` | the loop (Zig, wasm32-wasi, committed; `zig build bin` rewrites it) |
| `etc/app.json` | the manifest |
| `programs/loop/` | its source |

## Install it

```
skein-host install https://github.com/shruggr/skein-chat --instance <handle>
```

From the client (`bin/skein` in skein):

```
bin/skein chat --new --wait 'what is here?'
```

The manifest, `etc/app.json` (description left out):

```json
{
  "kind": "app",
  "name": "chat",
  "version": "0.1.0",
  "programs": { "loop": "bin/loop.wasm" },
  "provides": [
    { "interface": "chat/1", "functions": { "chat": { "writes": true,
      "args": { "text": "string", "tree?": "cid", "model?": "string", "replyTo?": "cid" },
      "answer": { "text": "string", "tree": "cid", "thread": "cid" } } } }
  ],
  "requires": [],
  "dispatch": [
    { "address": "chat", "sender": "$owner", "program": "loop" },
    { "address": "chat", "sender": "*", "program": "loop" }
  ]
}
```

The open row (`*`) lets other agents start a conversation; an owner who
wants chats from the owner only removes it (`skein-host dispatch <handle>
remove chat <loop>`) and keeps the owner's row.

## Build and test

Zig 0.16.0 (`mise.toml`).

```
zig build         # zig-out/bin/loop.wasm
zig build bin     # the same, into bin/ (reproducible)
zig build test    # the loop's tests (natively); the program built
```

The behaviour is tested in skein: `chat` through the host
(`kernel-zig/equiv/corpus.ts`, `boot.ts`, `serve.ts`, `browser-live.ts`)
and the npm suite (`src/host/loop.test.ts`). skein's tests install this
app at the commit pinned in its `src/testapps.ts` (or `$SKEIN_CHAT_DIR`, a
checkout).

## Docs

| what | where |
|---|---|
| chat between instances, the infer protocol, the turn stream | skein `docs/MESSAGES.md` |
| the shell app and the chat app | skein `docs/APPS.md` §6b |
| apps, manifests, install | skein `docs/APPS.md` |

## Versions

| | |
|---|---|
| this app | 0.1.0 (tag `v0.1.0`) |
| skein-sdk | v0.4.0, by tag tarball and hash in `build.zig.zon` |

0.1.0 is the split of shruggr/skein-workbench (archived) into this app and
shruggr/skein-shell (shruggr/skein#83). The history of the loop is this
repository's.

## Contributing

Work is tracked in shruggr/skein; start at issue
[#31](https://github.com/shruggr/skein/issues/31). MIT, as skein.
