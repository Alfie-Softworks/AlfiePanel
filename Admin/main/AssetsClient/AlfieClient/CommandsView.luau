local CommandsView = {}

local ui = require(script.Parent:WaitForChild("UiUtils"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")

function CommandsView.showCommands(rootScript, payload)
	local panel = ui.ensurePanel(rootScript)
	if not panel then return end
	local commandsBG = ui.findDescendant(panel, "CommandsBG")
	if not commandsBG then
		warn("[CommandsView] CommandsBG element not found inside AlfiePanel")
		return
	end
	local headerLabel = ui.findDescendant(commandsBG, "TextLabel")
	local closeBtn = ui.findDescendant(commandsBG, "TextButton")
	local scrollBG = ui.findDescendant(commandsBG, "ScrollBG")
	local templateTag = ui.findDescendant(commandsBG, "TemplateCommandTag")
	local templateCmd = ui.findDescendant(commandsBG, "TemplateCommand")

	if not scrollBG or not templateTag or not templateCmd then
		warn("[CommandsView] ScrollBG or templates missing in CommandsBG")
		return
	end

	for _, child in ipairs(scrollBG:GetChildren()) do
		if child ~= templateTag and child ~= templateCmd and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	templateTag.Visible = false
	templateCmd.Visible = false

	local list = (typeof(payload) == "table" and payload.commands) or {}

	local shouldOpen = true
	if typeof(payload) == "table" and payload.open == false then
		shouldOpen = false
	end
	local wasVisible = commandsBG.Visible
	if not wasVisible and not shouldOpen then
		return
	end
	if shouldOpen then
		commandsBG.Visible = true
	end
	if headerLabel then
		headerLabel.Text = "Commands (" .. tostring(#list) .. ")"
	end

	local groups = {}
	for _, c in ipairs(list) do
		local tags = (typeof(c.tags) == "table" and c.tags) or {}
		if #tags == 0 then tags = {"Other"} end
		local seenLocal = {}
		for _, t in ipairs(tags) do
			local key = string.lower(t)
			if not seenLocal[key] then
				seenLocal[key] = true
				if not groups[key] then
					groups[key] = { name = t, commands = {} }
				end
				table.insert(groups[key].commands, c)
			end
		end
	end

	local orderedKeys = {}
	if groups["fun"] then table.insert(orderedKeys, "fun") end
	local middle = {}
	for k, g in pairs(groups) do
		if k ~= "fun" and k ~= "other" then table.insert(middle, k) end
	end
	table.sort(middle, function(a, b)
		local na = tostring(groups[a].name or a)
		local nb = tostring(groups[b].name or b)
		return string.lower(na) < string.lower(nb)
	end)
	for _, k in ipairs(middle) do table.insert(orderedKeys, k) end
	if groups["other"] then table.insert(orderedKeys, "other") end

	local sectionIndex = 0
	for _, key in ipairs(orderedKeys) do
		sectionIndex += 1
		local group = groups[key]

		local tagItem = templateTag:Clone()
		tagItem.Name = "TagHeader_" .. tostring(sectionIndex) .. "_" .. tostring(key)
		tagItem.Visible = true
		tagItem.Parent = scrollBG
		local tagLabel = ui.findDescendant(tagItem, "CommandTag") or ui.findDescendant(tagItem, "Tag")
		if tagLabel and tagLabel:IsA("TextLabel") then
			local name = tostring(group.name or key)
			local nice = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
			tagLabel.Text = nice
		end

		table.sort(group.commands, function(a, b)
			return string.lower(tostring(a.name or "")) < string.lower(tostring(b.name or ""))
		end)
		for i, c in ipairs(group.commands) do
			local item = templateCmd:Clone()
			item.Name = "CommandItem_" .. tostring(sectionIndex) .. "_" .. tostring(i)
			item.Visible = true
			item.Parent = scrollBG

			local nameLabel = ui.findDescendant(item, "CommandName")
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = tostring(c.name or "")
			end
			local rankLabel = ui.findDescendant(item, "CommandRank")
			if rankLabel and rankLabel:IsA("TextLabel") then
				rankLabel.Text = tostring(c.rankName or ("Rank " .. tostring(c.rank or 0)))
			end
		end
	end

	if closeBtn and closeBtn:IsA("TextButton") and not closeBtn:GetAttribute("_HookedCmdClose") then
		closeBtn:SetAttribute("_HookedCmdClose", true)
		closeBtn.MouseButton1Click:Connect(function()
			commandsBG.Visible = false
		end)
	end
end

function CommandsView.wireRemotes(rootScript)
	local folder = ReplicatedStorage:WaitForChild("AdminEvents")
	local commandsEvt = folder and folder:WaitForChild("AdminCommands")
	if commandsEvt then
		commandsEvt.OnClientEvent:Connect(function(payload)
			CommandsView.showCommands(rootScript, payload)
		end)
	else
		warn("[CommandsView] AdminCommands RemoteEvent missing; did Remotes.provision run?")
	end
end

return CommandsView