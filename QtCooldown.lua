-----------------------------------------------------------------------------------------------
-- QtCooldown v2.0 by Ninix
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- QtCooldown Module Definition
-----------------------------------------------------------------------------------------------
local QtCooldown = {} 

local VERSION_NOTE = "v2.0 [30 June 2014]"
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
local mathfloor, mathpow, mathabs = math.floor, math.pow, math.abs
local tremove, tinsert = table.remove, table.insert
local strformat = string.format
local osclock = os.clock

function QtCooldown:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
    return o
end

function QtCooldown:Init()
    Apollo.RegisterAddon(self, true, "QtCooldown", {})
    self.bars = {}
    self.profiles = {}
	self:SetupTables()
end

function QtCooldown:OnSave(saveLevel)
	if saveLevel ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return nil
	end

	self:SaveBarPositions()
	return self.profiles
end

function QtCooldown:OnRestore(saveLevel, savedVars)
	if saveLevel ~= GameLib.CodeEnumAddonSaveLevel.Account then
		return
	end

	if savedVars ~= nil then
		for k, v in pairs(savedVars) do
			self.profiles[k] = v
		end
	end

	self.variablesLoaded = true

	--_G["qt"] = self
end
 
function QtCooldown:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("QtCooldown.xml")
	Apollo.LoadSprites("QtSprites.xml", "QtSprites")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)

	if (GameLib.GetPlayerUnit()) then
		self:OnCharacterCreated()
	else
		Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
	end
	
end

function QtCooldown:OnDocLoaded()
	Apollo.RegisterSlashCommand("qtcooldown", "OnSlashCommand", self)
	Apollo.RegisterSlashCommand("qtc", "OnSlashCommand", self)
end

function QtCooldown:OnCharacterCreated()
	if (not self.variablesLoaded) then
		self.timerGetPlayerUnit = ApolloTimer.Create(0.5, false, "OnCharacterCreated", self)
		self.variablesLoaded = true
		return
	end

	self.timerCycleIcons = ApolloTimer.Create(0.75, true, "CycleOverlappingWindows", self)
	self.timerUpdateUi = ApolloTimer.Create(0.02, true, "OnUiRedraw", self)
	self.timerUpdateTracker = ApolloTimer.Create(0.5, true, "UpdateTrackedItems", self)
	self.timerUpdateLas = ApolloTimer.Create(1, false, "GetLasAbilities", self)
	self.timerUpdateUi:Stop()

	Apollo.RegisterEventHandler("UnitEnteredCombat", "OnUnitEnteredCombat", self)
	Apollo.RegisterEventHandler("AbilityBookChange", "ScheduleLasUpdate", self)
	Apollo.RegisterEventHandler("TargetUnitChanged", "OnTargetUnitChanged", self)
	Apollo.RegisterEventHandler("AlternateTargetUnitChanged", "OnFocusUnitChanged", self)

	self.playerUnit = GameLib.GetPlayerUnit()
	self.classId = self.playerUnit:GetClassId()
	self:FindCharacterProfile()
	self:ScheduleLasUpdate()

	--If we're playing a spellslinger, load up our database of spellsurged spellIds
	if (self.classId == 7) then
		self.spellslingerSurgedAbilities = QtSpellslinger:LoadSpells()
	end
	QtSpellslinger = nil
end

