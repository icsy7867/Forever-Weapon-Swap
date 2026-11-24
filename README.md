# Forever Weapon Swap 1.7.0

Two compact main-hand/off-hand sets for World of Warcraft: Forever (Interface 16001). No dependencies. Existing 1.0 main-hand choices and position settings are retained.

## Install or update

Exit the game, replace the `ForeverWeaponSwap` folder in `World of Warcraft/_forever_/Interface/AddOns/`, and start the game. The final TOC path must be `AddOns/ForeverWeaponSwap/ForeverWeaponSwap.toc`.

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

## Fishing

- Drag a fishing pole onto the **Fishing** slot beside the weapon sets, or right-click the slot to save the pole you have equipped. Left-click equips the saved pole. Shift-right-click clears it.
- Hover the pole or chevron to open the lure drawer below Fishing. The icons show stack counts and are sorted strongest first. Hover an icon for its tooltip. Click a lure to apply it when the saved pole is equipped. While the pole is unequipped, the icons are dimmed and cannot apply a lure.
- The menu supports Aquadynamic Fish Attractor, Bright Baubles, Flesh Eating Worm, Nightcrawlers, Aquadynamic Fish Lens, and Shiny Bauble.
- The pole and arrow hide when combat starts by default. Hiding the controls leaves your equipped gear in place. Use the cycle key or a direct set key to switch back. In combat the cycle key uses weapon sets only and does nothing if neither is configured.

## Settings

Open **Options → AddOns → Forever Weapon Swap**, or type `/fws settings`. **Size** ranges from 60% to 200%, **Opacity** ranges from 20% to 100%, and **Hide fishing controls in combat** defaults to on. You can leave the fishing controls visible in combat by unchecking the box. **Include fishing pole in weapon cycle** also defaults to on. Uncheck it to keep the pole out of the cycle. Pole setup and lure application are available outside combat.

## Keybind and slash commands

Bind **Cycle Weapon Sets** under **Options → Keybindings → Forever Weapon Swap**. Outside combat the default order is Set 1 → Set 2 → Fishing Pole. The cycle skips empty sets and skips a pole that is unavailable or excluded in Settings. With one weapon set and a saved pole, it alternates between the two outside combat. Use **Equip Weapon Set 1** and **Equip Weapon Set 2** to select or retry a specific set. All three start unassigned on a fresh install. The update keeps the same binding IDs, so keys assigned to the working actions carry over. Restart WoW after updating so it reloads `Bindings.xml`.

| Command | Action |
| --- | --- |
| `/fws equip 1` or `/fws 1` | Equip set 1 outside combat |
| `/fws equip 2` or `/fws 2` | Equip set 2 outside combat |
| `/fws toggle` | Equip the next configured option outside combat |
| `/fws settings` | Open the addon settings |
| `/fws save 1` or `/fws save 2` | Capture the equipped main-hand and optional off-hand |
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

Items are stored by item ID. Differently enchanted copies of the same ID cannot be distinguished, and the same ID cannot occupy both hands in one saved set. The addon does not manage ranged weapons, armor, or a deliberately empty off-hand.

## Verification

Automated checks passed in a mock WoW API/frame environment using Lua 5.4. Checks cover the original behavior plus paired sets, shields, held off-hands, dual-wield configurations, partial-set highlighting, optional off-hand behavior, two-handed transitions, command parsing, slash combat guards, native macro export, missing items, and secure toggle target selection.

Run `python3 tests/run.py` from the extracted addon on Linux with `liblua5.4.so.0` installed. The mock suite covers the lure drawer, item placement, delayed off-hand swaps, and recovery when a load or drag overlaps combat. Version 1.7.0 still needs a live WoW check for rendering, input gestures, and combat restrictions. `/console scriptErrors 1` enables Lua error popups.

## Development references reviewed

- [Forever addon kit: measured client differences and secure snippet findings](https://github.com/Thunderz96/forever-addon-kit)
- [Forever API reference generated from client APIDocumentation](https://atraeau.github.io/WoW-Addons/)
- [Forever client API index and exported Blizzard interface code](https://github.com/reckhou/WoWBlzCode)
- [Blizzard secure action implementation, Forever branch](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua)
- [Blizzard secure handlers, Forever branch](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua)
- [Restricted secure environment, Forever branch](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/RestrictedEnvironment.lua)
- [WeaponSetsForever: existing Forever equipment addon example](https://github.com/jbedworth/WeaponSetsForever)

Implementation is original; references were used to verify API patterns and restrictions.
