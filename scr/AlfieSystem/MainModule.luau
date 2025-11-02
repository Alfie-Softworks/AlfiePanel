local Main = {}

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Modules = script.Parent:WaitForChild("Modules")
local Utils = require(Modules:WaitForChild("Utils"))
local Parser = require(Modules:WaitForChild("Parser"))
local Remotes = require(Modules:WaitForChild("Remotes"))
local ChatHandler = require(Modules:WaitForChild("ChatHandler"))

local function cloneChildren(fromParent: Instance, toParent: Instance)
	if not fromParent or not toParent then return end
	for _, child in ipairs(fromParent:GetChildren()) do
		local existing = toParent:FindFirstChild(child.Name)
		if existing then existing:Destroy() end

		local ok, cloned = pcall(function()
			return child:Clone()
		end)
		if ok and cloned then
			cloned.Parent = toParent
		end
	end
end

local function indexCommands(list)
	local byName = {}
	for _, cmd in ipairs(list) do
		if cmd.Name then
			byName[string.lower(cmd.Name)] = cmd
		end
		if cmd.Aliases then
			for _, alias in ipairs(cmd.Aliases) do
				byName[string.lower(alias)] = cmd
			end
		end
	end
	return byName
end

function Main.init(SettingsModule, CommandsBuilder)
	local assetsRoot = script.Parent
	local serverAssets = assetsRoot:FindFirstChild("AssetsServer")
	local clientAssets = assetsRoot:FindFirstChild("AssetsClient")
	local replicatedAssets = assetsRoot:FindFirstChild("AssetsReplicated")

	local serverFolder = serverAssets and serverAssets:FindFirstChild("AlfieServer")
	local clientFolder = clientAssets and clientAssets:FindFirstChild("AlfieClient")
	local replicatedFolder = replicatedAssets and replicatedAssets:FindFirstChild("AlfieReplicated")

	cloneChildren(serverFolder, ServerStorage)
	cloneChildren(clientFolder, StarterPlayerScripts)
	cloneChildren(replicatedFolder, ReplicatedStorage)

	local uiContainer = ReplicatedStorage:FindFirstChild("AlfieAssets")
	if not uiContainer then
		uiContainer = Instance.new("Folder")
		uiContainer.Name = "AlfieAssets"
		uiContainer.Parent = ReplicatedStorage
	end
	local clientPanel = clientAssets and clientAssets:FindFirstChild("AlfiePanel")
	if clientPanel and clientPanel:IsA("ScreenGui") then
		local existingPanel = uiContainer:FindFirstChild("AlfiePanel")
		if existingPanel then existingPanel:Destroy() end
		local panelClone = clientPanel:Clone()
		panelClone.Parent = uiContainer
	end

	Main.Settings = SettingsModule or {}
	Main.Utils = Utils
	Main.Parser = Parser
	Main.Logs = {}
	Main.MaxLogs = 50

	Main.Settings.TempRanks = Main.Settings.TempRanks or {}
	Main.Settings.PermRanks = Main.Settings.PermRanks or {}
	Main.RankThrottle = {}
	Main.RankThrottleWindow = tonumber(Main.Settings.RankThrottleSeconds) or 8

	local rankStoreName = (Main.Settings and Main.Settings.RankDataStoreName) or "AlfiePermRanks"
	local rankStore
	local okStore, storeOrErr = pcall(function()
		return DataStoreService:GetDataStore(rankStoreName)
	end)
	if okStore then
		rankStore = storeOrErr
	else
		warn("[AlfieMain] Failed to get DataStore '" .. tostring(rankStoreName) .. "':", storeOrErr)
	end
	Main.RankStore = rankStore

	local banStoreName = (Main.Settings and Main.Settings.BanDataStoreName) or "AlfieBans"
	local banStore
	do
		local okBan, storeOrErrBan = pcall(function()
			return DataStoreService:GetDataStore(banStoreName)
		end)
		if okBan then
			banStore = storeOrErrBan
		else
			warn("[AlfieMain] Failed to get DataStore '" .. tostring(banStoreName) .. "':", storeOrErrBan)
		end
	end
	Main.BanStore = banStore
	Main.Settings.BannedUsers = Main.Settings.BannedUsers or {}
	Main.BanThrottle = {}
	Main.BanThrottleWindow = tonumber(Main.Settings.RankThrottleSeconds) or 8

	do
		local key = (Main.Settings and Main.Settings.BanIndexKey) or "BannedUsers"
		if Main.BanStore then
			local okLoad, val = Utils.dataStoreCallWithRetry(function()
				return Main.BanStore:GetAsync(key)
			end, { attempts = 5, baseDelay = 0.5, maxDelay = 5 })
			if okLoad and typeof(val) == "table" then
				Main.Settings.BannedUsers = val
			end
		end
	end

	function Main.addLog(player: Player, commandText: string)
		local entry = {
			userId = player and player.UserId or 0,
			userName = player and player.Name or "?",
			command = tostring(commandText or ""),
			timestamp = os.time(),
		}
		table.insert(Main.Logs, entry)
		if #Main.Logs > Main.MaxLogs then
			while #Main.Logs > Main.MaxLogs do
				table.remove(Main.Logs, 1)
			end
		end
	end

	Main.Remotes = Remotes.provision()

	Main.CmdRunThrottle = {}
	Main.CmdRunThrottleWindow = tonumber(Main.Settings.ChatRateLimitSeconds) or 0.75

	local function buildRankPayloadFor(speaker)
		return Main.Utils.buildRankPayload(speaker, Main.Settings)
	end

	local function buildBanlandPayload()
		return Main.Utils.buildBanlandPayload(Main.Settings)
	end

	local unrankEvt = Main.Remotes and Main.Remotes.AdminUnrank
	if unrankEvt then
		unrankEvt.OnServerEvent:Connect(function(speaker, data)
			local okPayload, errPayload = Remotes.validatePayload("AdminUnrank", data)
			if not okPayload then
				local msg = Main.Remotes and Main.Remotes.AdminMessage
				if msg then msg:FireClient(speaker, { header = "Ranks", kind = "error", text = "Invalid request: " .. tostring(errPayload or "bad payload") }) end
				return
			end
			local viewerPower = Main.Utils.resolvePlayerRank(speaker, Main.Settings)
			local highest = Main.Utils.getMaxPower(Main.Settings)

			local userId = (typeof(data) == "table" and data.userId) or nil
			local userName = (typeof(data) == "table" and data.userName) or nil
			if not userId and userName and userName ~= "" then
				local okId, id = pcall(function() return Players:GetUserIdFromNameAsync(userName) end)
				if okId then userId = id end
			end
			if not userId and not userName then
				local msg = Main.Remotes and Main.Remotes.AdminMessage
				if msg then msg:FireClient(speaker, { header = "Ranks", kind = "error", text = "Invalid target for unrank." }) end
				return
			end

			local isSelf = false
			if speaker then
				local nameLower = string.lower(speaker.Name)
				if (typeof(userId) == "number" and userId == speaker.UserId) or (typeof(userName) == "string" and string.lower(userName) == nameLower) then
					isSelf = true
				end
			end
			if viewerPower ~= highest or isSelf then
				local msg = Main.Remotes and Main.Remotes.AdminMessage
				if msg then msg:FireClient(speaker, { header = "Ranks", kind = "error", text = "You are not authorized to unrank players." }) end
				return
			end

			do
				local serverPower = Main.Utils.findCurrentRankFor(userId, userName, Main.Settings)
				if serverPower and serverPower > 0 then
					local msg = Main.Remotes and Main.Remotes.AdminMessage
					if msg then msg:FireClient(speaker, { header = "Ranks", kind = "error", text = "Cannot unrank server-ranked users." }) end
					return
				end
			end

			local removedServer = false
			local removedTemp = false
			local removedPerm = false

			if typeof(userId) == "number" then
				local tempRanks = Main.Settings and Main.Settings.TempRanks
				if typeof(tempRanks) == "table" and tempRanks[userId] ~= nil then
					tempRanks[userId] = nil
					removedTemp = true
				end

				local permRanks = Main.Settings and Main.Settings.PermRanks
				if typeof(permRanks) == "table" and permRanks[userId] ~= nil then
					permRanks[userId] = nil
					removedPerm = true
				end
				local store = Main.RankStore
				if store then
					local allowed, waitLeft = Utils.throttleCheck(Main.RankThrottle, userId, Main.RankThrottleWindow)
					if not allowed then
						local msg = Main.Remotes and Main.Remotes.AdminMessage
						if msg then msg:FireClient(speaker, { header = "Ranks", kind = "error", text = "Rank changes are throttled. Try again in " .. tostring(waitLeft) .. "s." }) end
					else
						local okRm, errRm = Utils.dataStoreCallWithRetry(function()
							return store:RemoveAsync(tostring(userId))
						end, { attempts = 5, baseDelay = 0.5, maxDelay = 5 })
						if not okRm then
							local msg = Main.Remotes and Main.Remotes.AdminMessage
							if msg then msg:FireClient(speaker, { header = "Ranks", kind = "error", text = "Failed to clear permanent rank persistence: " .. tostring(errRm) }) end
						end
					end
				end
			end

			local parts = {}
			if removedServer then table.insert(parts, "Server") end
			if removedTemp then table.insert(parts, "Temp") end
			if removedPerm then table.insert(parts, "Perm") end
			local clearedText = (#parts > 0) and (" cleared (" .. table.concat(parts, "/") .. ")") or " cleared"
			local msg = Main.Remotes and Main.Remotes.AdminMessage
			if msg then msg:FireClient(speaker, { header = "Ranks", kind = "info", text = "Unranked " .. tostring(userName or (userId or "user")) .. "." .. clearedText }) end

			local ranksEvt = Main.Remotes and Main.Remotes.AdminRanks
			if ranksEvt then
				ranksEvt:FireClient(speaker, buildRankPayloadFor(speaker))
			end
		end)
	end

	do
		local unbanEvt = Main.Remotes and Main.Remotes.AdminUnban
		if unbanEvt then
			unbanEvt.OnServerEvent:Connect(function(speaker, data)
				local okPayload, errPayload = Remotes.validatePayload("AdminUnban", data)
				if not okPayload then
					local msgEvt = Main.Remotes and Main.Remotes.AdminMessage
					if msgEvt then msgEvt:FireClient(speaker, { header = "Banland", kind = "error", text = "Invalid request: " .. tostring(errPayload or "bad payload") }) end
					return
				end

				local viewerPower = Utils.resolvePlayerRank(speaker, Main.Settings)
				local maxP = Utils.getMaxPower(Main.Settings)
				if viewerPower < maxP then
					local msgEvt = Main.Remotes and Main.Remotes.AdminMessage
					if msgEvt then msgEvt:FireClient(speaker, { header = "Banland", kind = "error", text = "You are not authorized to unban." }) end
					return
				end

				local userId = (typeof(data.userId) == "number") and data.userId or nil
				local userName = (typeof(data.userName) == "string") and data.userName or nil
				if not userId and userName and userName ~= "" then
					local okId, uid = pcall(function()
						return Players:GetUserIdFromNameAsync(userName)
					end)
					if okId then userId = uid end
				end
				if not userId then
					local msgEvt = Main.Remotes and Main.Remotes.AdminMessage
					if msgEvt then msgEvt:FireClient(speaker, { header = "Banland", kind = "error", text = "Target not found." }) end
					return
				end

				Main.Settings.BannedUsers[userId] = nil
				local key = (Main.Settings and Main.Settings.BanIndexKey) or "BannedUsers"
				if Main.BanStore then
					local allowed, waitLeft = Utils.throttleCheck(Main.BanThrottle, userId, Main.BanThrottleWindow)
					if not allowed then
						local msgEvt = Main.Remotes and Main.Remotes.AdminMessage
						if msgEvt then msgEvt:FireClient(speaker, { header = "Banland", kind = "warn", text = "Ban operations are throttled. Try again in " .. tostring(waitLeft) .. "s." }) end
					else
						local okUpd, errUpd = Utils.dataStoreCallWithRetry(function()
							return Main.BanStore:UpdateAsync(key, function(prev)
								prev = typeof(prev) == "table" and prev or {}
								prev[userId] = nil
								return prev
							end)
						end, { attempts = 5, baseDelay = 0.5, maxDelay = 5 })
						if not okUpd then
							local msgEvt = Main.Remotes and Main.Remotes.AdminMessage
							if msgEvt then msgEvt:FireClient(speaker, { header = "Banland", kind = "error", text = "Failed to update ban index: " .. tostring(errUpd) }) end
						end
					end
				end

				local msgEvt = Main.Remotes and Main.Remotes.AdminMessage
				if msgEvt then msgEvt:FireClient(speaker, { header = "Banland", kind = "info", text = "Unbanned " .. tostring(userName or userId) .. "." }) end

				local banEvt = Main.Remotes and Main.Remotes.AdminBanland
				if banEvt then
					local payload = buildBanlandPayload()
					payload.open = false
					banEvt:FireClient(speaker, payload)
				end
			end)
		else
			warn("[AlfieMain] AdminUnban RemoteEvent missing; ensure Remotes.provision ran.")
		end
	end

	local runEvt = Main.Remotes and Main.Remotes.AdminRunCommand
	if runEvt then
		runEvt.OnServerEvent:Connect(function(speaker, payload)
			local okPayload, errPayload = Remotes.validatePayload("AdminRunCommand", payload)
			if not okPayload then
				local msgEvt = Main.Remotes and Main.Remotes.AdminMessage
				if msgEvt then msgEvt:FireClient(speaker, { header = "Cmdbar", kind = "error", text = "Invalid request: " .. tostring(errPayload or "bad payload") }) end
				return
			end

			local allowed, waitLeft = Utils.throttleCheck(Main.CmdRunThrottle, speaker.UserId, Main.CmdRunThrottleWindow)
			if not allowed then
				local msgEvt = Main.Remotes and Main.Remotes.AdminMessage
				if msgEvt then msgEvt:FireClient(speaker, { header = "Rate Limit", kind = "warn", text = "You’re sending commands too quickly. Try again in " .. tostring(waitLeft) .. "s." }) end
				return
			end

			local text = tostring(payload.text or "")
			text = string.gsub(text, "^%s*(.-)%s*$", "%1")
			if text == "" then
				local msgEvt = Main.Remotes and Main.Remotes.AdminMessage
				if msgEvt then msgEvt:FireClient(speaker, { header = "Cmdbar", kind = "error", text = "Enter a command." }) end
				return
			end

			local prefix = Main.Settings and Main.Settings.Prefix or ";"
			local normalized = text
			if string.sub(string.lower(text), 1, #prefix) ~= string.lower(prefix) then
				normalized = prefix .. text
			end

			local name, args = Main.Parser.parseWithPrefix(normalized, prefix)
			if not name then
				local msgEvt = Main.Remotes and Main.Remotes.AdminMessage
				if msgEvt then msgEvt:FireClient(speaker, { header = "Cmdbar", kind = "error", text = "Could not parse command." }) end
				return
			end

			local okRun, errRun = Main.executeCommand(speaker, name, args)
			if not okRun then
				local msgEvt = Main.Remotes and Main.Remotes.AdminMessage
				if msgEvt then msgEvt:FireClient(speaker, { header = "Error", kind = "error", text = tostring(errRun or "Command failed") }) end
			end
		end)
	end

	local commandsList = {}
	if typeof(CommandsBuilder) == "function" then
		local ok, built = pcall(function()
			return CommandsBuilder(Main, Main.Settings)
		end)
		if ok and type(built) == "table" then
			commandsList = built
		end
	end

	local coreModule = ServerStorage:FindFirstChild("Commands")
	if coreModule and coreModule:IsA("ModuleScript") then
		local okRequire, CoreBuilder = pcall(require, coreModule)
		if okRequire and typeof(CoreBuilder) == "function" then
			local okBuild, coreList = pcall(function()
				return CoreBuilder(Main, Main.Settings)
			end)
			if okBuild and type(coreList) == "table" then
				for _, cmd in ipairs(coreList) do
					table.insert(commandsList, cmd)
				end
			else
				warn("[AlfieMain] Failed to build core commands list")
			end
		else
			warn("[AlfieMain] Core commands module present but not a builder function")
		end
	else
		warn("[AlfieMain] Core commands module not found in ServerStorage; expected 'Commands'")
	end
	Main.Commands = commandsList
	Main.CommandIndex = indexCommands(commandsList)

	ChatHandler.start(Main)

	local function loadPermRankFor(player)
		if not player or not Main.RankStore then return end
		local key = tostring(player.UserId)
		local ok, value = Utils.dataStoreCallWithRetry(function()
			return Main.RankStore:GetAsync(key)
		end, { attempts = 5, baseDelay = 0.5, maxDelay = 5 })
		if ok and typeof(value) == "number" then
			Main.Settings.PermRanks[player.UserId] = value
		end
	end

	for _, pl in ipairs(Players:GetPlayers()) do
		loadPermRankFor(pl)
	end

	local function enforceBanFor(pl)
		local idx = Main.Settings and Main.Settings.BannedUsers
		if typeof(idx) == "table" and idx[pl.UserId] then
			local reason = "You are banned from this experience."
			pcall(function()
				pl:Kick(reason)
			end)
		end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		enforceBanFor(pl)
	end
	Players.PlayerAdded:Connect(function(pl)
		enforceBanFor(pl)
	end)

	Players.PlayerAdded:Connect(function(pl)
		loadPermRankFor(pl)
	end)

	Players.PlayerRemoving:Connect(function(pl)
		if Main.Settings and Main.Settings.TempRanks then
			Main.Settings.TempRanks[pl.UserId] = nil
		end
		if Main.Settings and Main.Settings.PermRanks then
			Main.Settings.PermRanks[pl.UserId] = nil
		end
	end)

	local adminClient = StarterPlayerScripts:WaitForChild("AdminClient")
	if adminClient then
		print("[AlfieMain] Found AdminClient in StarterPlayerScripts:", adminClient.ClassName)
	else
		warn("[AlfieMain] AdminClient not found in StarterPlayerScripts.")
	end

	local alfiePanelReplicated = (ReplicatedStorage:WaitForChild("AlfieAssets") and ReplicatedStorage.AlfieAssets:FindFirstChild("AlfiePanel"))
	if alfiePanelReplicated then
		print("[AlfieMain] AlfiePanel available for clients at:", alfiePanelReplicated:GetFullName())
	else
		warn("[AlfieMain] AlfiePanel not found")
	end

	return Main
end

function Main.executeCommand(speaker: Player, name: string, args: {string})
	local cmd = Main.CommandIndex[string.lower(name or "")] or nil
	if not cmd then return false, "Unknown command" end

	local playerRank = Utils.resolvePlayerRank(speaker, Main.Settings)
	local requiredRank = tonumber(cmd.Rank) or 0
	if playerRank < requiredRank then
		return false, "Insufficient rank"
	end

	local ok, err = Utils.safeCall(cmd.Function, speaker, args)
	if not ok then
		return false, err or "Command error"
	end

	local raw = (Main.Settings and Main.Settings.Prefix or ";") .. tostring(name)
	if args and #args > 0 then
		raw ..= " " .. table.concat(args, " ")
	end
	Main.addLog(speaker, raw)

	return true
end

return Main
