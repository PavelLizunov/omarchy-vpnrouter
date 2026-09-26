#!/usr/bin/env bash
# ==============================================================================
# Isolated QML Load Test Runner: Omarchy VPNRouter Plugin
#
# Runs an isolated QuickShell harness offscreen without live shell IPC collision.
# All real backend processes are disabled (processDisabled: true).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Shell and module search paths
HOST_SHELL_DIR="${OMARCHY_SHELL_DIR:-/usr/share/omarchy/shell}"

# Locate QuickShell executable (qs or quickshell)
QUICKSHELL_BIN="${QUICKSHELL:-}"
if [[ -z "${QUICKSHELL_BIN}" ]]; then
  if command -v qs >/dev/null 2>&1; then
    QUICKSHELL_BIN="$(command -v qs)"
  elif command -v quickshell >/dev/null 2>&1; then
    QUICKSHELL_BIN="$(command -v quickshell)"
  elif [[ -x "/usr/bin/qs" ]]; then
    QUICKSHELL_BIN="/usr/bin/qs"
  elif [[ -x "/usr/bin/quickshell" ]]; then
    QUICKSHELL_BIN="/usr/bin/quickshell"
  fi
fi

if [[ -z "${QUICKSHELL_BIN}" ]]; then
  echo "Error: QuickShell binary (qs or quickshell) not found in standard paths." >&2
  exit 1
fi

# Isolated temporary environment: isolated HOME, XDG_CONFIG_HOME, XDG_RUNTIME_DIR
TMP_ISOLATION_DIR="$(mktemp -d /tmp/vpnrouter-qs-test-XXXXXX)"
TMP_IMPORT_DIR="${TMP_ISOLATION_DIR}/imports"
TMP_RUN_DIR="${TMP_ISOLATION_DIR}/run"
TMP_HOME_DIR="${TMP_ISOLATION_DIR}/home"
TMP_CFG_DIR="${TMP_ISOLATION_DIR}/config"
RESULT_FILE="${TMP_ISOLATION_DIR}/result"
HARNESS_ENTRY="${PROJECT_DIR}/.qml-test-harness.qml"

cleanup() {
  rm -rf "${TMP_ISOLATION_DIR}" "${HARNESS_ENTRY}"
}
trap cleanup EXIT INT TERM

mkdir -p "${TMP_IMPORT_DIR}/qs/Commons" "${TMP_IMPORT_DIR}/qs/Ui" "${TMP_RUN_DIR}" "${TMP_HOME_DIR}" "${TMP_CFG_DIR}"

# Populate qs.Commons from host shell
if [[ -d "${HOST_SHELL_DIR}/Commons" ]]; then
  for f in "${HOST_SHELL_DIR}/Commons"/*; do
    [[ -e "$f" ]] && ln -sfn "$f" "${TMP_IMPORT_DIR}/qs/Commons/$(basename "$f")"
  done
fi

# Populate qs.Ui from host shell, providing an offscreen adapter for KeyboardPanel (no PanelWindow backend in offscreen)
if [[ -d "${HOST_SHELL_DIR}/Ui" ]]; then
  for f in "${HOST_SHELL_DIR}/Ui"/*; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    if [[ "$base" != "KeyboardPanel.qml" ]]; then
      ln -sfn "$f" "${TMP_IMPORT_DIR}/qs/Ui/$base"
    fi
  done
fi

cat << "EOF" > "${TMP_IMPORT_DIR}/qs/Ui/KeyboardPanel.qml"
import QtQuick
import qs.Commons

Item {
  id: root
  required property Item anchorItem
  required property QtObject bar
  property var owner: null
  property int margin: Style.gapsOut
  property int padding: Style.spacing.popupPadding
  property int contentWidth: Style.space(280)
  property int contentHeight: Style.space(200)
  property bool centerOnBar: false
  property bool open: false
  property int gap: Style.gapsOut
  property bool popoutSwitching: false
  property bool popoutSwitchClosing: false
  property bool focusPrimed: false
  property Item focusTarget: null
  default property alias contentItem: contentHolder.children

  function close() {
    if (owner && "close" in owner) owner.close()
    else root.open = false
  }
  function fittedContentWidth(w, cap) { return Math.max(1, Number(w) || 1) }
  function fittedContentHeight(h, cap) { return Math.max(1, Number(h) || 1) }
  function cappedContentHeight(h) { return Math.max(1, Number(h) || 1) }

  Item {
    id: contentHolder
    anchors.fill: parent
  }
}
EOF

# Stage harness entry at project root so Quickshell config folder is project root
ln -sfn "${SCRIPT_DIR}/qml-harness.qml" "${HARNESS_ENTRY}"

echo "=== Running Isolated QuickShell QML Load Test Harness (offscreen) ==="
export HOME="${TMP_HOME_DIR}"
export XDG_CONFIG_HOME="${TMP_CFG_DIR}"
export XDG_RUNTIME_DIR="${TMP_RUN_DIR}"
export QT_QPA_PLATFORM="offscreen"
export QML_DISABLE_DISK_CACHE="1"
export QML_IMPORT_PATH="${TMP_IMPORT_DIR}:${HOST_SHELL_DIR}:${PROJECT_DIR}"
export RESULT_FILE="${RESULT_FILE}"

# Run bounded QuickShell harness (≤60s)
set +e
timeout 60 "${QUICKSHELL_BIN}" -p "${HARNESS_ENTRY}"
QS_EXIT=$?
set -e

RESULT="$(cat "${RESULT_FILE}" 2>/dev/null || echo "")"

if [[ "${RESULT}" == "0" ]]; then
  echo "=== ALL QML LOAD TESTS PASSED! ==="
  exit 0
else
  echo "=== QML LOAD TESTS FAILED (result=${RESULT}, qs_exit=${QS_EXIT})! ==="
  exit 1
fi
