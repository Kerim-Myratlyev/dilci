# Dilçi 译

Chinese, from your own words. Free, private, offline.

Dilçi is an iOS keyboard and app. Type your message in English or Russian in any chat (WeChat, Telegram, iMessage), the way you normally text: "see u tmrw", "щас буду". Switch to the Dilçi keyboard. The natural Chinese and its pinyin appear above the keys. Tap **Insert** and send.

## Free, with no API key

Everything runs on your iPhone:

1. **Understands chat shorthand.** A built-in dictionary expands about 150 English and Russian abbreviations (u, tmrw, pls, idk, wru, спс, щас, норм, мб...). On iPhones with Apple Intelligence, Dilçi also uses Apple's on-device model to work out what you mean from the other person's last message.
2. **Translates with Apple's on-device translator** (the same engine as the Translate app). You download it once; after that it works offline.
3. **Shapes the tone.** Casual drops the full stop, as people do in chat. Polite and Work use 您.
4. **Lets you check.** Each translation is translated back ("Reads as"). Phrases that are easy to misread, like 改天, 呵呵 or 再说吧, get a short note.

There's no account and no server, and nothing you type leaves the phone.

## Keyboard

- **Insert** replaces what you wrote with the Chinese. **Undo** puts it back.
- **Their message**: copy the Chinese message you're answering, then tap this button. Dilçi explains it in English or Russian, and your reply uses it as context.
- Tap the Chinese to see what it reads as.
- Select part of your text to translate only that part.
- Built-in English and Russian layouts (the RU/EN key), and Casual, Polite and Work tones.
- **Swipe typing**: slide across the letters without lifting. The best word goes in, with up to three other guesses above the keys. Works in English (30,000 words) and Russian (40,000 words).
- **Cursor trackpad**: press and hold the space bar, or drag along it, then slide to move the cursor. Slide up or down to change lines.
- **Like the system keyboard**: hold Delete to erase faster, then whole words. Hold е for ё, ь for ъ, and e, a, u, o, n, c for accents. Double-tap Space for a full stop, double-tap Shift for caps lock. Key clicks and haptics follow your iPhone settings.

The keys are drawn in UIKit and every touch is handled directly, without SwiftUI, so typing stays light. Translation only runs after you pause.

## App

- **Translate**: a conversation view. Switch between Me and Them, paste their message, type your reply, and you get bubbles you can copy, listen to, or save.
- **Phrasebook**: everything you've translated, plus your saved lines, with search.
- **Settings**: offline languages, your explanation language, default tone and pinyin.

## Run it

You need **Xcode 16 or newer** and an iPhone on **iOS 18+**.

1. Open `Dilci.xcodeproj`.
2. For both targets, **Dilci** and **DilciKeyboard**, open Signing & Capabilities and choose your Team.
3. If the bundle ID is taken, change `DILCI_ID` in the project's Build Settings (for example `com.yourname.dilci`).
4. Run it on your iPhone. In the app, tap **Get** to download Chinese.
5. Go to Settings › General › Keyboard › Keyboards › Add New Keyboard › **Dilçi**. Then tap Dilçi and turn on **Allow Full Access**.

On a free Apple ID, Xcode may reject App Groups. Translation still works. Only the Phrasebook sync between keyboard and app needs App Groups.

## Project layout

```
App/        Translate (conversation), Phrasebook, Settings, onboarding
Keyboard/   keyboard extension: UIKit key grid, swipe decoder + word lists, translation strip
Shared/     translation pipeline, Apple Translation bridge, slang, notes, theme
Config/     Info.plists and entitlements
Tests/      Unit tests for the core (swift test)
```

Run the core tests with `swift test`. CI also builds the app and keyboard for the iOS Simulator on every push.

To teach Dilçi more shorthand, add lines to `Shared/Slang.swift`. Cultural notes live in `Shared/CultureNotes.swift`.
