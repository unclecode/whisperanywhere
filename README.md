To get WhisperAnywhere working on your Mac, follow these steps:

### Step 1: Clone the Repository

First, you need to clone the WhisperAnywhere repository to your local machine. Open Terminal and run the following command:

```bash
git clone https://github.com/unclecode/whisperanywhere.git
```

This will create a new directory called `whisperanywhere` in your current location.

### Step 2: Install Dependencies

Navigate to the project directory and install the required dependencies using Homebrew:

```bash
cd whisperanywhere
brew install ffmpeg
```

Note: You may need to install Homebrew if you haven't already. You can do this by running `brew --version` in Terminal. If it's not installed, you'll see instructions on how to install it.

### Step 3: Set Up Xcode Project

Open the project file located in the cloned repository:

```bash
open WhispeAnywhere.xcodeproj
```

This should open the project in Xcode.

### Step 4: Configure API Keys

Before building the project, you need to set up API keys for Whisper AI and Groq API. Create a new file named `config.json` in the project root directory with the following content:

```json
{
  "whisper_api_key": "YOUR_WHISPER_API_KEY",
  "groq_api_key": "YOUR_GROQ_API_KEY"
}
```

Replace `YOUR_WHISPER_API_KEY` and `YOUR_GROQ_API_KEY` with your actual API keys.

### Step 5: Build and Run the Project

In Xcode, build and run the project. You may encounter some issues related to dependencies or permissions. Here are some common solutions:

1. If you encounter permission errors, try running Xcode as administrator.
2. If there are dependency issues, make sure you have the latest version of Xcode installed.
3. If you encounter issues related to Swift versions, try updating your Swift version in Xcode preferences.

### Step 6: Set Up Hotkey

Once the app is running, you'll need to set up a hotkey to activate WhisperAnywhere. You can do this in System Preferences > Keyboard > Shortcuts > Services.

### Key Points to Consider:

- Ensure you have the latest version of macOS installed.
- Make sure you have sufficient disk space available.
- Some features may require an internet connection to work properly.

### Best Practices:

- Keep your API keys secure and don't share them publicly.
- Regularly update the project dependencies to ensure compatibility and security.
- Test the application thoroughly before using it in important situations.

If you encounter any specific errors during the setup process, please provide more details so I can offer more targeted assistance.
