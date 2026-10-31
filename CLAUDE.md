# Pulse — the motion engine shared by Neon, Void and Lightcube

Workspace rules (toolchain, compiler boundary, arcs and cards, code style) are in `~/metascript/CLAUDE.md` and are not repeated here.

## Where the truth is

| question | file |
|---|---|
| what the engine has to be, its references, departures, milestones, decisions | `docs/ANIMATION.md` |
| the code | `src/index.ms` exports the engine; `tests/` holds one file per module |

## Rules

- Pulse imports nothing outside its own `src/`: no Neon, no Void, no renderer, no host. A consumer binds it through its own adapter (Neon `src/motion/neon.ms` and `waapi.ms`, Void's adapter), because criterion 1 of `docs/ANIMATION.md` is that the core runs headless and standalone.
- A consumer names Pulse in its `build.ms` `deps` as `"pulse": "file:../pulse"` and imports `pulse/src/…`.
- A design question follows the reference `docs/ANIMATION.md` assigns to that concern, and a departure is recorded there.
- Every module is tested native and with `--target=js`.

## Commands

```bash
msc test tests/player.test.ms                # one file, native; add --target=js for the JS lane
bash tests/run.sh                            # the gate: every test file native, then JS
```

## Git

Pulse follows the arc model of `~/.claude/CLAUDE.md` and lands with the plain-git recipe of `~/metascript/CLAUDE.md`. The gate is `bash tests/run.sh`, read by its exit code. A change to an exported type or function runs the motion tests of Neon and Void too, because they are its consumers.
