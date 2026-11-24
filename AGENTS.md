# Forever Weapon Swap

## Project map

- Target WoW Forever, interface `16001`, and write Lua 5.1-compatible code with no runtime dependencies.
- `ForeverWeaponSwap.lua` owns saved sets, the swap UI, input handlers, settings, and the shared consumable drawer.
- `Consumables.lua` holds the bag item IDs and compatibility rules. The TOC loads it before the main Lua file. Both files receive the same addon namespace as their second vararg.
- Keep the addon folder and TOC named `ForeverWeaponSwap`. Preserve the per-character `ForeverWeaponSwapDB` and its existing keys. Give new booleans defaults only when the saved value is `nil`; an explicit `false` is a user choice.
- Keep the existing secure frame names and `CLICK` action IDs in `Bindings.xml` so configured keys carry over. Forever uses the XML `category` attribute for grouping. The old `header` attribute produced a dead `HEADER_FOREVERWEAPONSWAP` row under Other in the live client. Fully restart WoW when checking changes to the bindings.

## Secure input, combat, and swapping

- Use `InCombatLockdown()` to decide when ordinary Lua can change protected frames. Secure snippets use the game's macro conditions, such as `SecureCmdOptionParse("[nocombat] yes")`. Keep the initial protected UI setup deferred if combat lockdown is already active at addon load. The first `PLAYER_REGEN_ENABLED` must build the secure actions, including the direct set buttons. Refreshing the cycle state alone cannot install their macros.
- Keep combat equip actions on secure buttons and use native `/equipslot` commands. Slot `16` is main-hand and `17` is off-hand. Keep the binding's key-release behavior in mind when diagnosing latency. The secure cycle cannot insert a wait between its macro commands.
- Use state drivers for in-combat visibility. Showing, hiding, repositioning, or changing protected attributes from an ordinary combat event can fail. `StopMovingOrSizing()` is also restricted for protected frames. If combat interrupts a drag, finish it and save the position after combat.
- Preserve the distinction between an equip click and placing a cursor item. Populated slots have both a secure equip action and a drop path. Placing a cursor item should save it without also equipping the old set. Test both a real drag and picking up an item then clicking the slot.
- A slash-command paired swap sends the main-hand request immediately, then waits for the expected main hand and unlocked slots before requesting the off-hand. `PLAYER_EQUIPMENT_CHANGED` and `ITEM_LOCK_CHANGED` drive the check. The two-second timeout is a cutoff. Cancel a pending off-hand when combat or a newer swap supersedes the request.
- Keep the selection highlight tied to what WoW actually equipped. An unset off-hand is unmanaged. The fishing pole is separate and only participates in the out-of-combat cycle when enabled and available. Skip empty sets. The in-combat cycle tracks its next secure macro, so a failed equip can leave that sequence out of step until combat ends.

## Items, drawers, and cooldowns

- Use bag **item IDs** for `C_Item.GetItemCount` and `/use item:<id>`. Recipe IDs and use-spell IDs are separate. `C_Item.GetItemInfoInstant` returns equip location in result 4, item class in result 6, and item subclass in result 7. Use Forever item records and spell equipment rules when extending the catalog. The ordinary sharpening-stone and weightstone masks differ. Keep special stones as separate entries because their restrictions can differ.
- `C_Item.GetItemInfo` may have no link for uncached gear. Save the ID first, request data with `C_Item.RequestLoadItemDataByID`, then fill in the link when the item-data event arrives. The current equip, availability, and highlighting logic still identifies items by numeric ID. Supporting two copies with different suffixes or enchants would require updating all of those paths and testing the exact item payload in a live `/equipslot` macro.
- Both drawers use secure rows with a native two-command macro. The first command uses the selected consumable. The second targets the displayed hand. Both have `[nocombat]` guards. Recheck the saved target, actual equipped slot, lock state, cursor, and bag count at click time. Keep unequipped previews read-only.
- A timer is fine for the drawer's closing delay. A timer cannot carry the original click's secure permissions forward. Equip-then-apply on one click has not been verified in Forever when the pole equip is asynchronous. Preserve the separate user click for applying a lure unless a live test establishes a supported route.
- For hover checks, use the region method `frame:IsMouseOver()`. Keep the drawer open while crossing the gap from its owner to an item. Use the secure state driver to close it on combat entry. Avoid refreshing or rewriting secure rows from `CURSOR_CHANGED`, which can fire in the middle of a native item-use macro.
- For the global cooldown, get a duration object with `C_Spell.GetSpellCooldownDuration` and pass it directly to the addon-owned cooldown widget. Try sentinel `61304` when present, otherwise Forever can use `29515`. Keep the widget separate from the secure equip button. Do not compare, format, or do arithmetic on secret cooldown fields. Use the existing `Public()` check before branching on ordinary API results that can be secret. Reuse the flat weapon-button list in the high-frequency cooldown handler.
- Before copying examples from Retail or Classic, check the [Forever client API index](https://github.com/reckhou/WoWBlzCode/tree/main/index/Forever) and [Forever FrameXML](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns). The README lists sources for consumable IDs and compatibility.

## Checks and releases

- Run `python3 tests/run.py` from the checkout root or the extracted addon on Linux with `liblua5.4.so.0` installed. The mock checks data and Lua behavior. It does not model WoW's protected action execution, event timing, UI rendering, or taint.
- For live changes, enable `/console scriptErrors 1`. Check the direct bindings and cycle outside and inside combat with one and two saved sets, including a pole. Reload in combat and confirm the UI initializes on leaving combat. Try entering combat while dragging the bar.
- For drawer changes, hover each hand, cross into the drawer, then test a valid item, a locked or unequipped target, a swap between hover and click, and combat entry. Check that the consumable applies to the intended hand and that WoW handles any replacement warning. Repeat with a lure and the saved pole.
- Package the `ForeverWeaponSwap/` folder with its TOC, bindings, both Lua files, `README.md`, this file, and the mock suite under `tests/`. Check the TOC load order and run the tests from the extracted ZIP. Update both the README and TOC version for addon releases.
