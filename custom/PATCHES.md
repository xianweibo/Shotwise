# PATCHES.md - Paul's Mod Registry

Every local modification to Shotwise is registered here. If it is not in this table,
it does not exist (and will be lost on the next upstream sync).

Baseline at time of fork: `upstream/main` = `4db7aa5fa13b2efde733bdd861b1f8e3a09ceb52`
(2026-09-21, tag v0.28.0)

Column meaning:
- MOD ID - stable handle, prefix `ZYT-`, never reused.
- Purpose - why upstream cannot do this as-is. Write it so future-me understands without context.
- Files - touch points in the repo.
- Commit - `paul/main` commit hash (authoritative). Empty means not committed yet - do not sync upstream until it is.
- Verify - how to prove it still works after an upstream merge.
- Upstreamable - `no` = local-only (our hardware / our LAN); `maybe` = could PR later.

## Registry

| MOD ID | Purpose | Files | Commit | Verify | Upstreamable |
|---|---|---|---|---|---|
| (none yet - table kept non-empty so the header survives merges) | - | - | - | - | - |

## Decision log

- 2026-10-02 Fork created. Original intent was to fork because we assumed local ComfyUI
  (SDXL stills / H3 video) would need backend changes. Investigation of
  `lib/custom_provider/endpoints.py` showed upstream already ships an OpenAI-compatible
  endpoint registry (`openai-images` for T2I+I2I, `openai-video` for `/v1/videos`), so the
  local ComfyUI channel can be plugged in as a **custom provider** through a small local
  bridge instead. Mod layer stands by; no patch is needed for that integration.
  Revisit if a change cannot be expressed as a custom provider endpoint.
