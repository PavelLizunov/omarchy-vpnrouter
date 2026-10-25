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
