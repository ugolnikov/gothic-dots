# One persisted palette mode instead of two markers

The palette used to be driven by two independent markers, `light-theme` and `dynamic-theme`, with an exclusivity rule ("light wins") re-implemented in three scripts. We replaced both with a single persisted `palette-mode` value (`dark` | `light` | `dynamic`). Exclusivity is now structural — one value cannot express two modes — and the three copies of the rule are gone. The legacy markers are read once and migrated.

## Considered options

- **Two markers (status quo).** Familiar, but the invariant lived in three places and could drift.
- **Single mode value (chosen).** The invariant becomes unrepresentable; the cost is a one-time migration read on an existing install.
