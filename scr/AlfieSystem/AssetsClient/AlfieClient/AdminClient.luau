local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function findDescendant(root, name)
	if not root then return nil end
	if root.Name == name then return root end
	for _, d in ipairs(root:GetDescendants()) do
		if d.Name == name then return d end
	end
	return nil
end

local _noclipState = { active = false, connDA = nil }

local function applyNoclipToCharacter(char, active)
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = not active and true or false
		end
	end
	if _noclipState.connDA then _noclipState.connDA:Disconnect() _noclipState.connDA = nil end
	if active then
		_noclipState.connDA = char.DescendantAdded:Connect(function(inst)
			if _noclipState.active and inst:IsA("BasePart") then
				inst.CanCollide = false
			end
		end)
	end
end

player.CharacterAdded:Connect(function(char)
	if _noclipState.active then
		applyNoclipToCharacter(char, true)
	end
end)

local function ensurePanel()
	local existing = playerGui:FindFirstChild("AlfiePanel")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	local source = script.Parent:FindFirstChild("AlfiePanel")
		or (ReplicatedStorage:FindFirstChild("AlfieAssets") and ReplicatedStorage.AlfieAssets:FindFirstChild("AlfiePanel"))
		or ReplicatedStorage:FindFirstChild("AlfiePanel")
	if not source or not source:IsA("ScreenGui") then
		warn("[AdminClient] AlfiePanel ScreenGui not found next to AdminClient or in ReplicatedStorage")
		return nil
	end

	local clone = source:Clone()
	clone.ResetOnSpawn = false
	clone.IgnoreGuiInset = false
	clone.Enabled = true
	clone.Parent = playerGui

	local function hide(name)
		local inst = findDescendant(clone, name)
		if inst and inst:IsA("Frame") or (inst and inst:IsA("TextLabel")) or (inst and inst:IsA("ImageLabel")) then
			inst.Visible = false
		elseif inst and inst:IsA("ScreenGui") then
			inst.Enabled = false
		end
	end
	hide("Cmdbar")
	hide("BanlandBG")
	hide("RankBG")
	hide("CommandsBG")
	hide("LoggingBG")
	hide("Notice")
	return clone
end

local function showLogs(logs)
	local panel = ensurePanel()
	if not panel then return end
	local loggingBG = findDescendant(panel, "LoggingBG")
	if not loggingBG then
		warn("[AdminClient] LoggingBG element not found inside AlfiePanel")
		return
	end

	local headerTextLabel = findDescendant(loggingBG, "HeaderText")
	local closeBtn = findDescendant(loggingBG, "CloseButton")
	local scrollBG = findDescendant(loggingBG, "ScrollBG")
	local template = findDescendant(loggingBG, "TemplateLog")

	if not scrollBG or not template then
		warn("[AdminClient] ScrollBG or TemplateLog missing in LoggingBG")
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

	local function formatTime(ts)
		local ok, text = pcall(function()
			return os.date("%H:%M:%S", ts)
		end)
		return ok and text or "--:--:--"
	end

	if typeof(logs) == "table" then
		for i, entry in ipairs(logs) do
			local item = template:Clone()
			item.Name = "LogItem_" .. tostring(i)
			item.Visible = true 
			item.Parent = scrollBG

			local userCmd = findDescendant(item, "UserCommand")
			local userName = findDescendant(item, "UserName")
			local userTime = findDescendant(item, "UserTime")
			local userAvatar = findDescendant(item, "UserAvatar")

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

