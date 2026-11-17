# Half-Baked 🍞

A cozy pixel-art bakery for your half-baked ideas — a native macOS app.

- **Jot it down.** Open the app and type an idea in the middle of the screen; hit Return and it floats onto the shelf to rise.
- **Give it a counter.** Every idea gets its own workspace: a **Recipe** (steps you tick off) and **Notes**. Click any step or note to open it and add findings, answers or follow-ups.
- **Watch it bake.** Each idea's pixel loaf goes from raw dough → rising in a bowl → shaped loaf → golden and steaming as you make progress and mark it baked.
- **Always within reach.** A little steaming loaf floats on your desktop showing how many ideas are rising. Click it, or press **⌃⌥B** from anywhere, to open the bakery.

## Download

**[Download the latest Half-Baked.zip](https://github.com/amoveablefeastym/half-baked/releases/latest/download/Half-Baked.zip)** (macOS 14+, Apple Silicon & Intel)

1. Unzip and drag **Half-Baked.app** into Applications.
2. **First launch:** right-click the app → **Open** → **Open**. The app isn't notarized yet, so macOS asks once.
   If macOS says the app "is damaged", run `xattr -cr /Applications/Half-Baked.app` in Terminal, then open it again.

Free and open source. Your ideas stay on your Mac.

## Build from source

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
| ⌃⌥B | Open / hide Half-Baked from anywhere |
| Esc | Close thread / go back / hide |
| ⌘N | New dough (home) |

## Demo mode

For screen recordings (like the launch video made with [demoforge](https://github.com/amoveablefeastym/demoforge)), launch it with a throwaway data folder:

```sh
build/Half-Baked.app/Contents/MacOS/HalfBaked --demo /tmp/hb-demo
```

In demo mode, ideas are read from and saved to `<dir>/items.json` instead of your real ones, and settings go to a separate store that is wiped on launch. The panel opens right away at a fixed 1280×800, centered and pinned, with no floating icon or global shortcut. Copy `demo/items.json` into the folder first for a shelf of sample ideas.

## Credits

Font: [Pixelify Sans](https://github.com/eifetx/Pixelify-Sans), SIL Open Font License (see `Resources/Fonts/OFL.txt`).
