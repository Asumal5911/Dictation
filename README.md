# Mac Local Dictation 🎙️

A fast, completely local dictation tool for macOS powered by the **Whisper Turbo** model. It runs right from your terminal and uses global keyboard shortcuts so you can transcribe audio anywhere, anytime.

## The Story Behind It
I originally built this out of a bit of frustration. I was using a tool called Wispr Flow to transcribe my thoughts, but I quickly hit their limit and was prompted to pay for a subscription. Looking at how it worked, I thought: *"I can probably just build my own version of this for free."* So, I did.

I designed it specifically for note-taking. When you're sitting in a lecture, you should be able to just *listen* to the professor and only jot down the most critical points that naturally come to you. Meanwhile, this app quietly transcribes the entire talk in the background. It’s not 100% perfect yet (it's a work in progress!), but it gives you a fantastic base transcript that you can later feed into tools like ChatGPT or Gemini to summarize, organize, and actually learn from.

## Features
- **100% Free & Local:** Runs locally on your Mac using the Whisper Turbo engine—no subscriptions, no internet required.
- **Global Shortcuts:** Seamlessly start and stop dictation without leaving the app you are currently typing in.
- **Smart Post-Processing (WIP):** 
  - Automatically analyzes and labels your transcriptions.
  - Uses context to correct sentences and make the text highly readable.

## ⚠️ Quick Usage Notes
Because this app runs locally and pastes directly into your workflow, there are two important things to keep in mind:
1. **Cursor Focus is Required:** When you finish dictating and hit the checkmark (or confirm shortcut), the app will automatically type the transcribed text into your currently active window. Make sure you have actually clicked inside a document, note, or text field before confirming!
2. **Give it a Second:** The local Whisper engine is fast, but it still has to think! Depending on how long you were speaking, it may take a couple of seconds to process and paste the final transcription. Just give it a brief moment to do its magic.
