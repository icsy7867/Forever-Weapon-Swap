# Forever Weapon Swap 1.9.0

Two compact main-hand/off-hand sets for World of Warcraft: Forever (Interface 16001). No dependencies. Existing 1.0 main-hand choices and position settings are retained.

## Install or update

Exit the game, replace the `ForeverWeaponSwap` folder in `World of Warcraft/_forever_/Interface/AddOns/`, and start the game. The final TOC path must be `AddOns/ForeverWeaponSwap/ForeverWeaponSwap.toc`.

## Bind the weapon swap key

1. In WoW, open **Options → Keybindings → Forever Weapon Swap**.
2. Assign a key to **Cycle Weapon Sets**. Press it to swap between your saved sets.

Outside combat, the default order is **Set 1 → Set 2 → Fishing Pole**. The key skips empty or incomplete sets, sets whose managed slots already match, and any pole that's missing or excluded in Settings. In combat, it cycles only through weapon sets.

You can also bind **Equip Weapon Set 1** and **Equip Weapon Set 2** to select a set directly. All three bindings start unassigned on a fresh install. Existing bindings carry over when you update. Fully restart WoW after updating so it reloads the bindings.

## Setup and UI

The bar has two columns for **set 1** and **set 2**. Each column has a main-hand icon. A smaller **OH** icon appears below it when the set has an off-hand or when you're holding a compatible item to drop there outside combat.

- Drop a main-hand weapon onto the top icon. Then pick up an off-hand weapon, shield, or held off-hand item to reveal its **OH** drop target. If you put the item back, any unfilled targets disappear.
- Right-click a visible icon to save the item currently equipped in that hand. Use `/fws save 1` or `/fws save 2` to capture an equipped pair when its off-hand icon is hidden.
- Alternatively, equip the pair normally and type `/fws save 1` or `/fws save 2` to capture it. Saving checks both hands first. If an item is moving or the pair is unsupported, your previous set is preserved.
- Left-click either icon in a column to equip the entire set.
- Yellow borders indicate the matching equipped set, including its saved off-hand. A partial match is not marked as equipped. If two sets share a main-hand, an explicit off-hand match takes precedence over a main-hand-only match.
- A clock sweep on each populated weapon-set icon shows the player's shared global cooldown (GCD) when the client provides it. Empty slots stay clear.
- Shift-right-click an off-hand icon to remove that saved off-hand; shift-right-click a main-hand icon to clear the entire set.
- Drag the **WEAPONS** header to move the bar. Missing items appear gray.

An **unconfigured off-hand is ignored**: it leaves the existing off-hand alone. A two-handed main-hand lets WoW remove an incompatible equipped off-hand normally. Replacing a saved main-hand with a two-hander removes that set's saved off-hand. An empty off-hand is not an instruction to unequip slot 17.

Weapon sets, the saved pole, position, visibility, size, opacity, and lock state save per character. The weapon panel is 92 × 60 at default scale and grows to 92 × 91 when it shows the off-hand row.

## Weapon enhancements

- Outside combat, hover a saved weapon to see compatible enhancements from your bags. The main-hand drawer opens above its icon and the off-hand drawer opens below. Hover an enhancement for its in-game tooltip. Press its icon to equip the saved weapon. Release on the same icon to apply the enhancement to that hand.
- The drawer supports 42 consumables, including standard and special sharpening stones, weightstones, wizard and mana oils, Frost and Shadow Oil, and rogue poison ranks. Standard stones filter by weapon subclass. Poisons appear for rogues. WoW checks any additional requirements when you apply an item.
- Right-click an enhancement to star it for that hand. Your main-hand and off-hand favorites are saved separately per character. An available favorite appears first and carries a star. Right-click it again to remove the star.
- When the saved weapon is equipped, its drawer shows the active temporary enhancement and imbue by icon, time remaining, and available charges. The lure drawer shows the same information for the equipped pole.
- A quick click works when the swap finishes before release. For a slower swap, hold until the drawer says **Release to apply**. If you release early, click the same consumable again once the drawer says **Click to apply**. WoW handles any confirmation to replace an existing enhancement.
- An off-hand enhancement normally swaps just the off-hand. If the main hand is empty, holds a two-hander such as a fishing pole, or holds the weapon you want in your off-hand, the addon requests the saved pair first. Missing items and locked hands dim the consumables. Shields, held off-hand items, and empty slots have no drawer. Permanent enchants and ranged scopes are outside this feature.

