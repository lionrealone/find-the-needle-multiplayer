# Find The Needle Coop Launcher

Unofficial launcher and multiplayer mod for the Steam game **Find The Needle**, by **lionrealone**.

Targets the **full release** (the Steam demo is no longer supported).

## What the launcher does

- Enables the coop mod only when you start through this launcher
- Launches the game via Steam
- Removes the mod again when the game closes
- Starting from Steam alone = vanilla (no mod)

## Requirements

- Windows
- Steam
- [Find The Needle](https://store.steampowered.com/app/5160800/Find_The_Needle/)
- Node.js 18+ (build only)

## Game not found?

1. Install the game and start Steam once
2. In the launcher choose **Select FindTheNeedle.exe…**
3. Pick `FindTheNeedle.exe` from your Steam library folder  
   (usually `steamapps/common/Needle in a Haystack/`)

## Develop

```bash
npm install
npm start
```

## Build the EXE

```bash
npm install
npm run dist
```

Output: `dist/Find The Needle.exe`

## Layout

| Path | Contents |
| --- | --- |
| `src/` | Electron launcher |
| `resources/multiplayer/` | Godot coop mod |
| `build/` | Icons |
| `scripts/` | Build hooks (icon) |

## Multiplayer

1. Start the launcher, then **Start game!**
2. In game: **Multiplayer**, then **Create Game**
3. Invite friends
4. In the main menu use **New Game** or **Load** as usual

You can also play without Steam over direct IP (default port 7777).

## Download

Release builds: [Releases](https://github.com/lionrealone/find-the-needle-multiplayer/releases)

## License

MIT. See `LICENSE`.

Unofficial fan project for Find The Needle. Not affiliated with the game developers or Valve/Steam. The game remains their property.

## Authors

- [lionrealone](https://github.com/lionrealone)
- [alexm622](https://github.com/alexm622)
