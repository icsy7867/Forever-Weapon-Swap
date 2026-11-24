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
function methods:GetFrameLevel() return 1 end
function methods:SetCooldownFromDurationObject(duration, clearIfZero)
    assert(self.frameType == 'Cooldown' and clearIfZero == true)
    self.duration = duration
end
function methods:Clear() self.duration = nil end
for _, n in ipairs({'SetFrameStrata','SetClampedToScreen','SetMovable','SetBackdrop','SetBackdropColor','SetBackdropBorderColor','ClearAllPoints','EnableMouse','RegisterForDrag','RegisterForClicks','SetAllPoints','SetTexCoord','SetHighlightTexture','SetFrameLevel','SetWidth','SetNormalFontObject','SetHighlightFontObject','SetNormalTexture','SetDrawBling','SetDrawEdge','SetDrawSwipe','SetHideCountdownNumbers','SetMultiLine','SetAutoFocus','SetFontObject','SetFocus','ClearFocus','HighlightText'}) do methods[n] = noop end
function CreateFrame(frameType,name,parent,template)
 local f = setmetatable({attrs={},scripts={},events={},shown=true,name=name,template=template,frameType=frameType,parent=parent}, {__index=methods})
 frames[#frames+1]=f
 if name then _G[name]=f end
 return f
end
function InCombatLockdown() return combat end
function SecureCmdOptionParse(options)
    assert(options == '[nocombat] yes')
    if not combat then return 'yes' end
end
function issecretvalue() return false end
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
C_Timer = { After = Timer, NewTimer = Timer }
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
 GetItemInfoInstant=function(id) return id,'Weapon','Weapon',metadata[id],123, (id == 400 or id == 500) and 4 or 2, id == 700 and 20 or nil end,
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
    if state == 'visibility' then frame:Show() end
end
local function ChangeCombat(active)
    combat = active
    for frame, states in pairs(drivers) do
        if states.visibility then
            frame:SetShown(not (active and states.visibility:find('[combat] hide', 1, true)))
        end
        if states.combat then
            local env = {self=frame, newstate=active and 'active' or 'idle'}
            assert(load(frame.attrs['_onstate-combat'],'combat state','t',env))()
        end
    end
end
local settings, openedCategory = {}, nil
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
Settings = {
 VarType = { Number = 1, Boolean = 2 },
 RegisterVerticalLayoutCategory = function() return { GetID = function() return 42 end } end,
 RegisterProxySetting = function(_,key,kind,label,default,get,set)
    local setting = {label=label, default=default, get=get, set=set}
    settings[key] = setting
    return setting
 end,
 CreateSliderOptions = function(min, max) return { min=min, max=max, SetLabelFormatter=noop } end,
 CreateSlider = function(_,setting,options) setting.options = options end,
 CreateCheckbox = function(_,setting) setting.checkbox = true end,
 RegisterAddOnCategory = noop,
 OpenToCategory = function(id) openedCategory = id end,
}
GameTooltip=setmetatable({}, {__index=function() return noop end})
assert(loadfile(addonSource))('ForeverWeaponSwap')
local eventFrame = frames[1]
local function event(e,arg) eventFrame.scripts.OnEvent(eventFrame,e,arg) end
event('ADDON_LOADED','ForeverWeaponSwap')
local one,two,toggle=ForeverWeaponSwapChoice1,ForeverWeaponSwapChoice2,ForeverWeaponSwapToggle
local control=ForeverWeaponSwapController
local function click(button, mouse, down, fail)
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
     for slot,id in macro:gsub('%[nocombat%] ', ''):gmatch('/equipslot (%d+) item:(%d+)') do
       slot,id=tonumber(slot),tonumber(id)
       if slot==16 then equipped=id; if metadata[id]=='INVTYPE_2HWEAPON' then equippedOff=nil end else equippedOff=id end
       event('PLAYER_EQUIPMENT_CHANGED',slot)
     end
   end
 end
 if button.scripts.PostClick then button.scripts.PostClick(button,mouse or 'LeftButton',down) end
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
assert(menu.shown and menu.status.text=='Equip pole first')
assert(menu.rows[1].shown and menu.rows[1].icon.desaturated and not menu.rows[1].attrs['*type1'])
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
assert(not menu.rows[1].icon.desaturated and menu.rows[1].attrs['*type1']=='macro')

lureCounts[6529], lureCounts[6533] = 3, 2
arrow.scripts.OnClick(arrow)
assert(menu.shown and menu.rows[1].shown and not menu.rows[2].shown)
assert(menu.rows[#menu.rows].shown and menu.rows[1].count.text==2)
assert(menu.rows[1].attrs['*macrotext1']=='/use [nocombat] item:6533\n/use [nocombat] 16')
menu.rows[1].scripts.PostClick(menu.rows[1],'LeftButton',false)
assert(not menu.shown, 'close menu after selecting lure')
arrow.scripts.OnClick(arrow)
lureCounts[6533]=0
event('BAG_UPDATE_DELAYED')
assert(not menu.rows[1].shown and menu.rows[#menu.rows].shown)
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
assert(settings.FWS_includeFishingInCycle.get() == true, 'fishing in cycle defaults on')
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
settings.FWS_includeFishingInCycle.set(false)
click(toggle); click(toggle)
assert(equipped==100, 'disabled option cycles only through weapon sets')
click(toggle)
assert(equipped==200)
settings.FWS_includeFishingInCycle.set(true)
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
ChangeCombat(true)
assert(loadfile(addonSource))('ForeverWeaponSwap')
local loginFrame=frames[#frames]
loginFrame.scripts.OnEvent(loginFrame,'ADDON_LOADED','ForeverWeaponSwap')
assert(loginFrame.events.PLAYER_REGEN_ENABLED and ForeverWeaponSwapBar==priorBar)
ChangeCombat(false)
loginFrame.scripts.OnEvent(loginFrame,'PLAYER_REGEN_ENABLED')
assert(ForeverWeaponSwapBar~=priorBar)
assert(ForeverWeaponSwapChoice1.attrs['*macrotext1']:find('/equipslot 17 item:400',1,true))
assert(ForeverWeaponSwapController.attrs.weapon1, 'combat toggle configured after deferral')
io.write('PASS: drawer hover and disabled lures, occupied-slot assignment, item cache, async off-hand equip, combat login/drag recovery\n')
