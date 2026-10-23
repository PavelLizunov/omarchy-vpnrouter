# R8 native Omarchy theming

The owner's correction keeps the R7 composition and original PNGs, and replaces
the copied desktop design system with the installed Omarchy design contract.
The initial `ui/qmldir` live-resolution correction is a separate lead commit.

Design read: a compact native Omarchy VPN panel with the Virtual Penguin Network
identity carried by its layout, original mascot, ring and shield. Energy 1,
rhythm 2, motion 1 except for an in-flight connection indicator. Typography and
geometry follow the host; the ring remains circular because it communicates state.

- `Commons.Color.popups.background/text` own the content surface and text.
- `accent` marks connected/connecting; `urgent` marks error/unavailable;
  `muted` marks neutral state. There is no host success/green role.
- `Commons.Style.font`, spacing, corner radius and control states replace the
  desktop font, palette and radius system. Small explanatory text uses popup
  text rather than muted to retain contrast in the installed light theme.
- Native `Ui.Button`, `Toggle`, `ToggleSwitch`, `TextField`, `CursorSurface` and
  `BorderSurface` own reusable chrome, including theme border specifications.
- `Brand.qml` only chooses the original black/white mascot by popup luminance.

Verification: the production theme/export guard, existing Node suites, packaging,
manifest validation, qmllint, and the actual QML consumer. The theme runner uses
Omarchy's own generator and unchanged Color startup FileViews in private HOMEs.
All plugin source copies are byte-identical. The built-in Bluetooth reference
replaces only three hardware model bindings with fixture inputs; its visual code
is unchanged. The only visual adapter replaces the
layer-shell window with an Item. Bluetooth devices and backend requests are inert.
Do not add a filesystem `qs/Commons` alias: Quickshell's own namespace must own
singleton identity. The scan root is an inert `Item`, not the running shell.

Review targets: EN/RU first run, disconnected, connecting, connected, error,
unavailable, Servers and Settings for Catppuccin Latte, Tokyo Night, Hackerman;
all section routes, forms, keyboard, motion and fixed frame geometry. Compare
against actual built-in Bluetooth content under each theme. Evidence, source
hashes, command exit codes and remaining limits are recorded in `r8-plugin.md`
in the coordinator's requested scratchpad.

This records the H09 correction: palette similarity and a successful offscreen
load did not establish native host styling or live directory type resolution.
The theme/export guard and actual host-component matrix cover the new scope.
The owner/lead owns live shell loading, compositor placement and final visual
acceptance. No installation, shell activation/restart or VPN traffic is part of R8.
