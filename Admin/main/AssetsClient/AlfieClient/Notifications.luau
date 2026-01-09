local Notifications = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local ui
local playSound: (name: string) -> () = function() end

function Notifications.init(deps)
	ui = require(script.Parent:WaitForChild("UiUtils"))
	if typeof(deps) == "table" and typeof(deps.playSound) == "function" then
		playSound = deps.playSound
	end
end

local function _getAnnouncementGui(rootScript)
	local playerGui = player:WaitForChild("PlayerGui")
	local ga = ui.findDescendant(playerGui, "Announcement")
	if not ga then
		local panel = playerGui:FindFirstChild("AlfiePanel") or ui.ensurePanel(rootScript)
		ga = panel and ui.findDescendant(panel, "Announcement") or nil
	end
	return ga
end

local function _getHintGui(rootScript)
	local playerGui = player:WaitForChild("PlayerGui")
	local hint = ui.findDescendant(playerGui, "Hint")
	if not hint then
		local panel = playerGui:FindFirstChild("AlfiePanel") or ui.ensurePanel(rootScript)
		hint = panel and ui.findDescendant(panel, "Hint") or nil
	end
	return hint
end

local _noticeQueue = {}
local _noticeBusy = false
local _noticeHomePos: UDim2? = nil
local _noticeSeq = 0
local _activeNoticeGui: Instance? = nil
local _noticeOffscreenPos: UDim2? = nil

local function _getNoticeGui(rootScript)
	local panel = ui.ensurePanel(rootScript)
	if not panel then return nil end
	local notice = ui.findDescendant(panel, "Notice")
	if not notice then
		warn("[Notifications] Notice element not found inside AlfiePanel")
		return nil
	end
	return notice
end

local function _hideNotice(rootScript)
	local notice = _getNoticeGui(rootScript)
	if not notice then return end
	notice.Visible = false
	if _noticeHomePos then
		notice.Position = _noticeHomePos
	end
end

local function _processNotice(rootScript)
	if _noticeBusy then return end
	local nextPayload = table.remove(_noticeQueue, 1)
	if not nextPayload then return end
	_noticeBusy = true
	_noticeSeq += 1
	local seq = _noticeSeq

	local notice = _getNoticeGui(rootScript)
	if not notice then
		_noticeBusy = false
		return
	end

	local headerTextLabel = ui.findDescendant(notice, "HeaderText")
	local mainTextLabel = ui.findDescendant(notice, "MainText")
	local closeBtn = ui.findDescendant(notice, "TextButton")

	if headerTextLabel and nextPayload.header then
		headerTextLabel.Text = tostring(nextPayload.header)
	elseif headerTextLabel and nextPayload.kind then
		headerTextLabel.Text = tostring(nextPayload.kind)
	end
	if mainTextLabel and nextPayload.text then
		mainTextLabel.RichText = true
		mainTextLabel.Text = tostring(nextPayload.text)
	end

	notice.Visible = true

	if not _noticeHomePos then
		_noticeHomePos = notice.Position
	end
	local originalPos = _noticeHomePos
	local offscreenPos = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, originalPos.Y.Scale, originalPos.Y.Offset + 60)
	notice.Position = offscreenPos
	_activeNoticeGui = notice
	_noticeOffscreenPos = offscreenPos

	local popIn = TweenService:Create(notice, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = originalPos })
	popIn:Play()
	playSound("Notification")

	if closeBtn and closeBtn:IsA("TextButton") and not closeBtn:GetAttribute("_Hooked") then
		closeBtn:SetAttribute("_Hooked", true)
		closeBtn.MouseButton1Click:Connect(function()

			_noticeSeq += 1
			local slideOut = TweenService:Create(notice, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = offscreenPos })
			slideOut:Play()
			slideOut.Completed:Wait()
			_hideNotice(rootScript)
			_noticeBusy = false
			_processNotice(rootScript)
		end)
	end

	local baseDuration = (typeof(nextPayload.duration) == "number" and math.max(nextPayload.duration, 0.1)) or 1.0
	local backlog = #_noticeQueue
	local duration = baseDuration
	if backlog >= 3 then
		duration = math.min(baseDuration, 0.4)
	elseif backlog >= 1 then
		duration = math.min(baseDuration, 0.6)
	end
	task.delay(duration, function()

		if seq ~= _noticeSeq then return end
		local slideOut = TweenService:Create(notice, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = offscreenPos })
		slideOut:Play()
		slideOut.Completed:Wait()
		_hideNotice(rootScript)
		_noticeBusy = false
		_processNotice(rootScript)
	end)
end

function Notifications.showNotice(rootScript, header, text, kind, duration)
	table.insert(_noticeQueue, {
		header = header,
		text = text,
		kind = kind,
		duration = duration,
	})

	if _noticeBusy and _activeNoticeGui and _noticeOffscreenPos then
		_noticeSeq += 1 
		local slideOut = TweenService:Create(_activeNoticeGui, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = _noticeOffscreenPos })
		slideOut:Play()
		slideOut.Completed:Wait()
		_hideNotice(rootScript)
		_noticeBusy = false
	end
	_processNotice(rootScript)
end

local _gaQueue = {}
local _gaBusy = false

