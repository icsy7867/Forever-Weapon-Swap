local ADDON, addon = ...
BINDING_HEADER_FOREVERWEAPONSWAP = "Forever Weapon Swap"
_G["BINDING_NAME_CLICK ForeverWeaponSwapToggle:LeftButton"] = "Cycle Weapon Sets"

for index = 1, 2 do
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
local function Weapon(index, offhand)
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
    for index = 1, 2 do
        local main = Weapon(index, false)
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

local function IsFishingPole(id)
    if not id then return false end
    local _, _, _, _, _, class, subclass = C_Item.GetItemInfoInstant(id)
    return class == 2 and subclass == FISHING_SUBCLASS
end

local function IsWeaponSet(index)
    local set = db.weapons[index]
    return set and set.id and not IsFishingPole(set.id)
        and not (set.offhand and IsFishingPole(set.offhand.id))
end

local function EquippedChoice()
    local id = EquippedID()
    local fallback
    for i = 1, 2 do
        local set = db.weapons[i]
        if set and set.id == id then
            if set.offhand and set.offhand.id == EquippedID(OFF_HAND) then return i end
            if not set.offhand and not fallback then fallback = i end
        end
    end
    return fallback
end

local bagItems

local function Carried(id)
    if EquippedID() == id or EquippedID(OFF_HAND) == id then return true end
    if not bagItems then
        bagItems = {}
        for bag = 0, NUM_BAG_SLOTS or 4 do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local item = C_Container.GetContainerItemID(bag, slot)
                if Public(item) and item then bagItems[item] = true end
            end
        end
    end
    return bagItems[id] == true
end

local function UpdateGlobalCooldown()
    local duration
    if C_Spell.GetSpellCooldownDuration then
        -- Some Forever builds expose the Classic dummy spell instead of 61304.
        local spell = GCD_SPELL
        if C_Spell.DoesSpellExist and not C_Spell.DoesSpellExist(spell) then
            spell = CLASSIC_GCD_SPELL
        end
        duration = C_Spell.GetSpellCooldownDuration(spell)
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
    local present = pole and Carried(pole.id)
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
        local present = weapon and Carried(weapon.id)
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
    local text = "/equipslot 16 item:" .. set.id
    if set.offhand then text = text .. "\n/equipslot 17 item:" .. set.offhand.id end
    return text
end

local function NextOutOfCombat()
    local pole = not db.disableFishing and db.fishingPole
    local current = EquippedChoice() or 0
    if pole and EquippedID() == pole.id then current = 3 end
    for step = 1, 3 do
        local index = (current + step - 1) % 3 + 1
        if index == 3 then
            if db.includeFishingInCycle and current ~= 3 and pole and Carried(pole.id) then
                return index, "/equipslot [nocombat] 16 item:" .. pole.id
            end
        elseif IsWeaponSet(index) then
            return index, MacroText(index)
        end
    end
end

local function SyncToggle()
    if InCombatLockdown() then return end
    controller:SetAttribute("next", EquippedChoice() == 1 and 2 or 1)
    local _, macro = NextOutOfCombat()
    controller:SetAttribute("peacefulMacro", macro)
end

-- Rebuild only outside combat. Secure handlers own the alternating target in combat.
local function ConfigureActions()
    if not db or not controller or InCombatLockdown() then return end
    for i = 1, 2 do
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

local function ReadItem(id, offhand, main)
    if not id then return nil, "No item is equipped in that hand." end
    local _, _, _, location, _, classID = C_Item.GetItemInfoInstant(id)
    if offhand then
        if not main then return nil, "Save the main-hand weapon first." end
        local _, _, _, mainLocation = C_Item.GetItemInfoInstant(main.id)
        if mainLocation == "INVTYPE_2HWEAPON" then return nil, "A two-handed weapon cannot have an off-hand." end
        if not offhandLocations[location] or (classID ~= 2 and classID ~= 4) then
            return nil, "Choose an off-hand weapon, shield, or held off-hand item."
        end
        if main.id == id then return nil, "Two copies of the same item ID are unsupported in one set." end
    elseif IsFishingPole(id) then
        return nil, "Save fishing poles in the Fishing slot."
    elseif classID ~= 2 or not validLocations[location] then
        return nil, "Choose a one-handed or two-handed main-hand weapon."
    end
    local _, link = C_Item.GetItemInfo(id)
    return { id = id, link = link }, nil, location
