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

    -- Debugging prints to check the template structure
    print("Applying talent points for class:", template.class)
    print("Pet:", pet, "Talent Group:", group)

    -- Print the entire template for debugging
    for tabIndex, tabTemplate in ipairs(template) do
        print("Tab:", tabIndex, "Template:")
        for talentIndex, talentRank in ipairs(tabTemplate) do
            print("  Talent Index:", talentIndex, "Rank:", talentRank)
        end
    end

    local cp = GetUnspentTalentPoints(nil, pet, group)
    print("Current unspent talent points:", cp)

    local tabs = {1, 2, 3}  -- Assuming 3 talent tabs
    local masteryTab = nil

    if not pet then
        local _, masteryState = self:GetTemplateMasteryState(template)
        assert(masteryState)
        masteryTab = masteryState
        SetPreviewPrimaryTalentTree(masteryState, group)

        -- Prioritize the mastery tab first
        print("Mastery state:", masteryState)
        tabs[1], tabs[masteryState] = masteryState, tabs[1]
    end

    -- Function to create a grid of talents for each tab
    local function BuildTalentGrid(tab)
        local talentGrid = {}
        for i = 1, GetNumTalents(tab) do
            local name, icon, row, column, rank, maxRank = GetTalentInfo(tab, i)

            -- Exclude talents that return nil or invalid data
            if name and name ~= "" then
                if not talentGrid[row] then
                    talentGrid[row] = {}
                end
                -- Store the valid talent in the correct row and column
                talentGrid[row][column] = {
                    name = name,
                    icon = icon,
                    row = row,
                    column = column,
                    rank = rank,
                    maxRank = maxRank,
                    index = i -- Store the original index to maintain mapping
                }
            end
        end
        return talentGrid
    end

    -- Apply talents based on the grid and template (numerical order matching grid order)
    local function ApplyTalentsFromGrid(talentGrid, tab)
        -- Get the template for the current tab
        local ttab = template[tab]
		local k = 0 
        -- Iterate through talents row by row, column by column
        for row = 1, 7 do  -- Assume max 7 rows
            for column = 1, 4 do  -- Assume max 4 columns
                local talent = talentGrid[row] and talentGrid[row][column]
                if talent then
					k = k + 1
                    -- Get the talent index from the grid
                    local talentIndex = talent.index

                    -- Retrieve the current rank for the talent
                    local currentRank = select(5, GetTalentInfo(tab, talentIndex, nil, pet, group))

                    -- Retrieve the desired rank from the template, using the correct numerical order
                    local desiredRank = ttab[k]  -- Use the template's talent index

                    -- Calculate the delta between current and desired rank
                    local delta = desiredRank - currentRank

                    print("Tab:", tab, "Row:", row, "Column:", column, "Talent:", talent.name, "Current rank:", currentRank, "Desired rank:", desiredRank, "Delta:", delta)

                    if delta > 0 and cp > 0 then
                        print("Adding", delta, "points to talent:", talent.name, "at index:", talentIndex)
                        AddPreviewTalentPoints(tab, talentIndex, delta, pet, group)

                        -- Update unspent talent points
                        cp = cp - delta  -- Adjust for the actual delta applied
                        print("Updated unspent talent points:", cp)

                        -- Stop if no points are left
                        if cp <= 0 then
                            print("No talent points left. Stopping further iterations.")
                            return false
                        end
                    end
                end
            end
        end
        return true
    end

    -- Iterate over the tabs, prioritizing the mastery tab
    for _, tab in ipairs(tabs) do
        if cp <= 0 then
            print("No talent points left to spend.")
            break
        end

        print("Building talent grid for tab:", tab)
        local talentGrid = BuildTalentGrid(tab)

        print("Applying talents for tab:", tab)
        local success = ApplyTalentsFromGrid(talentGrid, tab)

        -- Stop outer loop if no points are left
        if not success or cp <= 0 then
            break
        end
    end

    -- Check if we're running out of talent points
    if cp < 0 then
        Talented:Print(L["Error while applying talents! Not enough talent points!"])
        print("Error: Not enough talent points!")
        ResetGroupPreviewTalentPoints(pet, group)
        Talented:EnableUI(true)
    else
        -- Switch to the appropriate tab based on whether it's for a pet or player
        if pet then
            PlayerTalentFrameTab2:Click()
        else
            PlayerTalentFrameTab1:Click()
        end
        self:ShowLearnButtonTutorial()
    end
end