function QtCooldown:FindCharacterProfile()
	local charId = self.playerUnit:GetName().."@"..GameLib.GetRealmName()
	local foundProfile = false

	for i=1,#self.profiles do
		for j=1,#self.profiles[i].profileCharacters do
			if (not foundProfile and self.profiles[i].profileCharacters[j] == charId) then
				foundProfile = true
				self:ApplyProfile(i)
			end
		end
	end

	--No profile found for this character, make a new one
	if (not foundProfile) then
		local t = {
			profileName = charId.."'s Profile",
    		profileCharacters = {charId},
    		profileSettings = {
	    		bars = {
	    			{
    					name = "Default Bar",
    					settings = self:GetBarDefaultsTable()
		    		}
    			}
		    }
		}
		tinsert(self.profiles, t)
		self:ApplyProfile(#self.profiles)
	end
end

function QtCooldown:ValidateCurrentProfile()
	local defaults = self:GetBarDefaultsTable()
	for i=1,#self.currentProfile.bars do
		for k,v in pairs(defaults) do
			if (self.currentProfile.bars[i].settings[k] == nil) then
				self:CPrint("QtCooldown: Updating config (adding default value for missing preference "..k..")")
				self.currentProfile.bars[i].settings[k] = v
			end
		end
	end
end

function QtCooldown:SaveBarPositions()
	for i=1,#self.currentProfile.bars do
		local t = self.currentProfile.bars[i].settings
		t.anchorLeft, t.anchorTop, t.anchorRight, t.anchorBottom = self.bars[i].wnd:GetAnchorOffsets()
	end
end

function QtCooldown:SetupBars()
	--Cleanup existing bars and icons
	if (#self.bars > 0) then	
		for i = 1, #self.bars do
			if (self.bars[i].wnd ~= nil) then
				self.bars[i].wnd:Destroy()
				if (#self.bars[i].iconPool > 0) then
					for j = 1, #self.bars[i].iconPool do
						self.bars[i].iconPool[j]:Destroy()
					end
				end
				if (#self.bars[i].activeIcons > 0) then
					for j = 1, #self.bars[i].activeIcons do
						self.bars[i].activeIcons[j].wnd:Destroy()
					end
				end
			end
		end
	end

	self:SetupTables()

	self.bars = {}
	for i=1,#self.currentProfile.bars do
		self.bars[i] = {}
		self.bars[i].wnd = Apollo.LoadForm(self.xmlDoc, "QtBar", nil, self)
	   	self.bars[i].wnd:SetAnchorOffsets(self.currentProfile.bars[i].settings.anchorLeft, self.currentProfile.bars[i].settings.anchorTop, self.currentProfile.bars[i].settings.anchorRight, self.currentProfile.bars[i].settings.anchorBottom)
	   	self.bars[i].iconPool = {}
	   	self.bars[i].activeIcons = {}
	   	self.bars[i].overlapIndex = 0
	   	self.bars[i].lastOverlapIndex = 0
	end
	self:UpdateBarAppearance()
	self:SetListeners()
	self:UpdateVisibility()
end

function QtCooldown:SetupTables()
	self.activeCooldowns = {}
	self.recentlyEndedCooldowns = {}
	self.activeMyAuras = {}
	self.activeTargetAuras = {}
	self.activeFocusAuras = {}
	
	self.bars = {}
	self.playingAnimations = {}
	
	self.cooldownListeners = {}
	self.myListeners = {}
	self.targetListeners = {}
	self.focusListeners = {}
end

function QtCooldown:ApplyProfile(pIndex)
	self.currentProfile = self.profiles[pIndex].profileSettings
	self:ValidateCurrentProfile()
	self:SetupBars()
end

-----------------------------------------------------------------------------------------------
-- QtCooldown Functions
-----------------------------------------------------------------------------------------------
function QtCooldown:OnUnitEnteredCombat(unit, inCombat)
	if unit ~= GameLib.GetPlayerUnit() then
		return
	end

	self:UpdateVisibility()
end

function QtCooldown:InvalidateAuras()
	for i = 1, #self.myListeners do
		for k, _ in pairs(self.myListeners[i].icons) do
			if (k > 100000) then --Auras have 100000 added to their spellId to differentiate them from cooldowns which might share the same spellId (astral infusion)
				self:ExpireIcon(self.myListeners[i], k, true)
			end
		end
	end
	for i = 1, #self.targetListeners do
		for k, _ in pairs(self.targetListeners[i].icons) do
			if (k > 100000) then
				self:ExpireIcon(self.targetListeners[i], k, true)
			end
		end
	end
	for i = 1, #self.focusListeners do
		for k, _ in pairs(self.focusListeners[i].icons) do
			if (k > 100000) then
				self:ExpireIcon(self.focusListeners[i], k, true)
			end
		end
	end
	self.activeMyAuras = {}
	self.activeTargetAuras = {}
	self.activeFocusAuras = {}
end

function QtCooldown:OnTargetUnitChanged()
	self.targetUnit = GameLib.GetTargetUnit()
	self:InvalidateAuras()
	self:UpdateTrackedItems()
	self:UpdateVisibility()
end

function QtCooldown:OnFocusUnitChanged()
	self.focusUnit = self.playerUnit.GetAlternateTarget()
	self:InvalidateAuras()
	self:UpdateTrackedItems()
	self:UpdateVisibility()
end

function QtCooldown:SetLabelPositions(barIndex)
	local settings = self.currentProfile.bars[barIndex].settings
	for i = 1, 6 do
		local bar = self.bars[barIndex].wnd
		local f = bar:FindChild("lblTime"..i)
		local time = settings.labelPositions[i]

		if (time == nil or time > settings.timelineLength) then
			f:Show(false)
		else
			f:Show(true)
			local barWidth = bar:GetWidth()
			local left, top, right, bottom = f:GetAnchorOffsets()
			local centerPoint = self:GetPositionOnTimeline(time, settings.timelineLength, settings.timelineCompression, settings.reverseDirection) * barWidth

			left = centerPoint - 25
			right = centerPoint + 25
			bottom = settings.barHeight
			f:SetText(time.."s")
			f:SetAnchorOffsets(left, top, right, bottom)
			f:SetOpacity(settings.barTextOpacity * 0.01, 1000)
		end
	end
end

function QtCooldown:SetListeners()
	self.cooldownListeners = {}
	self.myListeners = {}
	self.targetListeners = {}
	self.focusListeners = {}

	self.checkMyBuffs = false
	self.checkMyDebuffs = false
	self.checkTargetBuffs = false
	self.checkTargetDebuffs = false
	self.checkFocusBuffs = false
	self.checkFocusDebuffs = false
	for i = 1, #self.currentProfile.bars do
		local settings = self.currentProfile.bars[i].settings
		if (settings.trackMyCooldowns) then
			tinsert(self.cooldownListeners, {index = i, icons = self.bars[i].activeIcons})
		end
		if (settings.trackMyBuffs or settings.trackMyDebuffs) then
			if (settings.trackMyBuffs) then
				self.checkMyBuffs = true
			end
			if (settings.trackMyDebuffs) then
				self.checkMyDebuffs = true
			end
			tinsert(self.myListeners, {index = i, icons = self.bars[i].activeIcons})
		end
		if (settings.trackTargetBuffs or settings.trackTargetDebuffs) then
			if (settings.trackTargetBuffs) then
				self.checkTargetBuffs = true
			end
			if (settings.trackTargetDebuffs) then
				self.checkTargetDebuffs = true
			end
			tinsert(self.targetListeners, {index = i, icons = self.bars[i].activeIcons})
		end
		if (settings.trackFocusBuffs or settings.trackFocusDebuffs) then
			if (settings.trackFocusBuffs) then
				self.checkFocusBuffs = true
			end
			if (settings.trackFocusDebuffs) then
				self.checkFocusDebuffs = true
			end
			tinsert(self.focusListeners, {index = i, icons = self.bars[i].activeIcons})
		end
	end
end

function QtCooldown:AddActiveCooldown(argId, argSpl, argCooldown, argCharges, argMaxCharges)
	local time = osclock()

	--Workaround for GetCooldownRemaining() bug that sometimes returns a spell's max cooldown if it has just come off CD
	if (self.recentlyEndedCooldowns[argId] ~= nil and self.recentlyEndedCooldowns[argId] > osclock()) then
		return
	end

	self.activeCooldowns[argId] = {
		splObj = argSpl,
	 	timer = argCooldown,
	 	maxTimer = argCooldown,
	 	lastTimerUpdate = time,
	 	timerFinished = time + argCooldown,
	 	charges = argCharges,
	 	maxCharges = argMaxCharges,
	}

	for i = 1, #self.cooldownListeners do
		--Print("AddActiveCooldown: "..argSpl:GetName()..", filtered="..tostring(skip))

		if (not self:TestFilter(argSpl:GetName(), self.cooldownListeners[i].index, 1, argCooldown)) then
			self.cooldownListeners[i].icons[argId] = {
				wnd = nil,
				loc = -1,
				data = self.activeCooldowns[argId],
				overlayColor = self.currentProfile.bars[self.cooldownListeners[i].index].settings.cooldownColor
			}
		end
	end
	self:UpdateVisibility()
end

function QtCooldown:AddActiveAura(argId, argSpl, argTimer, argStacks, argDataTable, argBeneficial)
	local time = osclock()
	argDataTable[argId] = {
		splObj = argSpl,
	 	timer = argTimer,
	 	maxTimer = argTimer,
	 	lastTimerUpdate = time,
	 	timerFinished = time + argTimer,
	 	charges = argStacks,
	 	maxCharges = argStacks,
	 	bene = argBeneficial
	}

	local listenersTable = nil
	if (argDataTable == self.activeMyAuras) then
		listenersTable = self.myListeners
	elseif (argDataTable == self.activeTargetAuras) then
		listenersTable = self.targetListeners
	else
		listenersTable = self.focusListeners
	end

	for i = 1, #listenersTable do
		if (not self:TestFilter(argSpl:GetName(), listenersTable[i].index, (argBeneficial == true and 2 or 3), argTimer)) then
			listenersTable[i].icons[argId + 100000] = { --Auras have 100000 added to their spellId to differentiate them from cooldowns which might share the same spellId (astral infusion)
				wnd = nil,
				loc = -1,
				data = argDataTable[argId],
				overlayColor = (argBeneficial and self.currentProfile.bars[listenersTable[i].index].settings.buffColor or self.currentProfile.bars[listenersTable[i].index].settings.debuffColor)
			}
		end
	end
	self:UpdateVisibility()
end

function QtCooldown:TestFilter(splName, barIndex, timerType, timer)
		local skip = false
		local filterMatched = false
		local filterMode = nil
		local filterList = nil
		local settings = self.currentProfile.bars[barIndex].settings
		if (timerType == 1) then
			filterMode = settings.cooldownBlacklistMode
			filterList = settings.cooldownFilterList
			if (timer > settings.maxCooldownDuration or timer < settings.minCooldownDuration) then skip = true end
		elseif (timerType == 2) then
			filterMode = settings.buffBlacklistMode
			filterList = settings.buffFilterList
			if (timer > settings.maxBuffDuration or timer < settings.minBuffDuration) then skip = true end
		else
			filterMode = settings.debuffBlacklistMode
			filterList = settings.debuffFilterList
			if (timer > settings.maxDebuffDuration or timer < settings.minDebuffDuration) then skip = true end
		end

		if (filterMode == true) then
			for i=1,#filterList do
				if (splName == filterList[i]) then
					filterMatched = true
				end
			end
		else
			filterMatched = true
			for i=1,#filterList do
				if (splName == filterList[i]) then
					filterMatched = false
				end
			end
		end

		if (filterMatched) then
			skip = true
		end

		return skip
end

function QtCooldown:ExpireActiveCooldown(id)
	--Print("Cleaning up "..self.activeCooldowns[id].splObj:GetName())
	self.recentlyEndedCooldowns[id] = osclock() + 0.10
	for i = 1, #self.cooldownListeners do
		self:ExpireIcon(self.cooldownListeners[i], id, false)
	end
	self.activeCooldowns[id] = nil
end

function QtCooldown:ExpireActiveAura(unit, id, skipPulse)
	local listenersTable = nil
	local dataTable = nil

	if (unit == "player") then
		listenersTable = self.myListeners
		dataTable = self.activeMyAuras
	elseif (unit == "target") then
		listenersTable = self.targetListeners
		dataTable = self.activeTargetAuras
	else
		listenersTable = self.focusListeners
		dataTable = self.activeFocusAuras
	end

	for i = 1, #listenersTable do
		self:ExpireIcon(listenersTable[i], id + 100000, skipPulse)
	end
	dataTable[id] = nil
end

function QtCooldown:ExpireIcon(listener, spellId, skipPulse)
	if (listener.icons[spellId] == nil) then
		return
	end

	if (listener.icons[spellId].wnd ~= nil) then
		if (self.currentProfile.bars[listener.index].settings.playPulseAnimation and not skipPulse) then
			self:StartPulseAnimation(listener.icons[spellId].wnd:FindChild("wndIcon"):GetSprite(), listener.icons[spellId].wnd:FindChild("wndOverlay"):GetBGColor(), listener.index)
		end
		self:ReleaseIcon(listener.icons[spellId].wnd)
	end
	listener.icons[spellId] = nil
	self:UpdateVisibility()
end

function QtCooldown:StartPulseAnimation(sprite, overlayColor, barIndex)
	local settings = self.currentProfile.bars[barIndex].settings
	local f = Apollo.LoadForm(self.xmlDoc, "QtPulse", nil, self)
	local newanim = {
		animationEndTime = osclock() + settings.pulseDuration,
		wnd = f,
	}
	f:FindChild("wndIcon"):SetSprite(sprite)
	f:FindChild("wndOverlay"):SetBGColor(overlayColor)

	if (settings.customPulseAnchor) then
		local offset = settings.pulseSize / 2
		newanim.wnd:SetAnchorPoints(0.5, 0.5, 0.5, 0.5)
		newanim.wnd:SetAnchorOffsets(settings.customPulseX - offset, settings.customPulseY - offset, settings.customPulseX + offset, settings.customPulseY + offset)
	else
		local apL, apT, apR, apB = self.bars[barIndex].wnd:GetAnchorPoints()
		local aoL, aoT = self.bars[barIndex].wnd:GetAnchorOffsets()
		local left, top, right, bottom
		local offset = settings.pulseSize / 2
		local hCenterPoint = self:GetPositionOnTimeline(0, settings.timelineLength, settings.timelineCompression, settings.reverseDirection) * settings.barWidth
		local vCenterPoint = settings.barHeight / 2
		left = (hCenterPoint - offset) + aoL
		top = (vCenterPoint - offset) + aoT
		newanim.wnd:SetAnchorPoints(apL, apT, apR, apB)
		newanim.wnd:SetAnchorOffsets(left, top, left + settings.pulseSize, top + settings.pulseSize)
	end

	newanim.wnd:TransitionPulse(2, self:GetApolloAnimationRate(settings.pulseDuration), true)
	newanim.wnd:SetOpacity(0, self:GetApolloAnimationRate(settings.pulseDuration))
	tinsert(self.playingAnimations, newanim)
end

--This function is called every half-second and is responsible for updating the backing data for each
--tracked cooldown and aura.  Another timer handles actually updating the UI and animating icons.
function QtCooldown:UpdateTrackedItems()
	if (#self.cooldownListeners > 0) then
		self:UpdateCooldowns()
	end
	if (self.checkMyBuffs) then
		self:UpdateAuras(self.playerUnit, true, "player")
	end
	if (self.checkMyDebuffs) then
		self:UpdateAuras(self.playerUnit, false, "player")
	end
	if (self.checkTargetBuffs and self.targetUnit ~= nil) then
		self:UpdateAuras(self.targetUnit, true, "target")
	end
	if (self.checkTargetDebuffs and self.targetUnit ~= nil) then
		self:UpdateAuras(self.targetUnit, false, "target")
	end
	if (self.checkFocusBuffs and self.focusUnit ~= nil) then
		self:UpdateAuras(self.focusUnit, true, "focus")
	end
	if (self.checkFocusDebuffs and self.focusUnit ~= nil) then
		self:UpdateAuras(self.focusUnit, false, "focus")
	end
end

function QtCooldown:UpdateCooldowns()
	if (self.trackedCooldowns == nil) then
		self:GetLasAbilities()
		return
	end

	for i = 1, #self.trackedCooldowns do
		local spl = self.trackedCooldowns[i]
		local id = spl:GetId()
		local time = osclock()

		if (spl:GetAbilityCharges().nChargesMax > 0) then 
			--Handle abilities with charges
			local chargeObj = spl:GetAbilityCharges()
			if (chargeObj.nChargesRemaining < chargeObj.nChargesMax) then
				--Add new active cooldown or update existing active cooldown
				if (self.activeCooldowns[id] == nil) then
					self:AddActiveCooldown(id, spl, (chargeObj.fRechargeTime * chargeObj.fRechargePercentRemaining), chargeObj.nChargesRemaining, chargeObj.nChargesMax)
				else
					self.activeCooldowns[id].charges = chargeObj.nChargesRemaining
					self.activeCooldowns[id].timer = (chargeObj.fRechargeTime * chargeObj.fRechargePercentRemaining)
					self.activeCooldowns[id].lastTimerUpdate = time
				end
			else
				--Set expired flag for cleanup
				if (self.activeCooldowns[id] ~= nil) then 
					self.activeCooldowns[id].expired = true
				end
			end
		else 
			--Handle abilities with cooldowns
			local fCooldown = spl:GetCooldownRemaining()

			if (self.activeCooldowns[id] == nil) then
				if (fCooldown > 0) then
					self:AddActiveCooldown(id, spl, fCooldown, -1, -1)
				end
			elseif (fCooldown > 0) then
				self.activeCooldowns[id].lastTimerUpdate = time

				--Sometimes GetSpellCooldown will return a spell's full cooldown for a quick moment as
				--it comes off cooldown, instead of returning 0.  To handle this, ignore increases in
				--fCooldown if the spell is about to expire.
				if (not(self.activeCooldowns[id].timer < 1 and fCooldown > self.activeCooldowns[id].timer)) then
					self.activeCooldowns[id].timer = fCooldown
					self.activeCooldowns[id].timerFinished = fCooldown + time
				else
					self.activeCooldowns[id].timer = self.activeCooldowns[id].timerFinished - time
				end
			end

			--TODO: Fix issues with Warrior CD reset and Stalker stealth combat cooldown reset
			if (self.activeCooldowns[id] ~= nil and fCooldown <= 0) then
				self.activeCooldowns[id].expired = true
			end
		end

		--Handle expired cooldowns
		if (self.activeCooldowns[id] ~= nil and self.activeCooldowns[id].expired) then
			self:ExpireActiveCooldown(id)
		end
	end
end

function QtCooldown:UpdateAuras(unit, beneficial, unitType)
	if (unit == nil or unit:GetBuffs() == nil) then
		if (unitType == "player") then
			self.playerUnit = GameLib.GetPlayerUnit()
		elseif (unitType == "target") then
			self.targetUnit = nil
		else
			self.focusUnit = nil
		end
		return
	end

	local time = osclock()
	local buffs = nil
	local dataTable = nil

	if (unitType == "player") then
		dataTable = self.activeMyAuras
	elseif (unitType == "target") then
		dataTable = self.activeTargetAuras
	else
		dataTable = self.activeFocusAuras
	end

	if (beneficial) then
		buffs = unit:GetBuffs().arBeneficial
	else
		buffs = unit:GetBuffs().arHarmful
	end

	for i = 1, #buffs do
		local buff = buffs[i]
		if (buff.fTimeRemaining > 0) then
			local spl = buff.splEffect
			local id = spl:GetId()

			if (dataTable[id] == nil) then
				self:AddActiveAura(id, spl, buff.fTimeRemaining, (buff.nCount > 1 and buff.nCount or -1), dataTable, beneficial)
			else
				dataTable[id].lastTimerUpdate = time
				dataTable[id].timer = buff.fTimeRemaining
				dataTable[id].timerFinished = buff.fTimeRemaining + time
				dataTable[id].charges = (buff.nCount > 1 and buff.nCount or -1)
				dataTable[id].maxCharges = (buff.nCount > 1 and buff.nCount or -1)
			end
		end

		if (self.activeCooldowns[id] ~= nil and self.activeCooldowns[id].timerFinished < time) then
			self.activeCooldowns[id].expired = true
		end
	end

	for k,v in pairs(dataTable) do
		if (v.bene == beneficial) then
			if (v.lastTimerUpdate ~= time) then --If the timer wasn't updated during this call, it has expired.
				self:ExpireActiveAura(unitType, k, (v.timer > 1 and true or false))
			end
		end
	end
end

--This function is called much more frequently and is responsible for animating icon positions and pulse effects
function QtCooldown:OnUiRedraw()
	local forceUpdate = false
	for i = 1, #self.currentProfile.bars do
		local settings = self.currentProfile.bars[i].settings
		for k,v in pairs(self.bars[i].activeIcons) do
			--Each activeIcon's 'data' field contains a reference to the activeCooldown/activeAura
			--table it is associated with, which contains the backing data for whatever the icon is
			--supposed to represent

			if (v.wnd == nil) then
				--Claim a window from our icon pool and perform some initial setup on it
				v.wnd = self:ClaimIcon(i)
				v.wnd:FindChild("wndOverlay"):SetBGColor(v.overlayColor)
				v.wnd:FindChild("wndIcon"):SetSprite(v.data.splObj:GetIcon())
				v.cdtext = v.wnd:FindChild("lblTimerText")
				v.chargestext = v.wnd:FindChild("lblStacksText")
				v.wnd:Show(true,false)
				if (v.data.maxCharges == -1) then
					v.chargestext:SetText("")
				end
			end

			--Since the data timer is only updated twice per second, interpolate the true time remaining
			--and display that on the icon
			local timer = v.data.timer - (osclock() - v.data.lastTimerUpdate)
			if (timer < 1) then
				v.cdtext:SetText(strformat("%.1f", timer))
			else
				v.cdtext:SetText(mathfloor(timer))
			end
			if (v.data.maxCharges > -1) then
				v.chargestext:SetText(v.data.charges)
			end

			if (timer > 0) then
				--Calculate anchor offsets
				local left, top, right, bottom = v.wnd:GetAnchorOffsets()
				local offset = settings.iconSize / 2
				local hCenterPoint = self:GetPositionOnTimeline(timer, settings.timelineLength, settings.timelineCompression, settings.reverseDirection) * settings.barWidth
				local vCenterPoint = settings.barHeight / 2
				left = hCenterPoint - offset
				right = hCenterPoint + offset
				top = vCenterPoint - offset
				bottom = vCenterPoint + offset
				v.wnd:SetAnchorOffsets(left, top, right, bottom)
				v.loc = left

				--Determine if this icon overlaps with any sibling icons on the same bar, and set an overlapped flag if so.
				--The actual fadein/fadeout animation is handled by another timer.
				if (settings.overlapFade) then
					local overlapping = false
					local iconSize = settings.iconSize * 0.7
					for k2,v2 in pairs(self.bars[i].activeIcons) do
						if ((v2.loc > v.loc and v2.loc < v.loc + iconSize) or (v2.loc + iconSize > v.loc and v2.loc < v.loc)) then
							overlapping = true
						end
					end
					if (overlapping) then
						v.overlapping = true
					else
						v.overlapping = false
						v.wnd:SetOpacity(settings.iconOpacity * 0.01, 5)
					end
				end
			else
				--This icon has expired, but the UpdateTrackedItems timer hasn't fired yet.
				--We'll manually call it later once we've finished redrawing all of the icons this frame.
				v.data.expired = true
				forceUpdate = true
			end
		end
	end

	if (forceUpdate) then
		self:UpdateTrackedItems()
	end

	--Animate any expiring icons.  This only deals with the icon's scale, the opacity animation is handled 
	--automatically by Apollo when we call SetOpacity.
	for k,v in pairs(self.playingAnimations) do
		--local clock = osclock()
		--local delta = clock - v.lastFrameTime
		--v.elapsedTime = v.elapsedTime + delta
		--v.lastFrameTime = clock
		--if (v.elapsedTime > v.animDuration) then
			--self:ReleaseIcon(v.wnd)
			--v.wnd:SetScale(1)
			--self.playingAnimations[k] = nil
		--else
			--local scalecalc = 1 + ((v.elapsedTime / v.animDuration) * v.scaleTarget)
			--v.wnd:SetScale(scalecalc)
		--end

		if (v.animationEndTime < osclock()) then
			--self:ReleaseIcon(v.wnd)
			self.playingAnimations[k].wnd:Destroy()
			self.playingAnimations[k] = nil
			self:UpdateVisibility()
		end
	end
end

--This function and its associated timer fade out overlapping icons in order from left to right along the bar.
--It runs once per 0.75s and advances one icon each time it's called.
function QtCooldown:CycleOverlappingWindows()
	for i = 1, #self.currentProfile.bars do
		local settings = self.currentProfile.bars[i].settings
		if (not(next(self.bars[i].activeIcons) == nil or not settings.overlapFade or not self.bars[i].wnd:IsVisible())) then 
			local sorted = self:SortTimers(i)
			local looped = 0
			local done = false
			while (not done) do
				self.bars[i].overlapIndex = self.bars[i].overlapIndex + 1
				if (self.bars[i].overlapIndex > #sorted) then
					self.bars[i].overlapIndex = 1
					looped = looped + 1
				end
				if (sorted[self.bars[i].overlapIndex].value.overlapping or looped == 2) then
					done = true
				end
			end

			if (sorted[self.bars[i].lastOverlapIndex] ~= nil and sorted[self.bars[i].lastOverlapIndex].value.wnd ~= nil) then
				sorted[self.bars[i].lastOverlapIndex].value.wnd:SetOpacity(settings.iconOpacity * 0.01, 2)
			end
			
			if (sorted[self.bars[i].overlapIndex].value.wnd ~= nil) then
				sorted[self.bars[i].overlapIndex].value.wnd:SetOpacity(0.20, 2)
			end
			self.bars[i].lastOverlapIndex = self.bars[i].overlapIndex
		end	
	end
end

function QtCooldown:SortTimers(barIndex)
  local u = { }
  for k, v in pairs(self.bars[barIndex].activeIcons) do table.insert(u, { key = k, value = v }) end
  table.sort(u, function(o1,o2) return o1.value.data.timer > o2.value.data.timer end)
  return u
end

function QtCooldown:ScheduleLasUpdate()
	self.timerUpdateLas:Start()
	--Apollo.StartTimer("QtCooldownUpdateLasTimer")
end

function QtCooldown:GetLasAbilities()
	self.trackedCooldowns = {}
	local las = ActionSetLib.GetCurrentActionSet()
	local abilities = AbilityBook.GetAbilitiesList()
	local innates = GameLib.GetClassInnateAbilitySpells()

	if (abilities == nil) then 
		return 
	end

	self:SetupBars()
	
	--GetCurrentActionSet returns the base spellId for each spell on our LAS.
	--GetAbilitiesList returns the base spellId for all the valid spells for our class.
	--We loop through the abilitybook looking for base spells that are on our LAS,
	--and then get the appropriately tiered spellId, which is added to our trackedCooldowns table.
	for i = 1, #abilities do
		if (abilities[i].bIsActive) then
			for j = 1,8 do
				if (abilities[i].nId == las[j]) then
					local splObj = abilities[i].tTiers[abilities[i].nCurrentTier].splObject
					if (splObj:GetCooldownTime() > 0 or splObj:GetAbilityCharges().nChargesMax > 0) then
						tinsert(self.trackedCooldowns, splObj)
					end

					--Engineer bot activated abilities aren't in our spellbook (only the summon spells), so we have to find them.
					if (self.classId == 2) then
						local botSpell = self:GetBotSpell(abilities[i].nId, abilities[i].nCurrentTier)
						if (botSpell ~= nil) then
							tinsert(self.trackedCooldowns, botSpell)
						end
					end

					--The surged version of each tier of each spellslinger spell has a different spellId, so we have to find those.
					if (self.classId == 7) then
						local surged = self.spellslingerSurgedAbilities[abilities[i].nId]
						if (surged ~= nil) then
							local idTable = surged.tiers["t"..abilities[i].nCurrentTier]
							for k=1,#idTable do
								tinsert(self.trackedCooldowns, GameLib.GetSpell(idTable[k]))
							end
						end
					end
				end
			end
		end
	end

	for i = 1, innates.nSpellCount do
		tinsert(self.trackedCooldowns, innates.tSpells[i])
	end

	local gadget = GameLib.GetGadgetAbility()
	if (gadget ~= nil and gadget:GetId() ~= nil) then
		tinsert(self.trackedCooldowns, gadget)
	end
	self:UpdateVisibility()
end

function QtCooldown:GetPositionOnTimeline(value, maximum, base, reverse)
	local r = mathpow(value, base) / mathpow(maximum, base)
	r = r > 1 and 1 or r
	return reverse and mathabs(r - 1) or r
end 

function QtCooldown:GetBotSpell(spellId, tier)
	local engiSpells = {
		{botSummonSpell = 27021, tiers={70593, 70673, 70674, 70675, 70676, 70677, 70678, 70679, 70680}}, --Diminisherbot's Strobe
		{botSummonSpell = 27002, tiers={51365, 56267, 56268, 56269, 56270, 56271, 56272, 56273, 56274}}, --Artillerybot's Barrage
		{botSummonSpell = 27082, tiers={35501, 56334, 56335, 56336, 56337, 56338, 56339, 56340, 56341}}, --Bruiserbot's Blitz
		{botSummonSpell = 26998, tiers={35657, 55864, 55865, 55866, 55867, 55868, 55869, 55870, 55871}}, --Repairbot's Shield Boost
	}
	for i=1,4 do
		if (spellId == engiSpells[i].botSummonSpell) then
			return GameLib.GetSpell(engiSpells[i].tiers[tier])
		end
	end
	return nil
end

--Icon pool stuff
function QtCooldown:CreateNewIcon(poolIndex)
	--Print("[CreateNewIcon] poolIndex = "..poolIndex)
	local f = Apollo.LoadForm(self.xmlDoc, "QtIcon", self.bars[poolIndex].wnd, self)
	if (self.currentProfile.bars[poolIndex].settings.showIconBorder) then
		f:SetBGOpacity(1, 1000)
	else
		f:SetBGOpacity(0, 1000)
	end
	f:SetData(poolIndex)
	tinsert(self.bars[poolIndex].iconPool, f)
end

function QtCooldown:ClaimIcon(poolIndex)
	local f = tremove(self.bars[poolIndex].iconPool)
	if (f == nil) then
		self:CreateNewIcon(poolIndex)
		f = tremove(self.bars[poolIndex].iconPool)
	end
	--Print("[ClaimIcon] poolIndex = "..poolIndex..", size = "..#self.bars[poolIndex].iconPool)
	return f
end

function QtCooldown:ReleaseIcon(wnd)
	wnd:Show(false,true)
	wnd:SetOpacity(1, 1000)
	tinsert(self.bars[wnd:GetData()].iconPool, wnd)
	--Print("[ReleaseIcon] poolIndex = "..wnd:GetData()..", size = "..#self.bars[wnd:GetData()].iconPool)
end

function QtCooldown:OnSlashCommand(slashcommand, arguments)
	
	local arg2 = nil
	if (arguments) then
		local spaceIndex = arguments:find(" ")
		if (spaceIndex ~= nil) then
			arg2 = arguments:sub(spaceIndex + 1)
			arguments = arguments:sub(1, spaceIndex - 1)
		end
		
	end
	--Print("'"..tostring(arguments).."', '"..tostring(arg2).."'")
	if (arguments == "defaults") then
		self.profiles = {}
		RequestReloadUi()
	elseif (arguments == "swapprofile" or arguments == "sp") then
		if (arg2 == nil) then
			self:CPrint("Usage: /qtc swapprofile My Profile Name")
			return
		end

		local profileIndex = -1
		for i = 1,#self.profiles do
			if (self.profiles[i].profileName == arg2) then
				profileIndex = i
			end
		end
		if (profileIndex ~= -1) then
			self:CPrint("Swapping to profile <"..self.profiles[profileIndex].profileName..">.")
			self:SwapProfile(profileIndex)
			if (self.configWindows ~= nil) then
				self:InitializeControlValues()
			end
		else
			self:CPrint("No profile by that name was found.")
		end
	else
		self:OnConfigure()
	end
end

function QtCooldown:UpdateVisibility()
	self.isIdle = true
	for i = 1, #self.bars do
		local anyIcons = next(self.bars[i].activeIcons)
		local anyAnimations = next(self.playingAnimations)

		if ((self.currentProfile.bars[i].settings.hideOutOfCombat and not self.playerUnit:IsInCombat()) or (self.currentProfile.bars[i].settings.hideWhenEmpty and anyIcons == nil)) then
			self.bars[i].wnd:Show(false)
		else
			self.bars[i].wnd:Show(true)
		end

		if (anyIcons ~= nil or anyAnimations ~= nil) then
			self.isIdle = false
		end
	end

	if (self.isIdle) then
		self.timerUpdateUi:Stop()
	else
		self.timerUpdateUi:Start()
	end
end

--Apply user preferences to each spawned bar
function QtCooldown:UpdateBarAppearance()
	for i=1,#self.currentProfile.bars do
		local settings = self.currentProfile.bars[i].settings
		self.bars[i].wnd:SetOpacity(settings.barOpacity * 0.01, 1000)
		if (settings.barColor == "ff27e6ff") then
			self.bars[i].wnd:SetBGColor("ffffffff")
			self.bars[i].wnd:SetSprite("QtSprites:BarSprite2")
		else
			self.bars[i].wnd:SetBGColor("2x:"..settings.barColor)
			self.bars[i].wnd:SetSprite("QtSprites:BarSprite1")
		end
		self.bars[i].wnd:SetBGOpacity(settings.barBgOpacity * 0.01, 1000)
		local left, top, right, bottom = self.bars[i].wnd:GetAnchorOffsets()
		right = left + settings.barWidth
		bottom = top + settings.barHeight
		self.bars[i].wnd:SetAnchorOffsets(left, top, right, bottom)
		self:SetLabelPositions(i)
		for k,v in pairs(self.bars[i].activeIcons) do
			if (v.wnd ~= nil) then
				v.wnd:SetOpacity(settings.iconOpacity * 0.01, 1000)
				if (settings.showIconBorder) then
					v.wnd:SetBGOpacity(1, 1000)
				else
					v.wnd:SetBGOpacity(0, 1000)
				end
			end
		end
		self.bars[i].wnd:SetStyle("IgnoreMouse", settings.barLocked)
		self.bars[i].wnd:SetStyle("Moveable", not settings.barLocked)
	end
end

-----------------------------------------------------------------------------------------------
-- Options Form Functions
-----------------------------------------------------------------------------------------------
function QtCooldown:OnConfigure()
	if (self.configWindows == nil) then
		self.configWindows = {}
		self.configWindows.config = Apollo.LoadForm(self.xmlDoc, "QtPrefs", nil, self)
		self.configWindows.configLeftPanel = self.configWindows.config:FindChild("ConfigPanel:LeftSide:BarTreeList")
		self.configWindows.configRightPanel = self.configWindows.config:FindChild("ConfigPanel:RightSide:RightContent")
		self.configWindows.configTab1 = Apollo.LoadForm(self.xmlDoc, "QtPrefsTab1", self.configWindows.configRightPanel, self)
		self.configWindows.configTab2 = Apollo.LoadForm(self.xmlDoc, "QtPrefsTab2", self.configWindows.configRightPanel, self)
		self.configWindows.configTab3 = Apollo.LoadForm(self.xmlDoc, "QtPrefsTab3", self.configWindows.configRightPanel, self)
		self.configWindows.configTab4 = Apollo.LoadForm(self.xmlDoc, "QtPrefsTab4", self.configWindows.configRightPanel, self)
		self.configWindows.configTab5 = Apollo.LoadForm(self.xmlDoc, "QtPrefsTab5", self.configWindows.configRightPanel, self)
		self.configWindows.configTab6 = Apollo.LoadForm(self.xmlDoc, "QtPrefsTab6", self.configWindows.configRightPanel, self)
		self.configWindows.configTab7 = Apollo.LoadForm(self.xmlDoc, "QtPrefsTab7", self.configWindows.configRightPanel, self)
		self.configWindows.config:FindChild("AboutLabel"):SetText(VERSION_NOTE)

		--These tables map slider and checkbox controls to their respective savedVariable fields.  Sliders have a buddy control that displays the numeric value of the slider.
		self.sliderMapping = {
			{wnd = self.configWindows.config:FindChild("sliBarOpacity"), 		savedVar = "barOpacity",			buddy = self.configWindows.config:FindChild("editBarOpacity"), 			format = "%d%%"},
			{wnd = self.configWindows.config:FindChild("sliBarHeight"), 		savedVar = "barHeight",				buddy = self.configWindows.config:FindChild("editBarHeight"), 			format = "%d"},
			{wnd = self.configWindows.config:FindChild("sliBarWidth"), 			savedVar = "barWidth",				buddy = self.configWindows.config:FindChild("editBarWidth"), 			format = "%d"},
			{wnd = self.configWindows.config:FindChild("sliBarTextOpacity"), 	savedVar = "barTextOpacity",		buddy = self.configWindows.config:FindChild("editBarTextOpacity"), 		format = "%d%%"},
			{wnd = self.configWindows.config:FindChild("sliBarBgOpacity"), 		savedVar = "barBgOpacity",			buddy = self.configWindows.config:FindChild("editBarBgOpacity"), 		format = "%d%%"},
			{wnd = self.configWindows.config:FindChild("sliIconSize"), 			savedVar = "iconSize",				buddy = self.configWindows.config:FindChild("editIconSize"), 			format = "%d"},
			{wnd = self.configWindows.config:FindChild("sliIconOpacity"), 		savedVar = "iconOpacity",			buddy = self.configWindows.config:FindChild("editIconOpacity"), 		format = "%d%%"},
			{wnd = self.configWindows.config:FindChild("sliTimeCompression"), 	savedVar = "timelineCompression",	buddy = self.configWindows.config:FindChild("editTimeCompression"), 	format = "%.2f"},
			{wnd = self.configWindows.config:FindChild("sliTimelineLength"), 	savedVar = "timelineLength",		buddy = self.configWindows.config:FindChild("editTimelineLength"), 		format = "%ds"},
			{wnd = self.configWindows.config:FindChild("sliMinCooldown"), 		savedVar = "minCooldownDuration",	buddy = self.configWindows.config:FindChild("editMinCooldown"), 		format = "%.1fs"},
			{wnd = self.configWindows.config:FindChild("sliMaxCooldown"), 		savedVar = "maxCooldownDuration",	buddy = self.configWindows.config:FindChild("editMaxCooldown"), 		format = "%ds"},
			{wnd = self.configWindows.config:FindChild("sliMinBuff"), 			savedVar = "minBuffDuration",		buddy = self.configWindows.config:FindChild("editMinBuff"), 			format = "%.1fs"},
			{wnd = self.configWindows.config:FindChild("sliMaxBuff"), 			savedVar = "maxBuffDuration",		buddy = self.configWindows.config:FindChild("editMaxBuff"), 			format = "%ds"},
			{wnd = self.configWindows.config:FindChild("sliMinDebuff"), 		savedVar = "minDebuffDuration",		buddy = self.configWindows.config:FindChild("editMinDebuff"), 			format = "%.1fs"},
			{wnd = self.configWindows.config:FindChild("sliMaxDebuff"), 		savedVar = "maxDebuffDuration",		buddy = self.configWindows.config:FindChild("editMaxDebuff"), 			format = "%ds"},
			{wnd = self.configWindows.config:FindChild("sliPulseDuration"), 	savedVar = "pulseDuration",			buddy = self.configWindows.config:FindChild("editPulseDuration"), 		format = "%.2fs"},
			{wnd = self.configWindows.config:FindChild("sliPulseScale"), 		savedVar = "pulseSize",				buddy = self.configWindows.config:FindChild("editPulseScale"), 			format = "%d"},
		}
		self.checkboxMapping = {
			{wnd = self.configWindows.config:FindChild("chkHideOutOfCombat"), 	savedVar = "hideOutOfCombat"},
			{wnd = self.configWindows.config:FindChild("chkHideWhenEmpty"), 	savedVar = "hideWhenEmpty"},
			{wnd = self.configWindows.config:FindChild("chkBarLocked"), 		savedVar = "barLocked"},
			{wnd = self.configWindows.config:FindChild("chkOverlapFade"), 		savedVar = "overlapFade"},
			{wnd = self.configWindows.config:FindChild("chkPulseAnimation"), 	savedVar = "playPulseAnimation"},
			{wnd = self.configWindows.config:FindChild("chkReverseDirection"), 	savedVar = "reverseDirection"},
			{wnd = self.configWindows.config:FindChild("chkShowIconBorder"), 	savedVar = "showIconBorder"},
			{wnd = self.configWindows.config:FindChild("chkMyCooldowns"), 		savedVar = "trackMyCooldowns", 		reloadbars = true},
			{wnd = self.configWindows.config:FindChild("chkMyBuffs"), 			savedVar = "trackMyBuffs", 			reloadbars = true},
			{wnd = self.configWindows.config:FindChild("chkTargetBuffs"), 		savedVar = "trackTargetBuffs", 		reloadbars = true},
			{wnd = self.configWindows.config:FindChild("chkFocusBuffs"), 		savedVar = "trackFocusBuffs", 		reloadbars = true},
			{wnd = self.configWindows.config:FindChild("chkMyDebuffs"), 		savedVar = "trackMyDebuffs", 		reloadbars = true},
			{wnd = self.configWindows.config:FindChild("chkTargetDebuffs"), 	savedVar = "trackTargetDebuffs", 	reloadbars = true},
			{wnd = self.configWindows.config:FindChild("chkFocusDebuffs"), 		savedVar = "trackFocusDebuffs", 	reloadbars = true},
			{wnd = self.configWindows.config:FindChild("chkCustomPulseAnchor"), savedVar = "customPulseAnchor"}
		}
	end
	self.configWindows.config:Show(true)
	self:ConfigSwapBar(-1)
	self.configWindows.configRightPanel:RecalculateContentExtents()
	self.configWindows.configRightPanel:SetVScrollPos(0)
end

function QtCooldown:OnSliderChanged(wndHandler, wndControl, fValue, fOldValue)
	if (not wndControl:IsMouseTarget()) then --workaround for Apollo bug where sliders react to mouse events even when hidden/clipped
		wndControl:SetValue(fOldValue)
		return
	end
	for _,v in pairs(self.sliderMapping) do
		if (v.wnd == wndControl) then
			if (not string.match(v.format, "f")) then
				fValue = math.floor(fValue)
			end
			self.currentProfile.bars[self.barConfigIndex].settings[v.savedVar] = fValue
			v.buddy:SetText(string.format(v.format, fValue))
		end
	end
	self:UpdateBarAppearance()
	self:UpdateVisibility()
end

function QtCooldown:OnCheckboxChanged(wndHandler, wndControl)
	for _,v in pairs(self.checkboxMapping) do
		if (v.wnd == wndControl) then
			self.currentProfile.bars[self.barConfigIndex].settings[v.savedVar] = wndControl:IsChecked()
			if (v.reloadbars ~= nil) then
				self:SaveBarPositions()
				self:SetupBars()
			end
		end
	end
	self:UpdateBarAppearance()
	self:UpdateVisibility()
end

function QtCooldown:OnConfigCloseBtn()
	self.configWindows.config:Close()
end

function QtCooldown:OnConfigClosed()
	if (self.pulseAnchorVisible) then
		self:OnTogglePulseBtn()
	end
	self.configWindows.config:Destroy()
	self.configWindows = nil
end

function QtCooldown:OnConfigBarBtn(wndHandler, wndControl)
	if (self.pulseAnchorVisible) then
		self:OnTogglePulseBtn()
	end
	if (not wndControl:IsChecked()) then
		wndControl:SetCheck(false)
		self:ConfigSwapBar(-1)
	else
		wndControl:SetCheck(true)
		self:ConfigSwapBar(wndControl:GetData())
	end
	self.configWindows.configRightPanel:RecalculateContentExtents()
	self.configWindows.configRightPanel:SetVScrollPos(0)
end

function QtCooldown:OnConfigTabBtn(wndHandler, wndControl)
	if (self.pulseAnchorVisible) then
		self:OnTogglePulseBtn()
	end
	self:ConfigSwapTab(wndControl:GetData())
	wndControl:SetCheck(true)
end

function QtCooldown:OnAddNewBarBtn()
	self:SaveBarPositions()
	self.currentProfile.bars[#self.currentProfile.bars + 1] = {
		name = "New Bar",
		settings = self:GetBarDefaultsTable()
	}
	self:ConfigLoadBarTree()
	self:ConfigSwapBar(#self.currentProfile.bars)
	self:SetupBars()
end

function QtCooldown:OnProfilesBtn()
	self:ConfigSwapTab(7)
end

function QtCooldown:OnRenameProfileBtn()
	local row = self.configWindows.configTab7:FindChild("ProfileGrid"):GetCurrentRow()
	local text = self.configWindows.configTab7:FindChild("editProfileName"):GetText()
	text = self:Trim(text)
	if (text == "") then
		text = self.profiles[row].profileName
	end
	if (text:len() >= 30) then
		text = text:sub(1,30)
	end
	local nameInUse = false
	for i = 1,#self.profiles do
		if (self.profiles[i].profileName == text) then
			self:CPrint("[QtCooldown] This profile name is already in use.")
			nameInUse = true
		end
	end
	if (nameInUse) then
		text = self.profiles[row].profileName
	end
	self.profiles[row].profileName = text
	self:InitializeProfileTab()
	self.configWindows.configTab7:FindChild("ProfileGrid"):SetCurrentRow(row)
	self:OnProfileSelChanged()
end

function QtCooldown:OnActivateProfileBtn()
	local selectedIndex = self.configWindows.configTab7:FindChild("ProfileGrid"):GetCurrentRow()
	self:SwapProfile(selectedIndex)

	self:InitializeProfileTab()
	self:ConfigLoadBarTree()
end

function QtCooldown:SwapProfile(index)
	self:SaveBarPositions()
	
	local charId = self.playerUnit:GetName().."@"..GameLib.GetRealmName()
	local currentIndex = self:GetCurrentProfileIndex()
	for i = 1,#self.profiles[currentIndex].profileCharacters do
		if (self.profiles[currentIndex].profileCharacters[i] == charId) then
			tremove(self.profiles[currentIndex].profileCharacters, i)
			i = #self.profiles[currentIndex].profileCharacters + 1
		end
	end
	tinsert(self.profiles[index].profileCharacters, charId)

	self:ApplyProfile(index)
end

function QtCooldown:OnAddNewProfileBtn()
	local t = {
		profileName = "New Profile",
    	profileCharacters = {},
    	profileSettings = {
	    	bars = {
	    		{
    				name = "Default Bar",
    				settings = self:GetBarDefaultsTable()
	    		}
    		}
	    }
	}
	tinsert(self.profiles, t)
	self:InitializeProfileTab()
end

function QtCooldown:OnProfileSelChanged()
	local grid = self.configWindows.configTab7:FindChild("ProfileGrid")
	local enableButton = grid:GetCurrentRow() ~= self:GetCurrentProfileIndex()
	self.configWindows.configTab7:FindChild("btnDeleteProfile"):Enable(enableButton)
	self.configWindows.configTab7:FindChild("btnActivateProfile"):Enable(enableButton)
	self.configWindows.configTab7:FindChild("editProfileName"):SetText(self.profiles[grid:GetCurrentRow()].profileName)
end

function QtCooldown:OnDeleteProfileBtn()
	local index = self.configWindows.configTab7:FindChild("ProfileGrid"):GetCurrentRow()
	if (index == self:GetCurrentProfileIndex()) then
		self:CPrint("[QtCooldown] Cannot delete this profile because it is the currently active profile.")
		return
	end
	tremove(self.profiles, index)
	self:InitializeProfileTab()
end

function QtCooldown:OnDeleteBarBtn()
	self:SaveBarPositions()
	tremove(self.currentProfile.bars, self.barConfigIndex)
	self:ConfigSwapBar(-1)
	self:SetupBars()
end

function QtCooldown:OnCustomPulseAnchorChanged(wndHandler, wndControl)
	local settings = self.currentProfile.bars[self.barConfigIndex].settings
	if (not wndControl:IsChecked()) then
		if (self.pulseAnchorVisible) then
			self:OnTogglePulseBtn()
		end
	end

	self:OnCheckboxChanged(wndHandler, wndControl)
	self:InitializeControlValues()
end

function QtCooldown:OnTogglePulseBtn()
	local settings = self.currentProfile.bars[self.barConfigIndex].settings
	if (self.pulseAnchorVisible) then
		local x, y = self.pulseAnchorWnd:GetAnchorOffsets()
		settings.customPulseX = x + (settings.pulseSize / 2)
		settings.customPulseY = y + (settings.pulseSize / 2)
		self.pulseAnchorVisible = false
		self:StartPulseAnimation(self.trackedCooldowns[1]:GetIcon(), settings.cooldownColor, self.barConfigIndex)
		self.pulseAnchorWnd:Destroy()
	else
		self.pulseAnchorVisible = true
		self.pulseAnchorWnd = Apollo.LoadForm(self.xmlDoc, "QtPulse", nil, self)
		self.pulseAnchorWnd:SetStyle("IgnoreMouse", false)
		self.pulseAnchorWnd:SetStyle("Moveable", true)
		self.pulseAnchorWnd:FindChild("wndIcon"):SetSprite(self.trackedCooldowns[1]:GetIcon())
		self.pulseAnchorWnd:FindChild("wndOverlay"):SetBGColor(settings.cooldownColor)
		self.pulseAnchorWnd:Show(true,true)
		local offset = settings.pulseSize / 2
		self.pulseAnchorWnd:SetAnchorPoints(0.5, 0.5, 0.5, 0.5)
		self.pulseAnchorWnd:SetAnchorOffsets(settings.customPulseX - offset, settings.customPulseY - offset, settings.customPulseX + offset, settings.customPulseY + offset)
	end
end

function QtCooldown:OnNameSaveBtn()
	local text = self.configWindows.configTab1:FindChild("editBarName"):GetText()
	text = self:Trim(text)
	if (text == "") then
		text = self.currentProfile.bars[self.barConfigIndex].name
	end
	if (text:len() >= 25) then
		text = text:sub(1,25)
	end
	self.currentProfile.bars[self.barConfigIndex].name = text
	self.configWindows.configTab1:FindChild("editBarName"):SetText(text)
	self:ConfigSwapBar(self.barConfigIndex)
end

function QtCooldown:OnFilterSaveBtn()
	self.currentProfile.bars[self.barConfigIndex].settings.cooldownBlacklistMode = self.configWindows.configTab5:FindChild("chkCooldownsBlacklist"):IsChecked()
	self.currentProfile.bars[self.barConfigIndex].settings.cooldownFilterList = self:StringToList(self.configWindows.configTab5:FindChild("editCooldowns"):GetText())
	
	self.currentProfile.bars[self.barConfigIndex].settings.buffBlacklistMode = self.configWindows.configTab5:FindChild("chkBuffsBlacklist"):IsChecked()
	self.currentProfile.bars[self.barConfigIndex].settings.buffFilterList = self:StringToList(self.configWindows.configTab5:FindChild("editBuffs"):GetText())
	
	self.currentProfile.bars[self.barConfigIndex].settings.debuffBlacklistMode = self.configWindows.configTab5:FindChild("chkDebuffsBlacklist"):IsChecked()
	self.currentProfile.bars[self.barConfigIndex].settings.debuffFilterList = self:StringToList(self.configWindows.configTab5:FindChild("editDebuffs"):GetText())

	self:SaveBarPositions()
	self:InitializeControlValues()
	self:SetupBars()
end

function QtCooldown:OnTimeLabelSaveBtn()
	local numbers = {}
	local text = self.configWindows.config:FindChild("editTimeLabels"):GetText()
	for i in string.gmatch(text, "([^,]+)") do
		local number = tonumber(i)
		if (number and number > 0 and number < 9999 and #numbers < 6) then
  			tinsert(numbers, number)
  		end
	end
	self.currentProfile.bars[self.barConfigIndex].settings.labelPositions = numbers
	self:InitializeControlValues()
	self:UpdateBarAppearance()
end

function QtCooldown:OnColorSaveBtn(wndHandler, wndControl)
	local c = self.configWindows.configTab2
	if (wndControl == c:FindChild("btnBarColorSave")) then
		self:ValidateColor("barColor", c:FindChild("editBarColor"):GetText(), false)
	elseif (wndControl == c:FindChild("btnCooldownColorSave")) then
		self:ValidateColor("cooldownColor", c:FindChild("editCooldownColor"):GetText(), true)
	elseif (wndControl == c:FindChild("btnBuffColorSave")) then
		self:ValidateColor("buffColor", c:FindChild("editBuffColor"):GetText(), true)
	elseif (wndControl == c:FindChild("btnDebuffColorSave")) then
		self:ValidateColor("debuffColor", c:FindChild("editDebuffColor"):GetText(), true)
	end
	self:SaveBarPositions()
	self:InitializeControlValues()
	self:SetupBars()
end

function QtCooldown:ValidateColor(savedVar, colorStr, hasAlpha)
	--Strip off leading pound sign, remove non-hexadecimal characters, make sure the 
	--provided color is actually a valid (A)RGB value
	if (colorStr:sub(1,1)=="#") then 
		colorStr = colorStr:sub(2)
	end

	local len = colorStr:len()
	colorStr = colorStr:gsub("%X+", "")
	if (len ~= colorStr:len()) then
		return
	end

	if (hasAlpha) then
		if (len ~= 8) then
			return
		end
		self.currentProfile.bars[self.barConfigIndex].settings[savedVar] = colorStr
	else
		if (len ~= 6) then
			return
		end
		self.currentProfile.bars[self.barConfigIndex].settings[savedVar] = "ff"..colorStr
	end
end

function QtCooldown:ConfigSwapBar(barIndex)
	self.barConfigIndex = barIndex
	if (barIndex == -1) then
		self:ConfigSwapTab(6)
	else
		self:ConfigSwapTab(1)
	end
	self:InitializeControlValues()
	self:ConfigLoadBarTree()
end

function QtCooldown:ConfigSwapTab(tabIndex)
	for i =1, 7 do
		local panel = self.configWindows["configTab"..i]
		if (i == tabIndex) then
			panel:Show(true)
		else
			panel:Show(false)
		end
	end
	self.configWindows.configRightPanel:RecalculateContentExtents()
	self.configWindows.configRightPanel:SetVScrollPos(0)
end

function QtCooldown:ConfigLoadBarTree()
	local scrollPos = self.configWindows.configLeftPanel:GetVScrollPos()
	self.configWindows.configLeftPanel:DestroyChildren()
	local targetWnd = nil
	for i = 1,#self.currentProfile.bars do
		local item = Apollo.LoadForm(self.xmlDoc, "BarConfigItem", self.configWindows.configLeftPanel, self)
		item:FindChild("ItemBtn:Text"):SetText(self.currentProfile.bars[i].name)
		item:FindChild("ItemBtn"):SetData(i)
		

		if (self.barConfigIndex == i) then
			item:FindChild("ItemBtn"):SetCheck(true)
			targetWnd = item
			local form = Apollo.LoadForm(self.xmlDoc, "BarConfigSubItem", self.configWindows.configLeftPanel, self)
			form:FindChild("SubItemBtn:Text"):SetText("General")
			form:FindChild("SubItemBtn"):SetData(1)
			form:FindChild("SubItemBtn"):SetCheck(true)

			form = Apollo.LoadForm(self.xmlDoc, "BarConfigSubItem", self.configWindows.configLeftPanel, self)
			form:FindChild("SubItemBtn:Text"):SetText("Appearance")
			form:FindChild("SubItemBtn"):SetData(2)

			form = Apollo.LoadForm(self.xmlDoc, "BarConfigSubItem", self.configWindows.configLeftPanel, self)
			form:FindChild("SubItemBtn:Text"):SetText("Tracking")
			form:FindChild("SubItemBtn"):SetData(3)

			form = Apollo.LoadForm(self.xmlDoc, "BarConfigSubItem", self.configWindows.configLeftPanel, self)
			form:FindChild("SubItemBtn:Text"):SetText("Pulse Animation")
			form:FindChild("SubItemBtn"):SetData(4)

			form = Apollo.LoadForm(self.xmlDoc, "BarConfigSubItem", self.configWindows.configLeftPanel, self)
			form:FindChild("SubItemBtn:Text"):SetText("Blacklist/Whitelist")
			form:FindChild("SubItemBtn"):SetData(5)
		end
	end
	self.configWindows.configLeftPanel:ArrangeChildrenVert(0)
	self.configWindows.configLeftPanel:SetVScrollPos(scrollPos)
	if (#self.currentProfile.bars >= 6) then
		self.configWindows.config:FindChild("btnAddBar"):Enable(false)
	else
		self.configWindows.config:FindChild("btnAddBar"):Enable(true)
	end
	if (#self.currentProfile.bars == 1) then
		self.configWindows.configTab1:FindChild("btnDeleteBar"):Enable(false)
	else
		self.configWindows.configTab1:FindChild("btnDeleteBar"):Enable(true)
	end
end

function QtCooldown:InitializeControlValues()
	local barIndex = self.barConfigIndex
	if (barIndex == -1) then
		self:InitializeProfileTab()
		return
	end

	--Apply slider and checkbox values from mapping tables
	for _,v in pairs(self.sliderMapping) do
		if (v.global ~= nil) then
			v.wnd:SetValue(self.currentProfile[v.savedVar])
			v.buddy:SetText(string.format(v.format, self.currentProfile[v.savedVar]))
		else
			v.wnd:SetValue(self.currentProfile.bars[barIndex].settings[v.savedVar])
			v.buddy:SetText(string.format(v.format, self.currentProfile.bars[barIndex].settings[v.savedVar]))
		end
	end

	for _,v in pairs(self.checkboxMapping) do
		v.wnd:SetCheck(self.currentProfile.bars[barIndex].settings[v.savedVar])
	end

	--Initialize time label Edit control
	self.configWindows.config:FindChild("editTimeLabels"):SetText(QtCooldown:ListToString(self.currentProfile.bars[barIndex].settings.labelPositions))

	--Initialize bar name Edit control
	self.configWindows.configTab1:FindChild("editBarName"):SetText(self.currentProfile.bars[barIndex].name)

	--Initialize blacklist/whitelist Edit controls
	self.configWindows.configTab5:FindChild("editCooldowns"):SetText(QtCooldown:ListToString(self.currentProfile.bars[barIndex].settings.cooldownFilterList))
	self.configWindows.configTab5:FindChild("editBuffs"):SetText(QtCooldown:ListToString(self.currentProfile.bars[barIndex].settings.buffFilterList))
	self.configWindows.configTab5:FindChild("editDebuffs"):SetText(QtCooldown:ListToString(self.currentProfile.bars[barIndex].settings.debuffFilterList))

	--Initialize tracking checkbox controls
	self.configWindows.configTab5:FindChild("chkCooldownsBlacklist"):SetCheck(self.currentProfile.bars[barIndex].settings.cooldownBlacklistMode)
	self.configWindows.configTab5:FindChild("chkCooldownsWhitelist"):SetCheck(not self.currentProfile.bars[barIndex].settings.cooldownBlacklistMode)
	self.configWindows.configTab5:FindChild("chkBuffsBlacklist"):SetCheck(self.currentProfile.bars[barIndex].settings.buffBlacklistMode)
	self.configWindows.configTab5:FindChild("chkBuffsWhitelist"):SetCheck(not self.currentProfile.bars[barIndex].settings.buffBlacklistMode)
	self.configWindows.configTab5:FindChild("chkDebuffsBlacklist"):SetCheck(self.currentProfile.bars[barIndex].settings.debuffBlacklistMode)
	self.configWindows.configTab5:FindChild("chkDebuffsWhitelist"):SetCheck(not self.currentProfile.bars[barIndex].settings.debuffBlacklistMode)	

	--Initialize color Edit controls
	self.configWindows.configTab2:FindChild("editBarColor"):SetText("#"..self.currentProfile.bars[barIndex].settings.barColor:sub(3))
	self.configWindows.configTab2:FindChild("editCooldownColor"):SetText("#"..self.currentProfile.bars[barIndex].settings.cooldownColor)
	self.configWindows.configTab2:FindChild("editBuffColor"):SetText("#"..self.currentProfile.bars[barIndex].settings.buffColor)
	self.configWindows.configTab2:FindChild("editDebuffColor"):SetText("#"..self.currentProfile.bars[barIndex].settings.debuffColor)

	self.configWindows.configTab4:FindChild("btnTogglePulseAnchor"):Enable(self.currentProfile.bars[barIndex].settings.customPulseAnchor)

	self:InitializeProfileTab()
end

function QtCooldown:InitializeProfileTab()
	local currentIndex = self:GetCurrentProfileIndex()
	self.configWindows.configTab7:FindChild("editProfileName"):SetText(self.profiles[currentIndex].profileName)
	local grid = self.configWindows.configTab7:FindChild("ProfileGrid")
	local currentScrollPos = grid:GetVScrollPos()
	grid:DeleteAll()
	for i=1,#self.profiles do
		grid:AddRow(self.profiles[i].profileName..(i == currentIndex and " [Active]" or ""), "", i)
	end
	grid:SetCurrentRow(currentIndex)
	self.configWindows.configTab7:FindChild("btnDeleteProfile"):Enable((#self.profiles > 1))
	self:OnProfileSelChanged()
	grid:SetVScrollPos(currentScrollPos)
end

function QtCooldown:GetCurrentProfileIndex()
	for i=1,#self.profiles do
		if (self.profiles[i].profileSettings == self.currentProfile) then
			return i
		end
	end
end

function QtCooldown:GetBarDefaultsTable()
	local t = 	{
		barOpacity = 100,
		barBgOpacity = 50,
		barHeight = 35,
		barWidth = 500,
		barTextOpacity = 100,
		barColor = "ff27e6ff",
		cooldownColor = "00ffffff",
		buffColor = "5500aa00",
		debuffColor = "55aa0000",
		iconSize = 64,
		iconOpacity = 100,
		showIconBorder = true,
		barLocked = false,
		hideOutOfCombat = false,
		hideWhenEmpty = false,
		overlapFade = true,
		playPulseAnimation = true,
		pulseDuration = 0.75,
		pulseSize = 75,
		customPulseAnchor = false,
		customPulseX = 0,
		customPulseY = 0,
		reverseDirection = false,
		timelineLength = 65,
		timelineCompression = 0.35,
		minCooldownDuration = 2,
		maxCooldownDuration = 300,
		minBuffDuration = 1,
		maxBuffDuration = 60,
		minDebuffDuration = 1,
		maxDebuffDuration = 60,
		trackMyCooldowns = true,
		trackMyBuffs = false,
		trackTargetBuffs = false,
		trackFocusBuffs = false,
		trackMyDebuffs = false,
		trackTargetDebuffs = false,
		trackFocusDebuffs = false,
		cooldownBlacklistMode = true,
		cooldownFilterList = {},
		buffBlacklistMode = true,
		buffFilterList = {},
		debuffBlacklistMode = true,
		debuffFilterList = {},
		labelPositions = {1, 5, 15, 30, 50},
		anchorLeft = 0,
		anchorTop = 0,
		anchorRight = 0,
		anchorBottom = 0}
	return t
end

-----------------------------------------------------------------------------------------------
-- Utility
-----------------------------------------------------------------------------------------------
function QtCooldown:CopyTable(sourceTable)
	local newTable = {}

	for k,v in pairs(sourceTable) do
		if type(v) == "table" then
			newTable[k] = self:CopyTable(v)
		else
			newTable[k] = v
		end
	end

	return newTable
end

function QtCooldown:StringToList(text)
	local list = {}
	for item in string.gmatch(text, "([^,]+)") do
		if (string.len(item) > 0) then
			tinsert(list, item)
		end
	end
	return list
end


function QtCooldown:ListToString(list)
	local str = ""
	for i=1,#list do
		if (i > 1) then
			str = str..","
		end
		str = str..list[i]
	end
	return str
end

function QtCooldown:Trim(str)
	return str:gsub("^%s*(.-)%s*$", "%1")
end

--Kudos to Idzuna, author of Doom_CooldownPulse, for calculating this
function QtCooldown:GetApolloAnimationRate(seconds)
	return 1 / (0.5 * (seconds * seconds) + 0.1)
end

function QtCooldown:CPrint(string)
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Command, string, "")
end

-----------------------------------------------------------------------------------------------
-- QtCooldown Instance
-----------------------------------------------------------------------------------------------
local QtCooldownInst = QtCooldown:new()
QtCooldownInst:Init()