local function showRanks(payload)
	local panel = ensurePanel()
	if not panel then return end
	local rankBG = findDescendant(panel, "RankBG")
	if not rankBG then
		warn("[AdminClient] RankBG element not found inside AlfiePanel")
		return
	end

	local headerTextLabel = findDescendant(rankBG, "TextLabel")
	local closeBtn = findDescendant(rankBG, "TextButton")
	local scrollBG = findDescendant(rankBG, "ScrollBG")
	local templateRank = findDescendant(rankBG, "TemplateRankPower")
	local templateUser = findDescendant(rankBG, "TemplateUsername")

	if not scrollBG or not templateRank or not templateUser then
		warn("[AdminClient] ScrollBG or templates missing in RankBG")
		return
	end

	for _, child in ipairs(scrollBG:GetChildren()) do
		if child ~= templateRank and child ~= templateUser and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	templateRank.Visible = false
	templateUser.Visible = false

	if headerTextLabel then
		headerTextLabel.Text = "Ranks"
	end

	local ranks = (typeof(payload) == "table" and payload.ranks) or {}
	local viewerPower = (typeof(payload) == "table" and payload.viewerPower) or 0
	local maxPower = (typeof(payload) == "table" and payload.maxPower) or 0

	local shouldOpen = true
	if typeof(payload) == "table" and payload.open == false then
		shouldOpen = false
	end
	local wasVisible = rankBG.Visible
	if not wasVisible and not shouldOpen then

		return
	end
	if shouldOpen then
		rankBG.Visible = true
	end

	local createdCount = 0
	for i, r in ipairs(ranks) do
		local itemRank = templateRank:Clone()
		itemRank.Name = "RankPower_" .. tostring(i)
		itemRank.Visible = true
		itemRank.Parent = scrollBG
		createdCount += 1
		if createdCount % 15 == 0 then task.wait() end

		local rankNameLabel = findDescendant(itemRank, "RankName")
		local rankPowerText = findDescendant(itemRank, "RankPowerText")
		if rankNameLabel and rankNameLabel:IsA("TextLabel") then
			rankNameLabel.Text = tostring(r.name or "")
		end
		if rankPowerText and rankPowerText:IsA("TextLabel") then
			rankPowerText.Text = tostring(r.power or 0)
		end

		local users = r.users or {}
		for j, u in ipairs(users) do

			local isServer = tostring(u.status or "") == "Server"
			if u.online or isServer then
				local itemUser = templateUser:Clone()
				itemUser.Name = "RankUser_" .. tostring(i) .. "_" .. tostring(j)
				itemUser.Visible = true
				itemUser.Parent = scrollBG
				createdCount += 1
				if createdCount % 15 == 0 then task.wait() end

				local userName = findDescendant(itemUser, "UserName")
				local userState = findDescendant(itemUser, "UserState")
				local userAvatar = findDescendant(itemUser, "UserAvatar")
				local unrankButton = findDescendant(itemUser, "UnrankButton")

				if userName and userName:IsA("TextLabel") then
					userName.Text = tostring(u.name or "?")
				end
				if userState and userState:IsA("TextLabel") then
					userState.Text = tostring(u.status or "")
				end
				if userAvatar and (userAvatar:IsA("ImageLabel") or userAvatar:IsA("ImageButton")) then
					local uid = u.userId
					if typeof(uid) == "number" and uid ~= 0 then
						task.spawn(function()
							local okThumb, thumb = pcall(function()
								return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
							end)
							if okThumb and thumb then
								userAvatar.Image = thumb
							end
						end)
					end
				end
				if unrankButton and unrankButton:IsA("TextButton") then
					local isSelf = (typeof(u.userId) == "number" and u.userId == player.UserId) or (string.lower(tostring(u.name or "")) == string.lower(player.Name))
					local statusText = tostring(u.status or "")
					local shouldShow = (viewerPower == maxPower) and (not isSelf) and (statusText == "Temp" or statusText == "Perm")
					unrankButton.Visible = shouldShow
					if shouldShow and not unrankButton:GetAttribute("_HookedUnrank") then
						unrankButton:SetAttribute("_HookedUnrank", true)
						unrankButton.MouseButton1Click:Connect(function()
							local folder = ReplicatedStorage:FindFirstChild("AdminEvents")
							local evt = folder and folder:FindFirstChild("AdminUnrank")
							if evt and evt:IsA("RemoteEvent") then
								evt:FireServer({ userId = u.userId, userName = u.name })
							else
								warn("[AdminClient] AdminUnrank RemoteEvent missing; did Remotes.provision run?")
							end
						end)
					end
				end
			end
		end
	end

	if closeBtn and closeBtn:IsA("TextButton") and not closeBtn:GetAttribute("_HookedRankClose") then
		closeBtn:SetAttribute("_HookedRankClose", true)
		closeBtn.MouseButton1Click:Connect(function()
			rankBG.Visible = false
		end)
	end
