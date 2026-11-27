# Forever Weapon Swap glossary

Forever Weapon Swap saves two weapon sets and an optional fishing pole per character. A player can click a set or bind one key to cycle. Hovering a saved weapon or pole opens a drawer of compatible consumables from the player's bags.

## Start here

| Question | Where to look |
| --- | --- |
| How does a player set up, use, or clear a slot? | [README.md](README.md), including settings, slash commands and changelog |
| What conventions and live checks apply to changes? | [AGENTS.md](AGENTS.md) |
| How does the client load the addon? | [ForeverWeaponSwap.toc](ForeverWeaponSwap.toc) declares interface 16001, saved variables and Lua load order. The addon files share the private namespace passed as the second Lua vararg. |
| Where does a keypress go? | [Bindings.xml](Bindings.xml) declares the action IDs. [ForeverWeaponSwap.lua](ForeverWeaponSwap.lua) creates their named buttons, handles clicks and listens for game events. |
| Which items can be applied? | [Consumables.lua](Consumables.lua) holds bag item IDs, lure bonuses and target compatibility rules. |
| How do I check a change outside the game? | Run `python3 tests/run.py`. [The mock suite](tests/test.lua) exercises the Lua logic. Live Forever checks cover protected actions, native macro resolution, input timing and UI layout. |

## Gear and player-facing terms

| Term | Meaning in this addon |
| --- | --- |
| Set 1 / Set 2 | A saved main hand with an optional off-hand. Clicking either icon requests the whole set. Clearing the main hand clears the set. |
| MH / OH | Main hand and off-hand. OH can be a weapon, shield or held item. Dual wield means a weapon in each hand. A two-handed weapon occupies the main hand and can displace the OH. |
| Unmanaged off-hand | An empty saved OH leaves the equipped OH alone when possible. A sword-only set can already match a player wearing that sword and a shield. |
| Equipped / carried / selected | Equipped means the item is in the relevant hand. Carried means it is equipped or available in the player's bags. The yellow highlight follows the matching equipped set. A pending swap is only a request. |
| Cycle / direct binding | The cycle key chooses the next distinct available option outside combat. A direct binding requests a particular set. In combat the secure cycle alternates requested weapon sets and can get out of step after a failed equip. |
| Fishing pole / rod | A separate saved two-hander. **Skip pole when cycling** keeps it clickable. **Disable fishing** removes its UI and addon actions. **Hide fishing in combat** controls combat visibility. |
| Drawer / owner / row | A drawer is the hover panel. Its owner determines the target hand or pole. Each row is a clickable consumable icon with a count. A star marks the preferred weapon enhancement for that hand. |
| Lure / bait | A consumable applied to a pole for a temporary Fishing skill bonus. **“Secret” Bait** is the name of bag item 268880. See **secret value** below for the unrelated Lua term. |
| Enhancement / imbue | Temporary weapon effects include poisons, oils and stones. Forever can report both a Temporary and an Imbue record for a hand. Ordinary sharpening stones and weightstones use separate weapon-subclass rules. Shields and held OH items have no enhancement drawer. |

## Slots, identifiers and item data

| Operation | Main hand | Off-hand |
| --- | --- | --- |
| Equip, inspect equipped gear, or target a consumable | Inventory slot `16` | Inventory slot `17` |
| Read enhancements with `C_Item.GetWeaponEnchantInfo` | `Enum.WeaponSlot.MainHand` (0) | `Enum.WeaponSlot.OffHand` (1) |

- **Bag slot** identifies a position inside a particular bag. **Equip location** is a category such as `INVTYPE_2HWEAPON` or `INVTYPE_SHIELD`. **Class/subclass** identifies the kind of item. In `C_Item.GetItemInfoInstant`, equip location, class and subclass are results 4, 6 and 7.
- **Item ID** identifies a base item. For a consumable, use the ID of the item in the bags for counts and use commands. Its crafting recipe, use spell and resulting enchant can each have a different ID.
- **Item link / payload / variant**. A displayed item hyperlink contains an `item:…` payload. Normal sets store base IDs. Experimental `/fws exact 1` or `2` captures the equipped links. `VariantKey` compares stable fields through the random suffix, including permanent enchant. Copies differing only by temporary poison remain indistinguishable.
- **Item cache**. The client can know the ID before it has a display link. Save the ID, request item data, and fill in the link on `GET_ITEM_INFO_RECEIVED`. **Bag cache** refers separately to the addon's record of what the player carries.
- **SavedVariablesPerCharacter** is the TOC declaration for settings and sets persisted by WoW. This addon uses `ForeverWeaponSwapDB`. An explicit `false` is meaningful when restoring an option.

