# Forever Weapon Swap

- Target WoW Forever, interface `16001`, with Lua 5.1-compatible addon code and no runtime dependencies.
- Keep the folder and TOC named `ForeverWeaponSwap`. Preserve the per-character `ForeverWeaponSwapDB` structure and the frame names used by `Bindings.xml`.
- Use the `category` attribute to group the three actions in Forever's keybinding menu. Keep their existing `CLICK` action IDs so configured keys carry over.
- Keep combat equip actions on secure buttons using native equip commands. Reconfigure those buttons outside combat. Custom slash equip commands require leaving combat.
- Keep the yellow selection tied to actual equipment. Treat an unset off-hand as unmanaged and use slots 16 and 17 for the two hands.
- Store the fishing pole separately from the weapon sets. The cycle skips empty sets and includes the saved fishing pole outside combat when enabled. Use secure state drivers for combat visibility and secure lure rows for native item-use commands.
- Display the shared global cooldown by passing the client duration object directly to an addon-owned cooldown widget. Keep this display independent of secure equip logic. Avoid arithmetic or comparisons on restricted timer values.
- Run `python3 tests/run.py` from the checkout root or the extracted addon with `liblua5.4.so.0` installed. The mock tests cover Lua behavior. Verify live secure buttons, keybinds, and cooldown sweeps in WoW.
- Package the `ForeverWeaponSwap/` folder with the TOC, Lua source, bindings, `README.md`, this file, and the mock tests under `tests/`. Update the README and TOC version for releases.
