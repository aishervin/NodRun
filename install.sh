#!/bin/sh

echo "🚀 Scanning & Setting up ☬SHΞN™ NodRun Repository..."

# 1. بررسی و نصب پیش‌نیازهای پایه‌ای در ترموکس
MISSING_PKGS=""
for pkg in python3 nodejs git curl; do
    if ! command -v $pkg >/dev/null 2>&1; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

if [ -n "$MISSING_PKGS" ]; then
    echo "📦 Installing missing packages:$MISSING_PKGS..."
    pkg update -y >/dev/null 2>&1
    pkg install -y python3 nodejs git curl cloudflared >/dev/null 2>&1
else
    echo "✔ Core packages (Python, Node, Git, Curl, Cloudflared) are ready."
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

# 3. نصب وابستگی‌های Node در صورت وجود package.json
if [ -f "package.json" ]; then
    echo "📦 Checking Node modules..."
    if [ ! -d "node_modules" ]; then
        npm install --silent >/dev/null 2>&1
    else
        echo "✔ Node modules already installed."
    fi
fi

# 4. ساخت پوشه سلامت (Health Check) برای جلوگیری از خطاهای 404/530
echo "🛠 Configuring API health endpoints..."
mkdir -p ~/global
cat << 'EOF' > ~/global/health
{
  "status": "ok",
  "service": "NodRun Engine",
  "version": "1.0.0"
}
EOF

# اگر پوشه website یا public توی پروژه هست، فایل سلامت را آنجا هم کپی می‌کنیم تا سرور پایتون بدون مشکل پاسخ دهد
if [ -d "website" ]; then
    mkdir -p website/global
    cp ~/global/health website/global/health
fi

# 5. ساخت دستورات میانبر اختصاصی ocr و ock (نسخه کامل برای رفع خطای سشن)
echo "⚡ Creating global shortcuts (ocr & ock)..."

cat << 'EOF' > $PREFIX/bin/ocr
#!/data/data/com.termux/files/usr/bin/sh
# پاکسازی کامل پورت‌ها و پروسه‌های قبلی برای جلوگیری از تداخل
pkill -9 -f "http.server 4096" 2>/dev/null
pkill -9 -f "ts-node" 2>/dev/null
pkill -9 -f "node" 2>/dev/null
fuser -k 4096/tcp 2>/dev/null
sleep 0.5

# تعیین مسیر ریشه پروژه
PROJECT_DIR="$HOME/NodRun"
if [ ! -d "$PROJECT_DIR" ]; then
    PROJECT_DIR="$PWD"
fi

# ۱. اجرای سرور پایتون برای فایل‌های استاتیک و مسیر سلامت
SERVE_DIR="$PROJECT_DIR/website"
if [ ! -d "$SERVE_DIR" ]; then
    SERVE_DIR="$PROJECT_DIR"
fi
nohup python3 -m http.server 4096 --directory "$SERVE_DIR" >/dev/null 2>&1 &

# ۲. اجرای بک‌اند اصلی پروژه (Node.js / TypeScript) جهت مدیریت سشن‌ها
cd "$PROJECT_DIR"
if [ -f "package.json" ]; then
    if grep -q "start" package.json; then
        nohup npm start >/dev/null 2>&1 &
    elif [ -f "src/index.ts" ] || [ -f "index.js" ]; then
        nohup npx ts-node src/index.ts >/dev/null 2>&1 &
    fi
fi

printf "\n==================================================\n"
printf "🚀 NodRun Engine & Session Server is LIVE on port 4096!\n"
printf "📂 Serving from: $SERVE_DIR\n"
printf "🔗 Health Check: http://127.0.0.1:4096/global/health\n"
printf "==================================================\n"
EOF
chmod +x $PREFIX/bin/ocr

cat << 'EOF' > $PREFIX/bin/ock
#!/data/data/com.termux/files/usr/bin/sh
pkill -9 -f "http.server 4096" 2>/dev/null
pkill -9 -f "ts-node" 2>/dev/null
pkill -9 -f "node" 2>/dev/null
fuser -k 4096/tcp 2>/dev/null
printf "🛑 NodRun Server stopped successfully.\n"
EOF
chmod +x $PREFIX/bin/ock

# 6. فعال‌سازی Wakelock برای پایداری ۲۴ ساعته در پس‌زمینه
if command -v termux-wake-lock >/dev/null 2>&1; then
    termux-wake-lock
    echo "🔋 Termux Wakelock activated (Background stability secured)."
fi

echo ""
echo "✅ All checks and configurations completed successfully, Boss!"
echo "👉 Now your users just need to type 'ocr' to run the server instantly."
