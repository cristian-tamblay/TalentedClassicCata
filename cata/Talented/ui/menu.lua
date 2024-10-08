local Talented = Talented
local L = LibStub("AceLocale-3.0"):GetLocale("Talented")

local classNames = {}
FillLocalizedClassList(classNames, false)
classNames["FEROCITY"] = Talented.tabdata["FEROCITY"][1].name
classNames["TENACITY"] = Talented.tabdata["TENACITY"][1].name
classNames["CUNNING"] = Talented.tabdata["CUNNING"][1].name

local menuColorCodes = {}
local function fill_menuColorCodes()
	for name, default in pairs(RAID_CLASS_COLORS) do
		local color = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[name] or default
		menuColorCodes[name] =  string.format("|cff%2x%2x%2x", color.r * 255, color.g * 255, color.b * 255)
	end
	menuColorCodes["FEROCITY"] = "|cffe0a040"
	menuColorCodes["TENACITY"] = "|cffe0a040"
	menuColorCodes["CUNNING"] = "|cffe0a040"
end
fill_menuColorCodes()

if CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS.RegisterCallback then
	CUSTOM_CLASS_COLORS:RegisterCallback(fill_menuColorCodes)
end

function Talented:OpenOptionsFrame()
	LibStub("AceConfigDialog-3.0"):Open("Talented")
end

function Talented:GetNamedMenu(name)
	local menus = self.menus
	if not menus then
		menus = {}
		self.menus = menus
	end
	local menu = menus[name]
	if not menu then
		menu = {}
		menus[name] = menu
	end
	return menu
end

local function Menu_SetTemplate(entry, template)
--	if IsShiftKeyDown() then
--		local frame = Talented:MakeAlternateView()
--		frame.view:SetTemplate(template)
--		frame.view:SetViewMode"view"
--		frame:Show()
--	else
		Talented:OpenTemplate(template)
--	end
	Talented:CloseMenu()
end

local function Menu_IsTemplatePlayerClass()
	return Talented.template.class == select(2, UnitClass("player"))
end

local function Menu_NewTemplate(entry, class)
	Talented:OpenTemplate(Talented:CreateEmptyTemplate(class))
	Talented:CloseMenu()
end

local function Menu_CloneTemplate(entry, talentGroup)
	Talented:UpdatePlayerSpecs()
	local spec = Talented.alternates[talentGroup]
	if spec then
		Talented:OpenTemplate(Talented:CopyTemplate(spec))
	end
	Talented:CloseMenu()
end

