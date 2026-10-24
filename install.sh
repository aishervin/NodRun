#!/usr/bin/env sh
# =====================================================================
# NodRun Automated Installer for Termux
# Author: Shervin (aishervin)
# Exclusive ☬SHΞN™ made
# =====================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_banner() {
    clear
    printf "${CYAN}"
    printf "  _   _           _ ____              \n"
    printf " | \ | | ___   __| |  _ \ _   _ _ __  \n"
    printf " |  \| |/ _ \ / _\` | |_) | | | | '_ \ \n"
    printf " | |\  | (_) | (_| |  _ <| |_| | | | |\n"
    printf " |_| \_|\___/ \__,_|_| \_\\\\__,_|_| |_|\n"
    printf "        Exclusive SHEN lvps v1.0.0      \n"
    printf "${NC}\n"
    printf "--------------------------------------------------\n"
}

print_step() {
    printf "${YELLOW}[*] %s${NC}\n" "$1"
}

print_success() {
    printf "${GREEN}[✔] %s${NC}\n" "$1"
}

print_error() {
    printf "${RED}[✖] %s${NC}\n" "$1"
    exit 1
}

print_banner

print_step "Cleaning up background processes..."
pkill -9 -f "proot|nodrun|opencode|python" >/dev/null 2>&1

print_step "Updating Termux packages..."
export DEBIAN_FRONTEND=noninteractive
yes "" 2>/dev/null | pkg update -y >/dev/null 2>&1
yes "" 2>/dev/null | pkg upgrade -y -o Dpkg::Options::="--force-confnew" >/dev/null 2>&1 || print_error "Failed to update Termux packages."
print_success "Termux packages updated."

print_step "Installing essential dependencies..."
pkg install -y proot-distro curl git python -o Dpkg::Options::="--force-confnew" >/dev/null 2>&1 || print_error "Failed to install dependencies."
print_success "Dependencies installed."

print_step "Setting up Alpine Linux..."
if ! proot-distro login alpine -- true >/dev/null 2>&1; then
    proot-distro install alpine >/dev/null 2>&1 || print_error "Failed to install Alpine Linux."
fi
print_success "Alpine Linux is ready."

print_step "Installing NodRun inside Alpine..."
proot-distro login alpine --isolated -- sh -c '
    apk update >/dev/null 2>&1
    apk add --no-cache nodejs npm git openssh-client github-cli >/dev/null 2>&1
    npm i -g git+https://github.com/aishervin/NodRun.git >/dev/null 2>&1
' || print_error "Failed to install NodRun."
print_success "NodRun installed."

print_step "Configuring runner & 'nodrun' command..."
proot-distro login alpine --isolated -- sh -c '
    cat << "EOF" > /usr/local/bin/start-nodrun
#!/bin/sh
cd /root/workspace 2>/dev/null || cd /root
BIN=$(find /usr -name opencode -type f | grep node_modules/opencode-linux-arm64 | head -n 1)
if [ -z "$BIN" ]; then
    BIN=$(find /usr -name opencode -type f | head -n 1)
fi
if [ -z "$BIN" ]; then
    BIN=$(find /usr -name nodrun -type f | head -n 1)
fi
exec "$BIN" serve --port 4096 --hostname 0.0.0.0
EOF
    chmod +x /usr/local/bin/start-nodrun
'

cat << 'EOF' > $PREFIX/bin/nodrun
#!/data/data/com.termux/files/usr/bin/sh
mkdir -p ~/.ssh ~/.config ~/.wrangler
touch ~/.gitconfig

pkill -f "start-nodrun" 2>/dev/null
pkill -f "opencode" 2>/dev/null

nohup proot-distro login alpine --isolated \
  --bind /data/data/com.termux/files/home:/root/workspace \
  --bind /data/data/com.termux/files/home/.ssh:/root/.ssh \
  --bind /data/data/com.termux/files/home/.gitconfig:/root/.gitconfig \
  --bind /data/data/com.termux/files/home/.wrangler:/root/.wrangler \
  -- /usr/local/bin/start-nodrun >/dev/null 2>&1 &

printf "🚀 NodRun Server is running in background on port 4096!\n"
EOF
chmod +x $PREFIX/bin/nodrun
print_success "Command 'nodrun' configured."

print_step "Generating local dashboard..."
cat << 'EOF' > ~/nodrun-dashboard.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NodRun Connection Dashboard</title>
    <style>
        body { background: #0f172a; color: #f8fafc; font-family: system-ui, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; padding: 20px; }
        .card { background: #1e293b; border: 1px solid #334155; border-radius: 14px; padding: 28px; max-width: 400px; width: 100%; box-shadow: 0 10px 25px rgba(0,0,0,0.4); text-align: center; }
        h1 { color: #38bdf8; font-size: 22px; margin-top: 0; }
        p { color: #94a3b8; font-size: 13px; line-height: 1.5; }
        .url-box { background: #0f172a; border: 1px solid #475569; padding: 12px; border-radius: 8px; font-family: monospace; font-size: 15px; color: #34d399; margin: 16px 0; }
        button { background: #0284c7; color: white; border: none; padding: 12px 20px; border-radius: 8px; font-size: 15px; font-weight: bold; cursor: pointer; width: 100%; }
        .footer { margin-top: 18px; font-size: 11px; color: #64748b; }
    </style>
</head>
<body>
    <div class="card">
        <h1>NodRun Server Ready</h1>
        <p>Copy the server URL below and paste it into the NodRun app:</p>
        <div class="url-box" id="serverUrl">http://127.0.0.1:4096</div>
        <button onclick="copyUrl()">Copy Server URL</button>
        <div class="footer">Exclusive ☬SHΞN™ made</div>
    </div>
    <script>
        function copyUrl() {
            navigator.clipboard.writeText('http://127.0.0.1:4096').then(() => {
                const btn = document.querySelector('button');
                btn.innerText = 'Copied! ✓';
                btn.style.background = '#059669';
                setTimeout(() => {
                    btn.innerText = 'Copy Server URL';
                    btn.style.background = '#0284c7';
                }, 2000);
            });
        }
    </script>
</body>
</html>
EOF

pkill -f "python3 -m http.server 4097" >/dev/null 2>&1
nohup python3 -m http.server 4097 --directory ~/ >/dev/null 2>&1 &

# Auto launch NodRun server
nodrun >/dev/null 2>&1

printf "\n"
printf "==================================================\n"
printf "  INSTALLATION COMPLETED SUCCESSFULLY!\n"
printf "==================================================\n"
printf "  1. Server Status: Running in background (Port 4096)\n"
printf "  2. Start / Restart command: nodrun\n"
printf "  3. Open Dashboard command: termux-open http://127.0.0.1:4097\n"
printf "==================================================\n"
