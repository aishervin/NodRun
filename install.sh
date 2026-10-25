#!/bin/sh

echo "🚀 Scanning & Setting up ☬SHΞN™ NodRun Repository..."

# 1. بررسی و نصب پیش‌نیازهای پایه‌ای در ترموکس
MISSING_PKGS=""
for pkg in nodejs git curl; do
    if ! command -v $pkg >/dev/null 2>&1; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

if [ -n "$MISSING_PKGS" ]; then
    echo "📦 Installing missing packages:$MISSING_PKGS..."
    pkg update -y >/dev/null 2>&1
    pkg install -y nodejs git curl cloudflared >/dev/null 2>&1
else
    echo "✔ Core packages (Node, Git, Curl, Cloudflared) are ready."
fi

# 2. بررسی مخزن گیت و پوشه پروژه
if [ -d ".git" ]; then
    echo "🔄 Updating existing repository..."
    git pull origin main >/dev/null 2>&1
else
    echo "📥 Cloning NodRun repository..."
    git clone https://github.com/aishervin/NodRun.git ~/NodRun >/dev/null 2>&1
    cd ~/NodRun
fi

# 3. نصب پکیج‌های Node
if [ -f "package.json" ]; then
    echo "📦 Checking Node modules..."
    if [ ! -d "node_modules" ]; then
        npm install --silent >/dev/null 2>&1
    else
        echo "✔ Node modules already installed."
    fi
fi

# 4. ساخت پوشه سلامت (Health Check)
echo "🛠 Configuring API health endpoints..."
mkdir -p ~/global
cat << 'EOF' > ~/global/health
{
  "status": "ok",
  "service": "NodRun Engine",
  "version": "1.0.0"
}
EOF

# 5. ساخت دستورات میانبر اختصاصی ocr و ock
echo "⚡ Creating global shortcuts (ocr & ock)..."

cat << 'EOF' > $PREFIX/bin/ocr
#!/data/data/com.termux/files/usr/bin/sh
pkill -9 -f "node" 2>/dev/null
pkill -9 -f "ts-node" 2>/dev/null
fuser -k 4096/tcp 2>/dev/null
sleep 0.5

PROJECT_DIR="$HOME/NodRun"
if [ ! -d "$PROJECT_DIR" ]; then
    PROJECT_DIR="$PWD"
fi

cd "$PROJECT_DIR"
export PORT=4096

if grep -q "start" package.json; then
    nohup npm start >/dev/null 2>&1 &
elif [ -f "src/index.ts" ]; then
    nohup npx ts-node src/index.ts >/dev/null 2>&1 &
else
    nohup node index.js >/dev/null 2>&1 &
fi

printf "\n==================================================\n"
printf "🚀 NodRun Engine is LIVE directly on port 4096!\n"
printf "🔗 Health Check: http://127.0.0.1:4096/global/health\n"
printf "==================================================\n"
EOF
chmod +x $PREFIX/bin/ocr

cat << 'EOF' > $PREFIX/bin/ock
#!/data/data/com.termux/files/usr/bin/sh
pkill -9 -f "node" 2>/dev/null
pkill -9 -f "ts-node" 2>/dev/null
fuser -k 4096/tcp 2>/dev/null
printf "🛑 NodRun Server stopped successfully.\n"
EOF
chmod +x $PREFIX/bin/ock

# 6. فعال‌سازی Wakelock
if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock
    echo "🔋 Termux Wakelock activated."
fi

echo ""
echo "✅ Setup completed, Boss!"
echo "👉 Now type 'ock' then 'ocr' to run the main server!"