end

local function showBanland(payload)
	local panel = ensurePanel()
	if not panel then return end
	local banBG = findDescendant(panel, "BanlandBG")
	if not banBG then
		warn("[AdminClient] BanlandBG element not found inside AlfiePanel")
		return
	end

	local header = findDescendant(banBG, "Header")
	local closeBtn = findDescendant(banBG, "TextButton") or (header and findDescendant(header, "TextButton"))
	local scrollBG = findDescendant(banBG, "ScrollBG")
	local templateUser = findDescendant(banBG, "TemplateUsername")
	local layout = scrollBG and findDescendant(scrollBG, "UIListLayout")

	if not scrollBG or not templateUser then
		warn("[AdminClient] ScrollBG or TemplateUsername missing in BanlandBG")
		return
	end

	for _, child in ipairs(scrollBG:GetChildren()) do
		if child ~= templateUser and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	templateUser.Visible = false

	local list = (typeof(payload) == "table" and payload.banned) or {}

	local shouldOpen = true
	if typeof(payload) == "table" and payload.open == false then
		shouldOpen = false
	end
	local wasVisible = banBG.Visible
	if not wasVisible and not shouldOpen then
		return
	end
	if shouldOpen then
		banBG.Visible = true
	end

	local created = 0
	for i, b in ipairs(list) do
		local item = templateUser:Clone()
		item.Name = "BannedUser_" .. tostring(i)
		item.Visible = true
		item.Parent = scrollBG
		created += 1
		if created % 15 == 0 then task.wait() end

		local nameLabel = findDescendant(item, "UserName")
		local avatar = findDescendant(item, "UserAvatar")
		local unbanBtn = findDescendant(item, "UnBanButton") or findDescendant(item, "UnbanButton")
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = tostring(b.name or "?")
		end
		if avatar and (avatar:IsA("ImageLabel") or avatar:IsA("ImageButton")) then
			local uid = tonumber(b.userId or 0) or 0
			if uid ~= 0 then
				task.spawn(function()
					local okThumb, thumb = pcall(function()
						return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
					end)
					if okThumb and thumb then
						avatar.Image = thumb
					end
				end)
			end
		end
		if unbanBtn and unbanBtn:IsA("TextButton") and not unbanBtn:GetAttribute("_HookedUnban") then
			unbanBtn:SetAttribute("_HookedUnban", true)
			unbanBtn.MouseButton1Click:Connect(function()
				local folder = ReplicatedStorage:FindFirstChild("AdminEvents")
				local evt = folder and folder:FindFirstChild("AdminUnban")
				if evt and evt:IsA("RemoteEvent") then

					pcall(function()
						local row = unbanBtn:FindFirstAncestorOfClass("Frame") or unbanBtn.Parent
						if row and row ~= templateUser then
							row.Visible = false
							row:Destroy()
						end
					end)
					evt:FireServer({ userId = b.userId, userName = b.name })
				else
					warn("[AdminClient] AdminUnban RemoteEvent missing; did Remotes.provision run?")
				end
			end)
		end
	end

	if closeBtn and closeBtn:IsA("TextButton") and not closeBtn:GetAttribute("_HookedBanClose") then
		closeBtn:SetAttribute("_HookedBanClose", true)
		closeBtn.MouseButton1Click:Connect(function()
			banBG.Visible = false
		end)
	end
end

