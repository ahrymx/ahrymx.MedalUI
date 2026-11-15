# Medalluin

> **A bespoke, artful HUD, unit frame and console suite for World of Warcraft.**

Medalluin turns the game's interface into one ornamental console in an ink-and-gold style. It wraps Blizzard's secure templates instead of replacing them, so combat security, macros, drag-and-drop and key bindings all work as they do in the default UI.

Runs on **WoW Forever** (`16001`) and **Retail** (`120105`).

> [!NOTE]
> **Medalluin is developed with the assistance of AI.** Design, art tooling and code are co-authored with AI under human direction and in-game testing, then linted and harness-tested for taint and combat safety.

---

## The console

The console sits at the bottom: player and target on its wings, action bars in between. The overhead row at the top holds the boss, pet, focus and target-of-target frames.

![The Reticule console with its minimap bay](showcase/central-console.png)

- **Two profiles:** the slim **Reticule** (default), or the round **Arena** below.
- **Reticule:** the minimap sits in the console's bay, with a 2×5 form, stance and skyriding grid (Action Bar 7) and a party row under the console.
- **Action bars:** one to three rows, with Blizzard's button art or **bare icons**. Empty buttons hide and reappear while you drag a spell, item or macro.
- **Class power and cast bars** built into the console: combo points, holy power, runes, soul shards and the rest.
- **Party, raid, boss and arena** frames: on the console's own row, or as draggable widgets. Offline and dead members get a look of their own: a plug icon, or wings and a timer.

### Arena

The medallion console: the party on wings around a large player and target, with the minimap in its ring.

