local frames, messages, equipped, combat, cursor = {}, {}, 100, false, nil
local equippedOff
local carried = {100, 200, 300, 400, 500, 600}
local metadata = { [100] = 'INVTYPE_2HWEAPON', [200] = 'INVTYPE_WEAPON', [300] = 'INVTYPE_WEAPONMAINHAND', [400] = 'INVTYPE_SHIELD', [500] = 'INVTYPE_HOLDABLE', [600] = 'INVTYPE_WEAPONOFFHAND', [700] = 'INVTYPE_2HWEAPON' }
_G.print = function(s) messages[#messages+1] = s end
UIParent = {}
SlashCmdList = {}
NUM_BAG_SLOTS = 4
local function noop() end
local methods = {}
function methods:SetAttribute(k,v)
    assert(not combat or self.secureWrite, 'insecure protected attribute mutation in combat')
    self.attrs[k] = v
end
function methods:GetAttribute(k) return self.attrs[k] end
function methods:WrapScript(frame, script, code) frame.wrapped = code; frame.control = self end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:HookScript(name, fn)
    local before = self.scripts[name]
    self.scripts[name] = function(...)
        if before then before(...) end
        fn(...)
    end
end
function methods:UnregisterEvent(e) self.events[e] = nil end
function methods:RegisterEvent(e) self.events[e] = true end
function methods:SetPoint(...) self.point = {...} end
function methods:GetPoint() return table.unpack(self.point or {'CENTER',UIParent,'CENTER',0,0}) end
function methods:SetShown(v)
    if self.template == 'SecureActionButtonTemplate' then
        assert(not combat, 'secure button visibility changed in combat')
    end
    self.shown = v
end
function methods:IsShown() return self.shown end
function methods:SetHeight(height) self.height = height end
function methods:GetHeight() return self.height end
function methods:SetSize(width,height) self.width = width; self.height = height end
function methods:SetWidth(width) self.width = width end
function methods:GetWidth() return self.width end
function methods:StartMoving() self.moving = true end
function methods:StopMovingOrSizing() assert(not combat); self.moving = false end
function methods:Show() self.shown = true end
function methods:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:SetTexture(v) self.texture = v end
function methods:SetColorTexture(...) self.color = {...} end
function methods:SetDesaturated(v) self.desaturated = v end
function methods:SetScale(v) self.scale = v end
function methods:SetAlpha(v) self.alpha = v end
function methods:CreateTexture() return setmetatable({attrs={},scripts={}}, {__index=methods}) end
methods.CreateFontString = methods.CreateTexture
function methods:SetText(s) self.text=s end
function methods:GetStringWidth() return #self.text * 6 end
function methods:GetFrameLevel() return 1 end
function methods:SetCooldownFromDurationObject(duration, clearIfZero)
    assert(self.frameType == 'Cooldown' and clearIfZero == true)
    self.duration = duration
end
function methods:Clear() self.duration = nil end
for _, n in ipairs({'SetFrameStrata','SetClampedToScreen','SetMovable','SetBackdrop','SetBackdropColor','SetBackdropBorderColor','ClearAllPoints','EnableMouse','RegisterForDrag','RegisterForClicks','SetAllPoints','SetTexCoord','SetHighlightTexture','SetFrameLevel','SetNormalFontObject','SetHighlightFontObject','SetNormalTexture','SetDrawBling','SetDrawEdge','SetDrawSwipe','SetHideCountdownNumbers','SetMultiLine','SetAutoFocus','SetFontObject','SetFocus','ClearFocus','HighlightText'}) do methods[n] = noop end
function CreateFrame(frameType,name,parent,template)
 local f = setmetatable({attrs={},scripts={},events={},shown=true,name=name,template=template,frameType=frameType,parent=parent}, {__index=methods})
 frames[#frames+1]=f
 if name then _G[name]=f end
 return f
end
function GetTime() return 100 end
function InCombatLockdown() return combat end
function SecureCmdOptionParse(options)
    assert(options == '[nocombat] yes')
    if not combat then return 'yes' end
end
local restricted = {}
function issecretvalue(value) return rawequal(value, restricted) end
local locked, unknownOff
local asyncEquip, queuedMain, missingLink
local itemRequests = {}
local timers, hovered = {}, {}
local function Timer(seconds, fn)
    local timer = { delay = seconds, fn = fn }
    function timer:Cancel() self.cancelled = true end
    timers[#timers + 1] = timer
    return timer
end
C_Timer = { After = Timer, NewTimer = Timer, NewTicker = Timer }
function methods:IsMouseOver() return hovered[self] == true end
local function RunTimers(maxDelay)
    for _, timer in ipairs(timers) do
        if not timer.cancelled and timer.delay <= maxDelay then
            timer:Cancel()
            timer.fn()
        end
    end
end
local lureCounts = {}
local playerClass = "WARRIOR"
function UnitClass() return playerClass, playerClass end
local weaponSubclass = { [100] = 8, [200] = 7, [300] = 4, [600] = 15, [700] = 20 }
function IsInventoryItemLocked(slot) return locked == slot end
function GetInventoryItemTexture(_,slot) return slot==17 and unknownOff or nil end
function GetInventoryItemID(_,slot) if slot==17 then return equippedOff else return equipped end end
function GetCursorInfo() if cursor then return 'item',cursor end end
function ClearCursor() cursor=nil end
function IsShiftKeyDown() return _G.shift or false end
C_Item = {
 EquipItemByName=function(item,slot) assert(not combat, 'slash combat equip'); if slot==16 then
    if asyncEquip then queuedMain=tonumber(item:match('item:(%d+)')); return end
    equipped=tonumber(item:match('item:(%d+)')); if metadata[equipped]=='INVTYPE_2HWEAPON' then equippedOff=nil end else equippedOff=tonumber(item:match('item:(%d+)')) end end,
 GetItemInfoInstant=function(id) return id,'Weapon','Weapon',metadata[id],123, (id == 400 or id == 500) and 4 or 2, weaponSubclass[id] end,
 GetItemInfo=function(id) if not lureCounts[id] and id ~= missingLink then return 'Weapon '..id, 'item:'..id end end,
 RequestLoadItemDataByID=function(id) itemRequests[id]=true end,
 GetItemCount=function(id) return lureCounts[id] or 0 end,
 GetItemIconByID=function(id) return id end,
}
local bagReads = 0
C_Container = {
 GetContainerNumSlots=function(bag) return bag==0 and #carried or 0 end,
 GetContainerItemID=function(_,slot) bagReads = bagReads + 1; return carried[slot] end,
}
local gcdSpellExists = true
local gcdDuration, gcdRequested
C_Spell = {
 DoesSpellExist=function(id) return id ~= 61304 or gcdSpellExists end,
 GetSpellCooldownDuration=function(id) gcdRequested=id; return gcdDuration end,
}
local drivers = {}
function RegisterStateDriver(frame, state, value)
    assert(not combat, 'state driver reconfigured during combat')
    drivers[frame] = drivers[frame] or {}
    drivers[frame][state] = value
    if state == 'visibility' then frame:SetShown(value ~= 'hide') end
end
local function ChangeCombat(active)
    combat = active
    for frame, states in pairs(drivers) do
        if states.visibility then
            frame:SetShown(states.visibility ~= 'hide'
                and not (active and states.visibility:find('[combat] hide', 1, true)))
        end
        if states.combat then
            local env = {self=frame, newstate=active and 'active' or 'idle'}
            assert(load(frame.attrs['_onstate-combat'],'combat state','t',env))()
        end
    end
end
local settings, openedCategory = {}, nil
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
local layoutRows
function GetNumBindings() return 2 end
function GetBinding(index) return index == 2 and "CLICK ForeverWeaponSwapToggle:LeftButton" or "JUMP" end
function CreateKeybindingEntryInitializer(index) return {bindingIndex=index} end
function CreateSettingsListSectionHeaderInitializer(name) return {heading=name} end
Settings = {
 VarType = { Number = 1, Boolean = 2 },
 RegisterVerticalLayoutCategory = function() layoutRows = {}; return { GetID = function() return 42 end }, { AddInitializer = function(_, row) table.insert(layoutRows, row) end } end,
 RegisterProxySetting = function(_,key,kind,label,default,get,set)
    local setting = {label=label, default=default, get=get, set=set}
    function setting:GetVariable() return key end
    settings[key] = setting
    return setting
 end,
 CreateSliderOptions = function(min, max) return { min=min, max=max, SetLabelFormatter=noop } end,
 CreateSlider = function(_,setting,options) setting.options = options end,
 CreateCheckbox = function(_,setting)
    setting.checkbox = true
    function setting:AddModifyPredicate(predicate) self.enabled = predicate end
    function setting:AddEvaluateStateCVar(variable) self.watch = variable end
    return setting
 end,
 RegisterAddOnCategory = noop,
 OpenToCategory = function(id) openedCategory = id end,
}
GameTooltip = {
    SetOwner = function(self, owner) self.owner = owner end,
    IsOwned = function(self, owner) return self.owner == owner end,
    SetItemByID = function(self, id) self.item = id end,
    AddLine = noop,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.owner, self.item, self.shown = nil, nil, false end,
}
local function LoadAddon()
    local namespace = {}
    local dataSource = addonSource:gsub("ForeverWeaponSwap%.lua$", "Consumables.lua")
    assert(loadfile(dataSource))("ForeverWeaponSwap", namespace)
    assert(loadfile(addonSource))("ForeverWeaponSwap", namespace)
end
LoadAddon()
local eventFrame = frames[1]
local function event(e,arg) eventFrame.scripts.OnEvent(eventFrame,e,arg) end
event('ADDON_LOADED','ForeverWeaponSwap')
local one,two,toggle=ForeverWeaponSwapChoice1,ForeverWeaponSwapChoice2,ForeverWeaponSwapToggle
local control=ForeverWeaponSwapController
local appliedItem, appliedSlot, rejectConsumable
local function release(button, mouse, down, fail)
 mouse = mouse or 'LeftButton'
 if button.scripts.PreClick then button.scripts.PreClick(button,mouse,down) end
 local cancelled
 if button.wrapped then
   local env=setmetatable({self=button,control=button.control,button=mouse or 'LeftButton',down=down}, {__index=_G})
   button.secureWrite=true; button.control.secureWrite=true
   cancelled = assert(load(button.wrapped,'secure snippet','t',env))() == false
   button.secureWrite=nil; button.control.secureWrite=nil
 end
 if not cancelled and not down and mouse=='LeftButton' and button.attrs['*type1']=='macro' then
   local macro=button.attrs['*macrotext1']
   if macro and not fail then
     local item = macro:match('^/use %[nocombat%] item:(%d+)$')
     if item and not combat and not rejectConsumable and button.attrs['*target-slot1'] then
       appliedItem, appliedSlot = tonumber(item), button.attrs['*target-slot1']
     end
     for slot,id in macro:gsub('%[nocombat%] ', ''):gmatch('/equipslot (%d+) item:(%d+)') do
       slot,id=tonumber(slot),tonumber(id)
       if slot==16 then equipped=id; if metadata[id]=='INVTYPE_2HWEAPON' then equippedOff=nil end else equippedOff=id end
       event('PLAYER_EQUIPMENT_CHANGED',slot)
     end
   end
 end
 if button.scripts.PostClick then button.scripts.PostClick(button,mouse or 'LeftButton',down) end
end
local function press(button, mouse)
    button.scripts.OnMouseDown(button, mouse or 'LeftButton')
end
local function click(button, mouse, down, fail)
    if button.scripts.OnMouseDown then press(button, mouse) end
    release(button, mouse, down, fail)
end
click(one,'RightButton'); assert(ForeverWeaponSwapDB.weapons[1].id==100)
cursor=200; two.scripts.OnReceiveDrag(two); assert(cursor==nil)
assert(one.selected.shown and not two.selected.shown,'actual equipped highlight')
click(toggle,nil,true); assert(equipped==100,'key down must not equip')
click(toggle); assert(equipped==200 and two.selected.shown)
click(toggle); assert(equipped==100 and one.selected.shown)
click(two); click(toggle); assert(equipped==100,'manual selection sync')
equipped=200; event('PLAYER_EQUIPMENT_CHANGED',16); click(toggle); assert(equipped==100,'external equip sync outside combat')
cursor=400; two.scripts.OnReceiveDrag(two); assert(cursor==400 and ForeverWeaponSwapDB.weapons[2].id==200,'reject shield')
cursor=nil
combat=true
click(toggle); assert(equipped==200 and two.selected.shown,'combat equip')
click(toggle); assert(equipped==100 and one.selected.shown,'combat alternation')
click(two,'RightButton'); assert(ForeverWeaponSwapDB.weapons[2].id==200,'combat setup guarded')
click(toggle,nil,nil,true); assert(equipped==100 and one.selected.shown,'failed equip must not change highlight')
click(two); click(toggle); assert(equipped==100,'direct choice recovers combat sequence')
combat=false; event('PLAYER_REGEN_ENABLED')
shift=true; click(two,'RightButton'); shift=false
assert(ForeverWeaponSwapDB.weapons[2]==nil)
click(toggle); assert(equipped==100,'single configured choice')
carried={200}; equipped=300; event('BAG_UPDATE_DELAYED'); assert(one.icon.desaturated and not one.selected.shown,'missing weapon')
SlashCmdList.FOREVERWEAPONSWAP('scale 1.5'); assert(ForeverWeaponSwapDB.scale==1.5)
SlashCmdList.FOREVERWEAPONSWAP('hide'); assert(not ForeverWeaponSwapBar.shown)
SlashCmdList.FOREVERWEAPONSWAP('reset'); assert(ForeverWeaponSwapBar.shown and ForeverWeaponSwapDB.weapons[1].id==100)

-- Off-hand configuration and full-set matching.
carried={100,200,300,400,500,600}
cursor=200; two.scripts.OnReceiveDrag(two)
local oh1,oh2=ForeverWeaponSwapOffhand1,ForeverWeaponSwapOffhand2
cursor=400; oh1.scripts.OnReceiveDrag(oh1)
assert(cursor==400 and not ForeverWeaponSwapDB.weapons[1].offhand,'reject offhand on two-hander')
cursor=300; one.scripts.OnReceiveDrag(one)
cursor=400; oh1.scripts.OnReceiveDrag(oh1)
assert(cursor==nil and ForeverWeaponSwapDB.weapons[1].offhand.id==400)
cursor=600; oh2.scripts.OnReceiveDrag(oh2)
assert(ForeverWeaponSwapDB.weapons[2].offhand.id==600)
click(one); assert(equipped==300 and equippedOff==400 and one.selected.shown and oh1.selected.shown)
click(toggle); assert(equipped==200 and equippedOff==600 and two.selected.shown)
click(oh1); assert(equipped==300 and equippedOff==400,'offhand icon equips full set')
equippedOff=500; event('PLAYER_EQUIPMENT_CHANGED',17)
assert(not one.selected.shown and not oh1.selected.shown,'partial set not highlighted')
combat=true
click(two); assert(equipped==200 and equippedOff==600 and two.selected.shown)
click(toggle); assert(equipped==300 and equippedOff==400)
SlashCmdList.FOREVERWEAPONSWAP('equip 2'); assert(equipped==300,'slash command combat guard')
combat=false; event('PLAYER_REGEN_ENABLED')
SlashCmdList.FOREVERWEAPONSWAP('equip 2'); assert(equipped==200 and equippedOff==600)
SlashCmdList.FOREVERWEAPONSWAP('toggle'); assert(equipped==300 and equippedOff==400)
SlashCmdList.FOREVERWEAPONSWAP('macro 1')
assert(ForeverWeaponSwapBar.macroPanel.edit.text:find('/equipslot 17 item:400',1,true),'native macro export')
shift=true; click(oh1,'RightButton'); shift=false
assert(not ForeverWeaponSwapDB.weapons[1].offhand,'clear optional offhand')
equippedOff=500
SlashCmdList.FOREVERWEAPONSWAP('1'); assert(equippedOff==500,'absent offhand leaves current offhand alone')
SlashCmdList.FOREVERWEAPONSWAP('save 1'); assert(ForeverWeaponSwapDB.weapons[1].offhand.id==500,'capture equipped pair')
cursor=100; one.scripts.OnReceiveDrag(one)
assert(not ForeverWeaponSwapDB.weapons[1].offhand,'twohand replacement clears incompatible offhand')
click(one); assert(equipped==100 and equippedOff==nil)
carried={100,200,300}; event('BAG_UPDATE_DELAYED'); SlashCmdList.FOREVERWEAPONSWAP('equip 2'); assert(equipped==100,'missing offhand blocks slash partial swap')
io.write('PASS: original behavior, paired sets, shields, held offhands, dual wield, partial highlight, combat guards, slash commands, macro export, optional offhand, twohand transition, missing items\n')

local before = ForeverWeaponSwapDB.weapons[2]
equipped, equippedOff = 300, 300
SlashCmdList.FOREVERWEAPONSWAP('save 2')
assert(before == ForeverWeaponSwapDB.weapons[2], 'invalid pair overwrote prior set')
equippedOff=nil
unknownOff=123
SlashCmdList.FOREVERWEAPONSWAP('save 2')
assert(before == ForeverWeaponSwapDB.weapons[2], 'unloaded off-hand overwrote prior set')
unknownOff=nil; locked=17
SlashCmdList.FOREVERWEAPONSWAP('save 2')
assert(before == ForeverWeaponSwapDB.weapons[2], 'locked hand overwrote prior set')
locked=nil
SlashCmdList.FOREVERWEAPONSWAP('save 2')
assert(ForeverWeaponSwapDB.weapons[2].id==300 and not ForeverWeaponSwapDB.weapons[2].offhand)
bagReads=0
event('BAG_UPDATE_DELAYED')
assert(bagReads==#carried, 'expected one full bag scan per refresh')
event('GET_ITEM_INFO_RECEIVED',99999)
event('GET_ITEM_INFO_RECEIVED',100)
assert(bagReads==#carried,'item info caused redundant bag scan')
io.write('PASS: rejected saves preserve the prior set, empty off-hand capture, bag lookup reuse\n')

assert(eventFrame.events.SPELL_UPDATE_COOLDOWN and eventFrame.events.ACTIONBAR_UPDATE_COOLDOWN)
local opaqueDuration = setmetatable({}, {__index=function() error('restricted timer read') end})
gcdDuration=opaqueDuration
combat=true
event('SPELL_UPDATE_COOLDOWN')
assert(gcdRequested==61304 and one.cooldown.duration==opaqueDuration and two.cooldown.duration==opaqueDuration)
assert(oh1.cooldown.duration==nil and oh2.cooldown.duration==nil, 'empty off-hands must stay clear')
assert(one.cooldown.parent==ForeverWeaponSwapBar, 'cooldown must stay separate from its secure button')
gcdSpellExists=false
event('PLAYER_ENTERING_WORLD')
event('ACTIONBAR_UPDATE_COOLDOWN')
assert(gcdRequested==29515 and one.cooldown.duration==opaqueDuration)
gcdDuration=nil
event('SPELL_UPDATE_COOLDOWN')
assert(one.cooldown.duration==nil and two.cooldown.duration==nil, 'clear an ended GCD')
combat=false
gcdDuration=opaqueDuration
cursor=400
oh2.scripts.OnReceiveDrag(oh2)
assert(oh2.cooldown.duration==opaqueDuration, 'newly populated off-hand gets the active sweep')
shift=true; click(oh2,'RightButton'); shift=false
assert(oh2.cooldown.duration==nil, 'cleared off-hand loses the sweep')
io.write('PASS: shared GCD display, Classic dummy fallback, restricted duration handling, off-hand assignment/clearing\n')

local bar = ForeverWeaponSwapBar
assert(eventFrame.events.CURSOR_CHANGED)
assert(not oh1.shown and not oh2.shown and bar.height==60, 'empty slots collapse')
cursor=400; event('CURSOR_CHANGED')
assert(not oh1.shown and oh2.shown and bar.height==91, 'show valid target only; set 1 uses a two-hander')
cursor=nil; event('CURSOR_CHANGED')
assert(not oh2.shown and bar.height==60, 'cancelled pickup collapses the row')
cursor=300; event('CURSOR_CHANGED')
assert(not oh2.shown, 'main-hand-only item does not reveal off-hand target')
cursor=400; event('CURSOR_CHANGED')
local beforePickupEquip = equipped
click(oh2)
assert(equipped==beforePickupEquip and ForeverWeaponSwapDB.weapons[2].offhand.id==400 and cursor==nil,
    'click to place on revealed slot saves without equipping')
assert(oh2.shown and bar.height==91, 'populated off-hand remains visible')
shift=true; click(oh2,'RightButton'); shift=false
assert(not oh2.shown and bar.height==60, 'clearing last off-hand collapses the row')
combat=true
cursor=400; event('CURSOR_CHANGED')
assert(not oh2.shown and bar.height==60, 'combat does not reveal empty secure slots')
combat=false; event('PLAYER_REGEN_ENABLED')
assert(oh2.shown and bar.height==91, 'leaving combat restores visibility for current cursor')
oh2.scripts.OnReceiveDrag(oh2)
assert(oh2.shown and cursor==nil and ForeverWeaponSwapDB.weapons[2].offhand.id==400,
    'dragging to revealed slot populates it')
io.write('PASS: compact mode, compatible cursor targets, cancellation, click/drag assignment and combat guards\n')

local pole = ForeverWeaponSwapFishingPole
local fishingPanel = ForeverWeaponSwapFishing
local arrow = ForeverWeaponSwapLures
local menu = fishingPanel.menu
local slash = SlashCmdList.FOREVERWEAPONSWAP
assert(settings.FWS_hideFishingInCombat.get() == true and bar.alpha == 1)
assert(settings.FWS_scale.options.min == 0.6 and settings.FWS_opacity.options.max == 100)
slash('settings')
assert(openedCategory==42)
settings.FWS_scale.set(1.35)
settings.FWS_opacity.set(65)
assert(bar.scale==1.35 and bar.alpha==0.65 and ForeverWeaponSwapDB.opacity==65)
slash('scale 1.1')
assert(settings.FWS_scale.get()==1.1 and bar.scale==1.1)

cursor=300
pole.scripts.OnReceiveDrag(pole)
assert(not ForeverWeaponSwapDB.fishingPole and cursor==300, 'reject non-pole item')
carried={100,200,300,400,700}
event('BAG_UPDATE_DELAYED')
cursor=700
pole.scripts.OnReceiveDrag(pole)
assert(ForeverWeaponSwapDB.fishingPole.id==700 and not cursor)
lureCounts[6529], lureCounts[6533] = 3, 2
hovered[fishingPanel]=true
pole.scripts.OnEnter(pole)
assert(menu.shown and menu.status.text=='Hold to equip')
local showGear = settings.FWS_showEquipmentTooltips
local showConsumables = settings.FWS_showConsumableTooltips
assert(showGear.checkbox and showGear.default == false and showGear.get() == false)
assert(showConsumables.checkbox and showConsumables.default == true and showConsumables.get() == true)
assert(not GameTooltip.shown, 'pole tooltip defaults off while its drawer opens')
showGear.set(true)
pole.scripts.OnEnter(pole)
assert(GameTooltip.shown and GameTooltip.item == 700)
showGear.set(false)
pole.scripts.OnLeave(pole)
assert(not GameTooltip.shown)
local lureRow = menu.rows[1]
lureRow.scripts.OnEnter(lureRow)
assert(GameTooltip.shown and GameTooltip.item == 6533, 'lure tooltip defaults on')
lureRow.scripts.OnLeave(lureRow)
showConsumables.set(false)
lureRow.scripts.OnEnter(lureRow)
assert(not GameTooltip.shown and menu.shown, 'lure tooltip can be disabled independently')
showConsumables.set(true)
assert(menu.rows[1].shown and not menu.rows[1].icon.desaturated and not menu.rows[1].attrs['*type1'])
hovered[fishingPanel]=nil
pole.scripts.OnLeave(pole)
menu.scripts.OnEnter(menu)
RunTimers(0.22)
assert(menu.shown, 'moving to drawer cancels close')
menu.scripts.OnLeave(menu)
RunTimers(0.22)
assert(not menu.shown)
arrow.scripts.OnClick(arrow)
assert(menu.shown)
pole.scripts.OnClick(pole,'LeftButton')
event('PLAYER_EQUIPMENT_CHANGED',16)
assert(equipped==700 and menu.shown and pole.border.color[1]==1)
assert(not menu.rows[1].icon.desaturated and menu.status.text=='Click to apply')

lureCounts[6529], lureCounts[6533] = 3, 2
arrow.scripts.OnClick(arrow)
assert(menu.shown and menu.rows[1].shown and not menu.rows[2].shown)
assert(menu.rows[#menu.rows].shown and menu.rows[1].count.text==2)
click(menu.rows[1])
assert(menu.rows[1].attrs['*macrotext1']=='/use [nocombat] item:6533')
assert(appliedItem == 6533 and appliedSlot == 16)
assert(not menu.shown, 'close menu after selecting lure')
arrow.scripts.OnClick(arrow)
lureCounts[6533]=0
event('BAG_UPDATE_DELAYED')
assert(not menu.rows[1].shown and menu.rows[#menu.rows].shown)
assert(menu.width < 140 and menu.width >= menu.status:GetStringWidth() + 16,
    'a single lure uses a compact drawer with room for its status')
shift=true; click(two,'RightButton'); shift=false
assert(not ForeverWeaponSwapDB.weapons[2])
ChangeCombat(true)
assert(not fishingPanel.shown and not menu.shown and bar.shown)
click(toggle)
assert(equipped==100, 'swap returns from pole to the only configured set in combat')
click(toggle)
assert(equipped==100, 'swap never picks the empty set or the fishing slot')
ChangeCombat(false); event('PLAYER_REGEN_ENABLED')
assert(fishingPanel.shown and not menu.shown)
settings.FWS_hideFishingInCombat.set(false)
ChangeCombat(true)
assert(fishingPanel.shown and not menu.shown, 'keep controls visible when opted out')
ChangeCombat(false); event('PLAYER_REGEN_ENABLED')
pole.scripts.OnClick(pole,'LeftButton')
event('PLAYER_EQUIPMENT_CHANGED',16)
slash('toggle')
assert(equipped==100, 'slash toggle returns to set 1 from fishing')
local excludePole = settings.FWS_excludeFishingFromCycle
local disableFishing = settings.FWS_disableFishing
assert(excludePole.checkbox and excludePole.default == false and excludePole.get() == false)
assert(disableFishing.checkbox and disableFishing.default == false and not disableFishing.get())
click(toggle)
assert(equipped==700, 'one set cycles to the saved pole outside combat')
click(toggle)
assert(equipped==100, 'pole cycles back to the only configured set')
cursor=200
two.scripts.OnReceiveDrag(two)
click(toggle)
assert(equipped==200, 'set 1 cycles to set 2')
click(toggle)
assert(equipped==700, 'set 2 cycles to fishing')
click(toggle)
assert(equipped==100, 'pole cycles to set 1')
excludePole.set(true)
assert(excludePole.get() and not ForeverWeaponSwapDB.includeFishingInCycle)
click(toggle); click(toggle)
assert(equipped==100, 'disabled option cycles only through weapon sets')
click(toggle)
assert(equipped==200)
assert(fishingPanel.shown, 'exclusion leaves the pole visible')
pole.scripts.OnClick(pole,'LeftButton')
event('PLAYER_EQUIPMENT_CHANGED',16)
assert(equipped==700, 'excluded pole can still be equipped directly')
click(toggle); click(toggle)
assert(equipped==200, 'cycle leaves an excluded pole for the weapon sets')
excludePole.set(false)

-- Disable fishing while the next cycle choice is the pole and its drawer is open.
arrow.scripts.OnEnter(arrow)
assert(menu.shown and bar:GetWidth() == 167)
local savedPole = ForeverWeaponSwapDB.fishingPole
disableFishing.set(true)
assert(bar:GetWidth() == 92 and not fishingPanel.shown and not menu.shown)
assert(not control.attrs.peacefulMacro:find('item:700', 1, true), 'remove the cached pole action')
pole.scripts.OnClick(pole, 'LeftButton')
arrow.scripts.OnEnter(arrow)
assert(equipped == 200 and not menu.shown, 'disabled fishing controls cannot act')
click(toggle)
assert(equipped == 100, 'keybind skips the pole while fishing is disabled')
slash('toggle'); slash('toggle')
assert(equipped == 100, 'slash cycle skips the pole too')
ChangeCombat(true)
ChangeCombat(false); event('PLAYER_REGEN_ENABLED')
assert(not fishingPanel.shown, 'returning from combat does not reveal disabled fishing')
disableFishing.set(false)
assert(fishingPanel.shown and bar:GetWidth() == 167 and ForeverWeaponSwapDB.fishingPole == savedPole)
click(toggle); click(toggle); click(toggle)
assert(equipped == 100, 'reenabling fishing restores the previous cycle')
click(toggle)
assert(equipped == 200)

carried={100,200,300,400}
event('BAG_UPDATE_DELAYED')
click(toggle)
assert(equipped==100, 'skip missing saved pole')
carried={100,200,300,400,700}
event('BAG_UPDATE_DELAYED')
slash('toggle'); slash('toggle')
assert(equipped==700, 'slash toggle includes fishing when enabled')
shift=true; click(two,'RightButton'); shift=false
shift=true; click(one,'RightButton'); shift=false
pole.scripts.OnClick(pole,'LeftButton')
event('PLAYER_EQUIPMENT_CHANGED',16)
click(toggle); slash('toggle')
assert(equipped==700 and toggle.attrs['*macrotext1']==nil, 'no configured weapon sets is a no-op')
io.write('PASS: fishing pole setup and equip, lure listing and native action, combat visibility, settings, empty-set fallback\n')

-- A cursor click on an occupied icon saves the item without equipping the old set.
cursor=200
one.scripts.OnReceiveDrag(one)
cursor=300
missingLink=300
click(one)
assert(equipped==700 and ForeverWeaponSwapDB.weapons[1].id==300 and not cursor)
assert(itemRequests[300] and not ForeverWeaponSwapDB.weapons[1].link)
missingLink=nil
event('GET_ITEM_INFO_RECEIVED',300)
assert(ForeverWeaponSwapDB.weapons[1].link=='item:300')

cursor=400
oh1.scripts.OnReceiveDrag(oh1)
asyncEquip=true
slash('equip 1')
assert(queuedMain==300 and not equippedOff, 'do not equip off-hand before main arrives')
equipped=queuedMain
locked=16
event('PLAYER_EQUIPMENT_CHANGED',16)
assert(not equippedOff, 'do not equip off-hand before hands unlock')
locked=nil
event('ITEM_LOCK_CHANGED')
assert(equippedOff==400, 'after main-hand confirmation, equip saved off-hand')
equipped,equippedOff=700,nil
slash('equip 1')
ChangeCombat(true)
event('PLAYER_REGEN_DISABLED')
ChangeCombat(false)
event('PLAYER_REGEN_ENABLED')
equipped=queuedMain
event('PLAYER_EQUIPMENT_CHANGED',16)
assert(not equippedOff, 'no off-hand request after entering combat')
equipped=700
slash('equip 1')
RunTimers(2)
equipped=queuedMain
event('PLAYER_EQUIPMENT_CHANGED',16)
assert(not equippedOff and messages[#messages]:find('timed out',1,true))
asyncEquip=false

local handle
for _, frame in ipairs(frames) do
    if frame.scripts.OnDragStart then handle=frame; break end
end
handle.scripts.OnDragStart(handle)
assert(bar.moving)
ChangeCombat(true)
handle.scripts.OnDragStop(handle)
assert(bar.moving, 'never call protected stop during combat')
ChangeCombat(false)
event('PLAYER_REGEN_ENABLED')
assert(not bar.moving and ForeverWeaponSwapDB.position, 'stop deferred drag after combat')

local priorBar=ForeverWeaponSwapBar
excludePole.set(true)
disableFishing.set(true)
showGear.set(true)
showConsumables.set(false)
ChangeCombat(true)
LoadAddon()
local loginFrame=frames[#frames]
loginFrame.scripts.OnEvent(loginFrame,'ADDON_LOADED','ForeverWeaponSwap')
assert(loginFrame.events.PLAYER_REGEN_ENABLED and ForeverWeaponSwapBar==priorBar)
ChangeCombat(false)
loginFrame.scripts.OnEvent(loginFrame,'PLAYER_REGEN_ENABLED')
assert(ForeverWeaponSwapBar~=priorBar)
assert(ForeverWeaponSwapChoice1.attrs['*macrotext1']:find('/equipslot 17 item:400',1,true))
assert(ForeverWeaponSwapController.attrs.weapon1, 'combat toggle configured after deferral')
assert(settings.FWS_excludeFishingFromCycle.get(), 'saved false inclusion survives reload')
assert(settings.FWS_disableFishing.get() and not ForeverWeaponSwapFishing.shown
    and ForeverWeaponSwapBar:GetWidth() == 92, 'disabled fishing survives reload')
settings.FWS_disableFishing.set(false)
assert(settings.FWS_showEquipmentTooltips.get() and not settings.FWS_showConsumableTooltips.get(),
    'both tooltip preferences survive reload')
io.write('PASS: drawer hover and lure actions, occupied-slot assignment, item cache, async off-hand equip, combat login/drag recovery\n')

-- Each enhancement drawer resolves a hand, filters by weapon class, and rechecks on click.
local mainButton, offButton = ForeverWeaponSwapChoice1, ForeverWeaponSwapOffhand1
local drawer = ForeverWeaponSwapBar.weaponDrawer
local fishDrawer = ForeverWeaponSwapFishing.menu
local function Row(menu, id)
    for _, row in ipairs(menu.rows) do
        if row.entry.id == id then return row end
    end
    error("missing catalog item " .. id)
end
assert(#drawer.rows == 42, "all catalog rows loaded")
local sharp = Row(drawer, 12404)
local blunt = Row(drawer, 12643)
local oil = Row(drawer, 20749)
local poison = Row(drawer, 8928)
local elemental = Row(drawer, 18262)
local bait = Row(fishDrawer, 268880)
lureCounts[12404], lureCounts[12643], lureCounts[20749] = 8, 3, 1
lureCounts[8928], lureCounts[18262], lureCounts[268880] = 2, 4, 1

-- A mace and its shield were saved by the prior scenario.
equipped, equippedOff = 300, 400
mainButton.scripts.OnEnter(mainButton)
assert(drawer.shown and blunt.shown and oil.shown and elemental.shown)
assert(not sharp.shown and not poison.shown and blunt.count.text == 3)
assert(GameTooltip.shown and GameTooltip.item == 300)
mainButton.scripts.OnLeave(mainButton)
blunt.scripts.OnEnter(blunt)
assert(not GameTooltip.shown, 'consumable setting also controls weapon enhancement tooltips')
settings.FWS_showConsumableTooltips.set(true)
blunt.scripts.OnEnter(blunt)
assert(GameTooltip.shown and GameTooltip.item == 12643)
click(blunt)
assert(appliedItem == 12643 and appliedSlot == 16 and not drawer.shown)
offButton.scripts.OnEnter(offButton)
assert(not drawer.shown, "shield has no drawer")
assert(GameTooltip.shown and GameTooltip.item == 400, 'equipment setting includes off-hands')
offButton.scripts.OnLeave(offButton)
settings.FWS_showEquipmentTooltips.set(false)

-- A dagger is saved and equipped in the off-hand. A rogue can use poison.
cursor=600
offButton.scripts.OnReceiveDrag(offButton)
equippedOff=600
playerClass="ROGUE"
offButton.scripts.OnEnter(offButton)
assert(drawer.shown and sharp.shown and poison.shown and oil.shown and not blunt.shown)
assert(not GameTooltip.shown, 'disabling off-hand tooltips leaves the drawer available')
click(poison)
assert(appliedItem == 8928 and appliedSlot == 17)

-- Swapping away between opening and clicking must not consume an item.
offButton.scripts.OnEnter(offButton)
press(sharp)
equippedOff=400
appliedItem, appliedSlot = nil, nil
release(sharp)
assert(not appliedItem and not sharp.attrs['*type1'])
local activeEvents
for _, frame in ipairs(frames) do
    if frame.events.ITEM_LOCK_CHANGED then activeEvents=frame end
end
activeEvents.scripts.OnEvent(activeEvents,"PLAYER_EQUIPMENT_CHANGED",17)
assert(sharp.shown and sharp.icon.desaturated and drawer.status.text=="Item missing")
equippedOff=600
activeEvents.scripts.OnEvent(activeEvents,"PLAYER_EQUIPMENT_CHANGED",17)
locked=17
click(sharp)
assert(not appliedItem, "cannot apply while hand is locked")
locked=nil
cursor=100
click(sharp)
assert(not appliedItem, "cannot apply while holding an item")
cursor=nil
ChangeCombat(true)
assert(not drawer.shown)
click(sharp)
assert(not appliedItem, "enhancements never apply in combat")
ChangeCombat(false)

equipped=700
ForeverWeaponSwapLures.scripts.OnEnter(ForeverWeaponSwapLures)
assert(fishDrawer.shown and bait.shown and not bait.attrs['*type1'])
click(bait)
assert(appliedItem == 268880 and appliedSlot == 16)
io.write("PASS: 42 enhancement IDs, sharp/blunt filtering, rogue gating, correct hands, stale/locked/cursor/combat guards, and Secret Bait\n")

-- Drive actual press/release edges separately to cover latency and cancellation.
local function update(e, slot)
    activeEvents.scripts.OnEvent(activeEvents, e, slot)
end
carried = {100, 200, 300, 400, 600, 700}
update("BAG_UPDATE_DELAYED")
local function openPole()
    ForeverWeaponSwapLures.scripts.OnEnter(ForeverWeaponSwapLures)
end
equipped, equippedOff = 300, 600
openPole()
appliedItem = nil
press(bait)
assert(equipped == 700 and not equippedOff and not appliedItem)
assert(fishDrawer.status.text == "Release to apply")
release(bait)
assert(appliedItem == 268880 and appliedSlot == 16 and not fishDrawer.shown)

offButton.scripts.OnEnter(offButton)
click(poison)
assert(equipped == 300 and equippedOff == 600 and appliedItem == 8928 and appliedSlot == 17,
    "off-hand poison restores a usable main hand after fishing")

equipped, equippedOff = 200, 400
offButton.scripts.OnEnter(offButton)
click(sharp)
assert(equipped == 200 and equippedOff == 600 and appliedItem == 12404 and appliedSlot == 17,
    "an off-hand swap preserves a compatible main hand")

mainButton.scripts.OnEnter(mainButton)
click(blunt)
assert(equipped == 300 and equippedOff == 600 and appliedItem == 12643 and appliedSlot == 16)

asyncEquip = true
openPole()
appliedItem = nil
press(bait)
assert(equipped == 300 and queuedMain == 700 and fishDrawer.status.text == "Wait for the swap")
local waitingWidth = fishDrawer.width
release(bait)
assert(not appliedItem and fishDrawer.shown)
equipped, equippedOff = queuedMain, nil
update("PLAYER_EQUIPMENT_CHANGED", 16)
RunTimers(2)
assert(not appliedItem and fishDrawer.status.text == "Click to apply", "events and timers never consume")
assert(fishDrawer.width == waitingWidth, 'status changes keep the lure icon in place')
click(bait)
assert(appliedItem == 268880 and appliedSlot == 16)

-- A held press can span both the equipment notification and the final unlock.
mainButton.scripts.OnEnter(mainButton)
appliedItem = nil
press(oil)
assert(queuedMain == 300)
equipped, locked = queuedMain, 16
update("PLAYER_EQUIPMENT_CHANGED", 16)
assert(drawer.status.text == "Wait for the swap")
locked = nil
update("ITEM_LOCK_CHANGED")
assert(drawer.status.text == "Release to apply" and not appliedItem)
release(oil)
assert(appliedItem == 20749 and appliedSlot == 16)
asyncEquip = false

-- A rejected oil swap must leave another compatible weapon untouched.
equipped = 200
mainButton.scripts.OnEnter(mainButton)
local equip = C_Item.EquipItemByName
local requested
C_Item.EquipItemByName = function(item, slot) requested = { item, slot } end
appliedItem = nil
click(oil)
assert(requested[1] == "item:300" and requested[2] == 16)
assert(equipped == 200 and not appliedItem and drawer.shown)
C_Item.EquipItemByName = equip
press(oil)
assert(equipped == 300)
locked = 16
release(oil)
assert(not appliedItem and drawer.shown)
locked = nil
click(oil, "RightButton")
assert(not appliedItem)

-- Releasing on a different hand, after bag depletion, or across combat cannot apply.
appliedItem = nil
mainButton.scripts.OnEnter(mainButton)
press(oil)
equippedOff = 600
offButton.scripts.OnEnter(offButton)
release(oil)
assert(not appliedItem)
press(oil)
lureCounts[20749] = 0
release(oil)
assert(not appliedItem)
press(poison)
ChangeCombat(true)
release(poison)
ChangeCombat(false)
offButton.scripts.OnEnter(offButton)
release(poison)
assert(not appliedItem)
io.write("PASS: same-click pole, main-hand and off-hand equip/application, delayed release, retry and cancellation\n")

-- Exercise the current addon instance and use both public cycling entry points.
local devDB = ForeverWeaponSwapDB
local devSlash = SlashCmdList.FOREVERWEAPONSWAP
local devToggle = ForeverWeaponSwapToggle
local function refreshBags() update("BAG_UPDATE_DELAYED") end
devDB.disableFishing, devDB.includeFishingInCycle = false, true
devDB.fishingPole = { id = 700 }
devDB.weapons = { {id=200}, {id=300, offhand={id=400}} }
equipped, equippedOff, carried = 200, nil, {200,300,700}
refreshBags()
assert(ForeverWeaponSwapController.attrs.peacefulMacro:find("item:700", 1, true))
click(devToggle)
assert(equipped == 700)
equipped=200
devSlash("toggle")
assert(equipped == 700)
devSlash("2")
assert(messages[#messages]:find("missing", 1, true))
devDB.weapons = { {id=200,offhand={id=400}}, {id=200} }
equipped, equippedOff = 200, 400
refreshBags()
assert(ForeverWeaponSwapController.attrs.peacefulMacro:find("item:700", 1, true))
devSlash("toggle")
assert(equipped == 700)
devDB.disableFishing=true
equipped, equippedOff = 200, 400
refreshBags()
assert(not ForeverWeaponSwapController.attrs.peacefulMacro)
devDB.disableFishing=false
local realEquip = C_Item.EquipItemByName
local requests = 0
C_Item.EquipItemByName = function(ref, slot)
    if slot == 17 then requests = requests + 1 else realEquip(ref,slot) end
end
equipped, equippedOff, carried = 300, nil, {200,300,400,700}
refreshBags()
devSlash("1")
update("ITEM_LOCK_CHANGED")
assert(requests == 1 and equipped == 200 and not equippedOff)
RunTimers(2)
assert(messages[#messages]:find("Main hand equipped",1,true))
local beforeMessages = #messages
devSlash("1")
equippedOff=400
update("PLAYER_EQUIPMENT_CHANGED",17)
RunTimers(2)
assert(requests == 2 and #messages == beforeMessages)
C_Item.EquipItemByName = realEquip
io.write("PASS: missing and overlapping sets advance the cycle, final off-hand confirmation and timeout\n")

-- No protected click on right-click. Independent favorites survive changes of drawer owner.
Enum = {WeaponSlot={MainHand=0, OffHand=1}, ItemEnchantType={Temporary=2,Imbue=3}}
devDB.favorites = {}
local askedSlot, timeLeft, charges = nil, 75000, 4
C_Item.GetWeaponEnchantInfo = function(hand)
    askedSlot = hand
    return {{hasEnchant=true, enchantType=1}, {hasEnchant=true, enchantType=2,
        timeLeft=timeLeft, charges=charges, enchantIconID=123},
        {hasEnchant=true, enchantType=3, timeLeft=10000, enchantIconID=987}}
end
devDB.weapons[1]={id=300, offhand={id=600}}
equipped, equippedOff, carried=300,600,{200,300,600,700}
lureCounts[20749], lureCounts[8928] = 3, 2
refreshBags()
mainButton.scripts.OnEnter(mainButton)
assert(askedSlot==0 and drawer.enchant.text:find("2m",1,true) and drawer.enchant.text:find("×4",1,true)
    and drawer.enchant.text:find("|T987:14|t 10s",1,true))
timeLeft, charges = 12000, restricted
drawer.ticker.fn()
assert(drawer.enchant.text:find("12s",1,true) and not drawer.enchant.text:find("×",1,true))
appliedItem=nil
click(oil, "RightButton")
assert(devDB.favorites[16]==20749 and drawer.visible[1]==oil and oil.star.shown and not appliedItem)
offButton.scripts.OnEnter(offButton)
assert(askedSlot==1 and not oil.star.shown)
if devDB.favorites[17]==8928 then click(poison,"RightButton") end
click(poison, "RightButton")
assert(devDB.favorites[17]==8928 and devDB.favorites[16]==20749 and drawer.visible[1]==poison)
local liveCount = C_Item.GetItemCount
local reads=0
C_Item.GetItemCount = function(id) reads=reads+1; return liveCount(id) end
update("ITEM_LOCK_CHANGED")
assert(reads==0)
rejectConsumable=true
click(poison)
assert(not appliedItem and poison.attrs['*macrotext1']=='/use [nocombat] item:8928'
    and not poison.attrs['*target-slot1'] and not drawer.ticker)
assert(reads>=2, "press and release still verify item count")
rejectConsumable=false
C_Item.GetItemCount = function() return restricted end
offButton.scripts.OnEnter(offButton)
assert(#drawer.visible==0)
C_Item.GetItemCount=liveCount
devDB.fishingPole=nil
openPole()
assert(fishDrawer.status.text=="Save a fishing pole first" and #fishDrawer.visible==0)
devDB.fishingPole={id=700}
equipped=300
openPole()
assert(fishDrawer.enchant.text=="")
equipped=700
update("PLAYER_EQUIPMENT_CHANGED",16)
assert(askedSlot==0 and fishDrawer.enchant.text:find("12s",1,true))
local ticker=fishDrawer.ticker
fishDrawer:Hide()
assert(ticker.cancelled)
assert(layoutRows[1].heading=="Keybindings" and layoutRows[2].bindingIndex==2)
assert(layoutRows[3].heading=="Visual Settings" and layoutRows[4].heading=="Fishing")
assert(settings.FWS_hideFishingInCombat.watch=="FWS_disableFishing")
settings.FWS_disableFishing.set(true)
assert(not settings.FWS_excludeFishingFromCycle.enabled() and not settings.FWS_hideFishingInCombat.enabled())
settings.FWS_disableFishing.set(false)
assert(settings.FWS_excludeFishingFromCycle.enabled())
settings.FWS_locked.set(true)
assert(devDB.locked)
io.write("PASS: per-hand status, favorites, guarded native targeting, lock-event costs and settings dependencies\n")

-- The experimental exact command captures and targets real equipped links.
local refA, refB = "item:200:101:::::5::60", "item:200:202:::::5::60"
local handLinks, bagLinks = {[16]=refA, [17]=refB}, {}
function GetInventoryItemLink(_,slot) return handLinks[slot] end
C_Container.GetContainerItemLink=function(_,slot) return bagLinks[slot] end
equipped, equippedOff = 200,200
devSlash("exact 1")
local exact=devDB.weapons[1]
assert(exact.payload==refA and exact.offhand.payload==refB)
local exactMacro="/equipslot 16 "..refA.."\n/equipslot 17 "..refB
assert(mainButton.attrs['*macrotext1']==exactMacro)
devSlash("macro 1")
assert(ForeverWeaponSwapBar.macroPanel.edit.text:find(exactMacro,1,true))
handLinks[17]=refA
devSlash("exact 1")
assert(devDB.weapons[1]==exact, "reject indistinguishable copies without losing the saved pair")
handLinks[17]=restricted
devSlash("exact 1")
assert(devDB.weapons[1]==exact)
equipped,equippedOff=300,nil
handLinks={}
carried,bagLinks={200,200,300},{refA,refB}
refreshBags()
assert(not mainButton.icon.desaturated and not offButton.icon.desaturated)
local requestedRefs={}
C_Item.EquipItemByName=function(ref,slot)
    requestedRefs[slot]=ref
    handLinks[slot]=ref
    if slot==16 then equipped=200 else equippedOff=200 end
end
devSlash("1")
assert(requestedRefs[16]==refA and requestedRefs[17]==refB and mainButton.selected.shown)
-- Moving a different copy of the same ID into slot 17 between press and release must not poison it.
offButton.scripts.OnEnter(offButton)
appliedItem=nil
press(poison)
handLinks[17]=refA
release(poison)
assert(not appliedItem)
C_Item.EquipItemByName=realEquip
bagLinks[2]=nil
refreshBags()
assert(offButton.icon.desaturated and not mainButton.selected.shown)
local getID=GetInventoryItemID
GetInventoryItemID=function() return restricted end
update("PLAYER_EQUIPMENT_CHANGED",16)
assert(not mainButton.selected.shown)
GetInventoryItemID=getID
io.write("PASS: exact variant capture, saved macro, bag availability, paired equip and wrong-copy rejection\n")

-- Damage to one saved record cannot prevent another set from loading.
devDB.weapons={ {id=300, offhand="invalid"}, {id=200,payload="item:999:100"} }
devDB.position={point="INVALID",relativePoint="CENTER",x=0,y=0}
devDB.fishingPole="invalid"
devDB.favorites={[16]=8928,[17]=-1}
devDB.showEquipmentTooltips=false
LoadAddon()
local reload=frames[#frames]
reload.scripts.OnEvent(reload,"ADDON_LOADED","ForeverWeaponSwap")
assert(devDB.weapons[1].id==300 and not devDB.weapons[1].offhand and not devDB.weapons[2])
assert(not devDB.position and not devDB.fishingPole and devDB.favorites[16]==8928 and not devDB.favorites[17])
assert(devDB.showEquipmentTooltips==false)
ForeverWeaponSwapChoice2.scripts.OnEnter(ForeverWeaponSwapChoice2)
assert(GameTooltip:IsOwned(ForeverWeaponSwapChoice2) and GameTooltip.shown)
io.write("PASS: damaged saved data recovers per entry and empty slots offer setup help\n")

-- Check set 3 through its public commands and settings, then drive the icon timer.
local third = settings.FWS_thirdSet
assert(not third.get() and not ForeverWeaponSwapChoice3.shown)
third.set(true)
equipped, equippedOff = 300, nil
SlashCmdList.FOREVERWEAPONSWAP("save 3")
assert(devDB.weapons[3].id == 300 and ForeverWeaponSwapChoice3.shown)
equipped = 200
SlashCmdList.FOREVERWEAPONSWAP("3")
assert(equipped == 300)
third.set(false)
assert(not ForeverWeaponSwapChoice3.shown and not ForeverWeaponSwapChoice3.attrs['*type1'] and devDB.weapons[3].id==300)
function methods:IsVisible() return self.shown end
function methods:SetSwipeColor(r,g,b,a) self.tint={r,g,b,a} end
function methods:SetCooldown(start,duration) self.span=duration end
methods.SetSwipeTexture=noop
local ms=100000
C_Item.GetWeaponEnchantInfo=function() return {{hasEnchant=true, enchantType=2, enchantID=999, timeLeft=ms}} end
local function tick() ForeverWeaponSwapBar.scripts.OnUpdate(nil,1) end
tick()
local dial=ForeverWeaponSwapChoice1.enchantDial
assert(dial.shown and dial.span==100 and dial.tint[2]==0.9)
ms=30000; tick(); assert(dial.tint[2]==0.52)
ms=15000; tick(); assert(dial.tint[2]==0.12)
settings.FWS_enchantDial.set(false); tick(); assert(not dial.shown)
io.write("PASS: optional third set, secure action removal and dial thresholds\n")
