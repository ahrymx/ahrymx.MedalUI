# mdlui_RadialMenu

> **Radial menus for [Medalluin](../../../../README.md), for WoW Forever (`16001`).**
>
> Based on the radial menu of [FlareUI](https://github.com/malkkav/FlareUI) by **Malkkav**, distributed under the [MIT License](LICENSE).

Hold a key, sweep the mouse towards a button, and let go: the button you aimed at is used, in combat too. A radial holds up to twelve buttons: spells (at the best rank you know), items, mounts, macros, target and world markers, game panels, emotes, quest items, a spell cast on a party member, or another radial, opened on the mouse wheel.

## Using it

- **First run.** A **Markers** radial is made for you.
- **`/mdlradial`** opens the editor window, as does its key binding (Key Bindings > AddOns). In the **Radials** tab:
  - the radials are listed on the right. Right-click one to group it, and drag to reorder. Under the list, **On This Character** shows every key that opens a radial here, and the live preview sits at the bottom;
  - in the middle you set who gets the selected radial, its key (click it, then press the key; right-click clears it) and whether this character has its own key. **Macro** puts a macro that opens the radial on your cursor;
  - click or drag from the **Catalog** to add buttons, or drop spells, items, mounts and macros from the game's windows. Drag to reorder, and right-click to remove. **Undo Changes** puts back everything since the window opened.
- **Options tab** (`/mdlradial options`): where a radial opens, hold or toggle, what a sub-radial remembers, the size, button names, following spell ranks, and the two fonts. With FlareUI enabled, **Import** copies its radials, groups and each character's keys here; FlareUI's settings are only read.
- **`/mdlradial list`** prints your radials with their keys and macro lines. **`/mdlradial key <number or name> <key>`** binds one, for example `/mdlradial key 1 SHIFT-Q`; `none` clears it.
- **Click mode.** A macro line such as `/click MdlRadial markers` opens a radial that stays up until you click a button.
- **Controller.** A radial imported from FlareUI with a stick press keeps it (there are no controller controls here until 2.0): it opens on a stick press (L3 or R3, with the triggers held or not). The right stick aims, letting go of the stick uses the button, and B closes it.
- **`/mdlradial padlog`** prints the controller's aim, for bug reports.

## What changed from upstream

- Stands alone: no FlareUI and no Ace libraries. Categorized under **Medalluin** in the AddOn list, and uses Medalluin's font when Medalluin is installed.
- Its own names: `/click MdlRadial <radial>` in place of `/click FUIRadial <radial>`.
- FlareUI's own micro-menu entries (its settings and its threat meter) are gone.
- If FlareUI's radial menu is on too, a chat line says so once: both would bind keys.
- The wheel keeps FlareUI's layout in Medalluin's gold and ink: its own rims, backdrop, centre ring, pointer and cancel X.
- The editor is a window of its own in Medalluin's look. Its controller rows (stick press, gamepad bar slot) and the controller options are left out until universal controller support (2.0).

## Not there yet

A page in Medalluin's options comes in a later version.