function Talented:CreateTemplateMenu()
	local menu = self:GetNamedMenu("Template")

	local list = {}
	for index, name in ipairs(CLASS_SORT_ORDER) do
		list[index] = name
	end
	list[#list + 1] = "FEROCITY"
	list[#list + 1] = "TENACITY"
	list[#list + 1] = "CUNNING"

	for _, name in ipairs(list) do
		entry = self:GetNamedMenu(name)
		entry.text = classNames[name]
		entry.colorCode = menuColorCodes[name]
		entry.hasArrow = true
		entry.notCheckable = true
		entry.menuList = self:GetNamedMenu(name.."List")
		menu[#menu + 1] = entry
	end

	menu[#menu + 1] = self:GetNamedMenu("separator")

	entry = self:GetNamedMenu("Inspected")
	entry.text = L["Inspected Characters"]
	entry.hasArrow = true
	entry.notCheckable = true
	entry.menuList = self:GetNamedMenu("InspectedList")
	menu[#menu + 1] = entry

	self.CreateTemplateMenu = function (self) return self:GetNamedMenu("Template") end
	return menu
end

local function Sort_Template_Menu_Entry(a, b)
	a, b = a.text, b.text
	if not a then return false end
	if not b then return true end
	return a < b
end

local function update_template_entry(entry, name, template)
	local points = template.points
	if not points then
		points = Talented:GetTemplateInfo(template)
		template.points = points
	end
	entry.text = name..points
end

function Talented:MakeTemplateMenu()
	local menu = self:CreateTemplateMenu()

	for class, color in pairs(menuColorCodes) do
		local menuList = self:GetNamedMenu(class.."List")
		local index = 1
		for name, template in pairs(self.db.global.templates) do
			if template.class == class then
				local entry = menuList[index]
				if not entry then
					entry = {}
					menuList[index] = entry
				end
				index = index + 1
				update_template_entry(entry, name, template)
				entry.func = Menu_SetTemplate
				entry.isNotRadio = true
				entry.checked = (self.template == template)
				entry.arg1 = template
				entry.colorCode = color
			end
		end
		for i = index, #menuList do
			menuList[i].text = nil
		end
		table.sort(menuList, Sort_Template_Menu_Entry)
		local menu = self:GetNamedMenu(class)
		menu.text = classNames[class]
		if index == 1 then
			menu.disabled = true
		else
			menu.disabled = nil
			menu.colorCode = color
		end
	end

	if not self.inspections then
		 self:GetNamedMenu("Inspected").disabled = true
	else
		 self:GetNamedMenu("Inspected").disabled = nil
		local menuList = self:GetNamedMenu("InspectedList")
		local index = 1
		for name, template in pairs(self.inspections) do
			local entry = menuList[index]
			if not entry then
				entry = {}
				menuList[index] = entry
			end
			index = index + 1
			update_template_entry(entry, name, template)
			entry.func = Menu_SetTemplate
			entry.checked = (self.template == template)
			entry.arg1 = template
			entry.colorCode = menuColorCodes[template.class]
		end
		table.sort(menuList, Sort_Template_Menu_Entry)
	end
	return menu
end

StaticPopupDialogs["TALENTED_IMPORT_URL"] = {
	text = L["Enter the complete URL of a template from Blizzard talent calculator or wowhead."],
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	editBoxWidth = 350,
	maxLetters = 256,
	whileDead = 1,
	OnShow = function (self)
		self.editBox:SetText""
	end,
	OnAccept = function(self)
		local url = self.editBox:GetText()
		self:Hide()
		local template = Talented:ImportTemplate(url)
		if template then Talented:OpenTemplate(template) end
	end,
	timeout = 0,
	EditBoxOnEnterPressed = function(self)
		local parent = self:GetParent()
		StaticPopupDialogs[parent.which].OnAccept(parent)
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide();
	end,
	hideOnEscape = 1
}

StaticPopupDialogs["TALENTED_EXPORT_TO"] = {
	text = L["Enter the name of the character you want to send the template to."],
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	editBoxWidth = 350,
	maxLetters = 256,
	whileDead = 1,
	autoCompleteParams = AUTOCOMPLETE_LIST.WHISPER,
	OnAccept = function(self)
		local name = self.editBox:GetText()
		self:Hide()
		Talented:ExportTemplateToUser(name)
	end,
	timeout = 0,
	EditBoxOnEnterPressed =
		StaticPopupDialogs.TALENTED_IMPORT_URL.EditBoxOnEnterPressed,
	EditBoxOnEscapePressed =
		StaticPopupDialogs.TALENTED_IMPORT_URL.EditBoxOnEscapePressed,
	hideOnEscape = 1
}

function Talented:CreateActionMenu()
	local menu = self:GetNamedMenu("Action")

	local menuList = self:GetNamedMenu("NewTemplates")

	local list = {}
	for index, name in ipairs(CLASS_SORT_ORDER) do
		list[index] = name
	end
	list[#list + 1] = "FEROCITY"
	list[#list + 1] = "TENACITY"
	list[#list + 1] = "CUNNING"

	local _, pclass = UnitClass"player"

	local cMenuList = self:GetNamedMenu("NewTemplatesClass")
	cMenuList[1] = {
		text = L["New Template"],
		colorCode = menuColorCodes[pclass],
		notCheckable = true,
		func = Menu_NewTemplate,
		arg1 = pclass,
	}
	cMenuList[2] = {
		text = L["Copy from primary talents"],
		colorCode = menuColorCodes[pclass],
		notCheckable = true,
		func = Menu_CloneTemplate,
		arg1 = 1,
	}
	cMenuList[3] = {
		text = L["Copy from secondary talents"],
		colorCode = menuColorCodes[pclass],
		notCheckable = true,
		func = Menu_CloneTemplate,
		arg1 = 2,
	}

	for _, name in ipairs(list) do
		local s
		if name == pclass then
			s = {
				text = classNames[name],
				colorCode = menuColorCodes[name],
				hasArrow = true,
				notCheckable = true,
				menuList = cMenuList,
			}
		else
			s = {
				text = classNames[name],
				colorCode = menuColorCodes[name],
				func = Menu_NewTemplate,
				arg1 = name,
				notCheckable = true,
			}
		end
		menuList[#menuList + 1] = s
	end

	menu[#menu + 1] = {
		text = L["New Template"],
		hasArrow = true,
		notCheckable = true,
		menuList = menuList,
	}
	local entry = self:GetNamedMenu("separator")
	if not entry.text then
		entry.text = ""
		entry.disabled = true
		entry.notCheckable = true
		entry.separator = true
	end
	menu[#menu + 1] = entry

	entry = self:GetNamedMenu("Apply")
	entry.text = L["Apply template"]
	entry.func = function () Talented:SetMode("apply") end
	entry.notCheckable = true
	menu[#menu + 1] = entry

	entry = self:GetNamedMenu("Delete")
	entry.text = L["Delete template"]
	entry.func = function () Talented:DeleteCurrentTemplate() end
	entry.notCheckable = true
	menu[#menu + 1] = entry

	entry = self:GetNamedMenu("Copy")
	entry.text = L["Copy template"]
	entry.func = function () Talented:OpenTemplate(Talented:CopyTemplate(Talented.template)) end
	entry.notCheckable = true
	menu[#menu + 1] = entry

	entry = self:GetNamedMenu("Target")
	entry.text = L["Set as target"]
	entry.func = function (entry, targetName, name)
		if entry.checked then
			Talented.db.char.targets[targetName] = nil
		else
			Talented.db.char.targets[targetName] = name
		end
	end
	entry.arg2 = self.template.name
	menu[#menu + 1] = entry

	menu[#menu + 1] = self:GetNamedMenu("separator")
	menu[#menu + 1] = {
		text = L["Import template ..."],
		notCheckable = true,
		func = function ()
			StaticPopup_Show"TALENTED_IMPORT_URL"
		end,
	}

	menu[#menu + 1] = {
		text = L["Export template"],
		hasArrow = true,
		notCheckable = true,
		menuList = self:GetNamedMenu("exporters"),
	}

	menu[#menu + 1] = {
		text = L["Send to ..."],
		notCheckable = true,
		func = function ()
			StaticPopup_Show"TALENTED_EXPORT_TO"
		end,
	}

	menu[#menu + 1] = {
		text = L["Options ..."],
		notCheckable = true,
		func = function ()
			Talented:OpenOptionsFrame()
		end,
	}

	self.CreateActionMenu = function (self) return self:GetNamedMenu("Action") end
	return menu
end

local function Export_Template(entry, handler)
	local url = handler(Talented, Talented.template)
	if url then
		if Talented.db.profile.show_url_in_chat then
			Talented:WriteToChat(url)
		else
			Talented:ShowInDialog(url)
		end
	end
end

function Talented:MakeActionMenu()
	local menu = self:CreateActionMenu()
	local activeTalentGroup = GetActiveTalentGroup()
	local restricted = (self.template.class ~= select(2, UnitClass("player")))
	local pet_restricted = not self.GetPetClass or self:GetPetClass() ~= self.template.class
	self:GetNamedMenu("NewTemplatesClass")[3].disabled = (GetNumTalentGroups() < 2)

	self:GetNamedMenu("Apply").disabled = restricted and pet_restricted
	self:GetNamedMenu("Delete").disabled = not self.db.global.templates[self.template.name]

	local target = self:GetNamedMenu("Target")
	local targetName
	if not restricted then
		targetName = activeTalentGroup
	elseif not pet_restricted then
		targetName = UnitName"PET"
	end
	local hasTargetTemplate = targetName and self.db.char.targets[targetName]
	local isCurrentTargetTemplate = hasTargetTemplate and self.template.name == hasTargetTemplate
	if hasTargetTemplate and not isCurrentTargetTemplate then
		target.text = L["Clear target"]
		target.arg1 = targetName
		target.arg2 = nil
		target.disabled = nil
		target.checked = nil
	else
		target.text = L["Set as target"]
		target.arg1 = targetName
		target.arg2 = self.template.name
		target.disabled = not targetName
		target.checked = isCurrentTargetTemplate
	end

	for _, entry in ipairs(self:GetNamedMenu("NewTemplates")) do
		local class = entry.arg1
		entry.colorCode = menuColorCodes[class]
	end

	local exporters = self:GetNamedMenu("exporters")
	local index = 1
	for name, handler in pairs(self.exporters) do
		exporters[index] = exporters[index] or {}
		exporters[index].text = name
		exporters[index].func = Export_Template
		exporters[index].arg1 = handler
		index = index + 1
	end
	for i = index, #exporters do
		exporters[i].text = nil
	end

	return menu
end

function Talented:CloseMenu()
	HideDropDownMenu(1)
end

function Talented:GetDropdownFrame(frame)
	local dropdown = CreateFrame("Frame", "TalentedDropDown", nil, "UIDropDownMenuTemplate")
	dropdown.point = "TOPLEFT"
	dropdown.relativePoint = "BOTTOMLEFT"
	dropdown.displayMode = "MENU"
	dropdown.xOffset = 2
	dropdown.yOffset = 2
	dropdown.relativeTo = frame
	self.dropdown = dropdown
	self.GetDropdownFrame = function (self, frame)
		local dropdown = self.dropdown
		dropdown.relativeTo = frame
		return dropdown
	end
	return dropdown
end

function Talented:OpenTemplateMenu(frame)
	EasyMenu(self:MakeTemplateMenu(), self:GetDropdownFrame(frame))
end

function Talented:OpenActionMenu(frame)
	EasyMenu(self:MakeActionMenu(), self:GetDropdownFrame(frame))
end

function Talented:OpenLockMenu(frame, parent)
	local menu = self:GetNamedMenu("LockFrame")
	local entry = menu[1]
	if not entry then
		entry = {
			text = L["Lock frame"],
			func = function (entry, frame)
				Talented:SetFrameLock(frame, not entry.checked)
			end,
		}
		menu[1] = entry
	end
	entry.arg1 = parent
	entry.checked = self:GetFrameLock(parent)
	EasyMenu(menu, self:GetDropdownFrame(frame))
end
