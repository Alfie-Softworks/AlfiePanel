local ChatLogsView = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ui = require(script.Parent:WaitForChild("UiUtils"))

local function formatTime(ts)
	local ok, text = pcall(function()
		return os.date("%H:%M:%S", ts)
	end)
	return ok and text or "--:--:--"
end

function ChatLogsView.showLogs(rootScript, logs)
	local panel = ui.ensurePanel(rootScript)
	if not panel then return end

	local loggingBG = ui.findDescendant(panel, "ChatLoggingBG")
	if not loggingBG then
		warn("[ChatLogsView] ChatLoggingBG element not found inside AlfiePanel")
		return
	end

	local headerTextLabel = ui.findDescendant(loggingBG, "HeaderText")
	local closeBtn = ui.findDescendant(loggingBG, "CloseButton")
	local scrollBG = ui.findDescendant(loggingBG, "ScrollBG")
	local template = ui.findDescendant(loggingBG, "TemplateChatLog")

	if not scrollBG or not template then
		warn("[ChatLogsView] ScrollBG or TemplateChatLog missing in ChatLoggingBG")
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
		headerTextLabel.Text = "Chat Logs (" .. tostring(count) .. ")"
	end

	local Players = game:GetService("Players")

	if typeof(logs) == "table" then

		for i = #logs, 1, -1 do
			local entry = logs[i]
			local item = template:Clone()
			item.Name = "ChatLogItem_" .. tostring(i)
			item.Visible = true
			item.Parent = scrollBG

			local userMsg = ui.findDescendant(item, "UserMessage")
			local userName = ui.findDescendant(item, "UserName")
			local userTime = ui.findDescendant(item, "UserTime")
			local userAvatar = ui.findDescendant(item, "UserAvatar")

			if userMsg and userMsg:IsA("TextLabel") then
				userMsg.Text = tostring(entry.message or "")
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

	if closeBtn and closeBtn:IsA("TextButton") and not closeBtn:GetAttribute("_HookedChatLogs") then
		closeBtn:SetAttribute("_HookedChatLogs", true)
		closeBtn.MouseButton1Click:Connect(function()
			loggingBG.Visible = false
		end)
	end
end

function ChatLogsView.wireRemotes(rootScript)
	local folder = ReplicatedStorage:WaitForChild("AdminEvents")
	local logsEvt = folder and folder:WaitForChild("AdminChatLogs")
	if logsEvt then
		logsEvt.OnClientEvent:Connect(function(logs)
			ChatLogsView.showLogs(rootScript, logs)
		end)
	else
		warn("[ChatLogsView] AdminChatLogs RemoteEvent missing; did Remotes.provision run?")
	end
end

return ChatLogsView