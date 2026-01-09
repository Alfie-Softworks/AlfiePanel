local BanlandView = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ui = require(script.Parent:WaitForChild("UiUtils"))

function BanlandView.showBanland(rootScript, payload)
	local panel = ui.ensurePanel(rootScript)
	if not panel then return end
	local banBG = ui.findDescendant(panel, "BanlandBG")
	if not banBG then
		warn("[BanlandView] BanlandBG element not found inside AlfiePanel")
		return
	end

	local header = ui.findDescendant(banBG, "Header")
	local closeBtn = ui.findDescendant(banBG, "TextButton") or (header and ui.findDescendant(header, "TextButton"))
	local scrollBG = ui.findDescendant(banBG, "ScrollBG")
	local templateUser = ui.findDescendant(banBG, "TemplateUsername")
	local layout = scrollBG and ui.findDescendant(scrollBG, "UIListLayout")

	if not scrollBG or not templateUser then
		warn("[BanlandView] ScrollBG or TemplateUsername missing in BanlandBG")
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

		local nameLabel = ui.findDescendant(item, "UserName")
		local avatar = ui.findDescendant(item, "UserAvatar")
		local unbanBtn = ui.findDescendant(item, "UnBanButton") or ui.findDescendant(item, "UnbanButton")
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
					warn("[BanlandView] AdminUnban RemoteEvent missing; did Remotes.provision run?")
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

function BanlandView.wireRemotes(rootScript)
	local folder = ReplicatedStorage:WaitForChild("AdminEvents")
	local banEvt = folder and folder:WaitForChild("AdminBanland")
	if banEvt then
		banEvt.OnClientEvent:Connect(function(payload)
			BanlandView.showBanland(rootScript, payload)
		end)
	else
		warn("[BanlandView] AdminBanland RemoteEvent missing; did Remotes.provision run?")
	end
end

return BanlandView