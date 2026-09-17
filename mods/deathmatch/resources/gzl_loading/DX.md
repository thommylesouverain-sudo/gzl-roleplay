# AURA DX loading

Full-screen scene, GZL branding, loading status, progress bar and rotating roleplay tips.
No marketing tabs, social buttons, large logo card or browser.

`/loadingtest` toggles an isolated 12-second simulated preview; Escape closes it.
Preview remains open at 100% and does not change the camera, chat, HUD or server state.

Real loading waits for server readiness and completed transfers, then closes after
1.4 seconds. There is no artificial 30-second minimum. Server startup percentages
use the reported resource count; downloads and unknown phases use an indeterminate
bar because resource counts do not measure downloaded bytes. Spawn also closes it.

The static scene and gradient are cached in an opaque render target. Only status,
progress and tips draw each frame. Resize, device restore and dependency recovery
rebuild the cache. Owned textures, fonts, timers and render handler are freed on close.

Run `python gzl_loading/test_dx.py`. In-game first-join appearance and FPS require
MTA verification; the offline checks do not measure rendering performance.
