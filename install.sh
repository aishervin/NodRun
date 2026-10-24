#!/usr/bin/env bash
set -euo pipefail

printf '\033[0;36m'
cat <<'NODRUN_BANNER'
  _   _           _ ____              
 | \ | | ___   __| |  _ \ _   _ _ __  
 |  \| |/ _ \ / _` | |_) | | | | '_ \ 
 | |\  | (_) | (_| |  _ <| |_| | | | |
 |_| \_|\___/ \__,_|_| \_\\__,_|_| |_|
        Exclusive SHEN lvps v1.0.0
NODRUN_BANNER
printf '\033[0m\n'
printf '%s\n' '--------------------------------------------------'

case "$(uname -m)" in
  aarch64|x86_64) ;;
  *) printf 'OpenCode server requires a 64-bit ARM or x86_64 device.\n' >&2; exit 1 ;;
esac

if ! command -v proot-distro >/dev/null 2>&1; then
  pkg update -y
  pkg install -y proot-distro
fi

if ! proot-distro login alpine -- true >/dev/null 2>&1; then
  printf 'Installing Alpine runtime...\n'
  proot-distro install alpine
fi

printf 'Installing OpenCode server...\n'
proot-distro login alpine -- sh -lc '
  set -e
  case "$(uname -m)" in
    aarch64)
      asset="opencode-linux-arm64-musl.tar.gz"
      checksum="aa32a91f62cfddfa4615ba4deffc2b13696e77cbee83551824e3f16e6770b37e"
      ;;
    x86_64)
      asset="opencode-linux-x64-musl.tar.gz"
      checksum="265bd8027e84fe01837f72df8b7615d2959491f45569d52a21f2fcdbec9decdf"
      ;;
  esac
  printf "Preparing standalone OpenCode binary...\n"
  apk add --no-cache ca-certificates curl
  work_dir="$(mktemp -d)"
  archive="$work_dir/opencode.tar.gz"
  curl -fsSL "https://github.com/anomalyco/opencode/releases/download/v1.19.4/$asset" -o "$archive"
  printf "%s  %s\n" "$checksum" "$archive" | sha256sum -c -
  tar -xzf "$archive" -C "$work_dir" opencode
  mkdir -p /usr/local/bin
  cp "$work_dir/opencode" /usr/local/bin/opencode
  chmod 755 /usr/local/bin/opencode
  /usr/local/bin/opencode --version
  rm -r "$work_dir"
'

mkdir -p "$HOME/.config/opencode" "$HOME/.local/share/opencode"
printf '\nStarting OpenCode on http://127.0.0.1:4096\n'
printf 'Keep this Termux session open while using NodRun. Press Ctrl+C to stop the server.\n\n'

exec proot-distro login alpine \
  --bind "$HOME:/root/workspace" \
  --bind "$HOME/.config/opencode:/root/.config/opencode" \
  --bind "$HOME/.local/share/opencode:/root/.local/share/opencode" \
  -- sh -lc 'cd /root/workspace && exec /usr/local/bin/opencode serve --hostname 127.0.0.1 --port 4096'
