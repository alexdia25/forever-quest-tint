# Handover: Forever Quest Tint 0.7.0

State of the work at the end of the last session, for whoever picks it up next. Not shipped (see `.pkgmeta`).

## Where things are

- **Branch:** `immersion-ellesmereui-support`, PR #3 into `main` (open, not merged). All work below is on it.
- **Owner's rules:** no AI/assistant references anywhere in the repo (commit messages, authorship, PR text). Commits are authored as Alex Diakovsky <alexdiakovsky@gmail.com>. Push to the branch; don't merge.
- **Release:** Forever only (`ForeverQuestTint.toc`, interface `16001`). Forever launches 4 November 2026.
- **Dev TOCs** (excluded from packages): `ForeverQuestTint_Mainline.toc` (Midnight `120100`, `120105`, `120107`) and `ForeverQuestTint_TBC.toc` (TBC Anniversary `20506`). Keep everything below the interface line identical in all three TOCs.

## What 0.7.0 adds (all on the branch)

| Feature | Where in `ForeverQuestTint.lua` | Status |
| --- | --- | --- |
| Dialogue UI (from 0.5.5) | "Dialogue UI (addon)" section | Confirmed in game |
| Immersion: glow on the Quest Objectives panel (`TalkBox.Elements`) | `IMM` table, `RefreshImmersion` | Confirmed |
| Storyline: glow in the speech bubble (`Storyline_NPCFrameChat`) | `SL` table, `RefreshStoryline` | Confirmed |
| Lorewalker (Classic mode): chamfered glow on the page, edge fade recoloured | `LW` table, `RefreshLorewalker` | Confirmed (light and dark) |
| ClassicUI Forever: quest log tinted copy of its art, map parchment, markers in its log and watch | `CUIF_*`, `ApplyCUIFCopies`, `HookCUIF` | Confirmed |
| EllesmereUI: flat glow when its skin hides the parchment | `IsSkinned`, `SkinRegion` near the top | Confirmed (quest window and log) |
| Questie: gradient over its map/minimap ! and ?, marker in its tracker | `ApplyQuestieTint`, `HookQuestie`, `HookQuestieTracker` | Confirmed on TBC Anniversary |
| Game's own map ! and ? (quest offer and turn-in pins) | `MapPins` table | **Not yet seen in game.** Test on Midnight with Questie off |
| Tracker logo (option, off by default) | `UpdateTrackerLogo` | Not explicitly confirmed |
| Preview `/fqt preview on|off|auto`, `/fqt status`, scrolling options | slash handler, `Options.lua` | Working |

Screenshots for the README gallery are in `screenshots/`. Still missing: Questie map icons and the game's own map icons.

## How the glows work (reuse these, don't reinvent)

- **Parchment that can be copied** (Blizzard's quest window and log, ClassicUI Forever): a desaturated copy of the art, tinted, fading from the bottom (`ApplyOverlay`, `ApplyCUIFCopies`).
- **Dark or sliced panels** (Immersion, Storyline, Lorewalker, EllesmereUI, dark themes): `ApplyFlat(key, parent, region, scale, strength, corner, drawLayer, vivid, art)`. With `corner`, it draws six pieces from `Media/GlowCorner.tga` (rounded) or `Media/GlowChamfer.tga` (45° cut), rendered by `logo/make_glow_corner.py`. Backdrop edges sit on `BORDER`, so glows over backdrops use `drawLayer = "BORDER"`. `vivid` uses `VividTint`.
- **Icons** (Questie, map pins): `ApplyIconGradient`. Two slices of a desaturated copy over the original: solid over the bottom 45%, fading out by 75% (`QUESTIE_SOLID`, `QUESTIE_FADE`). The original icon is never modified.
- **Markers in text lists:** `ApplyMarker`. Use `keep` for lists that rewrite their text, and the flat-list scan (`flatRoots`) for non-Blizzard trackers.

Sizes and insets were tuned against the owner's screenshots by measuring pixels. Ask for a screenshot (sent as its own message, so it is saved as a file) and measure rather than guess.

## Testing

- `lua5.1 tests/harness.lua .` from the repo root: 128 checks against stubbed frames, mirroring each addon's real structure (read from its source). Install Lua 5.1 and luacheck if missing. Lint with `luacheck --std lua51 --no-global --no-max-line-length -q *.lua` (3 old warnings are expected).
- The stubs return a no-op function for any unknown capitalised field. When a test fails with "attempt to index … (a function value)", it is usually the stub, not the addon.
- The harness checks behaviour, not looks. Visual changes need an in-game screenshot.
- `ForeverQuestTint.lua` is near Lua's limit of 200 top-level locals (180 now). Group new constants into tables (as `IMM`, `SL`, `LW`, `MapPins`).

## Source references

Clone into a scratch folder when needed:

- Blizzard UI: `https://github.com/Gethe/wow-ui-source`, branches `live`, `forever`, `classic_anniversary`. Fetch one with `git fetch --depth 1 --filter=blob:none origin refs/heads/forever:refs/remotes/origin/forever`.
- Questie: `https://github.com/Questie/Questie`, with `Questie_Camelot.toc` for Forever and `FOREVER_WORK_LEFT_TO_DO.md`.
- Immersion: `https://github.com/seblindfors/Immersion`
- Storyline: `https://github.com/Total-RP/Storyline`
- Lorewalker: `https://github.com/Adaptvx/Lorewalker`
- ClassicUI Forever: `https://github.com/wowaddonmaker/classicuiforever` (public API `ClassicUIForeverAPI`)
- EllesmereUI: only an old mirror (7.2.2) is reachable; its quest-window skin is newer, hence the defensive `IsSkinned`.

CurseForge and guide sites are blocked from the cloud environment unless the owner allows them.

## Open items

1. Confirm the game's own map ! and ? tint on Midnight (Questie off), then on Forever after launch.
2. On Forever launch day: check the interface number is still `16001`, and that the addon loads with the dev TOCs present.
3. Not covered yet: ClassicUI Forever's combined map pages, the logo in its quest log, objective colours in its watch and in Questie's tracker, and the tracker logo in Questie's tracker.
4. Before release: update the PR description (it predates the last round of visual fixes), merge, tag 0.7.0, and package with `.pkgmeta` (or remove the dev TOCs, `tests/` and this file by hand).
5. Dialogue UI on Forever may no longer need the TOC edit described in older notes. Check before mentioning it.
