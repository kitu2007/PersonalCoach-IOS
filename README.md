# Personal Coach

A comprehensive personal coaching app with AI-powered chat, reminders, and voice interaction capabilities.

## Features

- 🤖 **AI Chat Coach** - Get personalized advice and motivation
- ⏰ **Smart Reminders** - Customizable daily routines and habits
- 🎤 **Voice Input/Output** - Speak to your coach and hear responses
- 📊 **Progress Tracking** - Monitor your habit completion rates
- ⌚ **Apple Watch Support** - Quick responses on your wrist
- 🔔 **Smart Notifications** - Contextual reminders with actions

## Setup

### 1. OpenAI API Key

To use the AI chat feature, you need an OpenAI API key:

1. **Get an API Key:**
   - Visit [OpenAI Platform](https://platform.openai.com/api-keys)
   - Sign up or log in to your account
   - Create a new API key

2. **Add to App:**
   - Open the Personal Coach app
   - Go to the "Coach" tab
   - Tap the gear icon (⚙️) in the top right
   - Enter your API key in the "OpenAI API Key" field
   - Tap "Save API Key"

3. **Pricing:**
   - Check [OpenAI Pricing](https://openai.com/pricing) for current rates
   - GPT-3.5-turbo is used by default (very affordable)
   - You can set usage limits in your OpenAI account

### 2. Voice Features

The app supports voice input and output:

- **Voice Input:** Tap the microphone button to speak your message
- **Voice Output:** Enable in settings to hear AI responses spoken aloud
- **Permissions:** Grant microphone and speech recognition access when prompted

### 3. Permissions

The app requires these permissions:
- **Microphone** - For voice input
- **Speech Recognition** - To convert speech to text
- **Notifications** - For reminder alerts

## Usage

### Chat with AI Coach
- Type or speak your questions
- Get personalized advice and motivation
- View chat history
- Enable voice responses

### Manage Reminders
- Add custom reminders with specific times
- Choose response types (Yes/No, Text, Both)
- Edit existing reminders
- Track completion rates

### Voice Commands
- Tap microphone to start voice input
- Speak naturally - the app transcribes in real-time
- Tap stop when finished
- Your transcribed text appears in the message field

## Privacy & Security

- API keys are stored securely in UserDefaults
- Voice data is processed locally for transcription
- Chat history is stored locally on your device
- No data is shared with third parties except OpenAI for AI responses

## Troubleshooting

### API Key Issues
- Ensure your API key is valid and has credits
- Check your internet connection
- Verify the key is saved correctly in settings

### Voice Issues
- Grant microphone permissions in iOS Settings
- Ensure you're in a quiet environment
- Check that speech recognition is enabled

### App Crashes
- If you see database errors, use the "Reset Database" option
- Delete and reinstall the app if issues persist

## Development

Built with:
- SwiftUI
- SwiftData
- OpenAI API
- Speech Framework
- AVFoundation

## Support

For issues or questions, check the troubleshooting section above or review the app's error messages in the Xcode console. 