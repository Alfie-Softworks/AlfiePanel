local LogsView = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ui = require(script.Parent:WaitForChild("UiUtils"))

function LogsView.showLogs(rootScript, logs)
	local panel = ui.ensurePanel(rootScript)
	if not panel then return end
	local loggingBG = ui.findDescendant(panel, "LoggingBG")
	if not loggingBG then
		warn("[LogsView] LoggingBG element not found inside AlfiePanel")
		return
	end

	local headerTextLabel = ui.findDescendant(loggingBG, "HeaderText")
	local closeBtn = ui.findDescendant(loggingBG, "CloseButton")
	local scrollBG = ui.findDescendant(loggingBG, "ScrollBG")
	local template = ui.findDescendant(loggingBG, "TemplateLog")

	if not scrollBG or not template then
		warn("[LogsView] ScrollBG or TemplateLog missing in LoggingBG")
		return
	end

	for _, child in ipairs(scrollBG:GetChildren()) do
		if child ~= template and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	template.Visible = false

	if headerTextLabel then
		local count = typeof(logs) == "table" and #logs or 0
		headerTextLabel.Text = "Logs (" .. tostring(count) .. ")"
	end

	local Players = game:GetService("Players")
	local function formatTime(ts)
		local ok, text = pcall(function()
			return os.date("%H:%M:%S", ts)
		end)
		return ok and text or "--:--:--"
	end

	if typeof(logs) == "table" then

		for i = #logs, 1, -1 do
			local entry = logs[i]
			local item = template:Clone()
			item.Name = "LogItem_" .. tostring(i)
			item.Visible = true
			item.Parent = scrollBG

			local userCmd = ui.findDescendant(item, "UserCommand")
			local userName = ui.findDescendant(item, "UserName")
			local userTime = ui.findDescendant(item, "UserTime")
			local userAvatar = ui.findDescendant(item, "UserAvatar")

			if userCmd and userCmd:IsA("TextLabel") then
				userCmd.Text = tostring(entry.command or "")
			end
			if userName and userName:IsA("TextLabel") then
				userName.Text = tostring(entry.userName or "?")
			end
			if userTime and userTime:IsA("TextLabel") then
				userTime.Text = formatTime(entry.timestamp or os.time())
			end
			if userAvatar and (userAvatar:IsA("ImageLabel") or userAvatar:IsA("ImageButton")) then
				local okThumb, thumb = pcall(function()
					return Players:GetUserThumbnailAsync(entry.userId or 0, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
				end)
				if okThumb and thumb then
					userAvatar.Image = thumb
				end
			end
		end
	end

	loggingBG.Visible = true

	if closeBtn and closeBtn:IsA("TextButton") and not closeBtn:GetAttribute("_HookedLogs") then
		closeBtn:SetAttribute("_HookedLogs", true)
		closeBtn.MouseButton1Click:Connect(function()
			loggingBG.Visible = false
		end)
	end
end

function LogsView.wireRemotes(rootScript)
	local folder = ReplicatedStorage:WaitForChild("AdminEvents")
	local logsEvt = folder and folder:WaitForChild("AdminLogs")
	if logsEvt then
		logsEvt.OnClientEvent:Connect(function(logs)
			LogsView.showLogs(rootScript, logs)
		end)
	else
		warn("[LogsView] AdminLogs RemoteEvent missing; did Remotes.provision run?")
	end
end

return LogsView