local function showNotice(header, text, kind)
	local panel = ensurePanel()
	if not panel then return end
	local notice = findDescendant(panel, "Notice")
	if not notice then
		warn("[AdminClient] Notice element not found inside AlfiePanel")
		return
	end

	local headerTextLabel = findDescendant(notice, "HeaderText")
	local mainTextLabel = findDescendant(notice, "MainText")
	local closeBtn = findDescendant(notice, "TextButton")

	if headerTextLabel and header then
		headerTextLabel.Text = tostring(header)
	end
	if mainTextLabel and text then
		mainTextLabel.RichText = true
		mainTextLabel.Text = tostring(text)
	end

	notice.Visible = true

	local originalPos = notice.Position
	local offscreenPos = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, originalPos.Y.Scale, originalPos.Y.Offset + 60)
	notice.Position = offscreenPos

	local popIn = TweenService:Create(notice, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = originalPos })
	popIn:Play()

	task.delay(3, function()
		local slideOut = TweenService:Create(notice, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = offscreenPos })
		slideOut:Play()
		slideOut.Completed:Wait()
		notice.Visible = false
		notice.Position = originalPos
	end)

	if closeBtn and closeBtn:IsA("TextButton") and not closeBtn:GetAttribute("_Hooked") then
		closeBtn:SetAttribute("_Hooked", true)
		closeBtn.MouseButton1Click:Connect(function()
			local slideOut = TweenService:Create(notice, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = offscreenPos })
			slideOut:Play()
			slideOut.Completed:Wait()
			notice.Visible = false
			notice.Position = originalPos
		end)
	end
end

local _gaQueue = {}
local _gaBusy = false

local function _getGlobalAnnouncementGui()
	local ga = findDescendant(playerGui, "GlobalAnnouncement")
	if not ga then
		local panel = playerGui:FindFirstChild("AlfiePanel") or ensurePanel()
		ga = panel and findDescendant(panel, "GlobalAnnouncement") or nil
	end
	return ga
end

