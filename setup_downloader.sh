#!/bin/bash
# Telegram Channel File Downloader Setup Script

echo "=========================================="
echo "Setting up Telegram File Downloader on VPS"
echo "=========================================="

# Update system
echo "[1/6] Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Install required packages
echo "[2/6] Installing required packages..."
sudo apt install -y python3 python3-pip python3-venv tmux

# Create project directory
echo "[3/6] Creating project directory..."
mkdir -p ~/telegram-downloader
cd ~/telegram-downloader

# Create virtual environment
echo "[4/6] Setting up Python virtual environment..."
python3 -m venv myenv
source myenv/bin/activate

# Install Telethon
echo "[5/6] Installing Telethon..."
pip install telethon

# Create the downloader script
echo "[6/6] Creating downloader script..."
cat > telethon_downloader.py << 'EOF'
#!/usr/bin/env python3
"""
Telegram Channel File Downloader for VPS
Automatically downloads files from Telegram channel 24/7
"""

import asyncio
import os
import logging
from telethon import TelegramClient, events

# ==================== CONFIGURATION ====================
# GET THESE FROM: https://my.telegram.org
API_ID = d33232  # REPLACE WITH YOUR API ID (number)
API_HASH = '280f7876ddfdsfsdfsdfsdfs88b0'  # REPLACE WITH YOUR API HASH

# Your phone number (with country code)
PHONE_NUMBER = '+121323232323232323'  # REPLACE WITH YOUR PHONE NUMBER

# Channel to monitor (username without @)
CHANNEL_USERNAME = 'myfdsfte'  # REPLACE WITH YOUR CHANNEL

