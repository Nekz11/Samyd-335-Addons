# Samyd's 3.3.5a Addons

Modern UI addons for **World of Warcraft 3.3.5a** (Wrath of the Lich King, Interface 30300), written from scratch for private servers such as **Warmane**.
Every addon has its own in-game options window, so no chat-command fiddling is required.

| Addon | Version | What it does | Options |
|---|---|---|---|
| [BetterFrames 335](BetterFrames335/) | 2.1.1 | Better default unit frames: class colors, textures & fonts, aura filters & glows, castbar customization, interrupt tracking, absorb/combat/racial indicators, hide & move UI elements, profiles and presets (inspired by BetterBlizzFrames) | `/bbf` |
| [BetterPlates](BetterPlates/) | 2.0.0 | Complete nameplate suite: class colors, friend/foe styles, cast bars, auras, DR tracker, threat modes, flag carriers, totem timers, zone rules, profiles and presets (inspired by BetterBlizzPlates) | `/bbp` |
| [RetailPartyFrames](RetailPartyFrames/) | 2.0.1 | Retail-style party **and raid** frames: in-frame cast bars, party cooldowns, dispel highlighting, HoT indicators, click-casting, profiles with auto switching, presets | `/rpf` |
| [WArena](WArena/) | 2.0.1 | Full PvP frames package: arena frames with DR, enemy cooldowns, cast bars, indicators, BG enemy list, boss frames, announcements, themes, profiles, presets | `/warena` |
| [SpellFlash 335](SpellFlash335/) | 2.5 | Flashes an action button when you press its keybind, with several effects, colours and play modes (works with SnowfallKeyPress, Bartender4, Dominos, ElvUI) | `/sf` |

None of these addons contain code from the retail addons that inspired them.

## Download

Go to **[Releases](../../releases/latest)** and download either

- `Samyd-335-Addons-All.zip` (all five addons), or
- the ZIP of a single addon, e.g. `WArena.zip`.

> Please do **not** use the green "Code → Download ZIP" button - that archive has the wrong folder names and the addons will not show up in game.

## Installation

1. Close the game.
2. Extract the ZIP into `World of Warcraft\Interface\AddOns\`.
3. Check the folder names - each addon folder must contain its `.toc` file directly, e.g.
   `Interface\AddOns\WArena\WArena.toc` (not `AddOns\WArena\WArena\WArena.toc`).
4. Start the game and enable the addons on the character selection screen ("AddOns" button, bottom left).

## Bugs & feedback

Please open an [issue](../../issues) and include:

- addon name and version,
- what you were doing (arena, battleground, raid, open world ...),
- the error text if there is one (most addons also have a `debug` command, e.g. `/rpf debug`, `/bbp debug`).

## Support

All addons are and will stay free. If you'd like to say thanks, you can gift a few Warmane coins to **Samyd** on **Blackrock** via [Account Services](https://www.warmane.com/account/services). Totally optional!

## License

[MIT](LICENSE)