local function _renderGlobalAnnouncement(payload)
	local text = (typeof(payload) == "table" and tostring(payload.text or "")) or ""
	local titleText = (typeof(payload) == "table" and tostring(payload.title or "Announcement")) or "Announcement"
	local subtitleText = (typeof(payload) == "table" and tostring(payload.subtitle or "")) or ""

	local ga = _getGlobalAnnouncementGui()
	if not ga then
		warn("[AdminClient] GlobalAnnouncement GUI not found in PlayerGui")
		return
	end

	local function setText(name, value)
		local inst = findDescendant(ga, name)
		if inst and (inst:IsA("TextLabel") or inst:IsA("TextButton")) then
			inst.Text = tostring(value)
		end
	end

	setText("Title", titleText)
	setText("SubTitle", subtitleText)
	setText("Desc", text)

	local pic = findDescendant(ga, "Pic")
	local uid: number? = nil
	if typeof(payload) == "table" then
		if typeof(payload.userId) == "number" then uid = payload.userId end
		if not uid and typeof(payload.senderUserId) == "number" then uid = payload.senderUserId end
		if not uid and typeof(payload.senderId) == "number" then uid = payload.senderId end
		if not uid and typeof(payload.sender) == "number" then uid = payload.sender end
		if not uid and typeof(payload.senderName) == "string" then
			local ok, got = pcall(function()
				return Players:GetUserIdFromNameAsync(payload.senderName)
			end)
			if ok then uid = got end
		end
		if not uid and typeof(payload.userName) == "string" then
			local ok, got = pcall(function()
				return Players:GetUserIdFromNameAsync(payload.userName)
			end)
			if ok then uid = got end
		end
	end
	if pic and (pic:IsA("ImageLabel") or pic:IsA("ImageButton")) then
		if uid and uid ~= 0 then
			task.spawn(function()
				local okThumb, thumb = pcall(function()
					return Players:GetUserThumbnailAsync(uid :: number, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
				end)
				if okThumb and thumb then
					pic.Image = thumb
				end
				pic.Visible = true
			end)
		else
			pic.Visible = false
		end
	end

	local bg = findDescendant(ga, "Bg")
	if bg and (bg:IsA("Frame") or bg:IsA("ImageLabel")) then
		bg.Visible = true
	end

	if ga:IsA("ScreenGui") then
		ga.Enabled = true
	else
		ga.Visible = true
	end
end

local function _hideGlobalAnnouncement()
	local ga = _getGlobalAnnouncementGui()
	if not ga then return end
	local bg = findDescendant(ga, "Bg")
	if ga:IsA("ScreenGui") then
		ga.Enabled = false
	else
		ga.Visible = false
	end
	if bg and (bg:IsA("Frame") or bg:IsA("ImageLabel")) then
		bg.Visible = false
	end
end

local function showGlobalAnnouncement(payload)
	table.insert(_gaQueue, payload)
	local function process()
		if _gaBusy then return end
		local nextPayload = table.remove(_gaQueue, 1)
		if not nextPayload then return end
		_gaBusy = true
		local duration = (typeof(nextPayload) == "table" and tonumber(nextPayload.duration)) or 3
		_renderGlobalAnnouncement(nextPayload)
		task.delay(duration, function()
			_hideGlobalAnnouncement()
			_gaBusy = false
			process()
		end)
	end
	process()
end

local _hintQueue = {}
local _hintBusy = false

local function _getHintGui()
	local hint = findDescendant(playerGui, "Hint")
	if not hint then
		local panel = playerGui:FindFirstChild("AlfiePanel") or ensurePanel()
		hint = panel and findDescendant(panel, "Hint") or nil
	end
	return hint
end

local function _renderHintAnnouncement(payload)
	local text = (typeof(payload) == "table" and tostring(payload.text or "")) or ""
	local hint = _getHintGui()
	if not hint then
		warn("[AdminClient] Hint GUI not found in PlayerGui")
		return
	end
	local desc = findDescendant(hint, "Desc")
	if desc and (desc:IsA("TextLabel") or desc:IsA("TextButton")) then
		desc.Text = text
	end
	local bg = findDescendant(hint, "Bg")
	if bg and (bg:IsA("Frame") or bg:IsA("ImageLabel")) then
		bg.Visible = true
	end
	if hint:IsA("ScreenGui") then
		hint.Enabled = true
	else
		hint.Visible = true
	end
end

local function _hideHintAnnouncement()
	local hint = _getHintGui()
	if not hint then return end
	local bg = findDescendant(hint, "Bg")
	if hint:IsA("ScreenGui") then
		hint.Enabled = false
	else
		hint.Visible = false
	end
	if bg and (bg:IsA("Frame") or bg:IsA("ImageLabel")) then
		bg.Visible = false
	end
end

local function showHintAnnouncement(payload)
	table.insert(_hintQueue, payload)
	local function process()
		if _hintBusy then return end
		local nextPayload = table.remove(_hintQueue, 1)
		if not nextPayload then return end
		_hintBusy = true
		local duration = (typeof(nextPayload) == "table" and tonumber(nextPayload.duration)) or 3
		_renderHintAnnouncement(nextPayload)
		task.delay(duration, function()
			_hideHintAnnouncement()
			_hintBusy = false
			process()
		end)
	end
	process()
end

local folder = ReplicatedStorage:WaitForChild("AdminEvents", 5)
local evt = folder and folder:FindFirstChild("AdminMessage")
if evt then
	evt.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			showNotice(payload.header or payload.kind or "Info", payload.text or "")
		else
			showNotice("Info", tostring(payload))
		end
	end)
else
	warn("[AdminClient] AdminMessage RemoteEvent missing; did Remotes.provision run?")
end

