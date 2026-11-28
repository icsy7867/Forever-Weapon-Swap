local ADDON, addon = ...
BINDING_HEADER_FOREVERWEAPONSWAP = "Forever Weapon Swap"
_G["BINDING_NAME_CLICK ForeverWeaponSwapToggle:LeftButton"] = "Cycle Weapon Sets"

for index = 1, 3 do
    _G["BINDING_NAME_CLICK ForeverWeaponSwapChoice" .. index .. ":LeftButton"] = "Equip Weapon Set " .. index
end

local db, bar, controller, toggle
local buttons, weaponButtons = {}, {}
local moving, pendingOffhand
local fishing, weaponDrawer, settingsCategory
local FISHING_SUBCLASS = Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole or 20
-- SpellEquippedItems subclass masks for the standard stones: 33219 and 9264.
local SHARP = { [0] = true, [1] = true, [6] = true, [7] = true, [8] = true, [15] = true }
local BLUNT = { [4] = true, [5] = true, [10] = true, [13] = true }
local QUESTION = 134400
local MAIN_HAND = 16
local OFF_HAND = 17
local GCD_SPELL = 61304
local CLASSIC_GCD_SPELL = 29515
local COMPACT_HEIGHT = 60
local EXPANDED_HEIGHT = 91
local WEAPON_PANEL_WIDTH = 92
local FISHING_PANEL_WIDTH = 72
local PANEL_GAP = 3
local offhandLocations = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }
local function SetCount() return db.thirdSet and 3 or 2 end

local function Weapon(index, offhand)
    if index > SetCount() then return end
    local set = db.weapons[index]
    if offhand then return set and set.offhand end
    return set
end
local validLocations = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_2HWEAPON = true }

local function Message(text)
    print("|cffffd100Weapon Swap:|r " .. text)
end

local function Public(value)
    return not issecretvalue or not issecretvalue(value)
end

local function CursorItemID()
    local kind, id = GetCursorInfo()
    if Public(kind) and kind == "item" and Public(id) then return id end
end

local function UpdateOffhandVisibility()
    -- Changing the visibility or size of secure frames requires leaving combat.
    if InCombatLockdown() then return end

    local id = CursorItemID()
    local eligible
    if id then
        local _, _, _, location, _, class = C_Item.GetItemInfoInstant(id)
        eligible = offhandLocations[location] and (class == 2 or class == 4)
    end
    local expanded = false
    for index = 1, 3 do
        local main = Weapon(index, false)
        if index == 3 then buttons[index]:SetShown(db.thirdSet) end
        local show = main and main.offhand ~= nil
        if not show and eligible and main and main.id ~= id then
            local _, _, _, location = C_Item.GetItemInfoInstant(main.id)
            show = location ~= nil and location ~= "INVTYPE_2HWEAPON"
        end
        local button = buttons[index].offhandButton
        if button:IsShown() ~= (show == true) then button:SetShown(show == true) end
        if show then expanded = true end
    end
    local height = expanded and EXPANDED_HEIGHT or COMPACT_HEIGHT
    if bar:GetHeight() ~= height then bar:SetHeight(height) end
end

local function EquippedID(slot)
    local id = GetInventoryItemID("player", slot or MAIN_HAND)
    if Public(id) then return id end
end

-- Use the invariant item fields through suffix for variant matching. Later fields
-- (including link level) can change when the client renders the same item again.
local function ItemPayload(link)
    if not Public(link) or type(link) ~= "string" then return end
    return link:match("|H(item:[%d:%-]+)|h") or link:match("^(item:[%d:%-]+)$")
end