## Fishing

- Drag a fishing pole onto the **Fishing** slot beside the weapon sets, or right-click the slot to save the pole you have equipped. Left-click equips the saved pole. Shift-right-click clears it.
- Hover the pole or chevron to open the lure drawer below Fishing. The icons show stack counts and are sorted strongest first. Hover an icon for its tooltip. Press a lure to equip the saved pole, then release over that lure to apply it. If the pole is already equipped, click normally. If the swap is slow, hold for **Release to apply** or click again after the pole is ready.
- The menu supports Aquadynamic Fish Attractor, Bright Baubles, Flesh Eating Worm, Nightcrawlers, Aquadynamic Fish Lens, Shiny Bauble, and “Secret” Bait.
- The pole and arrow hide when combat starts by default. Hiding the controls leaves your equipped gear in place. Use the cycle key or a direct set key to switch back. In combat the cycle key uses weapon sets only and does nothing if neither is configured.

## Settings

Open **Options → AddOns → Forever Weapon Swap**, or type `/fws settings`. **Size** ranges from 60% to 200%, and **Opacity** ranges from 20% to 100%.

- Under **Keybindings**, click a **Cycle Weapon Sets** binding slot and press the desired key. This edits the same action as the main Keybindings screen. **Lock bar position** locks the WEAPONS drag handle.
- **Show equipment tooltips** defaults to off and covers main-hand weapons, off-hands, and the fishing pole. Empty slots still give brief setup instructions.
- **Show consumable tooltips** defaults to on and covers both weapon enhancements and fishing lures. Both drawers open on hover with either tooltip setting.
- **Disable fishing** defaults to off. Check it to show just the two weapon sets and disable the fishing pole slot, lure drawer, and pole selection through the keybind or `/fws toggle`. The two dependent fishing options gray out while fishing is disabled. Your saved pole and preferences return when you uncheck it. If changed during combat, the layout updates when combat ends. Use a weapon set to swap away from an already equipped pole.
- **Skip pole when cycling** defaults to off. Check it to skip the pole in the cycle and equip the pole by clicking it directly. The checkbox reflects each character's saved cycle preference from earlier versions.
- **Hide fishing in combat** defaults to on. Uncheck it to keep the controls visible during combat. Pole setup and lure application are available outside combat.

## Slash commands

| Command | Action |
| --- | --- |
| `/fws equip 1` or `/fws 1` | Equip set 1 outside combat |
| `/fws equip 2` or `/fws 2` | Equip set 2 outside combat |
| `/fws toggle` | Equip the next configured option outside combat |
| `/fws settings` | Open the addon settings |
| `/fws save 1` or `/fws save 2` | Capture the equipped main-hand and optional off-hand |
| `/fws exact 1` or `/fws exact 2` | Save equipped variants by item link (experimental) |
| `/fws macro 1` or `/fws macro 2` | Open copyable native macro text for that set |
| `/fws lock` / `/fws unlock` | Lock/unlock the position |
| `/fws scale 1.25` | Resize the bar; range 0.6–2 |
| `/fws show` / `/fws hide` | Show/hide the bar; toggle binding remains available |
| `/fws reset` | Restore default position, scale, visibility, and unlocked state; retain sets |
| `/fws` | Show help |

`/weaponswap` is an alias for `/fws`.

## Macros

Outside combat, a macro can contain:

```text
/fws equip 1
```

or:

```text
/fws toggle
```

**Custom slash equip commands are deliberately blocked in combat.** They run addon Lua, not a secure combat action. Calling the secure buttons through `/run` or chaining a macro through `/click` is not provided as a workaround.

For a combat-capable set macro, run `/fws macro 1` (or `2`) outside combat. Press Ctrl+C in the window and paste the text into a normal WoW macro. Example output, with illustrative IDs:

```text
#showtooltip item:12345
/equipslot 16 item:12345
/equipslot 17 item:67890
```

This uses native equip commands directly. Add other native macro commands as desired; normal game restrictions still apply. Regenerate and paste the macro again after changing the set: exported macros are static snapshots. The export is for a specific set, not an arbitrary two-set toggle; use the addon toggle binding for that.

## Combat and equipment restrictions

The UI and toggle binding use secure action buttons with native `/equipslot` commands. Configuration, movement, saving, and macro export are outside-combat operations. The addon does not cancel forms or bypass item locks, casting restrictions, weapon-swap cooldowns, class/proficiency restrictions, or bag-space requirements.

During combat the toggle alternates **requested sets**. If a swap fails or another interface changes your weapons, the sequence can diverge from your actual equipment. Yellow highlighting still follows actual equipment. Click a specific set to request it directly, or leave combat to resynchronize. A secure button swap may need another direct click if WoW delays or rejects one of the item moves. The slash commands wait for the expected main hand and unlocked slots before requesting the off-hand.

Slash equipping checks both saved items are carried before making a request. Game restrictions can still cause a partial equip, so it does not claim success before equipment events confirm the pair.

Normal saves use item IDs. For two copies of the same base weapon with different permanent enchants or random suffixes, equip the pair and use **`/fws exact 1`** or **`/fws exact 2`**. This experimental mode uses the equipped item payloads for direct buttons, keybinds, slash equips and macro export. Bag availability, highlights, and the consumable release check compare the saved variants. Re-save after changing a permanent enchant. Identical variants, including copies differing only in temporary poison, cannot be distinguished reliably and are rejected as a pair. Normal drag-and-drop and right-click assignments still save by ID. The addon does not manage ranged weapons, armor, or a deliberately empty off-hand.

## Verification

Automated checks passed in a mock WoW API/frame environment using Lua 5.4. Checks cover the original behavior plus paired sets, shields, held off-hands, dual-wield configurations, partial-set highlighting, optional off-hand behavior, two-handed transitions, command parsing, slash combat guards, native macro export, missing items, and secure toggle target selection.

Run `python3 tests/run.py` from the extracted addon on Linux with `liblua5.4.so.0` installed. The mock suite covers the lure drawer, item placement, delayed off-hand swaps, and recovery when a load or drag overlaps combat. The mock suite also exercises consumable presses and releases with immediate, delayed, and interrupted swaps. The dev suite also covers missing or overlapping cycle choices, rejected off-hand equips, favorites, both enchant types, saved-data recovery, restricted values and same-ID variant targeting. Live verification is still needed for native item-link resolution, enchant replacement prompts and secure press/release timing. For exact sets, swap two differently enchanted copies away and back via both the cycle key and a direct button, then apply a different poison to each hand. On a weapon with an on-use effect, try a consumable the game rejects and confirm the weapon's own cooldown stays ready. `/console scriptErrors 1` enables Lua error popups.

## Consumable data

The item list is in `Consumables.lua`. Each entry uses the bag item ID. Ordinary sharpening stones and weightstones share rules based on the target weapon subclass. Special stones have their own entries. Sources for item coverage and compatibility:

- [Method's WoW Forever weapon enhancements](https://www.method.gg/wow-forever/list-of-all-consumables-and-enchants-in-wow-forever#weapon-enhancements)
- [Legacy of Warcraft's Forever item database](https://legacyofwarcraft.com/db/forever/item/8928.html)
- [ForeverDB's rogue poison ranks](https://foreverdb.net/class/Rogue/poisons)
- [LibItemDB's explanation of stone subclass masks](https://www.curseforge.com/wow/addons/libitemdb/files/9208017/additional-files)

## Development references reviewed

- [Forever addon kit: measured client differences and secure snippet findings](https://github.com/Thunderz96/forever-addon-kit)
- [Forever API reference generated from client APIDocumentation](https://atraeau.github.io/WoW-Addons/)
- [Forever client API index and exported Blizzard interface code](https://github.com/reckhou/WoWBlzCode)
- [Blizzard secure action implementation, Forever branch](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua)
- [Blizzard secure handlers, Forever branch](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua)
- [Restricted secure environment, Forever branch](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/RestrictedEnvironment.lua)
- [WeaponSetsForever: existing Forever equipment addon example](https://github.com/jbedworth/WeaponSetsForever)

Implementation is original; references were used to verify API patterns and restrictions.

## Optional third set and consumable warnings

Enable **Enable third set** in settings to add Set 3 to the bar, cycle, direct bindings and slash commands. Disabling it preserves its gear. Two sets are enabled by default.

The optional translucent consumable dial displays the soonest-expiring active effect on each matching equipped hand or pole. Green changes to orange at 30% and red at 15%. Both thresholds are adjustable. Forever supplies remaining time, so percentages use the longest duration observed for that enchant on this character. A first observation halfway through an effect can overestimate the percentage until a fresh application is observed. The independent low-charge warning gently pulses the active consumable icon in the weapon drawer at five or fewer positive charges reported by the client.

## Changelog

- **1.9.0** — Added an optional third weapon set, configurable consumable countdown dials and a low-charge drawer warning.


- **1.9.0** — Documented the contributor update workflow and CurseForge changelog format.

- **1.9.0** — Edit the cycle binding directly in addon settings. Visual Settings and Fishing now group related options, with consistent fishing label sizes.

- **1.9.0** — Added a [developer glossary](GLOSSARY.md) covering addon terminology, Forever APIs, and the repository map.

- **1.9.0** — Out-of-combat cycling skips missing and already-matching sets. Paired slash swaps confirm the off-hand and report which part timed out.
- **1.9.0** — Added per-hand enhancement favorites, active enhancement and lure timers and charges, and conditional native item targeting. Drawer lock updates reuse the visible list and counts.
- **1.9.0** — Added experimental equipped-variant capture (`/fws exact 1|2`), per-entry saved-data recovery, current key and lock in Settings, shorter fishing options, and setup hints for empty slots.

- **1.8.3** — Added an opt-in **Disable fishing** setting that removes the fishing panel and lure drawer and limits the addon’s swap cycle to the two weapon sets.
- **1.8.2** — Added separate tooltip settings for equipment and consumables. Equipment tooltips default to off, and consumable tooltips default to on. Added an **Exclude fishing pole from weapon cycle** checkbox that preserves the previous preference. Made both consumable drawers fit their icons and status messages. Moved the swap keybinding instructions to the top of the README.
- **1.8.1** — Added click-to-equip and apply for fishing lures and weapon enhancements. Press to equip the saved item and release on the same icon once it is ready to apply.
- **1.8.0** — Added per-hand drawers for 42 temporary weapon enhancements, including sharpening stones, weightstones, oils, and rogue poisons. Filtered consumables by weapon type and class, and added support for “Secret” Bait to the fishing drawer.
- **1.7.0** — Centered the hoverable lure drawer and added compact item icons with stack counts. Fixed action setup after combat login, interrupted drags, and drops onto occupied slots. Improved delayed off-hand swaps, cooldown updates, and item-link loading. Packaged the mock tests.
- **1.6.0** — Included the fishing pole in the default cycle outside combat, with an option to exclude it. Skipped empty or unavailable choices and kept combat cycling limited to weapon sets.
- **1.5.0** — Added a dedicated fishing pole slot and a drawer with six supported lures. Added settings for scale, opacity, and fishing visibility during combat. Updated cycling to skip empty sets.
- **1.4.0** — Hid empty off-hand slots until a compatible item is dragged. Fixed the keybinding labels and category.
- **1.3.0** — Added a global cooldown sweep on weapon icons and expanded the README and contributor guidance.
- **1.2.0** — Added direct keybinds for each set, safer equipment saves, clearer missing-item messages, and fewer bag scans.
- **1.1.0** — Added an optional off-hand for each set, including shields and held items. Added slash commands to equip, cycle, save, and export set macros.
- **1.0** — Introduced two saved main-hand choices on a movable bar, with click-to-equip, a toggle keybind, a yellow equipped-item highlight, and per-character settings.