# Download directory
DOWNLOAD_PATH = '/home/ubuntu/ai/downloads'
# =======================================================

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    handlers=[
        logging.FileHandler('telethon_downloader.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Create download directory
os.makedirs(DOWNLOAD_PATH, exist_ok=True)
logger.info(f"Download directory: {DOWNLOAD_PATH}")

class TelegramDownloader:
    def __init__(self):
        self.client = TelegramClient('telegram_session', API_ID, API_HASH)
        self.downloaded_files = set()
        self._load_downloaded_files()
    
    def _load_downloaded_files(self):
        """Load list of already downloaded files"""
        if os.path.exists('downloaded_files.txt'):
            with open('downloaded_files.txt', 'r') as f:
                self.downloaded_files = set(line.strip() for line in f)
        logger.info(f"Loaded {len(self.downloaded_files)} previously downloaded files")
    
    def _mark_file_downloaded(self, file_id):
        """Mark a file as downloaded"""
        self.downloaded_files.add(file_id)
        with open('downloaded_files.txt', 'a') as f:
            f.write(f"{file_id}\n")
    
    async def start(self):
        """Start the downloader"""
        try:
            await self.client.start(phone=PHONE_NUMBER)
            logger.info("✅ Successfully logged in to Telegram")
            
            me = await self.client.get_me()
            logger.info(f"👤 Logged in as: {me.first_name}")
            
            try:
                channel = await self.client.get_entity(CHANNEL_USERNAME)
                logger.info(f"📊 Monitoring channel: {channel.title}")
            except Exception as e:
                logger.error(f"❌ Cannot find channel: {e}")
                return False
            
            @self.client.on(events.NewMessage(chats=channel))
            async def handler(event):
                await self.handle_message(event)
            
            logger.info("🎯 Started monitoring channel. Press Ctrl+C to stop.")
            await self.client.run_until_disconnected()
            return True
            
        except Exception as e:
            logger.error(f"❌ Error: {e}")
            return False
    
    async def handle_message(self, event):
        """Handle incoming messages"""
        message = event.message
        if not message.media:
            return
        
        try:
            file_id = str(message.id)
            file_name = self.get_file_name(message)
            
            if file_id in self.downloaded_files:
                logger.info(f"⏩ Already downloaded: {file_name}")
                return
            
            file_path = os.path.join(DOWNLOAD_PATH, file_name)
            file_size = message.file.size if message.file else 0
            
            logger.info(f"📥 Downloading: {file_name} ({file_size / (1024*1024):.1f} MB)")
            
            result = await message.download_media(file=file_path)
            
            if result and os.path.exists(result):
                file_stats = os.stat(result)
                logger.info(f"✅ Downloaded: {file_name} ({file_stats.st_size / (1024*1024):.1f} MB)")
                self._mark_file_downloaded(file_id)
                
        except Exception as e:
            logger.error(f"❌ Download error: {e}")
    
    def get_file_name(self, message):
        """Get appropriate file name"""
        if message.file and message.file.name:
            return message.file.name
        
        if message.document:
            ext = message.file.ext if message.file else ".bin"
            return f"document_{message.id}{ext}"
        elif message.photo:
            return f"photo_{message.id}.jpg"
        elif message.video:
            return f"video_{message.id}.mp4"
        elif message.audio:
            return f"audio_{message.id}.mp3"
        else:
            return f"file_{message.id}.dat"

async def main():
    print("Starting Telegram Channel Downloader...")
    downloader = TelegramDownloader()
    
    try:
        await downloader.start()
    except KeyboardInterrupt:
        logger.info("⏹️ Stopped by user")
    except Exception as e:
        logger.error(f"❌ Unexpected error: {e}")
    finally:
        await downloader.client.disconnect()
        logger.info("👋 Disconnected")

if __name__ == '__main__':
    asyncio.run(main())
EOF

# Make script executable
chmod +x telethon_downloader.py

# Create configuration helper script
cat > configure_downloader.sh << 'EOF'
#!/bin/bash
echo "Configuring Telegram Downloader..."
echo "Please enter your details:"

read -p "API ID (from my.telegram.org): " api_id
read -p "API Hash: " api_hash
read -p "Phone number (with country code): " phone_number
read -p "Channel username (without @): " channel_username

# Update the Python script with configuration
sed -i "s/API_ID = 12345678/API_ID = $api_id/" telethon_downloader.py
sed -i "s/API_HASH = 'your_api_hash_here'/API_HASH = '$api_hash'/" telethon_downloader.py
sed -i "s/PHONE_NUMBER = '+1234567890'/PHONE_NUMBER = '$phone_number'/" telethon_downloader.py
sed -i "s/CHANNEL_USERNAME = 'your_channel_username'/CHANNEL_USERNAME = '$channel_username'/" telethon_downloader.py

echo "Configuration updated successfully!"
echo "Run: ./start_downloader.sh to start the downloader"
EOF

chmod +x configure_downloader.sh

# Create start script
cat > start_downloader.sh << 'EOF'
#!/bin/bash
cd ~/telegram-downloader
source myenv/bin/activate

# Check if configuration is done
if grep -q "12345678" telethon_downloader.py || grep -q "your_api_hash_here" telethon_downloader.py; then
    echo "Please configure the downloader first:"
    echo "./configure_downloader.sh"
    exit 1
fi

echo "Starting Telegram Downloader in tmux..."
tmux new-session -d -s telegram_downloader "cd ~/telegram-downloader && source myenv/bin/activate && python telethon_downloader.py"

echo "✅ Downloader started in background!"
echo "To view logs: tmux attach -t telegram_downloader"
echo "To stop: tmux kill-session -t telegram_downloader"
echo "Log file: ~/telegram-downloader/telethon_downloader.log"
EOF

chmod +x start_downloader.sh

# Create status script
cat > check_status.sh << 'EOF'
#!/bin/bash
echo "=== Telegram Downloader Status ==="
if tmux has-session -t telegram_downloader 2>/dev/null; then
    echo "✅ Downloader is RUNNING"
    echo "To view: tmux attach -t telegram_downloader"
else
    echo "❌ Downloader is STOPPED"
    echo "To start: ./start_downloader.sh"
fi

echo -e "\n=== Downloaded Files ==="
ls -la ~/telegram_downloads/ 2>/dev/null || echo "No files downloaded yet"

echo -e "\n=== Log File ==="
tail -10 ~/telegram-downloader/telethon_downloader.log 2>/dev/null || echo "No log file found"
EOF

chmod +x check_status.sh

echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
echo "Next steps:"
echo "1. Configure your credentials:"
echo "   cd ~/telegram-downloader"
echo "   ./configure_downloader.sh"
echo ""
echo "2. Start the downloader:"
echo "   ./start_downloader.sh"
echo ""
echo "3. Check status anytime:"
echo "   ./check_status.sh"
echo "=========================================="