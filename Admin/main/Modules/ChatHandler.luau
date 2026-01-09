local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatHandler = {}

local RATE_LIMIT_SECONDS = 0.75
local NOTICE_COOLDOWN_SECONDS = 2
local BURST_WINDOW_SECONDS = 3
local BURST_LIMIT_COUNT = 2

local lastRun = {}
local lastNotice = {}
local recentRuns = {}

local function pruneWindow(list, now)
	local i = 1
	while i <= #list do
		if now - list[i] > BURST_WINDOW_SECONDS then
			table.remove(list, i)
		else
			i += 1
		end
	end
end

local function canRun(player)
	local now = os.clock()
	local prev = lastRun[player] or 0
	if now - prev < RATE_LIMIT_SECONDS then
		return false
	end
	local list = recentRuns[player]
	if not list then
		list = {}
		recentRuns[player] = list
	end
	pruneWindow(list, now)
	if #list >= BURST_LIMIT_COUNT then
		return false
	end
	lastRun[player] = now
	table.insert(list, now)
	return true
end

local function hookPlayer(player, main)
	player.Chatted:Connect(function(message)
		if main and main.Utils and typeof(main.Utils.cleanupExpiredTempRanks) == "function" then
			main.Utils.cleanupExpiredTempRanks(main.Settings)
		end

		local prefix = tostring((main and main.Settings and main.Settings.Prefix) or ";")
		local trimmed = tostring(message or "")
		trimmed = string.gsub(trimmed, "^%s*(.-)%s*$", "%1")

		local cmdName, args = main.Parser.parseWithPrefix(trimmed, prefix)

		if not cmdName or string.sub(trimmed, 1, #prefix) ~= prefix then
			if main and typeof(main.addChatLog) == "function" then
				pcall(function()
					main.addChatLog(player, trimmed)
				end)
			end
			return
		end
		if not canRun(player) then

			local now = os.clock()
			local prev = lastNotice[player] or 0
			if now - prev >= NOTICE_COOLDOWN_SECONDS then
				lastNotice[player] = now
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt then
					evt:FireClient(player, { header = "Rate Limit", kind = "warn", text = "You’re sending commands too quickly." })
				else
					warn("[ChatHandler] AdminMessage RemoteEvent missing; ensure Remotes.provision ran.")
				end
			end
			return
		end

		local ok, err = main.executeCommand(player, cmdName, args)
		if not ok and err then
			local evt = main.Remotes and main.Remotes.AdminMessage
			if evt then
				evt:FireClient(player, { header = "Error", kind = "error", text = tostring(err) })
			else
				warn("[ChatHandler] AdminMessage RemoteEvent missing; ensure Remotes.provision ran.")
			end
		end
	end)
end

function ChatHandler.start(main)

	if main and main.Settings then
		local s = main.Settings
		RATE_LIMIT_SECONDS = tonumber(s.ChatRateLimitSeconds) or RATE_LIMIT_SECONDS
		NOTICE_COOLDOWN_SECONDS = tonumber(s.NoticeRateLimitSeconds) or NOTICE_COOLDOWN_SECONDS
		BURST_WINDOW_SECONDS = tonumber(s.ChatBurstWindowSeconds) or BURST_WINDOW_SECONDS
		BURST_LIMIT_COUNT = tonumber(s.ChatBurstLimitCount) or BURST_LIMIT_COUNT
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		hookPlayer(plr, main)
	end
	Players.PlayerAdded:Connect(function(plr)
		hookPlayer(plr, main)
	end)
	Players.PlayerRemoving:Connect(function(plr)

		lastRun[plr] = nil
		lastNotice[plr] = nil
		recentRuns[plr] = nil
	end)

	if TextChatService and TextChatService.MessageReceived then
		TextChatService.MessageReceived:Connect(function(message)
			local textSource = message.TextSource
			if not textSource then return end
			local player = Players:GetPlayerByUserId(textSource.UserId)
			if not player then return end

			if main and main.Utils and typeof(main.Utils.cleanupExpiredTempRanks) == "function" then
				main.Utils.cleanupExpiredTempRanks(main.Settings)
			end

			local prefix = tostring((main and main.Settings and main.Settings.Prefix) or ";")
			local text = tostring(message and message.Text or "")
			local trimmed = string.gsub(text, "^%s*(.-)%s*$", "%1")
			local cmdName, args = main.Parser.parseWithPrefix(trimmed, prefix)

			if not cmdName or string.sub(trimmed, 1, #prefix) ~= prefix then
				if main and typeof(main.addChatLog) == "function" then
					pcall(function()
						main.addChatLog(player, trimmed)
					end)
				end
				return
			end
			if not canRun(player) then
				local now = os.clock()
				local prev = lastNotice[player] or 0
				if now - prev >= NOTICE_COOLDOWN_SECONDS then
					lastNotice[player] = now
					local evt = main.Remotes and main.Remotes.AdminMessage
					if evt then
						evt:FireClient(player, { header = "Rate Limit", kind = "warn", text = "You’re sending commands too quickly." })
					else
						warn("[ChatHandler] AdminMessage RemoteEvent missing; ensure Remotes.provision ran.")
					end
				end
				return
			end

			local ok, err = main.executeCommand(player, cmdName, args)
			if not ok and err then
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt then
					evt:FireClient(player, { header = "Error", kind = "error", text = tostring(err) })
				else
					warn("[ChatHandler] AdminMessage RemoteEvent missing; ensure Remotes.provision ran.")
				end
			end
		end)
	end
end

return ChatHandler