![The Arena console with its action bars, and the overhead's boss, pet, focus and target-of-target frames above](showcase/console-overhead.png)

---

## The corner strips

The bottom corners carry a strip each. The left one holds your portrait medallion and the micro menu under the chat box. The queue eye takes the portrait's place while you are queued, and a vehicle exit takes the backpack's on the right.

![The chat box with its tabs, above the left strip's portrait and micro menu](showcase/chat.png)

### Side panel

The right strip opens a panel with tabs. **Zone** lends it the minimap beside the current zone's quests; **Loot** lists the group's drops and who won each roll.

| Zone | Loot |
|:---:|:---:|
| ![The side panel's Zone tab: the minimap beside the zone's quests, with zoom, tracking and world map buttons](showcase/side-panel-zone.png) | ![The side panel's Loot tab: the group's loot with who won each roll](showcase/side-panel-loot.png) |

- **Meter** shows the game's own damage meter, on clients that have one; **Auras** lists your buffs and debuffs, live in combat.
- In the Zone tab, click a quest for its objectives, or shift-click it to track it.
- Addons' minimap buttons gather in a **drawer** at the end of the action bar, instead of crowding the minimap.

---

## Quests

| Quest tracker & chat | Quest log |
|:---:|:---:|
| ![The quest tracker's full view above the chat box, with a quest's tooltip](showcase/quest-tracker.png) | ![The quest log on the right strip, quests by zone with their XP, item and coin rewards](showcase/quest-log.png) |

A quest's own page spells out where it sits in its chain, step by step, with its giver, objectives and rewards.

![A quest's page: its level, zone, giver, step in its chain and status, the chain spelt out, then its objectives, description and rewards](showcase/quest-page.png)

---

## Character, bags and spells

| Character | Bags |
|:---:|:---:|
| ![The character window: the model, gear slots with item levels, and stats](showcase/character.png) | ![The bags window in groups, with locked items and the free slots](showcase/bags.png) |

| Spellbook | Macros |
|:---:|:---:|
| ![The spellbook: spells by school, with ranks, costs and click-cast bindings](showcase/spellbook.png) | ![The macros page, with a macro's editor](showcase/macros.png) |

- **Bags** (inspired by Baganator) put the backpack, bags and reagent bag in one window. Items are grouped (New, Equipment, Consumables, Quest items, Trade goods, Junk), and the equipped bags open in a drawer above.
- **Alt+click** an item to lock it: it shows a padlock and can't be sold or destroyed.

### Talents and plans

A **plan** lays out a build by level. Each talent shows its levels, goal and progress, and the next checkpoint is lit.

| Talents | Talent plans |
|:---:|:---:|
| ![The talents window: a tree with the points available and the next talent in your plan](showcase/talents.png) | ![A talent plan: each talent's levels, goal and progress, the next checkpoint lit](showcase/talent-plans.png) |

---

## Game menu

Esc opens a game menu that also shows your character, Medalluin's shortcuts, and your friends and guild on two tabs of a Social window. A clock at the top of the screen shows the time, with your gold, session length and latency under it. Left alone, the panel folds into a thin rail at the edge while the camera turns slowly around your character. The cog opens the menu's options.

![The game menu: the character, menu buttons, friends, guild and this session](showcase/game-menu.png)

---

## Settings

Every part of Medalluin can be switched off on the **Modules** page; turn off what you'd rather keep from another addon or the default UI.

![The Medalluin settings window on its Modules page: each part switched on or off](showcase/settings-modules.png)

- **Profiles:** settings, action bar skills and key bindings are kept per profile and restored when you switch.
- **Unit frame editor** (`/mui edit`): every piece's size, font, text and place, on a live canvas.
- **Movers** in Edit Mode for the consoles, widgets and cooldown viewers.
- **Cooldowns:** the game's Cooldown Manager viewers, each with its own layout (a bar or an arch), shape, text and visibility, and its tracked bars in the same ink and gold, plus a simulation to preview them.
- **Key binding mode** (`/mui kb`): hover a button and press a key.

---

## Companion addons

Companions appear under the **Medalluin** category in the AddOn List, each with its own documentation and license.

| Addon | What it adds | Docs & license |
|:---|:---|:---|
| **[`mdlui_Tooltips`](WoW/Interface/AddOns/mdlui_Tooltips/README.md)** | An ornamented reskin of every tooltip: items, spells, units, auras, quests, mail and world objects. Forever and Retail. Based on [PrettyTooltip](https://github.com/FallenShard/PrettyTooltip) by FallenShard. | [README](WoW/Interface/AddOns/mdlui_Tooltips/README.md) · [MIT](WoW/Interface/AddOns/mdlui_Tooltips/LICENSE) |

## Recommended addons

These addons are by other authors and pair well with Medalluin. They are not part of it: install each one separately from CurseForge.

| Addon | What it adds | Clients |
|:---|:---|:---|
| **[PlateSCT](https://www.curseforge.com/wow/addons/platesct)** | Scrolling damage and healing numbers above enemy nameplates or in movable screen areas. | Forever · Retail |
| **[Shadowflare](https://www.curseforge.com/wow/addons/shadowflare)** | On-screen alerts for spell procs: when your next spell is instant, faster, free or usable. | Forever |
| **[MF Nameplates](https://www.curseforge.com/wow/addons/mf-nameplates)** | Customizable nameplates with a live visual designer. | Forever · Retail |
| **[LootOptimizer Forever](https://www.curseforge.com/wow/addons/lootoptimizer-forever)** | Frees bag space for new loot when your bags are full, and compares gear upgrades for you and your alts. | Forever |
| **[Keep or Toss: Forever](https://www.curseforge.com/wow/addons/keep-or-toss-forever)** | A tooltip section saying whether an item is useful to your character, and why. | Forever |

---

## Slash commands

| Command | What it does |
|:---|:---|
| `/mui`, `/mdlui` or `/medalluin` | Opens the settings window |
| `/mui bar` | Opens settings at the action bars |
| `/mui party` · `raid` · `boss` | Opens settings at that unit frame page |
| `/mui kb` | Key binding mode: hover a button and press a key |
| `/mui edit` | Opens the unit frame editor |
| `/mui taint` | Runs taint diagnostics |
| `/mui fix-issues` | Checks for problems an older version left behind that updating does not undo, and offers to fix them |

---

## Credits and inspiration

- **[W2UI](https://wowinterface.com/downloads/info27203-W2UI.html)** by aesketch: a design reference for the character window, the corner medallions and the utility bars. Used as a reference only; no code or art is taken from it.
- **[Baganator](https://www.curseforge.com/wow/addons/baganator)**: inspiration for the bags window.
- **[PrettyTooltip](https://github.com/FallenShard/PrettyTooltip)** by FallenShard: the base of `mdlui_Tooltips` (MIT).
- **Marcellus SC** by Brian J. Bonislawsky (Astigmatic): the interface font (SIL OFL 1.1).

## Work in progress and contributions

> [!IMPORTANT]
> **Medalluin is a work in progress.** Features, textures and options keep changing.

- **Issues:** bug reports, compatibility problems and suggestions are welcome on GitHub.
- **Pull requests:** welcome. Please make sure your change passes `luacheck` and the test harness first. By opening one, you agree to the contribution terms in section 4 of the [LICENSE](LICENSE).

---

## License

Medalluin is **All Rights Reserved** © 2026 AhryMX. You may install it, play with it, read its code, and change your own copy for personal use. Screenshots, videos, and streams are welcome. You may not reupload, redistribute, fork, retexture, or rebrand it, in whole or in part, without written permission. The only official copies are on [GitHub](https://github.com/ahrymx/ahrymx.medalluin) and [CurseForge](https://www.curseforge.com/wow/addons/medalluin/). See [LICENSE](LICENSE) for the full terms.

The optional `mdlui_Tooltips` companion addon is based on [PrettyTooltip](https://github.com/FallenShard/PrettyTooltip) © 2026 FallenShard and is included under the [MIT License](WoW/Interface/AddOns/mdlui_Tooltips/LICENSE). The Marcellus SC font is © Brian J. Bonislawsky (Astigmatic) and is included under the [SIL Open Font License 1.1](WoW/Interface/AddOns/Medalluin/media/fonts/OFL.txt). World of Warcraft is a trademark of Blizzard Entertainment, Inc.; Medalluin is not affiliated with or endorsed by Blizzard.