local function VariantKey(payload)
    if not payload then return end
    local fields = {}
    for field in (payload:sub(6) .. ":"):gmatch("([^:]*):") do
        fields[#fields + 1] = tonumber(field) or 0
        if #fields == 7 then break end
    end
    for i = #fields + 1, 7 do fields[i] = 0 end
    return table.concat(fields, ":")
end

local function ItemRef(item)
    return item.payload or ("item:" .. item.id)
end

local function Equipped(item, slot)
    if EquippedID(slot) ~= item.id then return false end
    if not item.payload then return true end
    return VariantKey(ItemPayload(GetInventoryItemLink("player", slot))) == item.variant
end

local function IsFishingPole(id)
    if not id then return false end
    local _, _, _, _, _, class, subclass = C_Item.GetItemInfoInstant(id)
    return class == 2 and subclass == FISHING_SUBCLASS
end

local function IsWeaponSet(index)
    if index > SetCount() then return false end
    local set = db.weapons[index]
    return set and set.id and not IsFishingPole(set.id)
        and not (set.offhand and IsFishingPole(set.offhand.id))
end

local function EquippedChoice()
    local fallback
    for i = 1, SetCount() do
        local set = db.weapons[i]
        if set and Equipped(set, MAIN_HAND) then
            if set.offhand and Equipped(set.offhand, OFF_HAND) then return i end
            if not set.offhand and not fallback then fallback = i end
        end
    end
    return fallback
end

local bagItems, bagVariants

local function Carried(item)
    if Equipped(item, MAIN_HAND) or Equipped(item, OFF_HAND) then return true end
    if item.payload then
        if not bagVariants then
            bagVariants = {}
            for bag = 0, NUM_BAG_SLOTS or 4 do
                for slot = 1, C_Container.GetContainerNumSlots(bag) do
                    local key = VariantKey(ItemPayload(C_Container.GetContainerItemLink(bag, slot)))
                    if key then bagVariants[key] = true end
                end
            end
        end
        return bagVariants[item.variant] == true
    end
    if not bagItems then
        bagItems = {}
        for bag = 0, NUM_BAG_SLOTS or 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local item = C_Container.GetContainerItemID(bag, slot)
                if Public(item) and item then bagItems[item] = true end
            end
        end
    end
    return bagItems[item.id] == true
end

local gcdSpell
local function UpdateGlobalCooldown()
    local duration
    if C_Spell.GetSpellCooldownDuration then
        -- Some Forever builds expose the Classic dummy spell instead of 61304.
        if not gcdSpell then
            gcdSpell = GCD_SPELL
            if C_Spell.DoesSpellExist and not C_Spell.DoesSpellExist(gcdSpell) then
                gcdSpell = CLASSIC_GCD_SPELL
            end
        end
        duration = C_Spell.GetSpellCooldownDuration(gcdSpell)
    end
    for _, button in ipairs(weaponButtons) do
        local cooldown = button.cooldown
        if duration and Weapon(button.choice, button.isOffhand) then
            -- The widget can render restricted timing without reading it in Lua.
            cooldown:SetCooldownFromDurationObject(duration, true)
        else
            cooldown:Clear()
        end
    end
end

local function UpdateFishingIcon()
    local pole = db.fishingPole
    local present = pole and Carried(pole)
    local selected = pole and EquippedID() == pole.id
    local button = fishing.pole
    button.icon:SetTexture(pole and C_Item.GetItemIconByID(pole.id) or 132932)
    button.icon:SetDesaturated(pole ~= nil and not present)
    button.icon:SetAlpha(pole and (present and 1 or 0.4) or 0.5)
    if selected then
        button.border:SetColorTexture(1, 0.82, 0, 1)
    else
        button.border:SetColorTexture(0.3, 0.3, 0.3, 1)
    end
end

local function UpdateVisuals()
    if not db then return end
    local equipped = EquippedChoice()
    for _, button in ipairs(weaponButtons) do
        local weapon = Weapon(button.choice, button.isOffhand)
        local texture = weapon and C_Item.GetItemIconByID(weapon.id)
        button.icon:SetTexture(texture or QUESTION)
        local present = weapon and Carried(weapon)
        button.icon:SetDesaturated(weapon ~= nil and not present)
        button.icon:SetAlpha(weapon and (present and 1 or 0.4) or 0.35)
        local selected = equipped == button.choice and weapon ~= nil
        button.border:SetColorTexture(selected and 1 or 0.3, selected and 0.82 or 0.3, selected and 0 or 0.3, 1)
        button.selected:SetShown(selected)
    end
    UpdateOffhandVisibility()
    UpdateFishingIcon()
    UpdateGlobalCooldown()
end

local function MacroText(index)
    local set = db.weapons[index]
    if not IsWeaponSet(index) then return end
    local text = "/equipslot 16 " .. ItemRef(set)
    if set.offhand then text = text .. "\n/equipslot 17 " .. ItemRef(set.offhand) end
    return text
end

local function NextOutOfCombat()
    local pole = not db.disableFishing and db.fishingPole
    local current = EquippedChoice() or 0
    if pole and EquippedID() == pole.id then current = 4 end
    for step = 1, 4 do
        local index = (current + step - 1) % 4 + 1
        if index == 4 then
            if db.includeFishingInCycle and current ~= 4 and pole and Carried(pole) then
                return index, "/equipslot [nocombat] 16 item:" .. pole.id
            end
        elseif IsWeaponSet(index) then
            local set = db.weapons[index]
            local matches = Equipped(set, MAIN_HAND) and (not set.offhand or Equipped(set.offhand, OFF_HAND))
            if not matches and Carried(set) and (not set.offhand or Carried(set.offhand)) then
                return index, MacroText(index)
            end
        end
    end
end

local function SyncToggle()
    if InCombatLockdown() then return end
    controller:SetAttribute("next", (EquippedChoice() or 0) % SetCount() + 1)
    local _, macro = NextOutOfCombat()
    controller:SetAttribute("peacefulMacro", macro)
end

-- Rebuild only outside combat. Secure handlers own the alternating target in combat.
local function ConfigureActions()
    if not db or not controller or InCombatLockdown() then return end
    controller:SetAttribute("count", SetCount())
    for i = 1, 3 do
        local macro = MacroText(i)
        controller:SetAttribute("weapon" .. i, macro)
        buttons[i]:SetAttribute("*type1", macro and "macro" or nil)
        buttons[i]:SetAttribute("*macrotext1", macro)
        local offhand = buttons[i].offhandButton
        local offhandMacro = Weapon(i, true) and macro or nil
        offhand:SetAttribute("*type1", offhandMacro and "macro" or nil)
        offhand:SetAttribute("*macrotext1", offhandMacro)
    end
    SyncToggle()
end

local function ReadItem(id, offhand, main, exactLink)
    if not id then return nil, "No item is equipped in that hand." end
    local _, _, _, location, _, classID = C_Item.GetItemInfoInstant(id)
    local payload, variant
    if exactLink ~= nil then
        payload = ItemPayload(exactLink)
        if not payload or tonumber(payload:match("^item:(%d+)")) ~= id then
            return nil, "Item details are unavailable. Try saving the equipped pair again."
        end
        variant = VariantKey(payload)
    end
    if offhand then
        if not main then return nil, "Save the main-hand weapon first." end
        local _, _, _, mainLocation = C_Item.GetItemInfoInstant(main.id)
        if mainLocation == "INVTYPE_2HWEAPON" then return nil, "A two-handed weapon cannot have an off-hand." end
        if not offhandLocations[location] or (classID ~= 2 and classID ~= 4) then
            return nil, "Choose an off-hand weapon, shield, or held off-hand item."
        end
        if main.id == id and (not variant or not main.variant or main.variant == variant) then
            return nil, "Same-ID weapons need distinguishable enchants or suffixes. Use /fws exact 1 or 2."
        end
    elseif IsFishingPole(id) then
        return nil, "Save fishing poles in the Fishing slot."
    elseif classID ~= 2 or not validLocations[location] then
        return nil, "Choose a one-handed or two-handed main-hand weapon."
    end
    local _, link = C_Item.GetItemInfo(id)
    return { id = id, link = exactLink or link, payload = payload, variant = variant }, nil, location
end

local function RequestItemLink(item)
    if item and not item.link then C_Item.RequestLoadItemDataByID(item.id) end
end

local function SaveEquipped(index, exact)
    for slot = MAIN_HAND, OFF_HAND do
        if IsInventoryItemLocked(slot) then
            Message("An item is moving. Wait for the swap to finish and save again.")
            return
        end
    end
    local function EquippedLink(slot)
        if exact then
            local link = GetInventoryItemLink("player", slot)
            if Public(link) and type(link) == "string" then return link end
            return false
        end
    end
    local main, err = ReadItem(EquippedID(), false, nil, EquippedLink(MAIN_HAND))
    if not main then Message(err); return end
    local offID = GetInventoryItemID("player", OFF_HAND)
    if not Public(offID) or (not offID and GetInventoryItemTexture("player", OFF_HAND)) then
        Message("Off-hand data is unavailable. Try saving again.")
        return
    end
    if offID then
        main.offhand, err = ReadItem(offID, true, main, EquippedLink(OFF_HAND))
        if err then Message(err); return end
    end
    db.weapons[index] = main
    RequestItemLink(main)
    RequestItemLink(main.offhand)
    ConfigureActions()
    UpdateVisuals()
    if weaponDrawer and weaponDrawer:IsShown() then weaponDrawer:Hide() end
    Message("Saved set " .. index .. ".")
end

local function Assign(index, id, offhand)
    if InCombatLockdown() then Message("Set up weapons after combat."); return false end
    local item, err, location = ReadItem(id, offhand, db.weapons[index])
    if not item then Message(err); return false end
    if offhand then db.weapons[index].offhand = item
    else
        local old = db.weapons[index]
        if old and old.offhand and location ~= "INVTYPE_2HWEAPON" and old.offhand.id ~= id then item.offhand = old.offhand end
        db.weapons[index] = item
    end
    RequestItemLink(item)
    ConfigureActions()
    UpdateVisuals()
    if weaponDrawer and weaponDrawer:IsShown() then weaponDrawer:Hide() end
    Message("Set " .. index .. (offhand and " off-hand: " or " main-hand: ") .. (item.link or ("item " .. id)))
    return true
end

local function ClearChoice(index, offhand)
    if InCombatLockdown() then Message("Set up weapons after combat."); return end
    if offhand then
        if db.weapons[index] then db.weapons[index].offhand = nil end
    else db.weapons[index] = nil end
    ConfigureActions()
    UpdateVisuals()
    if weaponDrawer and weaponDrawer:IsShown() then weaponDrawer:Hide() end
end

local function ReceiveWeapon(button)
    if InCombatLockdown() then Message("Set up weapons after combat."); return end
    local id = CursorItemID()
    if id and Assign(button.choice, id, button.isOffhand) then
        ClearCursor()
        UpdateOffhandVisibility()
    end
end

local function HideTooltip(owner)
    if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

local function Tooltip(button, drawerOpened)
    local weapon = Weapon(button.choice, button.isOffhand)
    if weapon and not db.showEquipmentTooltips then return end
    local anchor = drawerOpened and not button.isOffhand and "ANCHOR_BOTTOM" or "ANCHOR_TOP"
    GameTooltip:SetOwner(button, anchor)
    if weapon then
        if weapon.payload then GameTooltip:SetHyperlink(weapon.payload)
        else GameTooltip:SetItemByID(weapon.id) end
        if not Carried(weapon) then GameTooltip:AddLine("Not in your bags or equipped", 1, 0.25, 0.25) end
    elseif button.isOffhand then
        GameTooltip:AddLine("Set " .. button.choice .. " optional off-hand", 1, 0.82, 0)
        GameTooltip:AddLine("Drop the item here to save it", 0.8, 0.8, 0.8)
        GameTooltip:Show()
        return
    else
        GameTooltip:AddLine("Drop a main-hand weapon here", 1, 0.82, 0)
        GameTooltip:AddLine("Or right-click to save your equipped weapon", 0.8, 0.8, 0.8)
        GameTooltip:Show()
        return
    end
    GameTooltip:AddLine("Left-click: equip this entire set", 1, 1, 1)
    GameTooltip:AddLine("Drop a weapon here to save it", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: save the item equipped in this hand", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Shift-right-click: clear this slot (main-hand clears set)", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function RestorePosition()
    bar:ClearAllPoints()
    local p = db.position
    if p then bar:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
    else bar:SetPoint("CENTER", UIParent, "CENTER", 0, -160) end
end

local function SetPanelBackdrop(panel)
    local white = "Interface\\Buttons\\WHITE8X8"
    panel:SetBackdrop({ bgFile = white, edgeFile = white, edgeSize = 1 })
    panel:SetBackdropColor(0.04, 0.04, 0.05, 0.92)
    panel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
end

local function ApplyAppearance()
    if InCombatLockdown() then return end
    bar:SetScale(db.scale)
    bar:SetAlpha(db.opacity / 100)
    local width = WEAPON_PANEL_WIDTH + (SetCount() - 2) * 42
    bar.weaponBackdrop:SetWidth(width)
    fishing:ClearAllPoints()
    fishing:SetPoint("TOPLEFT", bar, "TOPLEFT", width + PANEL_GAP, 0)
    local rule = "hide"
    if not db.disableFishing then
        width = width + PANEL_GAP + FISHING_PANEL_WIDTH
        rule = db.hideFishingInCombat and "[combat] hide; show" or "show"
    end
    if bar:GetWidth() ~= width then bar:SetWidth(width) end
    if fishing.visibilityRule ~= rule then
        if db.disableFishing then
            fishing.menu:Hide()
            HideTooltip(fishing.pole)
        end
        RegisterStateDriver(fishing, "visibility", rule)
        fishing:SetShown(not db.disableFishing)
        fishing.visibilityRule = rule
    end
end

local function SavePole(id)
    if db.disableFishing or InCombatLockdown() then return false end
    if not IsFishingPole(id) then
        Message("Choose a fishing pole.")
        return false
    end
    local _, link = C_Item.GetItemInfo(id)
    db.fishingPole = { id = id, link = link }
    RequestItemLink(db.fishingPole)
    fishing.menu:Hide()
    UpdateFishingIcon()
    SyncToggle()
    return true
end

local function DropPole()
    if InCombatLockdown() then return end
    local id = CursorItemID()
    if id and SavePole(id) then ClearCursor() end
end

local function EquipPole()
    if db.disableFishing then return end
    pendingOffhand = nil
    local pole = db.fishingPole
    if not pole then
        Message("Drop a fishing pole onto the Fishing slot.")
    elseif not Carried(pole) then
        Message("Put your saved fishing pole in your bags first.")
    elseif EquippedID() ~= pole.id then
        C_Item.EquipItemByName("item:" .. pole.id, MAIN_HAND)
    end
end

local function CursorBusy()
    local kind = GetCursorInfo()
    return not Public(kind) or kind ~= nil or (SpellIsTargeting and SpellIsTargeting())
end

local function FishingTarget()
    if db.disableFishing then return end
    return db.fishingPole, MAIN_HAND
end

local function WeaponTarget(menu)
    local button = menu.owner
    if not button then return end
    local item = Weapon(button.choice, button.isOffhand)
    if not item then return end
    local _, _, _, _, _, class, subclass = C_Item.GetItemInfoInstant(item.id)
    if class == 2 and (SHARP[subclass] or BLUNT[subclass]) then
        return item, button.isOffhand and OFF_HAND or MAIN_HAND, subclass
    end
end

local function AcceptsEnhancement(entry, subclass, isRogue)
    if entry.rule == "sharp" then return SHARP[subclass] end
    if entry.rule == "blunt" then return BLUNT[subclass] end
    if entry.rule == "poison" then return isRogue end
    return entry.rule == "melee"
end

local function FinishOffhandSwap()
    local swap = pendingOffhand
    if not swap then return end
    if InCombatLockdown() or db.weapons[swap.index] ~= swap.set or swap.set.offhand ~= swap.offhand then
        pendingOffhand = nil
        return
    end
    local mainID = EquippedID()
    if not Equipped(swap.set, MAIN_HAND) then
        -- An unrelated main-hand change supersedes this request.
        if mainID and (swap.sawMain or mainID ~= swap.previousMain) then pendingOffhand = nil end
        return
    end
    swap.sawMain = true
    if Equipped(swap.offhand, OFF_HAND) then
        pendingOffhand = nil
        return
    end
    if swap.requested or IsInventoryItemLocked(MAIN_HAND) or IsInventoryItemLocked(OFF_HAND) then return end
    swap.requested = true
    C_Item.EquipItemByName(ItemRef(swap.offhand), OFF_HAND)
    if Equipped(swap.offhand, OFF_HAND) and pendingOffhand == swap then pendingOffhand = nil end
end

local function EquipSet(index)
    if InCombatLockdown() then Message("Slash equipping is out of combat only. Use the keybind/UI in combat, or /fws macro " .. index .. " to copy a native macro after combat."); return end
    pendingOffhand = nil
    local set = db.weapons[index]
    if not IsWeaponSet(index) then Message("Configure weapon set " .. index .. " first."); return end
    for _, item in ipairs({ set, set.offhand }) do
        if not Carried(item) then
            Message("Set " .. index .. " is missing " .. (item.link or ("item " .. item.id)) .. ".")
            return
        end
    end
    local previousMain = EquippedID()
    if set.offhand and (not Equipped(set.offhand, OFF_HAND) or not Equipped(set, MAIN_HAND)) then
        local swap = { index = index, set = set, offhand = set.offhand, previousMain = previousMain }
        pendingOffhand = swap
        C_Timer.After(2, function()
            if pendingOffhand == swap then
                pendingOffhand = nil
                if db.weapons[index] ~= set or set.offhand ~= swap.offhand or InCombatLockdown() then return end
                if Equipped(set, MAIN_HAND) then
                    if not Equipped(swap.offhand, OFF_HAND) then
                        Message("Main hand equipped. Off-hand swap timed out for " .. (swap.offhand.link or ItemRef(swap.offhand)) .. ".")
                    end
                else
                    Message("Set " .. index .. " swap timed out waiting for the main hand.")
                end
            end
        end)
    end
    if not Equipped(set, MAIN_HAND) then C_Item.EquipItemByName(ItemRef(set), MAIN_HAND) end
    FinishOffhandSwap()
    UpdateVisuals()
    SyncToggle()
end

-- A pole, a two-hander, or the target itself in slot 16 may have to move first.
local function NeedsMainForOffhand(item, slot)
    if slot ~= OFF_HAND or Equipped(item, slot) then return false end
    local main = EquippedID(MAIN_HAND)
    if not main or Equipped(item, MAIN_HAND) then return true end
    local _, _, _, location = C_Item.GetItemInfoInstant(main)
    return location == "INVTYPE_2HWEAPON"
end

local drawerHints = {
    missing = "Item missing",
    cursor = "Clear your cursor",
    waiting = "Wait for the swap",
    missingMain = "Main hand missing",
    release = "Release to apply",
    apply = "Click to apply",
    equip = "Hold to equip",
}

local function DrawerBlockReason(menu, item, slot)
    if not item or not Carried(item) then return drawerHints.missing end
    if CursorBusy() then return drawerHints.cursor end
    if IsInventoryItemLocked(slot) then return drawerHints.waiting end
    if not Equipped(item, slot) then
        if IsInventoryItemLocked(slot == MAIN_HAND and OFF_HAND or MAIN_HAND) then return drawerHints.waiting end
        if NeedsMainForOffhand(item, slot) and not Carried(Weapon(menu.owner.choice)) then
            return drawerHints.missingMain
        end
    end
end

local function ConsumableCount(id)
    local count = C_Item.GetItemCount(id)
    if Public(count) and count and count > 0 then return count end
end

local function EnchantText(enchant, warn)
    local icon, time, charges = enchant.enchantIconID, enchant.timeLeft, enchant.charges
    local text = Public(icon) and type(icon) == "number" and ("|T%d:14|t"):format(icon) or "Active"
    if warn and db.chargePulse and Public(icon) and type(icon) == "number" and Public(charges)
        and type(charges) == "number" and charges > 0 and charges <= 5 and math.floor(GetTime()) % 2 == 1 then
        text = ("|T%d:16|t"):format(icon)
    end
    if Public(time) and type(time) == "number" and time > 0 then
        local seconds = math.ceil(time / 1000)
        text = text .. (seconds >= 60 and (" %dm"):format(math.ceil(seconds / 60)) or (" %ds"):format(seconds))
    end
    if Public(charges) and type(charges) == "number" and charges > 0 then
        text = text .. (" ×%d"):format(charges)
    end
    return text
end

local function RefreshEnchant(menu)
    if not C_Item.GetWeaponEnchantInfo then return end
    local item, slot = menu.targetItem, menu.targetSlot
    local text = ""
    if item and Equipped(item, slot) then
        local hand = slot == OFF_HAND and Enum.WeaponSlot.OffHand or Enum.WeaponSlot.MainHand
        local enchants = C_Item.GetWeaponEnchantInfo(hand)
        if Public(enchants) and type(enchants) == "table" then
            local temporary, imbue, unknown
            for _, enchant in pairs(enchants) do
                if not Public(enchant) or not Public(enchant.hasEnchant) or not Public(enchant.enchantType) then
                    unknown = true
                elseif enchant.hasEnchant then
                    if enchant.enchantType == Enum.ItemEnchantType.Temporary then temporary = EnchantText(enchant, menu.accepts)
                    elseif enchant.enchantType == Enum.ItemEnchantType.Imbue then imbue = EnchantText(enchant, menu.accepts) end
                end
            end
            if temporary and imbue then text = temporary .. "\n" .. imbue
            elseif temporary or imbue then text = temporary or imbue
            elseif not unknown then text = menu.accepts and "No enhancement" or "No lure" end
        end
    end
    menu.enchant:SetText(text)
end

local function UpdateDrawerStatus(menu)
    local item, slot = menu.targetItem, menu.targetSlot
    local blocked = DrawerBlockReason(menu, item, slot)
    local hint
    if not item and not menu.accepts then hint = "Save a fishing pole first"
    elseif #menu.visible == 0 then hint = menu.emptyText
    elseif blocked then hint = blocked
    elseif menu.pressedRow then hint = Equipped(item, slot) and drawerHints.release or drawerHints.waiting
    else hint = Equipped(item, slot) and drawerHints.apply or drawerHints.equip end
    menu.status:SetText(hint)
    for _, row in ipairs(menu.visible) do
        row.icon:SetDesaturated(blocked ~= nil)
        row.icon:SetAlpha(blocked and 0.45 or 1)
    end
    RefreshEnchant(menu)
end

local function RefreshDrawer(menu)
    local item, slot, subclass = menu.getTarget(menu)
    local _, class = UnitClass("player")
    local visible = {}
    local favorite = menu.accepts and db.favorites[slot]
    for _, row in ipairs(menu.rows) do
        local entry = row.entry
        local count
        if item and (not menu.accepts or menu.accepts(entry, subclass, class == "ROGUE")) then
            count = ConsumableCount(entry.id)
        end
        if count then
            if entry.id == favorite then table.insert(visible, 1, row)
            else visible[#visible + 1] = row end
            row.count:SetText(count)
            row.icon:SetTexture(C_Item.GetItemIconByID(entry.id) or QUESTION)
            if row.star then row.star:SetShown(entry.id == favorite) end
        end
        row:SetShown(count ~= nil)
    end
    if menu.pressedRow then
        for i, row in ipairs(menu.visible) do
            if row == menu.pressedRow and visible[i] ~= row then menu.pressedRow = nil end
        end
    end
    menu.visible, menu.targetItem, menu.targetSlot = visible, item, slot
    UpdateDrawerStatus(menu)
    local count = #visible
    local columns = math.max(1, math.min(6, count))
    local height = math.ceil(count / columns) * 30
    -- Reserve the enhancement line even during a swap so a held row stays under the mouse.
    local enchantHeight = C_Item.GetWeaponEnchantInfo and item and (menu.accepts and 32 or 16) or 0
    local textWidth = count == 0 and menu.status:GetStringWidth() or menu.hintWidth
    local width = math.max(8 + columns * 30, math.ceil(textWidth) + 16, enchantHeight > 0 and 104 or 0)
    menu:SetSize(width, 24 + height + enchantHeight)
    for index, row in ipairs(visible) do
        local column = (index - 1) % columns
        local line = math.floor((index - 1) / columns)
        local lineColumns = math.min(columns, count - line * columns)
        local left = (width - lineColumns * 30) / 2 + 1
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", left + column * 30, -5 - line * 30)
    end
end

local function RefreshOpenDrawers(rebuild)
    if InCombatLockdown() then return end
    local refresh = rebuild and RefreshDrawer or UpdateDrawerStatus
    if fishing.menu:IsShown() then refresh(fishing.menu) end
    if weaponDrawer:IsShown() then refresh(weaponDrawer) end
end

local function CreateItemDrawer(parent, entries, getTarget, accepts, emptyText)
    local menu = CreateFrame("Frame", nil, parent, "BackdropTemplate,SecureHandlerStateTemplate")
    menu.getTarget, menu.accepts = getTarget, accepts
    menu.emptyText = emptyText
    menu:EnableMouse(true)
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    SetPanelBackdrop(menu)
    menu:Hide()
    menu:SetAttribute("_onstate-combat", [[ if newstate == "active" then self:Hide() end ]])
    RegisterStateDriver(menu, "combat", "[combat] active; idle")
    menu.status = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    menu.status:SetPoint("BOTTOM", 0, 5)
    menu.hintWidth = 0
    for _, hint in pairs(drawerHints) do
        menu.status:SetText(hint)
        menu.hintWidth = math.max(menu.hintWidth, menu.status:GetStringWidth())
    end
    menu.status:SetText("")
    menu.enchant = menu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    menu.enchant:SetPoint("BOTTOM", 0, 20)
    menu.rows, menu.visible = {}, {}

    local closeTimer
    local function CancelClose()
        if closeTimer then closeTimer:Cancel(); closeTimer = nil end
    end
    function menu:ScheduleClose()
        if not self:IsShown() then return end
        CancelClose()
        closeTimer = C_Timer.NewTimer(0.22, function()
            closeTimer = nil
            if not InCombatLockdown() and not self.owner:IsMouseOver() and not self:IsMouseOver() then
                self:Hide()
            end
        end)
    end
    function menu:Open(owner)
        if InCombatLockdown() or CursorBusy() then return end
        CancelClose()
        self.pressedRow = nil
        self.owner = owner
        RefreshDrawer(self)
        self:Show()
        if C_Item.GetWeaponEnchantInfo and not self.ticker then
            self.ticker = C_Timer.NewTicker(1, function() RefreshEnchant(self) end)
        end
    end
    menu:SetScript("OnEnter", CancelClose)
    menu:SetScript("OnLeave", menu.ScheduleClose)
    menu:SetScript("OnHide", function(self)
        self.pressedRow = nil
        if self.ticker then self.ticker:Cancel(); self.ticker = nil end
        CancelClose()
    end)

    for _, entry in ipairs(entries) do
        local row = CreateFrame("Button", nil, menu, "SecureActionButtonTemplate")
        row.entry = entry
        row:SetSize(28, 28)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetAllPoints()
        row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.count:SetPoint("BOTTOMRIGHT", -1, 1)
        row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        if accepts then
            row.star = row:CreateTexture(nil, "OVERLAY")
            row.star:SetSize(12, 12)
            row.star:SetPoint("TOPLEFT")
            row.star:SetTexture("Interface\\COMMON\\FavoritesIcon")
            row.star:Hide()
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        else
            row:RegisterForClicks("LeftButtonUp")
        end
        row:SetAttribute("useOnKeyDown", false)
        row:Hide()

        local function CurrentTarget()
            local item, slot, subclass = getTarget(menu)
            if not item or not menu:IsShown() or not row:IsShown()
                or item ~= menu.targetItem or slot ~= menu.targetSlot
                or DrawerBlockReason(menu, item, slot) or not ConsumableCount(entry.id) then return end
            local _, class = UnitClass("player")
            if not accepts or accepts(entry, subclass, class == "ROGUE") then return item, slot end
        end

        row:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" or InCombatLockdown() then return end
            local item, slot = CurrentTarget()
            menu.pressedRow, menu.pressedItem, menu.pressedSlot = nil, item, slot
            if not item then return end
            menu.pressedRow = self
            pendingOffhand = nil
            if not Equipped(item, slot) then
                if NeedsMainForOffhand(item, slot) then EquipSet(menu.owner.choice)
                else C_Item.EquipItemByName(ItemRef(item), slot) end
            end
            UpdateDrawerStatus(menu)
        end)
        row:SetScript("PreClick", function(self, button, down)
            if button ~= "LeftButton" or down or InCombatLockdown() then return end
            local item, slot = CurrentTarget()
            local ready = menu.pressedRow == self and item and item == menu.pressedItem
                and slot == menu.pressedSlot and Equipped(item, slot)
            -- SecureTemplates targets this slot only if the action opened an item-targeting cursor.
            self:SetAttribute("*target-slot1", ready and slot or nil)
            if ready then self:SetAttribute("*macrotext1", ("/use [nocombat] item:%d"):format(entry.id)) end
            self:SetAttribute("*type1", ready and "macro" or nil)
            menu.pressedRow = nil
        end)
        row:SetScript("OnEnter", function(self)
            CancelClose()
            if not db.showConsumableTooltips then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetItemByID(entry.id)
            if accepts then GameTooltip:AddLine("Right-click to star or unstar for this hand", 1, 0.82, 0) end
            if entry.bonus then GameTooltip:AddLine("+" .. entry.bonus .. " Fishing", 0.3, 1, 0.3) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            if menu.pressedRow == self then menu.pressedRow = nil end
            HideTooltip(self)
            menu:ScheduleClose()
        end)
        row:HookScript("PostClick", function(self, button, down)
            if down or InCombatLockdown() then return end
            if button == "RightButton" and accepts and menu:IsShown() and row:IsShown() then
                local _, slot = getTarget(menu)
                if slot and slot == menu.targetSlot then
                    if db.favorites[slot] == entry.id then db.favorites[slot] = nil
                    else db.favorites[slot] = entry.id end
                    menu.pressedRow = nil
                    RefreshDrawer(menu)
                end
                return
            end
            if button ~= "LeftButton" then return end
            self:SetAttribute("*target-slot1", nil)
            if self:GetAttribute("*type1") == "macro" then
                self:SetAttribute("*type1", nil)
                menu:Hide()
                HideTooltip(self)
            elseif menu:IsShown() then
                UpdateDrawerStatus(menu)
            end
        end)
        menu.rows[#menu.rows + 1] = row
    end
    return menu
end

local function OpenWeaponDrawer(button)
    if InCombatLockdown() or CursorBusy() then return end
    -- Resolve the currently hovered icon before moving the shared drawer.
    weaponDrawer.owner = button
    if not WeaponTarget(weaponDrawer) then
        weaponDrawer:Hide()
        return
    end
    fishing.menu:Hide()
    weaponDrawer:ClearAllPoints()
    if button.isOffhand then
        weaponDrawer:SetPoint("TOP", button, "BOTTOM", 0, -3)
    else
        weaponDrawer:SetPoint("BOTTOM", button, "TOP", 0, 3)
    end
    weaponDrawer:Open(button)
    return true
end

local function CreateFishing()
    fishing = CreateFrame("Frame", "ForeverWeaponSwapFishing", bar, "BackdropTemplate")
    fishing:SetSize(FISHING_PANEL_WIDTH, COMPACT_HEIGHT)
    fishing:SetPoint("TOPLEFT", bar, "TOPLEFT", WEAPON_PANEL_WIDTH + PANEL_GAP, 0)
    SetPanelBackdrop(fishing)
    local heading = fishing:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    heading:SetPoint("TOP", 0, -3)
    heading:SetText("FISHING")

    local pole = CreateFrame("Button", "ForeverWeaponSwapFishingPole", fishing)
    fishing.pole = pole
    pole:SetPoint("TOP", 0, -18)
    pole:SetSize(36, 36)
    pole:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pole:RegisterForDrag("LeftButton")
    pole.border = pole:CreateTexture(nil, "BACKGROUND")
    pole.border:SetAllPoints()
    pole.icon = pole:CreateTexture(nil, "ARTWORK")
    pole.icon:SetPoint("TOPLEFT", 2, -2)
    pole.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    pole:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    pole:SetScript("OnReceiveDrag", DropPole)
    pole:SetScript("OnClick", function(_, mouseButton)
        if db.disableFishing then return end
        if InCombatLockdown() then Message("Fishing controls are available outside combat."); return end
        if mouseButton == "RightButton" then
            if IsShiftKeyDown() then
                db.fishingPole = nil
                fishing.menu:Hide()
                UpdateFishingIcon()
                SyncToggle()
            else
                SavePole(EquippedID())
            end
        elseif CursorItemID() then
            DropPole()
        else
            EquipPole()
        end
    end)
    pole:SetScript("OnEnter", function(self)
        if db.disableFishing or (db.fishingPole and not db.showEquipmentTooltips) then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if db.fishingPole then
            GameTooltip:SetItemByID(db.fishingPole.id)
            GameTooltip:AddLine("Left-click to equip", 1, 1, 1)
            GameTooltip:AddLine("Shift-right-click to clear", 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine("Fishing pole", 1, 0.82, 0)
        end
        GameTooltip:AddLine("Drop a pole here or right-click to save your equipped pole", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    pole:SetScript("OnLeave", HideTooltip)

    local menu = CreateItemDrawer(fishing, addon.Lures, FishingTarget, nil,
        "No lures in bags")
    fishing.menu = menu
    menu:SetPoint("TOP", fishing, "BOTTOM", 0, -3)
    local function OpenDrawer()
        if db.disableFishing or InCombatLockdown() or CursorBusy() then return end
        weaponDrawer:Hide()
        -- The pole and chevron share one hover region.
        menu:Open(fishing)
    end
    pole:HookScript("OnEnter", OpenDrawer)
    pole:HookScript("OnLeave", function() menu:ScheduleClose() end)

    local arrow = CreateFrame("Button", "ForeverWeaponSwapLures", fishing)
    arrow:SetPoint("LEFT", pole, "RIGHT", 1, 0)
    arrow:SetSize(14, 16)
    arrow:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    arrow:SetScript("OnClick", OpenDrawer)
    arrow:SetScript("OnEnter", OpenDrawer)
    arrow:SetScript("OnLeave", function() menu:ScheduleClose() end)
    ApplyAppearance()
end

local function RegisterSettings()
    local layout
    settingsCategory, layout = Settings.RegisterVerticalLayoutCategory("Forever Weapon Swap")
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Keybindings"))
    for index = 1, GetNumBindings() do
        if GetBinding(index) == "CLICK ForeverWeaponSwapToggle:LeftButton" then
            layout:AddInitializer(CreateKeybindingEntryInitializer(index))
            break
        end
    end
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Visual Settings"))
    local function Register(key, label, kind, default, onChanged)
        return Settings.RegisterProxySetting(settingsCategory, "FWS_" .. key, kind, label, default,
            function() return db[key] end,
            function(value)
                db[key] = value
                if onChanged then onChanged() end
            end)
    end
    local third = Register("thirdSet", "Enable third set", Settings.VarType.Boolean, false, function()
        if not InCombatLockdown() then ConfigureActions(); ApplyAppearance(); UpdateVisuals() end
    end)
    Settings.CreateCheckbox(settingsCategory, third, "Add a third weapon set. Combat layout changes take effect after combat.")
    Settings.CreateCheckbox(settingsCategory, Register("enchantDial", "Consumable timer dial", Settings.VarType.Boolean, true), "Show remaining enhancement time on equipped items.")
    Settings.CreateCheckbox(settingsCategory, Register("chargePulse", "Low-charge pulse", Settings.VarType.Boolean, true), "Pulse the active consumable icon at five or fewer reported charges.")
    local function Threshold(key, name, default)
        local setting = Register(key, name, Settings.VarType.Number, default, function()
            db.red = math.min(db.red, db.orange - 1)
        end)
        local options = Settings.CreateSliderOptions(key == "orange" and 2 or 1, key == "orange" and 99 or 98, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return v .. "%" end)
        Settings.CreateSlider(settingsCategory, setting, options, "Red must be below orange.")
    end
    Threshold("orange", "Orange time remaining", 30)
    Threshold("red", "Red time remaining", 15)
    local lock = Register("locked", "Lock bar position", Settings.VarType.Boolean, false)
    Settings.CreateCheckbox(settingsCategory, lock, "Prevent dragging the WEAPONS header.")
    local size = Register("scale", "Size", Settings.VarType.Number, 1, ApplyAppearance)
    local sizeOptions = Settings.CreateSliderOptions(0.6, 2, 0.05)
    local opacity = Register("opacity", "Opacity", Settings.VarType.Number, 100, ApplyAppearance)
    local opacityOptions = Settings.CreateSliderOptions(20, 100, 5)
    local label = MinimalSliderWithSteppersMixin.Label.Right
    sizeOptions:SetLabelFormatter(label, function(value) return ("%d%%"):format(math.floor(value * 100 + 0.5)) end)
    opacityOptions:SetLabelFormatter(label, function(value) return ("%d%%"):format(value) end)
    Settings.CreateSlider(settingsCategory, size, sizeOptions, "Change the size of the weapon swap bar.")
    Settings.CreateSlider(settingsCategory, opacity, opacityOptions, "Change how transparent the bar is.")
    local equipmentTooltips = Register("showEquipmentTooltips", "Show equipment tooltips", Settings.VarType.Boolean, false)
    Settings.CreateCheckbox(settingsCategory, equipmentTooltips, "Show item tooltips for weapons, off-hands, and the fishing pole.")
    local consumableTooltips = Register("showConsumableTooltips", "Show consumable tooltips", Settings.VarType.Boolean, true)
    Settings.CreateCheckbox(settingsCategory, consumableTooltips, "Show item tooltips for weapon enhancements and fishing lures.")
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Fishing"))
    local disable = Register("disableFishing", "Disable fishing", Settings.VarType.Boolean, false, function()
        ApplyAppearance()
        SyncToggle()
    end)
    Settings.CreateCheckbox(settingsCategory, disable, "Remove the fishing panel and skip the pole when cycling. The saved pole is kept.")
    local hide = Register("hideFishingInCombat", "Hide fishing in combat", Settings.VarType.Boolean, true, ApplyAppearance)
    local hideRow = Settings.CreateCheckbox(settingsCategory, hide, "Hide the fishing pole and lure arrow while in combat.")
    -- Keep the saved preference in the original form so it also works in older versions.
    local excludePole = Settings.RegisterProxySetting(settingsCategory, "FWS_excludeFishingFromCycle",
        Settings.VarType.Boolean, "Skip pole when cycling", false,
        function() return not db.includeFishingInCycle end,
        function(exclude)
            db.includeFishingInCycle = not exclude
            SyncToggle()
        end)
    local cycleRow = Settings.CreateCheckbox(settingsCategory, excludePole, "Skip the fishing pole when cycling weapon sets. Click the pole to equip it directly.")
    local function FishingEnabled() return not db.disableFishing end
    for _, row in ipairs({ hideRow, cycleRow }) do
        row:AddModifyPredicate(FishingEnabled)
        row:AddEvaluateStateCVar(disable:GetVariable())
    end
    Settings.RegisterAddOnCategory(settingsCategory)
end

local function FinishMoving()
    if not moving or InCombatLockdown() then return end
    bar:StopMovingOrSizing()
    moving = nil
    local point, _, relativePoint, x, y = bar:GetPoint()
    db.position = { point = point, relativePoint = relativePoint, x = x, y = y }
end

-- Forever supplies remaining milliseconds. Remember the longest observation per effect.
local function ReadDial(slot)
    local hand = slot == OFF_HAND and Enum.WeaponSlot.OffHand or Enum.WeaponSlot.MainHand
    local records = C_Item.GetWeaponEnchantInfo(hand)
    if not Public(records) or type(records) ~= "table" then return end
    local shortest, total
    for _, e in pairs(records) do
        if Public(e) and Public(e.hasEnchant) and e.hasEnchant and Public(e.enchantType)
            and (e.enchantType == Enum.ItemEnchantType.Temporary or e.enchantType == Enum.ItemEnchantType.Imbue)
            and Public(e.timeLeft) and type(e.timeLeft) == "number" and e.timeLeft > 0
            and Public(e.enchantID) and type(e.enchantID) == "number" then
            local seconds = e.timeLeft / 1000
            local prior = tonumber(db.enchantDurations[e.enchantID]) or 0
            local duration = math.max(seconds, prior)
            if duration ~= prior then db.enchantDurations[e.enchantID] = duration end
            if not shortest or seconds < shortest then shortest, total = seconds, duration end
        end
    end
    return shortest, total
end

local function UpdateDials()
    local hands = {}
    if db.enchantDial and C_Item.GetWeaponEnchantInfo then
        for slot = MAIN_HAND, OFF_HAND do hands[slot] = { ReadDial(slot) } end
    end
    local function Draw(button, item, slot)
        local dial = button.enchantDial
        local timing = hands[slot]
        if not item or not timing or not timing[1] or not Equipped(item, slot) then
            if dial then dial:Hide() end
            return
        end
        if not dial then
            dial = CreateFrame("Cooldown", nil, bar, "CooldownFrameTemplate")
            dial:SetAllPoints(button.icon)
            dial:SetFrameLevel(button:GetFrameLevel() + 1)
            dial:EnableMouse(false)
            dial:SetDrawEdge(false)
            dial:SetDrawBling(false)
            dial:SetHideCountdownNumbers(true)
            dial:SetSwipeTexture("Interface\\\\CHARACTERFRAME\\\\TempPortraitAlphaMask")
            button.enchantDial = dial
        end
        local remaining, duration = timing[1], timing[2]
        local percent = remaining * 100 / duration
        if percent <= db.red then dial:SetSwipeColor(1, 0.12, 0.1, 0.42)
        elseif percent <= db.orange then dial:SetSwipeColor(1, 0.52, 0.03, 0.38)
        else dial:SetSwipeColor(0.1, 0.9, 0.35, 0.32) end
        dial:SetCooldown(GetTime() + remaining - duration, duration)
        dial:Show()
    end
    for _, button in ipairs(weaponButtons) do
        Draw(button, Weapon(button.choice, button.isOffhand), button.isOffhand and OFF_HAND or MAIN_HAND)
    end
    Draw(fishing.pole, fishing:IsVisible() and db.fishingPole, MAIN_HAND)
end

local function CreateUI()
    controller = CreateFrame("Frame", "ForeverWeaponSwapController", UIParent, "SecureHandlerBaseTemplate")
    bar = CreateFrame("Frame", "ForeverWeaponSwapBar", UIParent)
    bar:SetSize(WEAPON_PANEL_WIDTH, COMPACT_HEIGHT)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    RestorePosition()

    local weaponBackdrop = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    weaponBackdrop:SetPoint("TOPLEFT", 0, 0)
    weaponBackdrop:SetPoint("BOTTOMLEFT", 0, 0)
    bar.weaponBackdrop = weaponBackdrop
    weaponBackdrop:SetWidth(WEAPON_PANEL_WIDTH)
    weaponBackdrop:SetFrameLevel(bar:GetFrameLevel())
    SetPanelBackdrop(weaponBackdrop)
    local handle = CreateFrame("Frame", nil, bar)
    handle:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    handle:SetPoint("TOPRIGHT", weaponBackdrop, "TOPRIGHT", -1, -1)
    handle:SetHeight(13)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    local label = handle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER")
    label:SetText("WEAPONS")
    handle:SetScript("OnDragStart", function()
        if not InCombatLockdown() and not db.locked then
            bar:StartMoving()
            moving = true
        end
    end)
    handle:SetScript("OnDragStop", FinishMoving)

    toggle = CreateFrame("Button", "ForeverWeaponSwapToggle", UIParent, "SecureActionButtonTemplate")
    toggle:SetSize(1, 1)
    toggle:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
    toggle:EnableMouse(false)
    toggle:RegisterForClicks("AnyUp", "AnyDown")
    toggle:SetAttribute("useOnKeyDown", false)
    toggle:SetAttribute("*type1", "macro")
    toggle:SetScript("PreClick", function(_, button, down)
        if button == "LeftButton" and not down then pendingOffhand = nil end
    end)
    controller:WrapScript(toggle, "OnClick", [[
        if down or button ~= "LeftButton" then return end
        if SecureCmdOptionParse("[nocombat] yes") then
            self:SetAttribute("*macrotext1", control:GetAttribute("peacefulMacro"))
            return
        end
        local target = control:GetAttribute("next") or 1
        local macro = control:GetAttribute("weapon" .. target)
        for i = 2, control:GetAttribute("count") do
            if macro then break end
            target = target % control:GetAttribute("count") + 1
            macro = control:GetAttribute("weapon" .. target)
        end
        self:SetAttribute("*macrotext1", macro)
        if macro then control:SetAttribute("next", target % control:GetAttribute("count") + 1) end
    ]])

    for n = 1, 6 do
        local i = n <= 3 and n or n - 3
        local offhand = n > 3
        local button = CreateFrame("Button", "ForeverWeaponSwap" .. (offhand and "Offhand" or "Choice") .. i, bar, "SecureActionButtonTemplate")
        if offhand then buttons[i].offhandButton = button else buttons[i] = button end
        weaponButtons[#weaponButtons + 1] = button
        button.choice = i
        button.isOffhand = offhand
        button:SetSize(offhand and 26 or 36, offhand and 26 or 36)
        button:SetPoint("TOPLEFT", (offhand and 12 or 7) + (i - 1) * 42, offhand and -58 or -18)
        button:RegisterForClicks("AnyUp", "AnyDown")
        button:RegisterForDrag("LeftButton")
        button:SetAttribute("useOnKeyDown", false)
        button:SetAttribute("choice", i)
        button.border = button:CreateTexture(nil, "BACKGROUND")
        button.border:SetAllPoints()
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        button.selected = button:CreateTexture(nil, "OVERLAY")
        button.selected:SetAllPoints(button.icon)
        button.selected:SetColorTexture(1, 0.82, 0, 0.15)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        -- Keep the display widget separate from the secure action button.
        local cooldown = CreateFrame("Cooldown", nil, bar, "CooldownFrameTemplate")
        cooldown:SetAllPoints(button.icon)
        cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
        cooldown:EnableMouse(false)
        cooldown:SetDrawBling(false)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawSwipe(true)
        cooldown:SetHideCountdownNumbers(true)
        button.cooldown = cooldown
        local number = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        number:SetPoint("BOTTOMRIGHT", -3, 3)
        number:SetText(offhand and "OH" or i)
        button:SetScript("PreClick", function(self, mouseButton, down)
            if down or mouseButton ~= "LeftButton" or InCombatLockdown() then return end
            pendingOffhand = nil
            self:SetAttribute("fwsDrop", CursorItemID() ~= nil)
        end)
        controller:WrapScript(button, "OnClick", [[
            if down or button ~= "LeftButton" then return end
            if SecureCmdOptionParse("[nocombat] yes") and self:GetAttribute("fwsDrop") then return false end
            local target = self:GetAttribute("choice")
            if self:GetAttribute("*type1") == "macro" then
                control:SetAttribute("next", target % control:GetAttribute("count") + 1)
            end
        ]])
        button:HookScript("PostClick", function(self, mouseButton, down)
            if down then return end
            if mouseButton == "RightButton" then
                if IsShiftKeyDown() then ClearChoice(self.choice, self.isOffhand)
                else Assign(self.choice, EquippedID(self.isOffhand and OFF_HAND or MAIN_HAND), self.isOffhand) end
            elseif mouseButton == "LeftButton" and CursorItemID() then
                ReceiveWeapon(self)
            elseif not db.weapons[self.choice] then
                Message("Drop an item here, or right-click to save the equipped item in this hand.")
            end
        end)
        button:SetScript("OnReceiveDrag", ReceiveWeapon)
        button:SetScript("OnEnter", function(self)
            local drawerOpened = OpenWeaponDrawer(self)
            Tooltip(self, drawerOpened)
        end)
        button:SetScript("OnLeave", function(self)
            HideTooltip(self)
            if weaponDrawer.owner == self and weaponDrawer:IsShown() then weaponDrawer:ScheduleClose() end
        end)
    end
    weaponDrawer = CreateItemDrawer(bar, addon.WeaponEnhancements, WeaponTarget, AcceptsEnhancement,
        "No compatible items in bags")
    bar.weaponDrawer = weaponDrawer
    CreateFishing()
    local elapsedSinceDialUpdate = 1
    bar:SetScript("OnUpdate", function(_, elapsed)
        elapsedSinceDialUpdate = elapsedSinceDialUpdate + elapsed
        if elapsedSinceDialUpdate >= 1 then
            elapsedSinceDialUpdate = 0
            UpdateDials()
        end
    end)
    ConfigureActions()
    UpdateVisuals()
end

local function ShowMacro(index)
    local text = MacroText(index)
    if not text then Message("Configure set " .. index .. " first."); return end
    if not bar.macroPanel then
        local panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        bar.macroPanel = panel
        panel:SetSize(430, 145)
        panel:SetPoint("CENTER")
        panel:SetFrameStrata("DIALOG")
        panel:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8"})
        panel:SetBackdropColor(0.05, 0.05, 0.05, 1)
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -12)
        title:SetText("Copy into a WoW macro (Ctrl+C). Escape to close.")
        local edit = CreateFrame("EditBox", nil, panel)
        panel.edit = edit
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("ChatFontNormal")
        edit:SetSize(400, 95)
        edit:SetPoint("TOPLEFT", 15, -35)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); panel:Hide() end)
    end
    bar.macroPanel:Show()
    bar.macroPanel.edit:SetText("#showtooltip item:" .. db.weapons[index].id .. "\n" .. text)
    bar.macroPanel.edit:SetFocus()
    bar.macroPanel.edit:HighlightText()
end

local function Command(text)
    if not bar then return end
    local cmd, value = text:lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "help" or cmd == "" then
        Message("Drop main-hands into 1/2 and optional off-hands below. /fws equip 1|2, toggle, save 1|2, exact 1|2, macro 1|2, settings, lock, unlock, scale 0.6-2, reset, show, hide. Shift-right-click to clear a saved slot (main hand clears the set). Slash equipping is out of combat; use UI/keybind or copied native macros in combat.")
        return
    end
    if cmd == "1" or cmd == "2" or cmd == "3" or cmd == "equip" then
        local index = tonumber(cmd == "equip" and value or cmd)
        if index ~= 1 and index ~= 2 and not (index == 3 and db.thirdSet) then Message("Specify an enabled set number."); return end
        EquipSet(index); return
    elseif cmd == "toggle" then
        if InCombatLockdown() then Message("Use the weapon cycle key in combat."); return end
        local index = NextOutOfCombat()
        if index == 4 then EquipPole()
        elseif index then EquipSet(index) end
        return
    end
    if cmd == "settings" then Settings.OpenToCategory(settingsCategory:GetID()); return end
    if InCombatLockdown() then Message("Change settings after combat."); return end
    if cmd == "save" or cmd == "exact" or cmd == "macro" then
        local index = tonumber(value)
        if index ~= 1 and index ~= 2 and not (index == 3 and db.thirdSet) then Message("Specify an enabled set number."); return end
        if cmd == "macro" then ShowMacro(index)
        else SaveEquipped(index, cmd == "exact") end
        return
    end
    if cmd == "lock" or cmd == "unlock" then
        db.locked = cmd == "lock"
        Message(db.locked and "Position locked." or "Drag the WEAPONS header to move.")
    elseif cmd == "reset" then
        db.position, db.scale, db.hidden, db.locked = nil, 1, false, false
        ApplyAppearance()
        RestorePosition()
        bar:Show()
    elseif cmd == "scale" then
        local scale = tonumber(value)
        if not scale or scale < 0.6 or scale > 2 then Message("Use /fws scale 0.6 through 2."); return end
        db.scale = scale
        ApplyAppearance()
    elseif cmd == "show" or cmd == "hide" then
        db.hidden = cmd == "hide"
        bar:SetShown(not db.hidden)
        if db.hidden then
            fishing.menu:Hide()
            weaponDrawer:Hide()
        end
    else Message("Use /fws help.") end
end

SLASH_FOREVERWEAPONSWAP1 = "/fws"
SLASH_FOREVERWEAPONSWAP2 = "/weaponswap"
SlashCmdList.FOREVERWEAPONSWAP = Command

local events = CreateFrame("Frame")
local function InitializeUI()
    CreateUI()
    RegisterSettings()
    if db.hidden then bar:Hide() end
    for _, name in ipairs({
        "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_REGEN_DISABLED",
        "PLAYER_ENTERING_WORLD", "GET_ITEM_INFO_RECEIVED", "SPELL_UPDATE_COOLDOWN",
        "ACTIONBAR_UPDATE_COOLDOWN", "CURSOR_CHANGED", "ITEM_LOCK_CHANGED",
    }) do
        events:RegisterEvent(name)
    end
    Message("Ready. /fws help for setup and keybind instructions.")
end

local function ValidID(id)
    return type(id) == "number" and id > 0 and id <= 2147483647 and id == math.floor(id)
end

local function CheckedItem(item)
    if type(item) ~= "table" or not ValidID(item.id) then return end
    if type(item.link) ~= "string" then item.link = nil end
    if item.payload ~= nil then
        if item.payload ~= ItemPayload(item.payload) or type(item.payload) ~= "string"
            or tonumber(item.payload:match("^item:(%d+)")) ~= item.id then return end
        item.variant = VariantKey(item.payload)
    else
        item.variant = nil
    end
    return item
end

local function LoadSettings()
    if type(ForeverWeaponSwapDB) ~= "table" then ForeverWeaponSwapDB = {} end
    db = ForeverWeaponSwapDB
    if type(db.weapons) ~= "table" then db.weapons = {} end
    for i = 1, 3 do
        local set = CheckedItem(db.weapons[i])
        if set then
            set.offhand = CheckedItem(set.offhand)
            if set.offhand and set.offhand.id == set.id and
                (not set.variant or not set.offhand.variant or set.variant == set.offhand.variant) then
                set.offhand = nil
            end
        end
        db.weapons[i] = set
    end
    db.fishingPole = CheckedItem(db.fishingPole)
    if type(db.enchantDurations) ~= "table" then db.enchantDurations = {} end
    if type(db.favorites) ~= "table" then db.favorites = {} end
    for hand = MAIN_HAND, OFF_HAND do
        if not ValidID(db.favorites[hand]) then db.favorites[hand] = nil end
    end
    local anchors = { TOPLEFT=true, TOP=true, TOPRIGHT=true, LEFT=true, CENTER=true, RIGHT=true,
        BOTTOMLEFT=true, BOTTOM=true, BOTTOMRIGHT=true }
    local function Finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
    local pos = db.position
    if type(pos) ~= "table" or not anchors[pos.point] or not anchors[pos.relativePoint]
        or not Finite(pos.x) or not Finite(pos.y) then db.position = nil end
    db.orange = math.max(2, math.min(99, tonumber(db.orange) or 30))
    db.red = math.max(1, math.min(db.orange - 1, tonumber(db.red) or 15))
    db.scale = math.max(0.6, math.min(2, tonumber(db.scale) or 1))
    db.opacity = math.max(20, math.min(100, tonumber(db.opacity) or 100))
    for key, default in pairs({ hideFishingInCombat=true, disableFishing=false, includeFishingInCycle=true,
        thirdSet=false, enchantDial=true, chargePulse=true, showEquipmentTooltips=false, showConsumableTooltips=true, locked=false, hidden=false }) do
        if type(db[key]) ~= "boolean" then db[key] = default end
    end
end

events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        LoadSettings()
        events:UnregisterEvent("ADDON_LOADED")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        if not InCombatLockdown() then InitializeUI() end
    elseif not bar then
        if event == "PLAYER_REGEN_ENABLED" and not InCombatLockdown() then InitializeUI() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        pendingOffhand = nil
    elseif event == "ITEM_LOCK_CHANGED" then
        FinishOffhandSwap()
        RefreshOpenDrawers()
    elseif event == "CURSOR_CHANGED" then
        UpdateOffhandVisibility()
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
        UpdateGlobalCooldown()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if arg1 == CursorItemID() then UpdateOffhandVisibility() end
        local changed, variantChanged
        local function UpdateLink(item)
            if item and item.id == arg1 then
                if not item.link then
                    local _, link = C_Item.GetItemInfo(arg1)
                    item.link = link
                end
                if item.payload then variantChanged = true end
                changed = true
            end
        end
        UpdateLink(db.fishingPole)
        for _, button in ipairs(weaponButtons) do UpdateLink(Weapon(button.choice, button.isOffhand)) end
        if variantChanged then bagVariants = nil end
        if changed then UpdateVisuals() end
        if variantChanged then SyncToggle() end
    elseif event == "BAG_UPDATE_DELAYED" then
        bagItems, bagVariants = nil, nil
        UpdateVisuals()
        SyncToggle()
        RefreshOpenDrawers(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        ConfigureActions()
        FinishMoving()
        ApplyAppearance()
        UpdateVisuals()
        SyncToggle()
    elseif event ~= "PLAYER_EQUIPMENT_CHANGED" or arg1 == MAIN_HAND or arg1 == OFF_HAND then
        if event == "PLAYER_ENTERING_WORLD" then gcdSpell = nil end
        bagItems, bagVariants = nil, nil
        if event == "PLAYER_EQUIPMENT_CHANGED" then FinishOffhandSwap() end
        RefreshOpenDrawers()
        UpdateVisuals()
        SyncToggle()
    end
end)