local function _renderAnnouncement(rootScript, payload)
	local text = (typeof(payload) == "table" and tostring(payload.text or "")) or ""
	local titleText = (typeof(payload) == "table" and tostring(payload.title or "Announcement")) or "Announcement"
	local subtitleText = (typeof(payload) == "table" and tostring(payload.subtitle or "")) or ""

	local ga = _getAnnouncementGui(rootScript)
	if not ga then
		warn("[Notifications] Announcement GUI not found in PlayerGui")
		return
	end

	local function setText(name, value)
		local inst = ui.findDescendant(ga, name)
		if inst and (inst:IsA("TextLabel") or inst:IsA("TextButton")) then
			inst.Text = tostring(value)
		end
	end

	setText("Title", titleText)
	setText("SubTitle", subtitleText)
	setText("Desc", text)

	local pic = ui.findDescendant(ga, "Pic")
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
				playSound("Announcement")
			end)
		else
			pic.Visible = false
		end
	end

	local bg = ui.findDescendant(ga, "Bg")
	if bg and (bg:IsA("Frame") or bg:IsA("ImageLabel")) then
		bg.Visible = true
	end

	if ga:IsA("ScreenGui") then
		ga.Enabled = true
	else
		ga.Visible = true
	end
end

local function _hideAnnouncement(rootScript)
	local ga = _getAnnouncementGui(rootScript)
	if not ga then return end
	local bg = ui.findDescendant(ga, "Bg")
	if ga:IsA("ScreenGui") then
		ga.Enabled = false
	else
		ga.Visible = false
	end
	if bg and (bg:IsA("Frame") or bg:IsA("ImageLabel")) then
		bg.Visible = false
	end
end

function Notifications.showAnnouncement(rootScript, payload)
	table.insert(_gaQueue, payload)
	local function process()
		if _gaBusy then return end
		local nextPayload = table.remove(_gaQueue, 1)
		if not nextPayload then return end
		_gaBusy = true
		local duration = (typeof(nextPayload) == "table" and tonumber(nextPayload.duration)) or 3
		_renderAnnouncement(rootScript, nextPayload)
		task.delay(duration, function()
			_hideAnnouncement(rootScript)
			_gaBusy = false
			process()
		end)
	end
	process()
end

local _hintQueue = {}
local _hintBusy = false

local function _renderHintAnnouncement(rootScript, payload)
	local text = (typeof(payload) == "table" and tostring(payload.text or "")) or ""
	local hint = _getHintGui(rootScript)
	if not hint then
		warn("[Notifications] Hint GUI not found in PlayerGui")
		return
	end
	local desc = ui.findDescendant(hint, "Desc")
	if desc and (desc:IsA("TextLabel") or desc:IsA("TextButton")) then
		desc.Text = text
	end
	local bg = ui.findDescendant(hint, "Bg")
	if bg and (bg:IsA("Frame") or bg:IsA("ImageLabel")) then
		bg.Visible = true
	end
	if hint:IsA("ScreenGui") then
		hint.Enabled = true
	else
		hint.Visible = true
	end
end

local function _hideHintAnnouncement(rootScript)
	local hint = _getHintGui(rootScript)
	if not hint then return end
	local bg = ui.findDescendant(hint, "Bg")
	if hint:IsA("ScreenGui") then
		hint.Enabled = false
	else
		hint.Visible = false
	end
	if bg and (bg:IsA("Frame") or bg:IsA("ImageLabel")) then
		bg.Visible = false
	end
end

function Notifications.showHintAnnouncement(rootScript, payload)
	table.insert(_hintQueue, payload)
	local function process()
		if _hintBusy then return end
		local nextPayload = table.remove(_hintQueue, 1)
		if not nextPayload then return end
		_hintBusy = true
		local duration = (typeof(nextPayload) == "table" and tonumber(nextPayload.duration)) or 3
		_renderHintAnnouncement(rootScript, nextPayload)
		task.delay(duration, function()
			_hideHintAnnouncement(rootScript)
			_hintBusy = false
			process()
		end)
	end
	process()
end

function Notifications.wireRemotes(rootScript)
	local folder = ReplicatedStorage:WaitForChild("AdminEvents")
	local msgEvt = folder and folder:WaitForChild("AdminMessage")
	if msgEvt then
		msgEvt.OnClientEvent:Connect(function(payload)
			if type(payload) == "table" then
				Notifications.showNotice(
					rootScript,
					payload.header or payload.kind or "Info",
					payload.text or "",
					payload.kind,
					payload.duration
				)
			else
				Notifications.showNotice(rootScript, "Info", tostring(payload))
			end
		end)
	else
		warn("[Notifications] AdminMessage RemoteEvent missing; did Remotes.provision run?")
	end

	local annEvt = folder and folder:FindFirstChild("AdminAnnouncement")
	if annEvt then
		annEvt.OnClientEvent:Connect(function(payload)
			local gui = (typeof(payload) == "table" and tostring(payload.gui or "")) or ""
			if string.lower(gui) == "hint" then
				Notifications.showHintAnnouncement(rootScript, payload)
			else
				Notifications.showAnnouncement(rootScript, payload)
			end
		end)
	else
		warn("[Notifications] AdminAnnouncement RemoteEvent missing; did Remotes.provision run?")
	end
end

return Notifications