local _flyState = {
	active = false,
	force = nil,
	gyro = nil,
	conn = nil,
	connIB = nil,
	connIE = nil,
	lockType = "PlatformStand",
	noclip = false,
	speed = 50,
}
do
	_flyState = _flyState

	local function setCharacterCollide(char, enabled)
		if not char then return end
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = enabled
			end
		end
	end

	local function stopFly()
		_flyState.active = false
		if _flyState.conn then _flyState.conn:Disconnect() _flyState.conn = nil end
		if _flyState.connIB then _flyState.connIB:Disconnect() _flyState.connIB = nil end
		if _flyState.connIE then _flyState.connIE:Disconnect() _flyState.connIE = nil end
		if _flyState.force then _flyState.force:Destroy() _flyState.force = nil end
		if _flyState.gyro then _flyState.gyro:Destroy() _flyState.gyro = nil end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			pcall(function() humanoid[_flyState.lockType] = false end)
		end
		if _flyState.noclip and not _noclipState.active then
			setCharacterCollide(player.Character, true)
		end
	end

	local function startFly(payload)
		stopFly()
		local char = player.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not (hrp and humanoid) then return end

		local hasNoclip = (typeof(payload) == "table" and payload.noclip ~= nil)
		local noclip = hasNoclip and payload.noclip or _noclipState.active
		local speed = (typeof(payload) == "table" and tonumber(payload.speed)) or 50
		local lockType = (typeof(payload) == "table" and tostring(payload.lockType)) or "PlatformStand"

		_flyState.noclip = noclip
		_flyState.speed = speed
		_flyState.lockType = lockType

		local flyForce = Instance.new("BodyPosition")
		flyForce.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		flyForce.Position = hrp.Position + Vector3.new(0, 4, 0)
		flyForce.Name = "AlfieFlyForce"
		flyForce.Parent = hrp

		local bodyGyro = Instance.new("BodyGyro")
		bodyGyro.D = 50
		bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		bodyGyro.P = noclip and 2000 or 200
		bodyGyro.Name = "AlfieFlyGyro"
		bodyGyro.CFrame = hrp.CFrame
		bodyGyro.Parent = hrp

		_flyState.force = flyForce
		_flyState.gyro = bodyGyro

		if noclip then
			setCharacterCollide(char, false)
		end

		local tiltMax = 25
		local tiltAmount = 0
		local tiltInc = 1
		local static = 0
		local lastUpdate = tick()
		local lastPosition = hrp.Position

		local movementKeysPressed = {}
		local function addDir(d) movementKeysPressed[d] = true end
		local function removeDir(d) movementKeysPressed[d] = nil end
		local function onInputBegan(io, gpe)
			if gpe then return end
			local kc = io.KeyCode
			if kc == Enum.KeyCode.W then addDir("Forwards")
			elseif kc == Enum.KeyCode.S then addDir("Backwards")
			elseif kc == Enum.KeyCode.A then addDir("Left")
			elseif kc == Enum.KeyCode.D then addDir("Right")
			elseif kc == Enum.KeyCode.Space then addDir("Up")
			elseif kc == Enum.KeyCode.LeftControl then addDir("Down") end
		end
		local function onInputEnded(io, _gpe)
			local kc = io.KeyCode
			if kc == Enum.KeyCode.W then removeDir("Forwards")
			elseif kc == Enum.KeyCode.S then removeDir("Backwards")
			elseif kc == Enum.KeyCode.A then removeDir("Left")
			elseif kc == Enum.KeyCode.D then removeDir("Right")
			elseif kc == Enum.KeyCode.Space then removeDir("Up")
			elseif kc == Enum.KeyCode.LeftControl then removeDir("Down") end
		end
		_flyState.connIB = UserInputService.InputBegan:Connect(onInputBegan)
		_flyState.connIE = UserInputService.InputEnded:Connect(onInputEnded)

		_flyState.active = true
		pcall(function() humanoid[lockType] = true end)

		local function GetNextMovement(deltaTime, speed)
			local nextMove = Vector3.new()
			local directions = {
				Left = Vector3.new(-1, 0, 0);
				Right = Vector3.new(1, 0, 0);
				Forwards = Vector3.new(0, 0, -1);
				Backwards = Vector3.new(0, 0, 1);
				Up = Vector3.new(0, 1, 0);
				Down = Vector3.new(0, -1, 0);
			}
			local isComputer = not UserInputService.TouchEnabled
			if isComputer then
				for k, _ in pairs(movementKeysPressed) do
					local v = directions[k]
					if v then nextMove = nextMove + v end
				end
			else
				local md = humanoid.MoveDirection
				for name, v in pairs(directions) do
					local worldVec = hrp.CFrame:VectorToWorldSpace(v)
					if (worldVec - md).Magnitude <= 1.05 and md ~= Vector3.new() then
						nextMove = nextMove + v
					end
				end
			end
			return CFrame.new(nextMove * speed * deltaTime), nextMove
		end

		_flyState.conn = RunService.RenderStepped:Connect(function()
			if not _flyState.active or not char or not hrp or not humanoid then
				stopFly()
				return
			end
			local now = tick()
			local delta = now - lastUpdate
			lastUpdate = now

			local cam = workspace.CurrentCamera
			local look = (cam and (cam.Focus.p - cam.CFrame.p).Unit) or (hrp and hrp.CFrame.LookVector) or Vector3.new(0, 0, -1)
			local pos = hrp.Position
			local move, directionalVector = GetNextMovement(delta, (_flyState.speed or 50) * 10)
			local targetCFrame = CFrame.new(pos, pos + look) * move

			local targetD = 750 + (_flyState.speed * 0.2)
			if _flyState.noclip then targetD = targetD / 2 end

			if move.p ~= Vector3.new() then
				static = 0
				flyForce.D = targetD
				tiltAmount = tiltAmount + tiltInc
				flyForce.Position = targetCFrame.p
			else
				static = static + 1
				tiltAmount = 1
				local maxMag = 6
				local mag = (hrp.Position - lastPosition).Magnitude
				if mag > maxMag and static >= 4 then
					flyForce.Position = hrp.Position
				end
			end

			if math.abs(tiltAmount) > tiltMax then tiltAmount = tiltMax end
			if flyForce.D == targetD then
				local tiltX = tiltAmount * directionalVector.X * -0.5
				local tiltZ = (_flyState.noclip and 0) or tiltAmount * directionalVector.Z
				bodyGyro.CFrame = targetCFrame * CFrame.Angles(math.rad(tiltZ), 0, 0)
			end
			lastPosition = hrp.Position

			pcall(function() humanoid[lockType] = true end)
		end)
	end

	local folderFly = ReplicatedStorage:FindFirstChild("AdminEvents")
	local flyEvt = folderFly and folderFly:FindFirstChild("AdminFly")
	if flyEvt then
		flyEvt.OnClientEvent:Connect(function(payload)
			local active = (typeof(payload) == "table" and payload.active)
			if active then
				startFly(payload)
			else
				stopFly()
			end
		end)
	else
		warn("[AdminClient] AdminFly RemoteEvent missing; did Remotes.provision run?")
	end
