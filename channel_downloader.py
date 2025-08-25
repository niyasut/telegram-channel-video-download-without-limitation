import asyncio
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes
from telethon.sync import TelegramClient
from telethon.tl.types import InputMessagesFilterVideo
import os
import logging

# Bot and API configuration
BOT_TOKEN = "YOUR_BOT_TOKEN"  # Replace with your BotFather token
API_ID = "YOUR_API_ID"        # Replace with your Telegram API ID
API_HASH = "YOUR_API_HASH"    # Replace with your Telegram API hash
DOWNLOAD_PATH = "downloads"   # Folder to store videos

# Set up logging
logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)
logger = logging.getLogger(__name__)

# Ensure download directory exists
if not os.path.exists(DOWNLOAD_PATH):
    os.makedirs(DOWNLOAD_PATH)

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Send welcome message when /start is issued."""
    await update.message.reply_text(
        "Hi! I'm a Telegram Video Downloader Bot. Send me a Telegram video post link, "
        "and I'll download the video for you. Ensure I'm a member of private channels!"
    )

async def download_video(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    """Handle video link and download the video."""
    chat_id = update.message.chat_id
    message_text = update.message.text

    # Check if the message is a valid Telegram link
    if not message_text.startswith("https://t.me/"):
        await update.message.reply_text("Please send a valid Telegram post link (e.g., https://t.me/channel/123).")
        return

    try:
        # Initialize Telethon client
        async with TelegramClient('bot_session', API_ID, API_HASH) as client:
            # Parse the link (e.g., https://t.me/channel/123 or https://t.me/c/123456789/123)
            parts = message_text.split("/")
            if "t.me/c/" in message_text:
                channel_id = int("-100" + parts[4])  # Private channel ID
                message_id = int(parts[5])
            else:
                channel_username = parts[3].replace("@", "")  # Public channel username
                message_id = int(parts[4])
                channel = await client.get_entity(channel_username)
                channel_id = channel.id

            # Fetch the message
            message = await client.get_messages(channel_id, ids=message_id)

            # Check if message contains a video
            if not message.media or not hasattr(message.media, 'document'):
                await update.message.reply_text("No video found in the provided link.")
                return

            # Download the video
            file_name = f"{DOWNLOAD_PATH}/video_{message_id}.mp4"
            await client.download_media(message.media, file_name)
            logger.info(f"Downloaded video to {file_name}")

            # Send the video back to the user
            with open(file_name, 'rb') as video_file:
                await context.bot.send_video(chat_id=chat_id, video=video_file, supports_streaming=True)
            await update.message.reply_text("Video downloaded and sent! Check above.")

            # Clean up the file
            os.remove(file_name)
            logger.info(f"Deleted temporary file {file_name}")

    except Exception as e:
        logger.error(f"Error processing link: {e}")
        await update.message.reply_text(f"Error downloading video: {str(e)}. Ensure the link is valid and I'm in the channel.")

async def main():
    """Start the bot."""
    # Create the Application
    application = Application.builder().token(BOT_TOKEN).build()

    # Add handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, download_video))

    # Start the bot
    await application.run_polling()

if __name__ == '__main__':
    asyncio.run(main())