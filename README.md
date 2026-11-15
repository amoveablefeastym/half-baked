# Half-Baked 🍞

A cozy pixel-art bakery for your half-baked ideas — a native macOS app.

- **Jot it down.** Open the app and type an idea in the middle of the screen; hit Return and it floats onto the shelf to rise.
- **Give it a counter.** Every idea gets its own workspace: a **Recipe** (steps you tick off) and **Notes**. Click any step or note to open it and add findings, answers or follow-ups.
- **Watch it bake.** Each idea's pixel loaf goes from raw dough → rising in a bowl → shaped loaf → golden and steaming as you make progress and mark it baked.

## Build

Requires macOS 14+ and the Swift toolchain (Xcode or Command Line Tools).

```sh
./build.sh           # builds build/Half-Baked.app
./build.sh install   # also copies it to ~/Applications and puts a shortcut on the Desktop
```

Your ideas are saved to `~/Library/Application Support/Half-Baked/items.json`.

## Keys

| Key | Does |
| --- | --- |
| Return | Save / add |
| Shift-Return | New line |
| Tab | Switch Note ↔ Step |
| Esc | Close thread / go back / hide |
| ⌘N | New dough (home) |

## Credits

Font: [Pixelify Sans](https://github.com/eifetx/Pixelify-Sans), SIL Open Font License (see `Resources/Fonts/OFL.txt`).