end

do
	local function setCharacterCollide(char, enabled)
		if not char then return end
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = enabled
			end
		end
	end

	local folderNC = ReplicatedStorage:FindFirstChild("AdminEvents")
	local noclipEvt = folderNC and folderNC:FindFirstChild("AdminNoclip")
	if noclipEvt then
		noclipEvt.OnClientEvent:Connect(function(payload)
			if typeof(payload) ~= "table" then return end
			local active = (payload.active == true)
			_noclipState.active = active
			local char = player.Character
			applyNoclipToCharacter(char, active)
			if _flyState and _flyState.active then
				_flyState.noclip = active
				if _flyState.gyro then _flyState.gyro.P = active and 2000 or 200 end
			end
		end)
	else
		warn("[AdminClient] AdminNoclip RemoteEvent missing; did Remotes.provision run?")
	end
end

do
	local annEvt = folder and folder:FindFirstChild("AdminAnnouncement")
	if annEvt then
		annEvt.OnClientEvent:Connect(function(payload)
			local gui = (typeof(payload) == "table" and tostring(payload.gui or "")) or ""
			if string.lower(gui) == "hint" then
				showHintAnnouncement(payload)
			else
				showGlobalAnnouncement(payload)
			end
		end)
	else
		warn("[AdminClient] AdminAnnouncement RemoteEvent missing; did Remotes.provision run?")
	end
end

local logsEvt = folder and folder:FindFirstChild("AdminLogs")
if logsEvt then
	logsEvt.OnClientEvent:Connect(function(logs)
		showLogs(logs)
	end)
else
	warn("[AdminClient] AdminLogs RemoteEvent missing; did Remotes.provision run?")
end

local ranksEvt = folder and folder:FindFirstChild("AdminRanks")
if ranksEvt then
	ranksEvt.OnClientEvent:Connect(function(payload)
		showRanks(payload)
	end)
else
	warn("[AdminClient] AdminRanks RemoteEvent missing; did Remotes.provision run?")