end

local function RequestItemLink(item)
    if item and not item.link then C_Item.RequestLoadItemDataByID(item.id) end
end

local function SaveEquipped(index)
    for slot = MAIN_HAND, OFF_HAND do
        if IsInventoryItemLocked(slot) then
            Message("An item is moving. Wait for the swap to finish and save again.")
            return
        end
    end
    local main, err = ReadItem(EquippedID(), false)
    if not main then Message(err); return end
    local offID = GetInventoryItemID("player", OFF_HAND)
    if not Public(offID) or (not offID and GetInventoryItemTexture("player", OFF_HAND)) then
        Message("Off-hand data is unavailable. Try saving again.")
        return
    end
    if offID then
        main.offhand, err = ReadItem(offID, true, main)
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
    if not db.showEquipmentTooltips then return end
    local anchor = drawerOpened and not button.isOffhand and "ANCHOR_BOTTOM" or "ANCHOR_TOP"
    GameTooltip:SetOwner(button, anchor)
    local weapon = Weapon(button.choice, button.isOffhand)
    if weapon then
        GameTooltip:SetItemByID(weapon.id)
        if not Carried(weapon.id) then GameTooltip:AddLine("Not in your bags or equipped", 1, 0.25, 0.25) end
    elseif button.isOffhand then
        GameTooltip:AddLine("Set " .. button.choice .. " optional off-hand", 1, 0.82, 0)
        GameTooltip:AddLine("Drop the item here to save it", 0.8, 0.8, 0.8)
        GameTooltip:Show()
        return
    else
        GameTooltip:AddLine("Set " .. button.choice .. " main-hand", 1, 0.82, 0)
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
    local width = WEAPON_PANEL_WIDTH
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
    elseif not Carried(pole.id) then
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
    if mainID ~= swap.set.id then
        -- An unrelated main-hand change supersedes this request.
        if mainID and (swap.sawMain or mainID ~= swap.previousMain) then pendingOffhand = nil end
        return
    end
    swap.sawMain = true
    if IsInventoryItemLocked(MAIN_HAND) or IsInventoryItemLocked(OFF_HAND) then return end
    pendingOffhand = nil
    if EquippedID(OFF_HAND) ~= swap.offhand.id then
        C_Item.EquipItemByName("item:" .. swap.offhand.id, OFF_HAND)
    end
end

local function EquipSet(index)
    if InCombatLockdown() then Message("Slash equipping is out of combat only. Use the keybind/UI in combat, or /fws macro " .. index .. " to copy a native macro after combat."); return end
    pendingOffhand = nil
    local set = db.weapons[index]
    if not IsWeaponSet(index) then Message("Configure weapon set " .. index .. " first."); return end
    for _, item in ipairs({ set, set.offhand }) do
        if not Carried(item.id) then
            Message("Set " .. index .. " is missing " .. (item.link or ("item " .. item.id)) .. ".")
            return
        end
    end
    local previousMain = EquippedID()
    if set.offhand and EquippedID(OFF_HAND) ~= set.offhand.id then
        local swap = { index = index, set = set, offhand = set.offhand, previousMain = previousMain }
        pendingOffhand = swap
        C_Timer.After(2, function()
            if pendingOffhand == swap then
                pendingOffhand = nil
                Message("Off-hand swap timed out. Try equipping the set again.")
            end
        end)
    end
    if previousMain ~= set.id then C_Item.EquipItemByName("item:" .. set.id, MAIN_HAND) end
    FinishOffhandSwap()
    UpdateVisuals()
    SyncToggle()
end

