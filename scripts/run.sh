#!/usr/bin/env bash
set -euo pipefail

# Launches the Flutter app against the local backend.
#
# - Android emulator / iOS simulator: no LAN IP needed, they reach the
#   host machine automatically (10.0.2.2 / 127.0.0.1, see
#   lib/core/network/api_config.dart). Use --emulator to skip detection.
# - Physical device on the same Wi-Fi: needs the Mac's LAN IP baked in
#   via --dart-define=API_BASE_URL=http://<ip>:3000. This script detects
#   that IP for you so you don't have to guess it (and get it wrong)
#   every time.

PORT="${PORT:-3000}"

usage() {
  cat <<EOF
Usage: scripts/run.sh [--emulator] [--ip=<addr>] [--port=<n>] [-- <extra flutter run args>]

  --emulator   Skip LAN IP detection (Android emulator / iOS simulator)
  --ip=<addr>  Use a specific IP instead of auto-detecting
  --port=<n>   Backend port (default: 3000)

Examples:
  scripts/run.sh                     # physical device, auto-detect LAN IP
  scripts/run.sh --emulator          # emulator/simulator, plain flutter run
  scripts/run.sh --ip=192.168.1.42   # force a specific IP
  scripts/run.sh -- -d <deviceId>    # forward extra args to flutter run
EOF
}

EMULATOR=false
IP_OVERRIDE=""
EXTRA_ARGS=()
PAST_DASHDASH=false

for arg in "$@"; do
  if $PAST_DASHDASH; then
    EXTRA_ARGS+=("$arg")
    continue
  fi
  case "$arg" in
    --emulator) EMULATOR=true ;;
    --ip=*) IP_OVERRIDE="${arg#--ip=}" ;;
    --port=*) PORT="${arg#--port=}" ;;
    -h|--help) usage; exit 0 ;;
    --) PAST_DASHDASH=true ;;
    *) EXTRA_ARGS+=("$arg") ;;
  esac
done

if $EMULATOR; then
  echo "Running without API_BASE_URL override (emulator/simulator default)."
  exec flutter run ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
fi

detect_ip() {
  if [[ -n "$IP_OVERRIDE" ]]; then
    echo "$IP_OVERRIDE"
    return
  fi

  local ip=""

  # macOS
  if command -v ipconfig >/dev/null 2>&1; then
    for iface in en0 en1; do
      ip=$(ipconfig getifaddr "$iface" 2>/dev/null || true)
      [[ -n "$ip" ]] && break
    done
  fi

  # Linux (iproute2)
  if [[ -z "$ip" ]] && command -v ip >/dev/null 2>&1; then
    ip=$(ip -4 addr show scope global 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n1)
  fi

  # Fallback (older/other *nix)
  if [[ -z "$ip" ]] && command -v ifconfig >/dev/null 2>&1; then
    ip=$(ifconfig 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127\.' | head -n1)
  fi

  echo "$ip"
}

IP="$(detect_ip)"

if [[ -z "$IP" ]]; then
  echo "Could not auto-detect a LAN IP. Pass one explicitly:" >&2
  echo "  scripts/run.sh --ip=192.168.x.x" >&2
  exit 1
fi

echo "Using API_BASE_URL=http://$IP:$PORT"
echo "(Make sure the backend is running and your device is on the same Wi-Fi network.)"
exec flutter run --dart-define="API_BASE_URL=http://$IP:$PORT" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
