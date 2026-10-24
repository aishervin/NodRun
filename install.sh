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
NC='\033[0m' # No Color

print_banner() {
    clear
    printf "${CYAN}"
    echo "  _   _           _ ____              "
    echo " | \ | | ___   __| |  _ \ _   _ _ __  "
    echo " |  \| |/ _ \ / _\` | |_) | | | | '_ \ "
    echo " | |\  | (_) | (_| |  _ <| |_| | | | |"
    echo " |_| \_|\___/ \__,_|_| \_\\\\__,_|_| |_|"
    echo "        Exclusive SHEN lvps v1.0.0      "
    printf "${NC}\n"
    echo "--------------------------------------------------"
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

print_step "Updating Termux packages..."
export DEBIAN_FRONTEND=noninteractive
yes "" | pkg update -y && yes "" | pkg upgrade -y -o Dpkg::Options::="--force-confnew" || print_error "Failed to update Termux packages."
print_success "Termux packages updated."

print_step "Installing essential dependencies (proot-distro, curl, git, python)..."
pkg install -y proot-distro curl git python -o Dpkg::Options::="--force-confnew" || print_error "Failed to install dependencies."
print_success "Dependencies installed successfully."

print_step "Setting up Alpine Linux environment via PRoot..."
if ! proot-distro list | grep -q "alpine.*installed"; then
    proot-distro install alpine || print_error "Failed to install Alpine Linux."
fi
print_success "Alpine Linux environment is ready."

print_step "Installing Node.js, Git, GitHub CLI, and NodRun package inside Alpine..."
proot-distro login alpine --isolated -- sh -c '
    apk update
    apk add --no-cache nodejs npm git openssh-client github-cli
    npm i -g git+https://github.com/aishervin/NodRun.git
' || print_error "Failed to install NodRun inside Alpine."
print_success "NodRun and developer tools installed successfully."

print_step "Configuring startup runner and global 'nodrun' command..."
proot-distro login alpine --isolated -- sh -c '
    cat << "EOF" > /usr/local/bin/start-nodrun
#!/bin/sh
cd /root/workspace 2>/dev/null || cd /root
BIN=$(find /usr -name nodrun -type f | grep node_modules/.bin/nodrun | head -n 1)
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

# Kill any existing old instance to prevent port conflicts
pkill -f "nodrun serve" 2>/dev/null

# Run safely in background with nohup so closing terminal won't kill it
nohup proot-distro login alpine --isolated \
  --bind /data/data/com.termux/files/home:/root/workspace \
  --bind /data/data/com.termux/files/home/.ssh:/root/.ssh \
  --bind /data/data/com.termux/files/home/.gitconfig:/root/.gitconfig \
  --bind /data/data/com.termux/files/home/.wrangler:/root/.wrangler \
  -- /usr/local/bin/start-nodrun >/dev/null 2>&1 &

echo "🚀 NodRun Server is running safely in the background on port 4096!"
EOF
chmod +x $PREFIX/bin/nodrun
print_success "Global command 'nodrun' created with background support."

print_step "Generating local HTML connection dashboard..."
cat << 'EOF' > ~/nodrun-dashboard.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NodRun Connection Dashboard</title>
    <style>
        body { background: #0f172a; color: #f8fafc; font-family: system-ui, -apple-system, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; padding: 20px; }
        .card { background: #1e293b; border: 1px solid #334155; border-radius: 14px; padding: 28px; max-width: 400px; width: 100%; box-shadow: 0 10px 25px rgba(0,0,0,0.4); text-align: center; }
        h1 { color: #38bdf8; font-size: 22px; margin-top: 0; margin-bottom: 8px; }
        p { color: #94a3b8; font-size: 13px; line-height: 1.5; margin-bottom: 20px; }
        .url-box { background: #0f172a; border: 1px solid #475569; padding: 12px; border-radius: 8px; font-family: monospace; font-size: 15px; color: #34d399; margin-bottom: 16px; word-break: break-all; }
        button { background: #0284c7; color: white; border: none; padding: 12px 20px; border-radius: 8px; font-size: 15px; font-weight: bold; cursor: pointer; width: 100%; transition: background 0.2s; }
        button:hover { background: #0369a1; }
        .footer { margin-top: 18px; font-size: 11px; color: #64748b; letter-spacing: 0.5px; }
    </style>
</head>
<body>
    <div class="card">
        <h1>NodRun Server Ready</h1>
        <p>Your local server is running in the background. Click the button below to copy your connection URL and paste it into the NodRun mobile app:</p>
        <div class="url-box" id="serverUrl">http://127.0.0.1:4096</div>
        <button onclick="copyUrl()">Copy Connection URL</button>
        <div class="footer">Exclusive ☬SHΞN™ made</div>
    </div>
    <script>
        function copyUrl() {
            const url = document.getElementById('serverUrl').innerText;
            navigator.clipboard.writeText(url).then(() => {
                const btn = document.querySelector('button');
                btn.innerText = 'Copied to Clipboard! ✓';
                btn.style.background = '#059669';
                setTimeout(() => {
                    btn.innerText = 'Copy Connection URL';
                    btn.style.background = '#0284c7';
                }, 2000);
            });
        }
    </script>
</body>
</html>
EOF

# Start lightweight Python HTTP server in the background for the dashboard
pkill -f "python3 -m http.server 4097" >/dev/null 2>&1
nohup python3 -m http.server 4097 --directory ~/ >/dev/null 2>&1 &

print_success "Dashboard generated at ~/nodrun-dashboard.html (Port 4097)"

# Automatically start the server in the background right after installation
nodrun

echo ""
echo "=================================================="
echo "  INSTALLATION & LAUNCH COMPLETED SUCCESSFULLY!   "
echo "=================================================="
echo "  1. Server is running in background (Port 4096)  "
echo "  2. To start/restart anytime, type: ${CYAN}nodrun${NC}"
echo "  3. To open connection helper page, type:"
echo "     ${CYAN}termux-open http://127.0.0.1:4097${NC}"
echo "=================================================="