## Input, combat and client vocabulary

| Term | Why it matters |
| --- | --- |
| Forever / FrameXML | Forever is the target WoW client flavor. FrameXML is Blizzard's UI implementation, including Lua and XML. Use the Forever branch when checking button or Settings behavior. |
| Secure action button / protected action | A `SecureActionButtonTemplate` can execute an action configured through attributes. The cycle and direct bindings use Blizzard's native equip commands. The button's name is part of the saved `CLICK FrameName:LeftButton` binding ID. |
| Combat lockdown / state driver | `InCombatLockdown()` gates ordinary Lua changes to protected UI. A driver registered before combat can respond to conditions such as `[combat]`. Defer setup, protected layout changes and interrupted drag cleanup until lockdown ends. |
| Secure snippet / taint | A secure snippet runs in Blizzard's restricted environment. Taint is the client's tracking of insecure addon influence on a protected execution path. A mock pass cannot establish that a path is taint-free in game. |
| Cursor / press / release | A cursor can be carrying an item for assignment or waiting for a spell target. A drawer press requests gear. Release on the same row rechecks the equipped target, cursor, lock and bag count before arming the action in `PreClick`. An early release can require a second click. |
| Target slot / on-use effect | The drawer runs `/use [nocombat] item:<id>` with `*target-slot1`. Blizzard's secure button targets that slot when the action opens an item-targeting cursor. A separate unconditional `/use 16` or `/use 17` can activate the weapon itself. |
| Slash command / macro export | `/fws` and `/weaponswap` invoke addon Lua. Slash equipping is available outside combat. `/fws macro 1` exports a snapshot of native equip commands that a player can paste into a WoW macro. |
| GCD / duration object | GCD means global cooldown, displayed as a sweep. The addon queries spell 61304 or Forever fallback 29515 and passes the duration object directly to the cooldown widget. Enhancement time remaining is a separate value in milliseconds. |
| Secret value / public value | Some client API results restrict Lua inspection. The addon's `Public()` helper checks `issecretvalue` before comparisons or formatting. The word “secret” here describes an API restriction. |
| Binding category | Forever groups entries through the `category` attribute in Bindings.xml. An earlier `header` entry appeared as a dead binding under Other. Preserve the working action IDs when changing labels. |

The addon Settings page uses Forever's native `CreateKeybindingEntryInitializer` with the action's index from `GetBinding`. Fishing options use `AddModifyPredicate` and `AddEvaluateStateCVar` to follow the disable setting while retaining top-level label styling. See [Forever Settings controls](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingControls.lua).

## Events worth recognizing in a trace

| Event | What the addon does |
| --- | --- |
| `ADDON_LOADED` | Loads and validates saved data. If already in lockdown, defers protected UI creation. |
| `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` | Entering combat cancels a pending paired swap. Leaving combat completes deferred UI work and resynchronizes the cycle. |
| `PLAYER_EQUIPMENT_CHANGED` / `ITEM_LOCK_CHANGED` | A hand changed or a lock changed. Check the actual equipped items before advancing a paired swap. The two-second timeout bounds the wait and reports failure. |
| `BAG_UPDATE_DELAYED` | Invalidate availability caches and rebuild open drawer contents. A lock-only update can reuse the visible rows. |
| `CURSOR_CHANGED` | Reevaluate optional OH drop targets outside combat. This can also fire during item use. |
| `SPELL_UPDATE_COOLDOWN` / `ACTIONBAR_UPDATE_COOLDOWN` | Refresh the GCD display. These events can fire frequently. |

For a newly encountered API, start with the [Forever client API index](https://github.com/reckhou/WoWBlzCode/tree/main/index/Forever). For secure click ordering, inspect [Forever SecureTemplates.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua). For item IDs and compatibility, use the sources under **Consumable data** in the [README](README.md).
