local RanksView = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local ui = require(script.Parent:WaitForChild("UiUtils"))

function RanksView.showRanks(rootScript, payload)
	local panel = ui.ensurePanel(rootScript)
	if not panel then return end
	local rankBG = ui.findDescendant(panel, "RankBG")
	if not rankBG then
		warn("[RanksView] RankBG element not found inside AlfiePanel")
		return
	end

	local headerTextLabel = ui.findDescendant(rankBG, "TextLabel")
	local closeBtn = ui.findDescendant(rankBG, "TextButton")
	local scrollBG = ui.findDescendant(rankBG, "ScrollBG")
	local templateRank = ui.findDescendant(rankBG, "TemplateRankPower")
	local templateUser = ui.findDescendant(rankBG, "TemplateUsername")

	if not scrollBG or not templateRank or not templateUser then
		warn("[RanksView] ScrollBG or templates missing in RankBG")
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

		local rankNameLabel = ui.findDescendant(itemRank, "RankName")
		local rankPowerText = ui.findDescendant(itemRank, "RankPowerText")
		if rankNameLabel and rankNameLabel:IsA("TextLabel") then
			rankNameLabel.Text = tostring(r.name or "")
		end
		if rankPowerText and rankPowerText:IsA("TextLabel") then
			rankPowerText.Text = tostring(r.power or 0)
		end

		local users = r.users or {}
		for j, u in ipairs(users) do
			local statusTextAll = tostring(u.status or "")
			local shouldShowUser = u.online or statusTextAll == "Server" or statusTextAll == "Perm" or statusTextAll == "Temp"
			if shouldShowUser then
				local itemUser = templateUser:Clone()
				itemUser.Name = "RankUser_" .. tostring(i) .. "_" .. tostring(j)
				itemUser.Visible = true
				itemUser.Parent = scrollBG
				createdCount += 1
				if createdCount % 15 == 0 then task.wait() end

				local userName = ui.findDescendant(itemUser, "UserName")
				local userState = ui.findDescendant(itemUser, "UserState")
				local userAvatar = ui.findDescendant(itemUser, "UserAvatar")
				local unrankButton = ui.findDescendant(itemUser, "UnrankButton")

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
								warn("[RanksView] AdminUnrank RemoteEvent missing; did Remotes.provision run?")
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

function RanksView.wireRemotes(rootScript)
	local folder = ReplicatedStorage:WaitForChild("AdminEvents")
	local ranksEvt = folder and folder:WaitForChild("AdminRanks")
	if ranksEvt then
		ranksEvt.OnClientEvent:Connect(function(payload)
			RanksView.showRanks(rootScript, payload)
		end)
	else
		warn("[RanksView] AdminRanks RemoteEvent missing; did Remotes.provision run?")
	end
end

return RanksView