-- A pole, a two-hander, or the target itself in slot 16 may have to move first.
local function NeedsMainForOffhand(item, slot)
    if slot ~= OFF_HAND or EquippedID(slot) == item.id then return false end
    local main = EquippedID(MAIN_HAND)
    if not main or main == item.id then return true end
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
    if not item or not Carried(item.id) then return drawerHints.missing end
    if CursorBusy() then return drawerHints.cursor end
    if IsInventoryItemLocked(slot) then return drawerHints.waiting end
    if EquippedID(slot) ~= item.id then
        if IsInventoryItemLocked(slot == MAIN_HAND and OFF_HAND or MAIN_HAND) then return drawerHints.waiting end
        if NeedsMainForOffhand(item, slot) and not Carried(Weapon(menu.owner.choice).id) then
            return drawerHints.missingMain
        end
    end
end

local function ConsumableCount(id)
    local count = C_Item.GetItemCount(id)
    if Public(count) and count and count > 0 then return count end
end

local function RefreshDrawer(menu)
    local item, slot, subclass = menu.getTarget(menu)
    local _, class = UnitClass("player")
    local blocked = DrawerBlockReason(menu, item, slot)
    local equipped = item and EquippedID(slot) == item.id
    local visible = {}
    menu.targetItem = item
    menu.targetSlot = slot
    for _, row in ipairs(menu.rows) do
        local entry = row.entry
        local count
        if slot and (not menu.accepts or menu.accepts(entry, subclass, class == "ROGUE")) then
            count = ConsumableCount(entry.id)
        end
        if count then
            visible[#visible + 1] = row
            row.count:SetText(count)
            row.icon:SetTexture(C_Item.GetItemIconByID(entry.id) or QUESTION)
            row.icon:SetDesaturated(blocked ~= nil)
            row.icon:SetAlpha(blocked and 0.45 or 1)
        end
        row:SetShown(count ~= nil)
    end

    local count = #visible
    local columns = math.max(1, math.min(6, count))
    local height = math.ceil(count / columns) * 30
    local hint
    if count == 0 then hint = menu.emptyText
    elseif blocked then hint = blocked
    elseif menu.pressedRow then hint = equipped and drawerHints.release or drawerHints.waiting
    else hint = equipped and drawerHints.apply or drawerHints.equip end
    menu.status:SetText(hint)
    -- Keep the row under the pointer when an equipment event changes the hint.
    local textWidth = count == 0 and menu.status:GetStringWidth() or menu.hintWidth
    local width = math.max(8 + columns * 30, math.ceil(textWidth) + 16)
    menu:SetSize(width, 24 + height)
    for index, row in ipairs(visible) do
        local column = (index - 1) % columns
        local line = math.floor((index - 1) / columns)
        local lineColumns = math.min(columns, count - line * columns)
        local left = (width - lineColumns * 30) / 2 + 1
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", left + column * 30, -5 - line * 30)
    end
end

local function RefreshOpenDrawers()
    if InCombatLockdown() then return end
    if fishing.menu:IsShown() then RefreshDrawer(fishing.menu) end
    if weaponDrawer:IsShown() then RefreshDrawer(weaponDrawer) end
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
    menu.rows = {}

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
    end
    menu:SetScript("OnEnter", CancelClose)
    menu:SetScript("OnLeave", menu.ScheduleClose)
    menu:SetScript("OnHide", function(self)
        self.pressedRow = nil
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
        row:RegisterForClicks("LeftButtonUp")
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
            if EquippedID(slot) ~= item.id then
                if NeedsMainForOffhand(item, slot) then EquipSet(menu.owner.choice)
                else C_Item.EquipItemByName("item:" .. item.id, slot) end
            end
            RefreshDrawer(menu)
        end)
        row:SetScript("PreClick", function(self, button, down)
            if button ~= "LeftButton" or down or InCombatLockdown() then return end
            local item, slot = CurrentTarget()
            local ready = menu.pressedRow == self and item and item == menu.pressedItem
                and slot == menu.pressedSlot and EquippedID(slot) == item.id
            if ready then
                self:SetAttribute("*macrotext1",
                    ("/use [nocombat] item:%d\n/use [nocombat] %d"):format(entry.id, slot))
            end
            self:SetAttribute("*type1", ready and "macro" or nil)
            menu.pressedRow = nil
        end)
        row:SetScript("OnEnter", function(self)
            CancelClose()
            if not db.showConsumableTooltips then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetItemByID(entry.id)
            if entry.bonus then GameTooltip:AddLine("+" .. entry.bonus .. " Fishing", 0.3, 1, 0.3) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            if menu.pressedRow == self then menu.pressedRow = nil end
            HideTooltip(self)
            menu:ScheduleClose()
        end)
        row:HookScript("PostClick", function(self, button, down)
            if button ~= "LeftButton" or down or InCombatLockdown() then return end
            if self:GetAttribute("*type1") == "macro" then
                self:SetAttribute("*type1", nil)
                menu:Hide()
                HideTooltip(self)
            elseif menu:IsShown() then
                RefreshDrawer(menu)
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
        if db.disableFishing or not db.showEquipmentTooltips then return end
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
    settingsCategory = Settings.RegisterVerticalLayoutCategory("Forever Weapon Swap")
    local function Register(key, label, kind, default, onChanged)
        return Settings.RegisterProxySetting(settingsCategory, "FWS_" .. key, kind, label, default,
            function() return db[key] end,
            function(value)
                db[key] = value
                if onChanged then onChanged() end
            end)
    end
    local size = Register("scale", "Size", Settings.VarType.Number, 1, ApplyAppearance)
    local sizeOptions = Settings.CreateSliderOptions(0.6, 2, 0.05)
    local opacity = Register("opacity", "Opacity", Settings.VarType.Number, 100, ApplyAppearance)
    local opacityOptions = Settings.CreateSliderOptions(20, 100, 5)
    local label = MinimalSliderWithSteppersMixin.Label.Right
    sizeOptions:SetLabelFormatter(label, function(value) return ("%d%%"):format(math.floor(value * 100 + 0.5)) end)
    opacityOptions:SetLabelFormatter(label, function(value) return ("%d%%"):format(value) end)
    Settings.CreateSlider(settingsCategory, size, sizeOptions, "Change the size of the weapon swap bar.")
    Settings.CreateSlider(settingsCategory, opacity, opacityOptions, "Change how transparent the bar is.")
    local disable = Register("disableFishing", "Disable fishing", Settings.VarType.Boolean, false, function()
        ApplyAppearance()
        SyncToggle()
    end)
    Settings.CreateCheckbox(settingsCategory, disable, "Remove the fishing panel and skip the pole when cycling. The saved pole is kept.")
    local hide = Register("hideFishingInCombat", "Hide fishing controls in combat", Settings.VarType.Boolean, true, ApplyAppearance)
    Settings.CreateCheckbox(settingsCategory, hide, "Hide the fishing pole and lure arrow while in combat.")
    local equipmentTooltips = Register("showEquipmentTooltips", "Show equipment tooltips", Settings.VarType.Boolean, false)
    Settings.CreateCheckbox(settingsCategory, equipmentTooltips, "Show item tooltips for weapons, off-hands, and the fishing pole.")
    local consumableTooltips = Register("showConsumableTooltips", "Show consumable tooltips", Settings.VarType.Boolean, true)
    Settings.CreateCheckbox(settingsCategory, consumableTooltips, "Show item tooltips for weapon enhancements and fishing lures.")
    -- Keep the saved preference in the original form so it also works in older versions.
    local excludePole = Settings.RegisterProxySetting(settingsCategory, "FWS_excludeFishingFromCycle",
        Settings.VarType.Boolean, "Exclude fishing pole from weapon cycle", false,
        function() return not db.includeFishingInCycle end,
        function(exclude)
            db.includeFishingInCycle = not exclude
            SyncToggle()
        end)
    Settings.CreateCheckbox(settingsCategory, excludePole, "Skip the fishing pole when cycling weapon sets. Click the pole to equip it directly.")
    Settings.RegisterAddOnCategory(settingsCategory)
end

local function FinishMoving()
    if not moving or InCombatLockdown() then return end
    bar:StopMovingOrSizing()
    moving = nil
    local point, _, relativePoint, x, y = bar:GetPoint()
    db.position = { point = point, relativePoint = relativePoint, x = x, y = y }
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
        if not macro then
            target = 3 - target
            macro = control:GetAttribute("weapon" .. target)
        end
        self:SetAttribute("*macrotext1", macro)
        if macro then control:SetAttribute("next", 3 - target) end
    ]])

    for n = 1, 4 do
        local i = n <= 2 and n or n - 2
        local offhand = n > 2
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
                control:SetAttribute("next", 3 - target)
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
        Message("Drop main-hands into 1/2 and optional off-hands below. /fws equip 1|2, toggle, save 1|2, macro 1|2, settings, lock, unlock, scale 0.6-2, reset, show, hide. Slash equipping is out of combat; use UI/keybind or copied native macros in combat.")
        return
    end
    if cmd == "1" or cmd == "2" or cmd == "equip" then
        local index = tonumber(cmd == "equip" and value or cmd)
        if index ~= 1 and index ~= 2 then Message("Use /fws equip 1 or /fws equip 2."); return end
        EquipSet(index); return
    elseif cmd == "toggle" then
        if InCombatLockdown() then Message("Use the weapon cycle key in combat."); return end
        local index = NextOutOfCombat()
        if index == 3 then EquipPole()
        elseif index then EquipSet(index) end
        return
    end
    if cmd == "settings" then Settings.OpenToCategory(settingsCategory:GetID()); return end
    if InCombatLockdown() then Message("Change settings after combat."); return end
    if cmd == "save" or cmd == "macro" then
        local index = tonumber(value)
        if index ~= 1 and index ~= 2 then Message("Specify set 1 or 2."); return end
        if cmd == "macro" then ShowMacro(index)
        else SaveEquipped(index) end
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

