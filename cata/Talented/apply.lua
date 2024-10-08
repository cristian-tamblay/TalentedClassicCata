local Talented = Talented
local L = LibStub("AceLocale-3.0"):GetLocale("Talented")

function Talented:ApplyCurrentTemplate()
	local template = self.template
	local pet = not RAID_CLASS_COLORS[template.class]
	if pet then
		if not self.GetPetClass or self:GetPetClass() ~= template.class then
			self:Print(L["Sorry, I can't apply this template because it doesn't match your pet's class!"])
			self.mode = "view"
			self:UpdateView()
			return
		end
	else
		if select(2, UnitClass"player") ~= template.class then
			self:Print(L["Sorry, I can't apply this template because it doesn't match your class!"])
			self.mode = "view"
			self:UpdateView()
			return
		end
		local state, mastery = self:GetTemplateMasteryState(template)
		if state == "error" then
			self:Print"Runtime error: Impossible to apply this template, It is invalid"
			self.mode = "view"
			self:UpdateView()
			return
		end
		if state == "none" then
			self:Print(L["Nothing to do"])
			self.mode = "view"
			self:UpdateView()
			return
		end
		local actual_mastery = GetPrimaryTalentTree(nil, nil, GetActiveTalentGroup())
		if actual_mastery and actual_mastery ~= mastery then
			self:Print(L["Sorry, I can't apply this template because it has the wrong primary talent tree selected"])
			self.mode = "view"
			self:UpdateView()
			return
		end
	end
	local count = 0
	local current = pet and self.pet_current or self:GetActiveSpec()
	local group = GetActiveTalentGroup(nil, pet)
	-- check if enough talent points are available
	local available = GetUnspentTalentPoints(nil, pet, group)
	for tab, tree in ipairs(self:UncompressSpellData(template.class)) do
		for index = 1, #tree do
			local delta = template[tab][index] - current[tab][index]
			if delta > 0 then
				count = count + delta
			end
		end
	end
	if count == 0 then
		self:Print(L["Nothing to do"])
		self.mode = "view"
		self:UpdateView()
	elseif count > available then
		self:Print(L["Sorry, I can't apply this template because you don't have enough talent points available (need %d)!"], count)
		self.mode = "view"
		self:UpdateView()
	else
		-- self:EnableUI(false)
		self:ApplyTalentPoints()
	end
end

function Talented:ShowLearnButtonTutorial()
	local frame = PlayerTalentFrameLearnButtonTutorial
	local text = PlayerTalentFrameLearnButtonTutorialText
	if not frame.talented_hook then
		frame.talented_hook = text:GetText()
		frame:HookScript("OnHide", function (self)
			local text = PlayerTalentFrameLearnButtonTutorialText
			text:SetText(self.talented_hook)
		end)
	end
	text:SetText(L["Talented has applied your template to the preview. Review the result and press Learn to validate."])
	frame:Show()
end

function Talented:ApplyTalentPoints()
	local template = self.template
	local pet = not RAID_CLASS_COLORS[template.class]
	local group = GetActiveTalentGroup(nil, pet)
	ResetGroupPreviewTalentPoints(pet, group)
	local cp = GetUnspentTalentPoints(nil, pet, group)
	if not pet then
		local _, m = self:GetTemplateMasteryState(template)
		assert(m)
		SetPreviewPrimaryTalentTree(m, group)
	end
	while true do
		local missing, set
		for tab, tree in ipairs(self:UncompressSpellData(template.class)) do
			local ttab = template[tab]
			for index = 1, #tree do
				local rank = select(8, GetTalentInfo(tab, index, nil, pet, group))
				local delta = ttab[index] - rank
				if delta > 0 then
					AddPreviewTalentPoints(tab, index, delta, pet, group)
					local nrank = select(8, GetTalentInfo(tab, index, nil, pet, group))
					if nrank < ttab[index] then
						missing = true
					elseif nrank > rank then
						set = true
					end
					cp = cp - nrank + rank
				end
			end
		end
		if not missing then break end
		assert(set) -- make sure we did something
	end
	if cp < 0 then
		Talented:Print(L["Error while applying talents! Not enough talent points!"])
		ResetGroupPreviewTalentPoints(pet, group)
		Talented:EnableUI(true)
	else
		if pet then
			PlayerTalentFrameTab2:Click()
		else
			PlayerTalentFrameTab1:Click()
		end
		self:ShowLearnButtonTutorial()
	end
end
