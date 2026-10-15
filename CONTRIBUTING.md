# Contributing to Dilçi

Thanks for helping. Small, focused pull requests are the easiest to review.

## Good first contributions

- **Shorthand**: add `("short", "full")` pairs to `Shared/Slang.swift`. Keep them whole words that people really type.
- **Culture notes**: add an `Entry` to `Shared/CultureNotes.swift` with an English and a Russian note, each under about 12 words.
- **Word lists**: `Keyboard/swipe_en.txt` and `Keyboard/swipe_ru.txt` are ordered by frequency, one word per line.

## Code

- SwiftUI for the app and the translation strip, UIKit for the keys. Keep anything that runs on every keystroke out of SwiftUI.
- The keyboard extension has a tight memory limit. Avoid loading large resources on the main thread.
- Test on a real iPhone. Keyboard extensions behave differently in the simulator.

## Reporting bugs

Include your iOS version, iPhone model, the app you were typing in, what you typed and what you expected.