events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        ForeverWeaponSwapDB = ForeverWeaponSwapDB or {}
        db = ForeverWeaponSwapDB
        db.weapons = db.weapons or {}
        db.scale = tonumber(db.scale) or 1
        db.scale = math.max(0.6, math.min(2, db.scale))
        db.opacity = math.max(20, math.min(100, tonumber(db.opacity) or 100))
        if db.hideFishingInCombat == nil then db.hideFishingInCombat = true end
        if db.disableFishing == nil then db.disableFishing = false end
        if db.includeFishingInCycle == nil then db.includeFishingInCycle = true end
        if db.showEquipmentTooltips == nil then db.showEquipmentTooltips = false end
        if db.showConsumableTooltips == nil then db.showConsumableTooltips = true end
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
        local changed
        local function UpdateLink(item)
            if item and item.id == arg1 then
                if not item.link then
                    local _, link = C_Item.GetItemInfo(arg1)
                    item.link = link
                end
                changed = true
            end
        end
        UpdateLink(db.fishingPole)
        for _, button in ipairs(weaponButtons) do UpdateLink(Weapon(button.choice, button.isOffhand)) end
        if changed then UpdateVisuals() end
    elseif event == "BAG_UPDATE_DELAYED" then
        bagItems = nil
        UpdateVisuals()
        SyncToggle()
        RefreshOpenDrawers()
    elseif event == "PLAYER_REGEN_ENABLED" then
        FinishMoving()
        ApplyAppearance()
        UpdateVisuals()
        SyncToggle()
    elseif event ~= "PLAYER_EQUIPMENT_CHANGED" or arg1 == MAIN_HAND or arg1 == OFF_HAND then
        bagItems = nil
        if event == "PLAYER_EQUIPMENT_CHANGED" then FinishOffhandSwap() end
        RefreshOpenDrawers()
        UpdateVisuals()
        SyncToggle()
    end
end)
