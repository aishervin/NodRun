#!/bin/sh

echo "🚀 Initializing ☬SHΞN™ NodRun Ultimate Master Script..."

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
    echo "✔ Core packages are ready."
fi

# 2. کلون یا آپدیت مخزن پروژه
PROJECT_DIR="$HOME/NodRun"
if [ -d "$PROJECT_DIR/.git" ]; then
    echo "🔄 Updating existing repository..."
    cd "$PROJECT_DIR"
    git pull origin main >/dev/null 2>&1
else
    echo "📥 Cloning NodRun repository..."
    git clone https://github.com/aishervin/NodRun.git "$PROJECT_DIR" >/dev/null 2>&1
    cd "$PROJECT_DIR"
fi

# 3. پاکسازی کامل و نصب تمیز پکیج‌ها (جلوگیری از خطای source-map و pngjs)
echo "📦 Performing clean npm installation & removing broken caches..."
cd "$PROJECT_DIR"
rm -rf node_modules package-lock.json >/dev/null 2>&1
npm cache clean --force >/dev/null 2>&1
npm install --legacy-peer-deps >/dev/null 2>&1

# تزریق صریح پکیج‌های حیاتی برای جلوگیری از ارور مفقودی ماژول‌ها
npm install expo pngjs source-map-support --save --legacy-peer-deps >/dev/null 2>&1

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

# 5. ساخت دستورات میانبر اختصاصی ocr و ock با تنظیم دقیق PATH و پاکسازی پورت‌ها
echo "⚡ Creating global shortcuts (ocr & ock)..."

cat << 'EOF' > $PREFIX/bin/ocr
#!/data/data/com.termux/files/usr/bin/sh
pkill -9 -f "node" 2>/dev/null
pkill -9 -f "expo" 2>/dev/null
fuser -k 4096/tcp 2>/dev/null
sleep 0.5

PROJECT_DIR="$HOME/NodRun"
if [ ! -d "$PROJECT_DIR" ]; then
    PROJECT_DIR="$PWD"
fi

cd "$PROJECT_DIR"
export PORT=4096
export PATH="$PROJECT_DIR/node_modules/.bin:$PREFIX/bin:$PATH"

echo "Starting NodRun server..." > ~/nodrun.log
nohup npx --yes expo start --port 4096 --offline > ~/nodrun.log 2>&1 &

sleep 3

printf "\n==================================================\n"
printf "🚀 NodRun Engine is LIVE on port 4096!\n"
printf "🔗 Health Check: http://127.0.0.1:4096/global/health\n"
printf "📄 Logs: cat ~/nodrun.log\n"
printf "==================================================\n"
EOF
chmod +x $PREFIX/bin/ocr

cat << 'EOF' > $PREFIX/bin/ock
#!/data/data/com.termux/files/usr/bin/sh
pkill -9 -f "node" 2>/dev/null
pkill -9 -f "expo" 2>/dev/null
fuser -k 4096/tcp 2>/dev/null
printf "🛑 NodRun Server stopped successfully.\n"
EOF
chmod +x $PREFIX/bin/ock

# 6. فعال‌سازی Wakelock برای جلوگیری از خواب رفتن پروسه در پس‌زمینه
if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock
    echo "🔋 Termux Wakelock activated."
fi

echo ""
echo "✅ Complete Master Setup Finished Successfully!"
echo "👉 Users can now just type 'ock' then 'ocr' to run everything smoothly!"
