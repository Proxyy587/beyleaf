# Source

- **Upstream:** https://github.com/kemiljk/skills, `skills/dxe-apple-native-ui/` @ 32a9154 (2026-11-18). This is the
  "apple-native-ui" skill. Its directory and `name` keep the upstream `dxe-` prefix.
- **Licence:** MIT, © Karl Koch (`LICENSE`, from the repository root). `references/macos-native-workflows.md` adapts
  Bart Reardon's mac-arsed-mac-app skill (MIT); that notice ships as `references/macos-source-license.txt`.
- **Files (verbatim, unmodified):**

| File | SHA-256 (first 16) |
|---|---|
| `SKILL.md` | `d0a35934f6c81f4f` |
| `references/macos-native-workflows.md` | `05a806b9113144ec` |
| `references/apple-verification.md` | `dff6d280bbe3c98f` |
| `references/macos-source-license.txt` | `b829decfb63b0f0f` |
| `LICENSE` | `21a7612180f31f07` |

## Why we use it
It covers native behaviour, where `swiftui-macos` covers our build and `belay-design` our look:
- real controls instead of tappable stacks;
- VoiceOver labels, values and order;
- state ownership and version gates with fallbacks;
- the macOS workflow (menu bar utility shape, keyboard, windows, pasteboard, drag and drop).

## How it fits Belay
- Belay is a **menu bar utility**: the notch panel plus a Settings window. That is the "app shape" the skill asks for first.
- Its verification notes assume Xcode, XCUITest and simulators. We build with the Command Line Tools only (ADR 0013), so
  use `swiftui-macos`'s checks (screencapture, CPU, logs). Record anything that needs Xcode as a limit, never as passed.
- `docs/design.md` still decides the look. This skill decides whether it behaves like a Mac app.