end

local function showCommands(payload)
	local panel = ensurePanel()
	if not panel then return end
	local commandsBG = findDescendant(panel, "CommandsBG")
	if not commandsBG then
		warn("[AdminClient] CommandsBG element not found inside AlfiePanel")
		return
	end
	local headerLabel = findDescendant(commandsBG, "TextLabel")
	local closeBtn = findDescendant(commandsBG, "TextButton")
	local scrollBG = findDescendant(commandsBG, "ScrollBG")
	local templateTag = findDescendant(commandsBG, "TemplateCommandTag")
	local templateCmd = findDescendant(commandsBG, "TemplateCommand")

	if not scrollBG or not templateTag or not templateCmd then
		warn("[AdminClient] ScrollBG or templates missing in CommandsBG")
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
		local tagLabel = findDescendant(tagItem, "CommandTag") or findDescendant(tagItem, "Tag")
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

			local nameLabel = findDescendant(item, "CommandName")
			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.Text = tostring(c.name or "")
			end
			local rankLabel = findDescendant(item, "CommandRank")
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

local commandsEvt = folder and folder:FindFirstChild("AdminCommands")
if commandsEvt then
	commandsEvt.OnClientEvent:Connect(function(payload)
		showCommands(payload)
	end)
else
	warn("[AdminClient] AdminCommands RemoteEvent missing; did Remotes.provision run?")
end

do
	local banEvt = folder and folder:FindFirstChild("AdminBanland")
	if banEvt then
		banEvt.OnClientEvent:Connect(function(payload)
			showBanland(payload)
		end)
	else
		warn("[AdminClient] AdminBanland RemoteEvent missing; did Remotes.provision run?")
	end
end

local _commandsCache = {}

do
	local folder2 = ReplicatedStorage:FindFirstChild("AdminEvents")
	local commandsEvt2 = folder2 and folder2:FindFirstChild("AdminCommands")
	if commandsEvt2 then
		commandsEvt2.OnClientEvent:Connect(function(payload)
			if typeof(payload) == "table" and typeof(payload.commands) == "table" then
				_commandsCache = payload.commands
			end
		end)
	end
end

local function findAutofillTemplate(autofillRoot)
	local t = findDescendant(autofillRoot, "TemplateAutofill")
		or findDescendant(autofillRoot, "TemplateAutoFill")
		or findDescendant(autofillRoot, "TemplateAutofil")
		or findDescendant(autofillRoot, "Template")
	return t
end

local function openCmdbar()
	local panel = ensurePanel()
	if not panel then return end
	local cmdbar = findDescendant(panel, "Cmdbar")
	if not cmdbar then
		warn("[AdminClient] Cmdbar element not found inside AlfiePanel")
		return
	end

	local textBox = findDescendant(cmdbar, "TextBox")
	local execBtn = findDescendant(cmdbar, "ExecuteButton")
	local closeBtn = findDescendant(cmdbar, "CloseButton")
	local autofill = findDescendant(cmdbar, "Autofill")
	local template = autofill and findAutofillTemplate(autofill)
	local layout = autofill and findDescendant(autofill, "UIListLayout")

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

			local cmdLbl = findDescendant(item, "CommandName")
			if cmdLbl and (cmdLbl:IsA("TextLabel") or cmdLbl:IsA("TextButton")) then
				cmdLbl.Text = name
			elseif item:IsA("TextButton") or item:IsA("TextLabel") then
				item.Text = name
			else
				local lbl = findDescendant(item, "TextLabel") or findDescendant(item, "Name")
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
				warn("[AdminClient] AdminRunCommand RemoteEvent missing; did Remotes.provision run?")
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

do
	local folder3 = ReplicatedStorage:FindFirstChild("AdminEvents")
	local openEvt = folder3 and folder3:FindFirstChild("AdminCmdbar")
	if openEvt then
		openEvt.OnClientEvent:Connect(function(_payload)
			openCmdbar()
		end)
	else
		warn("[AdminClient] AdminCmdbar RemoteEvent missing; did Remotes.provision run?")
	end
end
