# Forever Quest Tint

A small addon for **World of Warcraft: Forever** that tints the quest text background a light teal, to match the Forever logo, whenever the quest was **not** part of original Classic (vanilla).

Vanilla quests keep the normal parchment. Everything new to Forever gets a teal gradient rising from the bottom of the page, and a small infinity-sign marker after its name in the quest log list and the objective tracker.

| Quest giver window | Map & Quest Log |
| --- | --- |
| ![Quest giver window](screenshots/quest-giver.png) | ![Map and quest log](screenshots/quest-log.webp) |

## Install

1. Download the latest release zip.
2. Extract it into the `Interface\AddOns` folder of your World of Warcraft: Forever install, so you have `...\Interface\AddOns\ForeverQuestTint`.
3. Restart the game or type `/reload`.

## Options

Type `/fqt`, or open **Options → AddOns → Forever Quest Tint**.

- **Tint the parchment teal**: on by default.
- **Add the WoW Forever logo**: off by default. Puts the logo in the top-right corner of the bar above the quest text. Works with or without the tint.
- **Tint colour**: the colour of the overlay.
- **Bottom opacity**: strength of the teal at the bottom of the page.
- **Top opacity**: strength where the fade ends. `0%` fades out completely.
- **Fade length**: how far up the parchment the fade reaches.
- **Quest name marker**: an infinity sign after the name of non-vanilla quests, in the quest log list and the objective tracker.
  - Show or hide it, and put it at the start of the name instead of the end.
  - By default it is a small icon; you can set its height, nudge it up or down to line up with the text, and adjust its spacing from the name. Or switch to a plain text symbol (up to 4 characters, so you can use any character the game's font has).
  - By default it uses the tint colour; turn that off to pick its own colour.

- **Quest objectives**: off by default. Recolours the objective lines of non-vanilla quests (in the quest log list and the tracker) from white to the tint colour, or a colour of your choice. Completed and failed objectives keep their own colours.

- **Preview**: a testing aid. Forces the tint, logo and marker **on** for every quest, **off** for every quest, or back to **auto** (the normal behaviour). It is remembered between sessions, and the addon reminds you at login while it is not on auto.

### Commands

- `/fqt`: open the options.
- `/fqt preview on`, `/fqt preview off`, `/fqt preview auto`: set the preview. `/fqt preview` on its own cycles auto → on → off. `/fqt glow` works too.
- `/fqt id`: the ID of the quest you have open, and whether the addon considers it vanilla.
- `/fqt status`: the addon version, game interface, preview mode, and which supported UI addons were detected.

## How it decides what is vanilla

The addon contains a list of the quest IDs that existed in original Classic (`VanillaQuests.lua`). Any quest not on that list is tinted. The list was generated from the Classic quest database in [Questie](https://github.com/Questie/Questie). A few genuine vanilla quests may be missing, and would show as teal. If you spot one, open an issue with the ID from `/fqt id`.

Only quests that are open in a quest window are tinted. Gossip windows have no quest ID, so they are left alone.

## Other UI addons

Nothing to configure: the addon detects these on its own (`/fqt status` shows what it found).

- **Dialogue UI**: its quest window gets the tint (matching its Brown and Dark themes) and the logo. Dialogue UI doesn't load on the Forever client out of the box: in its `DialogueUI.toc`, delete the `## X-Expansion: MAINLINE` line and add `, 16001` to the `## Interface:` line.
- **Immersion**: its talking-head box gets a teal glow that follows the box's shape, and the logo in its top-right corner, while it shows quest text. Gossip is left alone.
- **Lorewalker**: in its Classic mode, the quest page gets a teal wash that follows the page's outline (a deeper glow on its Dark theme), and the logo on the title bar. Gossip is left alone. Its Immersive and Story modes have no page, so they are unchanged. Lorewalker gives quests it considers new to Forever a page of its own; the tint and logo follow this addon's list.
- **ClassicUI Forever**: its quest log window gets the teal wash on the selected quest's page, and the quest name marker in its list. Its quest watch gets the marker too. On the map, the tint follows its parchment when its quest pane is on, and its dark themes get a teal glow instead of the copy of the paper. Its quest-giver window is the game's, so it is tinted as usual. Not covered yet: its combined map's quest pages, the logo in its quest log, and objective colours in its quest watch.
- **EllesmereUI**: its Quest Tracker restyles Blizzard's objective tracker, so the quest name marker and objective colours work in it as usual. EllesmereUI shows quest names on a single line, so a long name can cut off a marker placed after it; if that happens, tick **Put the marker at the start of the name**.

Using another quest or tracker addon? Open an issue with its name.

## Game versions

Built for World of Warcraft: Forever (interface `16001`). It also loads on retail (Midnight, `120100`/`120105`, and the `120107` test realm), which is useful for testing alongside `/fqt preview`. It relies on Blizzard's quest window and quest log art, so it may need updates if that changes.

## Licence

GPL-3.0-or-later. See [LICENSE](LICENSE). The vanilla quest list is derived from Questie's data, which is GPL-3.0 licensed.
