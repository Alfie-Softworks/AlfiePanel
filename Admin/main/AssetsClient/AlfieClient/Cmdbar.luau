local Cmdbar = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ui = require(script.Parent:WaitForChild("UiUtils"))

local _commandsCache = {}

local function findAutofillTemplate(autofillRoot)
	local t = ui.findDescendant(autofillRoot, "TemplateAutofill")
		or ui.findDescendant(autofillRoot, "TemplateAutoFill")
		or ui.findDescendant(autofillRoot, "TemplateAutofil")
		or ui.findDescendant(autofillRoot, "Template")
	return t
end

function Cmdbar.open(rootScript)
	local panel = ui.ensurePanel(rootScript)
	if not panel then return end
	local cmdbar = ui.findDescendant(panel, "Cmdbar")
	if not cmdbar then
		warn("[Cmdbar] Cmdbar element not found inside AlfiePanel")
		return
	end

	local textBox = ui.findDescendant(cmdbar, "TextBox")
	local execBtn = ui.findDescendant(cmdbar, "ExecuteButton")
	local closeBtn = ui.findDescendant(cmdbar, "CloseButton")
	local autofill = ui.findDescendant(cmdbar, "Autofill")
	local template = autofill and findAutofillTemplate(autofill)
	local layout = autofill and ui.findDescendant(autofill, "UIListLayout")

	if autofill then
		if template then template.Visible = false end
		for _, child in ipairs(autofill:GetChildren()) do
			if child ~= template and child ~= layout then
				child:Destroy()
			end
		end
	end

	cmdbar.Visible = true

	local PREFIX = ";"
	local enforcingPrefix = false
	local function ensurePrefix()
		if not textBox then return end
		local t = tostring(textBox.Text or "")
		local cpOld = textBox.CursorPosition or (#t + 1)
		if string.sub(t, 1, #PREFIX) ~= PREFIX then
			enforcingPrefix = true
			textBox.Text = PREFIX .. t
			local caret = cpOld + #PREFIX
			if caret <= #PREFIX then caret = #PREFIX + 1 end
			pcall(function()
				textBox.SelectionStart = caret
				textBox.SelectionEnd = caret
				textBox.CursorPosition = caret
			end)
			enforcingPrefix = false
		else
			if cpOld <= #PREFIX then
				local caret = #PREFIX + 1
				pcall(function()
					textBox.SelectionStart = caret
					textBox.SelectionEnd = caret
					textBox.CursorPosition = caret
				end)
			end
		end
	end
	if textBox then
		if tostring(textBox.Text or "") == "" then
			textBox.Text = PREFIX
			local caret = #PREFIX + 1
			pcall(function()
				textBox.SelectionStart = caret
				textBox.SelectionEnd = caret
				textBox.CursorPosition = caret
			end)
		else
			ensurePrefix()
		end
	end

	local function updateSuggestions()
		if not autofill or not template then return end
		for _, child in ipairs(autofill:GetChildren()) do
			if child ~= template and child ~= layout then
				child:Destroy()
			end
		end
		local q = textBox and tostring(textBox.Text or "") or ""
		q = string.gsub(q, "^%s*(.-)%s*$", "%1")
		if q == "" then return end

		local prefix = PREFIX
		if string.sub(q, 1, #prefix) == prefix then
			q = string.sub(q, #prefix + 1)
		end
		local lower = string.lower(q)
		local candidates = {}
		for _, c in ipairs(_commandsCache) do
			local n = tostring(c.name or "")
			local ln = string.lower(n)
			local starts = string.sub(ln, 1, #lower) == lower
			local aliasStarts = false
			if not starts and typeof(c.aliases) == "table" then
				for _, a in ipairs(c.aliases) do
					local la = string.lower(tostring(a))
					if string.sub(la, 1, #lower) == lower then aliasStarts = true; break end
				end
			end
			if starts or aliasStarts then
				table.insert(candidates, n)
				if #candidates >= 3 then break end
			end
		end

		for i, name in ipairs(candidates) do
			local item = template:Clone()
			item.Name = "Auto_" .. tostring(i)
			item.Visible = true
			item.Parent = autofill

			local cmdLbl = ui.findDescendant(item, "CommandName")
			if cmdLbl and (cmdLbl:IsA("TextLabel") or cmdLbl:IsA("TextButton")) then
				cmdLbl.Text = name
			elseif item:IsA("TextButton") or item:IsA("TextLabel") then
				item.Text = name
			else
				local lbl = ui.findDescendant(item, "TextLabel") or ui.findDescendant(item, "Name")
				if lbl and lbl:IsA("TextLabel") then
					lbl.Text = name
				end
			end
			local function apply()
				local prefix = PREFIX
				if textBox then
					enforcingPrefix = true
					textBox.Text = prefix .. name .. " "
					local caret = #textBox.Text + 1
					pcall(function()
						textBox.SelectionStart = caret
						textBox.SelectionEnd = caret
						textBox.CursorPosition = caret
					end)
					enforcingPrefix = false
				end

				for _, child in ipairs(autofill:GetChildren()) do
					if child ~= template and child ~= layout then child:Destroy() end
				end
			end
			if item:IsA("TextButton") then
				item.MouseButton1Click:Connect(apply)
			else
				item.InputBegan:Connect(function(inp)
					if inp.UserInputType == Enum.UserInputType.MouseButton1 then apply() end
				end)
			end
		end
	end

	if textBox and not textBox:GetAttribute("_HookedCmdbarText") then
		textBox:SetAttribute("_HookedCmdbarText", true)
		textBox:GetPropertyChangedSignal("Text"):Connect(function()
			if enforcingPrefix then return end
			ensurePrefix()
			updateSuggestions()
		end)
		textBox.Focused:Connect(function()
			ensurePrefix()
		end)
	end

	if execBtn and execBtn:IsA("TextButton") and not execBtn:GetAttribute("_HookedCmdExec") then
		execBtn:SetAttribute("_HookedCmdExec", true)
		execBtn.MouseButton1Click:Connect(function()
			local text = textBox and tostring(textBox.Text or "") or ""
			local folder = ReplicatedStorage:FindFirstChild("AdminEvents")
			local runEvt = folder and folder:FindFirstChild("AdminRunCommand")
			if runEvt and runEvt:IsA("RemoteEvent") then
				runEvt:FireServer({ text = text })
			else
				warn("[Cmdbar] AdminRunCommand RemoteEvent missing; did Remotes.provision run?")
			end
		end)
	end

	if closeBtn and closeBtn:IsA("TextButton") and not closeBtn:GetAttribute("_HookedCmdClose") then
		closeBtn:SetAttribute("_HookedCmdClose", true)
		closeBtn.MouseButton1Click:Connect(function()
			cmdbar.Visible = false
		end)
	end
end

function Cmdbar.wireRemotes(rootScript)
	local folder = ReplicatedStorage:WaitForChild("AdminEvents")
	local openEvt = folder and folder:WaitForChild("AdminCmdbar")
	if openEvt then
		openEvt.OnClientEvent:Connect(function(_payload)
			Cmdbar.open(rootScript)
		end)
	else
		warn("[Cmdbar] AdminCmdbar RemoteEvent missing; did Remotes.provision run?")
	end

	local commandsEvt2 = folder and folder:FindFirstChild("AdminCommands")
	if commandsEvt2 then
		commandsEvt2.OnClientEvent:Connect(function(payload)
			if typeof(payload) == "table" and typeof(payload.commands) == "table" then
				_commandsCache = payload.commands
			end
		end)
	end
end

return Cmdbar