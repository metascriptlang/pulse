# Pulse

A motion engine for MetaScript: animations as versioned documents (clips, tracks, keyframes,
curves, slots), a player with play, pause, seek, reverse, rate, cancel and retarget, springs and
decay as pure functions of time, and one contract on every backend. Pulse knows nothing about a
renderer; Neon, Void and Lightcube bind it to what they draw. It is not a scene graph.

```ts
// build.ms of a project that uses it
deps: { "pulse": "file:../pulse" },

import { MotionDocument, MotionPlayer, motionOptions } from "pulse/src/index";
```

Design, references and milestones: `docs/ANIMATION.md`. MIT licensed.
