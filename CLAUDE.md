# Calc-9

A macOS menu bar calculator. Hotkey, type an expression, live result, Enter pastes it into
the app you came from. Swift 5, SwiftUI + AppKit, macOS 13+. No dependencies.

Sibling to Clip-9 (`~/code/apps/clip-9`) — same look, **deliberately no shared code**.
A fix here does not reach Clip-9 and vice versa. That was an explicit decision.

Public repo: https://github.com/monacotobi/calc-9

## Build and verify

Three gates, in increasing cost:

```sh
# 1. Engine logic — fast, no window server needed
swift test

# 2. Project file is structurally valid
plutil -lint Calc-9.xcodeproj/project.pbxproj

# 3. The real build
xcodebuild -project Calc-9.xcodeproj -target Calc-9 -configuration Release \
           CONFIGURATION_BUILD_DIR="$PWD/build" CODE_SIGN_IDENTITY="-" build
```

Use `CONFIGURATION_BUILD_DIR`, not `-derivedDataPath` — xcodebuild rejects the latter
unless `-scheme` is also passed, and no shared scheme is committed (`xcuserdata/` is
gitignored). CI uses the same invocation.

None of these prove the app *behaves*. The hotkey, the paste, and the panel need a real
keyboard and window server. Report a passing build as a passing build.

Editors running SourceKit per-file will report "cannot find X in scope" for sibling types;
that is single-file analysis without project context, not a real error.

## Layout

| Path | Function |
|---|---|
| `Sources/Calc9App.swift` | `@main`, empty Settings scene |
| `Sources/AppDelegate.swift` | Menu bar, `previousApp`, permission prompt, login toggle |
| `Sources/LoginItem.swift` | `SMAppService` launch-at-login |
| `Sources/Engine/` | Tokenizer → Parser (shunting-yard) → Evaluator, plus `Tape` |
| `Sources/HotKey/` | Carbon `RegisterEventHotKey` |
| `Sources/Paste/` | Synthetic Cmd+V |
| `Sources/UI/` | `CalcTheme`, `CalcState`, `CalcView`, `CalcWindow` |
| `Tests/` | Engine + Tape unit tests |
| `Package.swift` | Exists **only** to test the engine; see below |

## Constraints

- **`Package.swift` is a test harness, not the build.** It exposes `Sources/Engine` as a
  library so the pure-Swift logic can be tested with `swift test`. The Xcode app target
  compiles the same files directly. Do not add UI code to `Sources/Engine` — it would break
  `swift test`, which has no AppKit.
- **The hotkey uses Carbon `RegisterEventHotKey`, not a `CGEventTap`.** This is deliberate:
  a tap sees every keystroke system-wide, this sees one combination. Two ordering rules,
  both of which fail *silently* — registration returns `noErr` while nothing fires:
  1. `NSApplication.shared` must exist before any Carbon call.
  2. Install the handler on `GetEventDispatcherTarget()`, not `GetApplicationEventTarget()`.
- **Accessibility is needed only for pasting.** Declining must degrade, not break: the
  hotkey still works and results still reach the clipboard. Keep it that way.
- **Not sandboxed.** Synthetic keystrokes are denied inside the sandbox regardless of
  permission.
- **The panel must not steal focus.** `.nonactivatingPanel`, or `previousApp` is lost and
  the paste lands in the wrong app.
- **Geometry lives in `CalcLayout`.** `CalcWindow` sizes the panel before SwiftUI lays out,
  so it must predict the height. Never put bare numbers in `CalcWindow`.
- **The tape always renders `tapeCapacity` rows**, blanks included, so the panel height is
  constant and nothing shifts as entries accumulate.
- **`%` divides by 100, always.** `100+10%` is `100.1`, not `110`. There is a test asserting
  this. It is a decision, not a bug.
- **Live preview shows the longest valid prefix**, but returns nil on division by zero
  rather than falling back to a shorter prefix — printing `1` while the screen reads `1/0`
  is worse than printing nothing. Also tested.
- **`DEVELOPMENT_TEAM` is intentionally empty** so contributors and CI build unsigned. Do
  not commit a team ID.

## Scope

Three tape entries, in memory, cleared on quit. No named functions, variables, units, or
configurable hotkey. Ask before adding persistence or a dependency.
