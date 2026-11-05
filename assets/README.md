# Original VPNRouter mascot artwork

These PNGs are byte-identical copies of the owner-provided files in
`VPNRouter/VPNRouter.App/Assets/`, under the upstream GPL-3.0 license.
The artwork must not be redrawn, recolored, traced or modified. QML may only
place and scale the originals on tiles, rings and backgrounds.

- `penguin_mascot.png`: light-theme hero and header tile.
- `penguin_mascot_white.png`: dark-theme hero.
- The original supplied tile is a [test-only reference](../tests/fixtures/penguin_mascot_tile.png).
  Archive installation excludes it; git clones retain the fixture under `tests/`.

`tests/test-ui-brand-assets.js` pins all three SHA-256 digests. Runtime QML uses
only the two PNGs in this directory.

Every scaled mascot Image must decode at its displayed physical pixel size
using sourceSize with Screen.devicePixelRatio, smooth: true and mipmap: true.
smooth alone does not prevent jagged reduction of the large originals. Keep
this policy in both Header.qml and HeroCard.qml; check new consumers too.
Verify small light/dark icons at DPR 1 and 2 with isolated QML renders. Before
calling a fix delivered, compare installed files with the reviewed commit;
manifest version alone is insufficient (both sides of PR #8 report 0.1.2).
