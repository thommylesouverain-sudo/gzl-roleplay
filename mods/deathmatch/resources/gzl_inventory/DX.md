# AURA DX inventory

Inventory presentation now uses `client/dx.lua` and AURA surfaces. `client/main.lua`
keeps the existing item actions, progress callbacks, hotkeys and server events.
No browser is created. Old web sources remain on disk for reference; only item
images from that directory are declared for client download. Other CEF resources
are unchanged. Start `aura_ui` before `gzl_inventory` (also declared as a dependency).

The two five-column grids preserve the original player/world arrangement and
use AURA's opaque graphite surfaces, lime accent, Manrope type and rounded
cards. Only the CEF layout is retained, not its translucent visual skin. They
also display trunk/glovebox snapshots. Each grid scrolls independently. Drag to
a slot to move/split; Shift moves half; Ctrl-click transfers to the other grid;
double-click or Alt-click uses; right-click opens actions. The central quantity
field accepts digits, Backspace and Ctrl+A. Zero means the full stack for slot
transfers and one item for use/give/drop actions. Tab shows the five-slot hotbar;
1–5, F2 and I retain their existing roles. Escape closes the menu/input first,
then the inventory.

Server snapshots remain authoritative: no local optimistic item mutation. A
server update cancels any pending drag so it cannot target a stale item. UI input
mode is restored on close/session reset/resource stop. An AURA focus claim closes
the inventory; stopping AURA also hides it.

Render callbacks are attached only while inventory/hotbar is visible. Image
textures are loaded lazily, capped at 64 cached entries and destroyed on close.
Fonts are inventory-owned.
Inventory weights are recalculated on snapshots/deltas instead of each frame;
cursor position is read once per frame and texture dimensions are cached.
`client/surfaces.lua` caches up to 96 immutable instances of AURA's original
surface shader. Warm frames draw those materials locally, without per-surface
resource exports, option-table copying or repeated shader uniform writes. Exact
dimensions, colors, radius, border and shader source are retained; no raster cache,
text render target, resolution reduction or frame-rate cap is used. Materials are
destroyed when both inventory and hotbar close. Allocation failure uses the original
AURA export and throttles subsequent creation attempts.
`python gzl_inventory/tests/check_surfaces.py` compares shader inputs against the
original AURA renderer and checks zero export/uniform writes on a warm idle frame.
These choices remove this inventory's CEF runtime, but FPS/CPU gains require measurements in MTA; offline tests do not establish
performance. Texture lifetime follows the [MTA texture documentation](https://wiki.multitheftauto.com/wiki/DxCreateTexture).

`python gzl_inventory/tests/check_dx.py` checks Lua 5.1, event payloads, input,
drag/quantity, updates, hotbar, teardown and layout bounds. `preview_dx.py` creates
an approximate CPU-rendered layout image, **not an in-game screenshot**.

Remaining in-game validation: shader appearance, mouse interactions, server
acceptance for world/bagaj/torpido transfers and actual frame-time/memory comparison.
Packaged PNG artwork is supported; external metadata image URLs are not fetched
and show a placeholder. Generic web-only shop/crafting features had no matching
handlers in this resource and are not exposed by this DX presentation.
