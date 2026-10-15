# Deskling

A desktop pet for Claude Code on macOS and Windows.

Deskling walks along the bottom of your screen and reacts to what Claude Code is doing. When Claude Code asks for permission or finishes a task, the pet tells you with a speech bubble, so you can look away from the terminal.

- The bubble names the project folder and the prompt the session is working on, so you can tell sessions apart.
- Double-click or right-click the pet to see every Claude Code session and its state.
- Hold the pet to make it run, and let go in mid-air to watch it float down.
- Swap in your own pet with a folder of GIF or PNG images.

Deskling has no window of its own: there is the pet, and a paw icon in the macOS menu bar or the Windows notification area.

![Deskling showing a speech bubble](docs/images/demo.png)

[한국어 설명](README.ko.md)

> Deskling is an unofficial project. It is not affiliated with or endorsed by Anthropic.

## Install

Download the latest files from [Releases](https://github.com/fghjjkl32/deskling/releases/latest).

### macOS

Requires macOS 13 or later.

1. Download `Deskling-x.y.z.dmg`.
2. Open the DMG and drag **Deskling** into **Applications**.
3. Open Deskling. macOS will refuse the first time, because the app is not notarized by Apple.
4. Open **System Settings > Privacy & Security**, scroll down, and click **Open Anyway** next to the Deskling message.

If you prefer the terminal, this does the same as steps 3 and 4:

```bash
xattr -dr com.apple.quarantine /Applications/Deskling.app
```

### Windows

Requires 64-bit Windows 10 or 11. The Windows version is new in 0.2.0; please [report problems](https://github.com/fghjjkl32/deskling/issues).

1. Download `Deskling-windows-x.y.z.zip` and unzip it anywhere.
2. Run `Deskling.exe` in the `Deskling` folder.
3. Deskling is not signed, so Windows shows "Windows protected your PC" the first time. Choose **More info**, then **Run anyway**.

The pet walks along the taskbar. If the paw icon is hidden, click **^** in the notification area.

## Connect to Claude Code

Click the paw icon and choose **Connect to Claude Code**.

Deskling adds its hooks to Claude Code's `settings.json` and leaves your other settings and hooks alone. A copy of the original file is saved as `settings.json.deskling-backup`. Choose **Disconnect** to remove only Deskling's hooks. Sessions that were already running pick up the hooks after you restart them.

| | Settings file | Notes |
|---|---|---|
| macOS | `~/.claude/settings.json` | Connecting rewrites the file with sorted keys and standard indentation; every value is kept. `CLAUDE_CONFIG_DIR` is used only if the app was started with it in its environment, which is not the case from the Dock or Finder. |
| Windows | `%USERPROFILE%\.claude\settings.json` | Key order is kept. `CLAUDE_CONFIG_DIR` is used if it is set for your user. |
| WSL | `~/.claude/settings.json` in each distribution | Open the **WSL** submenu and connect each distribution where you run Claude Code. Its hooks call the Windows `deskling-hook.exe` through `/mnt/c/...`. |

What the pet does:

| Claude Code | Pet |
|---|---|
| Working on your prompt | Shows the working pose |
| Asking for permission or a question | Stops and shows a speech bubble, which stays until Claude Code continues |
| Finished | Celebrates and shows a speech bubble for 5 seconds |
| Nothing happening | Walks around and rests |

Click a speech bubble to dismiss it. Deskling only listens on your own computer: a Unix socket in `~/Library/Application Support/Deskling/` on macOS, and `127.0.0.1` with a random token on Windows. It sends nothing anywhere.

## Custom skins

Choose **Skin > Open Skins Folder** from the menu, create a folder, and put your images in it. The folder is `~/Library/Application Support/Deskling/skins/` on macOS and `%APPDATA%\Deskling\skins\` on Windows; the same skin folder works on both.

```
skins/my-pet/
  idle.gif      resting (required)
  walk.gif      walking
  working.gif   Claude Code is working
  waiting.gif   Claude Code needs you
  done.gif      Claude Code finished
  drag.gif      held with the mouse (running)
  fall.gif      floating down after you let go
  skin.json     optional
```

- Each file can be a GIF, an animated PNG, or a still PNG (`.gif` or `.png`).
- Only `idle` is required. Missing poses use the `idle` image.
- Without `drag`, the pet runs by playing `walk` at double speed. Without `fall`, it uses the `drag` image.
- Draw the pet facing right. Deskling flips it when it walks left.
- `skin.json` can set a display name and a height in points: `{ "name": "My Pet", "height": 120 }`.

Then pick your skin from the **Skin** menu. Only share images you have the right to share.

## Uninstall

Disconnect first. If you delete Deskling while it is connected, the hooks stay in `settings.json` and fail on every Claude Code event.

**macOS**

1. Choose **Disconnect** from the menu, then **Quit Deskling**.
2. Delete `Deskling.app` and the folder `~/Library/Application Support/Deskling`.

**Windows**

1. Choose **Disconnect**, and disconnect every WSL distribution you connected. Then choose **Quit Deskling**.
2. If you turned on **Launch at Login**, turn it off.
3. Delete the unzipped `Deskling` folder and `%APPDATA%\Deskling`.

If you already deleted the app, reinstall it and choose **Disconnect**, or open `settings.json` and remove every hook entry whose command contains `deskling-hook`.

## Build from source

**macOS**: Xcode (or its command line tools) with Swift 5.9 or later.

```bash
swift test
scripts/bundle.sh 0.2.0   # creates dist/Deskling.app
```

**Windows**: Flutter 3.44 and Visual Studio with the "Desktop development with C++" workload. The app lives in `deskling-windows/`.

```bash
cd deskling-windows
flutter test
flutter build windows --release
dart compile exe bin/deskling_hook.dart -o build/windows/x64/runner/Release/deskling-hook.exe
```

## License

Code is released under the [MIT License](LICENSE). The default pet is a CC0 cat by shuaa (megupets.com); see [CREDITS.md](CREDITS.md).
