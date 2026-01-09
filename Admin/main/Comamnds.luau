local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

return function(main, settings)
	local commands = {}

	table.insert(commands, {
		Name = "logs",
		Aliases = {"log"},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = {"fun", "utility", "view"},

		Args = {},
		Function = function(speaker, _)

			local logs = main.Logs or {}
			local max = (main.MaxLogs or 50)
			if #logs > max then
				logs = { table.unpack(logs, #logs - max + 1, #logs) }
			end

			local evt = main.Remotes and main.Remotes.AdminLogs
			if evt and evt:IsA("RemoteEvent") then
				evt:FireClient(speaker, logs)
			else
				warn("[CoreCommands] AdminLogs RemoteEvent missing; ensure Remotes.provision ran.")
			end
		end,
	})

	table.insert(commands, {
		Name = "chatlogs",
		Aliases = {"chatlog", "cl"},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = {"utility", "view"},

		Args = {},
		Function = function(speaker, _)
			local logs = main.ChatLogs or {}
			local max = (main.MaxChatLogs or 200)
			if #logs > max then
				logs = { table.unpack(logs, #logs - max + 1, #logs) }
			end

			local evt = main.Remotes and main.Remotes.AdminChatLogs
			if evt and evt:IsA("RemoteEvent") then
				evt:FireClient(speaker, logs)
			else
				warn("[CoreCommands] AdminChatLogs RemoteEvent missing; ensure Remotes.provision ran.")
			end
		end,
	})

	table.insert(commands, {
		Name = "credit",
		Aliases = {"credits", "creds"},
		Prefixes = { settings.Prefix },
		Rank = 0,
		RankLock = false,
		Tags = {"fun", "utility", "view"},

		Args = {},
		Function = function(speaker, args)
			local open = true
			if typeof(args) == "table" and #args >= 1 then
				local a1 = string.lower(tostring(args[1] or ""))
				if a1 == "close" or a1 == "off" or a1 == "hide" then
					open = false
				end
			end

			local evt = main.Remotes and main.Remotes.AdminCredits
			if evt and evt:IsA("RemoteEvent") then
				local payload = { open = open }
				evt:FireClient(speaker, payload)
			else
				warn("[CoreCommands] AdminCredits RemoteEvent missing; ensure Remotes.provision ran.")
			end
		end,
	})

	table.insert(commands, {
		Name = "kick",
		Aliases = {"k"},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = {"fun", "moderation"},

		Args = {},
		Function = function(speaker, args)
			local function sendMessage(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Kick", kind = kind, text = text })
				else
					warn("[CoreCommands] AdminMessage RemoteEvent missing; ensure Remotes.provision ran.")
				end
			end

			if typeof(args) ~= "table" or #args < 1 then
				sendMessage("error", "Usage: ;kick <player|userId> [reason]")
				return
			end

			local targetArg = tostring(args[1] or "")
			if targetArg == "" then
				sendMessage("error", "Provide a player name or userId.")
				return
			end

			local target, findErr = main.Utils.findPlayerByNameOrId(targetArg)
			if not target then
				local kind = (findErr == "Ambiguous name") and "warn" or "error"
				sendMessage(kind, findErr or "Player not found or not online.")
				return
			end

			if speaker and target == speaker then
				sendMessage("error", "You cannot kick yourself.")
				return
			end

			local viewerPower = 0
			local targetPower = 0
			if main and main.Utils and typeof(main.Utils.resolvePlayerRank) == "function" then
				local okV, v = pcall(function()
					return main.Utils.resolvePlayerRank(speaker, settings)
				end)
				local okT, t = pcall(function()
					return main.Utils.resolvePlayerRank(target, settings)
				end)
				if okV then viewerPower = tonumber(v) or 0 end
				if okT then targetPower = tonumber(t) or 0 end
			end

			if viewerPower <= targetPower then
				sendMessage("error", "You are not authorized to kick this player.")
				return
			end

			local reason = "Kicked by admin"
			if #args >= 2 then
				local r = table.concat(args, " ", 2)
				r = tostring(r or "")
				if r ~= "" then
					if #r > 200 then
						r = string.sub(r, 1, 200)
					end
					reason = r
				end
			end

			local okKick, errKick = pcall(function()
				target:Kick(reason)
			end)
			if okKick then
				sendMessage("info", "Kicked " .. target.Name .. ".")
			else
				sendMessage("error", "Kick failed: " .. tostring(errKick))
				warn("[CoreCommands] Kick failed:", tostring(errKick))
			end
		end,
	})

	table.insert(commands, {
		Name = "ban",
		Aliases = {"b"},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = {"moderation", "admin"},

		Args = {},
		Function = function(speaker, args)
			local function msg(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Ban", kind = kind, text = text })
				else
					warn("[CoreCommands] AdminMessage RemoteEvent missing; ensure Remotes.provision ran.")
				end
			end

			if typeof(args) ~= "table" or #args < 1 then
				msg("error", "Usage: ;ban <username|userId> [reason]")
				return
			end
			local targetQuery = tostring(args[1] or "")
			if targetQuery == "" then msg("error", "Provide a username or userId."); return end

			local viewerPower = tonumber(main.Utils.resolvePlayerRank(speaker, settings)) or 0
			if viewerPower < 3 then msg("error", "Insufficient rank."); return end

			local targetPlayer, findErr = main.Utils.findPlayerByNameOrId(targetQuery)
			local targetUserId
			local targetName
			if targetPlayer then
				targetUserId = targetPlayer.UserId
				targetName = targetPlayer.Name
			else
				local num = tonumber(targetQuery)
				if num then
					targetUserId = math.floor(num)
					local okName, nm = pcall(function()
						return Players:GetNameFromUserIdAsync(targetUserId)
					end)
					targetName = (okName and nm) or tostring(targetUserId)
				else
					local okId, uid = pcall(function()
						return Players:GetUserIdFromNameAsync(targetQuery)
					end)
					if okId then
						targetUserId = uid
						targetName = targetQuery
					else
						msg("error", findErr or "Player not found.")
						return
					end
				end
			end

			if speaker and targetUserId == speaker.UserId then msg("error", "You cannot ban yourself."); return end

			settings.BannedUsers = settings.BannedUsers or {}
			settings.BannedUsers[targetUserId] = { userId = targetUserId, name = targetName, at = os.time() }
			local store = main.BanStore
			local key = (settings and settings.BanIndexKey) or "BannedUsers"
			if store then
				local allowed, waitLeft = main.Utils.throttleCheck(main.BanThrottle, targetUserId, main.BanThrottleWindow)
				if not allowed then
					msg("warn", "Ban operations are throttled. Try again in " .. tostring(waitLeft) .. "s.")
				else
					local okUpd, errUpd = main.Utils.dataStoreCallWithRetry(function()
						return store:UpdateAsync(key, function(prev)
							prev = typeof(prev) == "table" and prev or {}

							prev[tostring(targetUserId)] = { userId = targetUserId, name = targetName, at = os.time() }

							prev[targetUserId] = nil
							return prev
						end)
					end, { attempts = 5, baseDelay = 0.5, maxDelay = 5 })
					if not okUpd then
						msg("error", "Failed to persist ban: " .. tostring(errUpd))
						return
					end
				end
			end

			if targetPlayer then
				pcall(function()
					targetPlayer:Kick("You are banned from this experience.")
				end)
			end

			msg("info", "Banned " .. tostring(targetName) .. ".")

			local evt = main.Remotes and main.Remotes.AdminBanland
			if evt and evt:IsA("RemoteEvent") then
				local payload = main.Utils.buildBanlandPayload(settings)
				payload.open = false
				evt:FireClient(speaker, payload)
			else
				warn("[CoreCommands] AdminBanland RemoteEvent missing; ensure Remotes.provision ran.")
			end
		end,
	})

	table.insert(commands, {
		Name = "unban",
		Aliases = {"ub"},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = {"moderation", "admin"},

		Args = {},
		Function = function(speaker, args)
			local function msg(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Unban", kind = kind, text = text })
				else
					warn("[CoreCommands] AdminMessage RemoteEvent missing; ensure Remotes.provision ran.")
				end
			end

			if typeof(args) ~= "table" or #args < 1 then
				msg("error", "Usage: ;unban <username|userId>")
				return
			end
			local targetQuery = tostring(args[1] or "")
			if targetQuery == "" then msg("error", "Provide a username or userId."); return end

			local viewerPower = tonumber(main.Utils.resolvePlayerRank(speaker, settings)) or 0
			if viewerPower < 3 then msg("error", "Insufficient rank."); return end

			local targetPlayer, findErr = main.Utils.findPlayerByNameOrId(targetQuery)
			local targetUserId
			local targetName
			if targetPlayer then
				targetUserId = targetPlayer.UserId
				targetName = targetPlayer.Name
			else
				local num = tonumber(targetQuery)
				if num then
					targetUserId = math.floor(num)
					local okName, nm = pcall(function()
						return Players:GetNameFromUserIdAsync(targetUserId)
					end)
					targetName = (okName and nm) or tostring(targetUserId)
				else
					local okId, uid = pcall(function()
						return Players:GetUserIdFromNameAsync(targetQuery)
					end)
					if okId then
						targetUserId = uid
						targetName = targetQuery
					else
						msg("error", findErr or "User not found.")
						return
					end
				end
			end

			settings.BannedUsers = settings.BannedUsers or {}
			settings.BannedUsers[targetUserId] = nil
			settings.BannedUsers[tostring(targetUserId)] = nil
			local store = main.BanStore
			local key = (settings and settings.BanIndexKey) or "BannedUsers"
			if store then
				local allowed, waitLeft = main.Utils.throttleCheck(main.BanThrottle, targetUserId, main.BanThrottleWindow)
				if not allowed then
					msg("warn", "Ban operations are throttled. Try again in " .. tostring(waitLeft) .. "s.")
				else
					local okUpd, errUpd = main.Utils.dataStoreCallWithRetry(function()
						return store:UpdateAsync(key, function(prev)
							prev = typeof(prev) == "table" and prev or {}
							prev[targetUserId] = nil
							prev[tostring(targetUserId)] = nil
							return prev
						end)
					end, { attempts = 5, baseDelay = 0.5, maxDelay = 5 })
					if not okUpd then
						msg("error", "Failed to update ban index: " .. tostring(errUpd))

					end
				end
			end

			msg("info", "Unbanned " .. tostring(targetName or targetUserId) .. ".")

			local evt = main.Remotes and main.Remotes.AdminBanland
			if evt and evt:IsA("RemoteEvent") then
				local payload = main.Utils.buildBanlandPayload(settings)
				payload.open = false
				evt:FireClient(speaker, payload)
			else
				warn("[CoreCommands] AdminBanland RemoteEvent missing; ensure Remotes.provision ran.")
			end
		end,
	})

	table.insert(commands, {
		Name = "banland",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = {"moderation", "view"},

		Args = {},
		Function = function(speaker, _)

			local store = main.BanStore
			local key = (settings and settings.BanIndexKey) or "BannedUsers"
			if store then
				local okLoad, val = main.Utils.dataStoreCallWithRetry(function()
					return store:GetAsync(key)
				end, { attempts = 5, baseDelay = 0.5, maxDelay = 5 })
				if okLoad and typeof(val) == "table" then
					local norm = {}
					for k, rec in pairs(val) do
						local uid = tonumber((typeof(rec) == "table" and rec.userId) or k)
						if typeof(uid) == "number" then
							norm[uid] = rec
						end
					end
					settings.BannedUsers = norm
				end
			end
			local payload = main.Utils.buildBanlandPayload(settings)
			local evt = main.Remotes and main.Remotes.AdminBanland
			if evt and evt:IsA("RemoteEvent") then
				evt:FireClient(speaker, payload)
			else
				warn("[CoreCommands] AdminBanland RemoteEvent missing; ensure Remotes.provision ran.")
			end
		end,
	})

	table.insert(commands, {
		Name = "permrank",
		Aliases = {"pr"},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = {"fun", "ranks", "admin"},

		Args = {},
		Function = function(speaker, args)
			local function msg(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Ranks", kind = kind, text = text })
				else
					warn("[CoreCommands] AdminMessage RemoteEvent missing; ensure Remotes.provision ran.")
				end
			end

			if typeof(args) ~= "table" or #args < 1 then
				msg("error", "Usage: ;permrank <username>")
				return
			end
			local targetQuery = tostring(args[1] or "")
			if targetQuery == "" then msg("error", "Provide a username."); return end

			local viewerPower = tonumber(main.Utils.resolvePlayerRank(speaker, settings)) or 0
			local maxP = main.Utils.getMaxPower(settings)
			if viewerPower < 3 then msg("error", "Insufficient rank."); return end

			local desiredPower = main.Utils.computeDesiredPower(viewerPower, maxP, main.Utils.parseDesiredPowerArg(args[2], settings))

			local targetPlayer, findErr = main.Utils.findPlayerByNameOrId(targetQuery)
			local targetUserId
			local targetName
			if targetPlayer then
				targetUserId = targetPlayer.UserId
				targetName = targetPlayer.Name
			else

				local okId, uid = pcall(function()
					return Players:GetUserIdFromNameAsync(targetQuery)
				end)
				if okId and typeof(uid) == "number" then
					targetUserId = uid
					targetName = targetQuery
				else
					msg("error", findErr or "Player not found.")
					return
				end
			end

			if speaker and targetUserId == speaker.UserId then msg("error", "You cannot rank yourself."); return end

			local currentPower = main.Utils.findCurrentRankFor(targetUserId, targetName, settings)
			do
				local okChange, errMsg = main.Utils.canChangeRank(viewerPower, currentPower)
				if not okChange then
					msg("error", errMsg)
					return
				end
			end

			local DataStoreService = game:GetService("DataStoreService")
			local store = main.RankStore or DataStoreService:GetDataStore((settings and settings.RankDataStoreName) or "AlfiePermRanks")
			local key = tostring(targetUserId)
			local allowed, waitLeft = main.Utils.throttleCheck(main.RankThrottle, targetUserId, main.RankThrottleWindow)
			if not allowed then
				msg("error", "Rank changes are throttled. Try again in " .. tostring(waitLeft) .. "s.")
				return
			end
			local okSet, errSet = main.Utils.dataStoreCallWithRetry(function()
				return store:UpdateAsync(key, function(_)
					return desiredPower
				end)
			end, { attempts = 5, baseDelay = 0.5, maxDelay = 5 })
			if not okSet then
				msg("error", "Failed to persist rank: " .. tostring(errSet))
				return
			end
			settings.PermRanks = settings.PermRanks or {}
			settings.PermRanks[targetUserId] = desiredPower

			local indexKey = (settings and settings.RankIndexKey) or "PermRankUsers"
			local okIdx, errIdx = main.Utils.dataStoreCallWithRetry(function()
				return store:UpdateAsync(indexKey, function(prev)
					prev = typeof(prev) == "table" and prev or {}
					prev[targetUserId] = desiredPower
					return prev
				end)
			end, { attempts = 5, baseDelay = 0.5, maxDelay = 5 })
			if not okIdx then
				msg("error", "Failed to update rank index: " .. tostring(errIdx))

			end
			settings.PermRanksIndex = settings.PermRanksIndex or {}
			settings.PermRanksIndex[targetUserId] = desiredPower
			msg("info", "Assigned permanent rank " .. tostring(desiredPower) .. " to " .. tostring(targetName) .. ".")

			local payload = main.Utils.buildRankPayload(speaker, settings)
			payload.open = false
			local evt = main.Remotes and main.Remotes.AdminRanks
			if evt and evt:IsA("RemoteEvent") then
				evt:FireClient(speaker, payload)
			else
				warn("[CoreCommands] AdminRanks RemoteEvent missing; ensure Remotes.provision ran.")
			end
		end,
	})

	table.insert(commands, {
		Name = "temprank",
		Aliases = {"tr"},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = {"fun", "ranks", "admin"},

		Args = {},
		Function = function(speaker, args)
			local function msg(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Ranks", kind = kind, text = text })
				else
					warn("[CoreCommands] AdminMessage RemoteEvent missing; ensure Remotes.provision ran.")
				end
			end

			if typeof(args) ~= "table" or #args < 1 then
				msg("error", "Usage: ;temprank <username> [power]")
				return
			end
			local targetQuery = tostring(args[1] or "")
			if targetQuery == "" then msg("error", "Provide a username."); return end

			local viewerPower = tonumber(main.Utils.resolvePlayerRank(speaker, settings)) or 0
			local maxP = main.Utils.getMaxPower(settings)
			if viewerPower < 3 then msg("error", "Insufficient rank."); return end

			local requested = (#args >= 2) and main.Utils.parseDesiredPowerArg(args[2], settings) or nil
			local desiredPower = main.Utils.computeDesiredPower(viewerPower, maxP, requested)

			local targetPlayer, findErr = main.Utils.findPlayerByNameOrId(targetQuery)
			if not targetPlayer then
				msg("error", findErr or "Target must be online for temprank.")
				return
			end
			local targetUserId = targetPlayer.UserId
			local targetName = targetPlayer.Name

			if speaker and targetUserId == speaker.UserId then msg("error", "You cannot rank yourself."); return end

			local currentPower = main.Utils.findCurrentRankFor(targetUserId, targetName, settings)
			do
				local okChange, errMsg = main.Utils.canChangeRank(viewerPower, currentPower)
				if not okChange then
					msg("error", errMsg)
					return
				end
			end

			settings.TempRanks = settings.TempRanks or {}
			settings.TempRanks[targetUserId] = {
				power = desiredPower,
				expiresAt = nil,
			}
			msg("info", "Temporarily assigned rank " .. tostring(desiredPower) .. " to " .. tostring(targetName) .. " (until they leave).")

			local payload = main.Utils.buildRankPayload(speaker, settings)
			payload.open = false
			local evt = main.Remotes and main.Remotes.AdminRanks
			if evt and evt:IsA("RemoteEvent") then
				evt:FireClient(speaker, payload)
			else
				warn("[CoreCommands] AdminRanks RemoteEvent missing; ensure Remotes.provision ran.")
			end
		end,
	})

	table.insert(commands, {
		Name = "ranks",
		Aliases = {"rank"},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = {"fun", "ranks", "view"},

		Args = {},
		Function = function(speaker, _)
			local payload = main.Utils.buildRankPayload(speaker, settings)

			local evt = main.Remotes and main.Remotes.AdminRanks
			if evt and evt:IsA("RemoteEvent") then
				evt:FireClient(speaker, payload)
			else
				warn("[CoreCommands] AdminRanks RemoteEvent missing; ensure Remotes.provision ran.")
			end
		end,
	})

	table.insert(commands, {
		Name = "cmds",
		Aliases = {"commands", "help", "list"},
		Prefixes = { settings.Prefix },
		Rank = 0,
		RankLock = false,
		Tags = {"fun", "utility", "view"},

		Args = {},
		Function = function(speaker, _)
			local payload = main.Utils.buildCommandsPayload(settings, main.Commands, nil)
			local evt = main.Remotes and main.Remotes.AdminCommands
			if evt and evt:IsA("RemoteEvent") then
				evt:FireClient(speaker, payload)
			else
				warn("[CoreCommands] AdminCommands RemoteEvent missing; ensure Remotes.provision ran.")
			end
		end,
	})

	table.insert(commands, {
		Name = "cmdbar",
		Aliases = {"bar"},
		Prefixes = { settings.Prefix },
		Rank = 0,
		RankLock = false,
		Tags = {"utility", "view"},

		Args = {},
		Function = function(speaker, _)

			local evtOpen = main.Remotes and main.Remotes.AdminCmdbar
			if evtOpen and evtOpen:IsA("RemoteEvent") then
				evtOpen:FireClient(speaker, { open = true })
			else
				warn("[CoreCommands] AdminCmdbar RemoteEvent missing; ensure Remotes.provision ran.")
			end

			local evtCmds = main.Remotes and main.Remotes.AdminCommands
			if evtCmds and evtCmds:IsA("RemoteEvent") then
				local payload = main.Utils.buildCommandsPayload(settings, main.Commands)
				payload.open = false 
				evtCmds:FireClient(speaker, payload)
			end
		end,
	})

	table.insert(commands, {
		Name = "cmd",
		Aliases = {"command", "info"},
		Prefixes = { settings.Prefix },
		Rank = 0,
		RankLock = false,
		Tags = {"fun", "utility", "view"},

		Args = {},
		Function = function(speaker, args)
			local filter = (typeof(args) == "table" and #args >= 1) and tostring(args[1]) or nil
			local payload = main.Utils.buildCommandsPayload(settings, main.Commands, filter)
			local evt = main.Remotes and main.Remotes.AdminCommands
			if evt and evt:IsA("RemoteEvent") then
				evt:FireClient(speaker, payload)
			else
				warn("[CoreCommands] AdminCommands RemoteEvent missing; ensure Remotes.provision ran.")
			end
		end,
	})

	table.insert(commands, {
		Name = "message",
		Aliases = {"msg", "announce", "broadcast","m"},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = {"moderation", "utility", "broadcast"},

		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Announcement", kind = kind, text = text })
				end
			end

			if typeof(args) ~= "table" or #args < 1 then
				msgSelf("error", "Usage: ;message <message>")
				return
			end

			local text = table.concat(args, " ")
			text = tostring(text or "")
			text = string.gsub(text, "^%s*(.-)%s*$", "%1")
			if text == "" then
				msgSelf("error", "Provide a message to broadcast.")
				return
			end
			if #text > 300 then
				text = string.sub(text, 1, 300)
			end

			local filtered, filterErr = main.Utils.filterBroadcastText(speaker, text)
			if not filtered then
				msgSelf("error", "Message blocked by content filter.")
				return
			end

			local payload = {
				title = "Message From " .. speaker.Name,
				subtitle = "Server Message",
				text = filtered,
				duration = 5,

				senderUserId = speaker and speaker.UserId or nil,
				senderName = speaker and speaker.Name or nil,
			}

			local evt = main.Remotes and main.Remotes.AdminAnnouncement
			if evt and evt:IsA("RemoteEvent") then
				evt:FireAllClients(payload)
			else
				warn("[CoreCommands] AdminAnnouncement RemoteEvent missing; ensure Remotes.provision ran.")
				msgSelf("error", "Announcement remote missing.")
				return
			end

		end,
	})

	table.insert(commands, {
		Name = "hint",
		Aliases = {"h"},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = {"moderation", "utility", "broadcast"},

		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Announcement", kind = kind, text = text })
				end
			end

			if typeof(args) ~= "table" or #args < 1 then
				msgSelf("error", "Usage: ;h <message>")
				return
			end

			local message = table.concat(args, " ")
			message = tostring(message or "")
			message = string.gsub(message, "^%s*(.-)%s*$", "%1")
			if message == "" then
				msgSelf("error", "Provide a message to broadcast.")
				return
			end
			if #message > 300 then
				message = string.sub(message, 1, 300)
			end

			local filteredMsg, filterErr = main.Utils.filterBroadcastText(speaker, message)
			if not filteredMsg then
				msgSelf("error", "Message blocked by content filter.")
				return
			end

			local who = speaker and tostring(speaker.Name) or "Admin"
			local text = who .. ": " .. filteredMsg

			local payload = {
				gui = "Hint",
				text = text,
				duration = 3,
			}

			local evt = main.Remotes and main.Remotes.AdminAnnouncement
			if evt and evt:IsA("RemoteEvent") then
				evt:FireAllClients(payload)
			else
				warn("[CoreCommands] AdminAnnouncement RemoteEvent missing; ensure Remotes.provision ran.")
				msgSelf("error", "Announcement remote missing.")
				return
			end

		end,
	})

	table.insert(commands, {
		Name = "teleport",
		Aliases = {"to"},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"utility", "movement"},

		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Teleport", kind = kind, text = text })
				end
			end

			if typeof(args) ~= "table" or #args < 1 then
				msgSelf("error", "Usage: ;teleport <player|me|all> <target>  or  ;to <target>")
				return
			end

			local selectionArg
			local targetArg
			if #args == 1 then
				selectionArg = "me"
				targetArg = tostring(args[1] or "")
			else
				selectionArg = tostring(args[1] or "")
				targetArg = tostring(args[2] or "")
			end
			if targetArg == "" then
				msgSelf("error", "Provide a target player.")
				return
			end

			local target, findErrT = main.Utils.findPlayerByNameOrId(targetArg)
			if not target then
				local kind = (findErrT == "Ambiguous name") and "warn" or "error"
				msgSelf(kind, findErrT or "Target not found or not online.")
				return
			end

			local selLower = string.lower(selectionArg)
			local list = {}
			if selLower == "me" or selLower == "self" or selLower == "" then
				table.insert(list, speaker)
			elseif selLower == "all" then
				list = Players:GetPlayers()
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				table.insert(list, pl)
			end

			local filtered = {}
			for _, p in ipairs(list) do
				if p and p ~= target then table.insert(filtered, p) end
			end
			if #filtered == 0 then
				msgSelf("warn", "No players to teleport.")
				return
			end

			local ok, err = main.Utils.teleportPlayers(filtered, target)
			if not ok then
				msgSelf("error", tostring(err or "Teleport failed."))
				return
			end

			if main and typeof(main.addLog) == "function" then
				local cmdText = (#args == 1) and (";to " .. targetArg) or (";teleport " .. selectionArg .. " " .. targetArg)
				pcall(function() main.addLog(speaker, cmdText) end)
			end
			msgSelf("info", "Teleported " .. tostring(#filtered) .. " player(s) to " .. tostring(target.Name) .. ".")
		end,
	})

	table.insert(commands, {
		Name = "bring",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"utility", "movement"},

		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Bring", kind = kind, text = text })
				end
			end

			if typeof(args) ~= "table" or #args < 1 then
				msgSelf("error", "Usage: ;bring <player|all|others>")
				return
			end

			local selectionArg = tostring(args[1] or "")
			local selLower = string.lower(selectionArg)
			local list = {}

			if selLower == "me" or selLower == "self" then
				msgSelf("warn", "Nothing to bring for 'me'. Use ;to <player> instead.")
				return
			elseif selLower == "all" then
				list = Players:GetPlayers()
			elseif selLower == "others" then
				for _, p in ipairs(Players:GetPlayers()) do
					if p ~= speaker then table.insert(list, p) end
				end
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				table.insert(list, pl)
			end

			local target = speaker
			if not target then
				msgSelf("error", "Speaker not found.")
				return
			end

			local filtered = {}
			for _, p in ipairs(list) do
				if p and p ~= target then table.insert(filtered, p) end
			end
			if #filtered == 0 then
				msgSelf("warn", "No players to bring.")
				return
			end

			local ok, err = main.Utils.teleportPlayers(filtered, target)
			if not ok then
				msgSelf("error", tostring(err or "Bring failed."))
				return
			end

			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";bring " .. selectionArg) end)
			end
			msgSelf("info", "Brought " .. tostring(#filtered) .. " player(s) to you.")
		end,
	})

	table.insert(commands, {
		Name = "fly",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"utility", "movement"},

		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Fly", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local speedArg = (#args >= 2) and tonumber(args[2]) or nil
			local noclipArg = (#args >= 3) and tostring(args[3]) or nil
			local noclip = false
			if noclipArg then
				local l = string.lower(noclipArg)
				noclip = (l == "noclip" or l == "nc" or l == "true" or l == "on")
			end
			local speed = (speedArg and math.max(10, math.min(200, speedArg))) or 50

			local target
			local selLower = string.lower(selectionArg)
			if selLower == "me" or selLower == "self" or selLower == "" then
				target = speaker
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				target = pl
			end

			local evt = main.Remotes and main.Remotes.AdminFly
			if not (evt and evt:IsA("RemoteEvent")) then
				msgSelf("error", "Fly remote missing.")
				warn("[CoreCommands] AdminFly RemoteEvent missing; ensure Remotes.provision ran.")
				return
			end

			evt:FireClient(target, { active = true, noclip = noclip, speed = speed, lockType = "PlatformStand" })
			msgSelf("info", "Enabled fly for " .. tostring(target and target.Name or "player") .. ".")
		end,
	})

	table.insert(commands, {
		Name = "fly2",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"utility", "movement"},

		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Fly", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local speedArg = (#args >= 2) and tonumber(args[2]) or nil
			local noclipArg = (#args >= 3) and tostring(args[3]) or nil
			local noclip = false
			if noclipArg then
				local l = string.lower(noclipArg)
				noclip = (l == "noclip" or l == "nc" or l == "true" or l == "on")
			end
			local speed = (speedArg and math.max(10, math.min(200, speedArg))) or 50

			local target
			local selLower = string.lower(selectionArg)
			if selLower == "me" or selLower == "self" or selLower == "" then
				target = speaker
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				target = pl
			end

			local evt = main.Remotes and main.Remotes.AdminFly
			if not (evt and evt:IsA("RemoteEvent")) then
				msgSelf("error", "Fly remote missing.")
				warn("[CoreCommands] AdminFly RemoteEvent missing; ensure Remotes.provision ran.")
				return
			end

			evt:FireClient(target, { active = true, noclip = noclip, speed = speed, lockType = "Sit" })
			msgSelf("info", "Enabled fly2 for " .. tostring(target and target.Name or "player") .. ".")
		end,
	})

	table.insert(commands, {
		Name = "unfly",
		Aliases = {"nofly"},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"utility", "movement"},

		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Fly", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local target
			local selLower = string.lower(selectionArg)
			if selLower == "me" or selLower == "self" or selLower == "" then
				target = speaker
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				target = pl
			end

			local evt = main.Remotes and main.Remotes.AdminFly
			if not (evt and evt:IsA("RemoteEvent")) then
				msgSelf("error", "Fly remote missing.")
				warn("[CoreCommands] AdminFly RemoteEvent missing; ensure Remotes.provision ran.")
				return
			end

			evt:FireClient(target, { active = false })
			msgSelf("info", "Disabled fly for " .. tostring(target and target.Name or "player") .. ".")
		end,
	})

	table.insert(commands, {
		Name = "noclip",
		Aliases = {"nc"},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"utility", "movement"},

		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Noclip", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local target
			local selLower = string.lower(selectionArg)
			if selLower == "me" or selLower == "self" or selLower == "" then
				target = speaker
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				target = pl
			end

			local evt = main.Remotes and main.Remotes.AdminNoclip
			if not (evt and evt:IsA("RemoteEvent")) then
				msgSelf("error", "Noclip remote missing.")
				warn("[CoreCommands] AdminNoclip RemoteEvent missing; ensure Remotes.provision ran.")
				return
			end

			evt:FireClient(target, { active = true })
			msgSelf("info", "Enabled noclip for " .. tostring(target and target.Name or "player") .. ".")
		end,
	})

	table.insert(commands, {
		Name = "clip",
		Aliases = {"recollide"},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"utility", "movement"},

		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Clip", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local target
			local selLower = string.lower(selectionArg)
			if selLower == "me" or selLower == "self" or selLower == "" then
				target = speaker
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				target = pl
			end

			local evt = main.Remotes and main.Remotes.AdminNoclip
			if not (evt and evt:IsA("RemoteEvent")) then
				msgSelf("error", "Noclip remote missing.")
				warn("[CoreCommands] AdminNoclip RemoteEvent missing; ensure Remotes.provision ran.")
				return
			end

			evt:FireClient(target, { active = false })
			msgSelf("info", "Disabled noclip for " .. tostring(target and target.Name or "player") .. ".")
		end,
	})

	table.insert(commands, {
		Name = "r6",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"utility", "character"},

		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Rig", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local target
			local selLower = string.lower(selectionArg)
			if selLower == "me" or selLower == "self" or selLower == "" then
				target = speaker
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				target = pl
			end

			local ok, err = main.Utils.convertCharacterToRig(target, "R6")
			if not ok then
				msgSelf("error", tostring(err or "Failed to convert to R6."))
				return
			end
			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";r6 " .. selectionArg) end)
			end
			msgSelf("info", "Converted " .. tostring(target and target.Name or "player") .. " to R6.")
		end,
	})

	table.insert(commands, {
		Name = "r15",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"utility", "character"},

		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Rig", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local target
			local selLower = string.lower(selectionArg)
			if selLower == "me" or selLower == "self" or selLower == "" then
				target = speaker
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				target = pl
			end

			local ok, err = main.Utils.convertCharacterToRig(target, "R15")
			if not ok then
				msgSelf("error", tostring(err or "Failed to convert to R15."))
				return
			end
			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";r15 " .. selectionArg) end)
			end
			msgSelf("info", "Converted " .. tostring(target and target.Name or "player") .. " to R15.")
		end,
	})

	table.insert(commands, {
		Name = "btools",
		Aliases = {"f3x", "buildingtools"},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"tools"},

		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "BTools", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local target
			local selLower = string.lower(selectionArg)
			if selLower == "me" or selLower == "self" or selLower == "" then
				target = speaker
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				target = pl
			end

			local char = target.Character
			if not char then
				msgSelf("error", "Target has no character loaded.")
				return
			end

			local backpack = target:FindFirstChildOfClass("Backpack")
			if not backpack then
				msgSelf("error", "No backpack found for player.")
				return
			end

			local function giveBTools()
				local tool = script.Gears:WaitForChild("Building Tools")

				tool:Clone().Parent = backpack
			end

			local ok, err = pcall(giveBTools)
			if not ok then
				msgSelf("error", "Failed to give BTool: " .. tostring(err))
				return
			end

			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";btools " .. selectionArg) end)
			end

			msgSelf("info", "Gave BTool to " .. tostring(target and target.Name or "player") .. ".")
		end,
	})

	table.insert(commands, {
		Name = "sit",
		Aliases = {"seat", "sitdown"},
		Prefixes = { settings.Prefix },
		Rank = 1,
		RankLock = false,
		Tags = {"movement"},
		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Sit", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local target
			local selLower = string.lower(selectionArg)
			if selLower == "me" or selLower == "self" or selLower == "" then
				target = speaker
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				target = pl
			end

			local char = target.Character
			if not char then
				msgSelf("error", "Target has no character loaded.")
				return
			end

			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if not humanoid then
				msgSelf("error", "No Humanoid found for target.")
				return
			end

			local ok, err = pcall(function()
				humanoid.Sit = true
			end)

			if not ok then
				msgSelf("error", "Failed to make target sit: " .. tostring(err))
				return
			end

			if main and typeof(main.addLog) == "function" then
				pcall(function()
					main.addLog(speaker, ";sit " .. selectionArg)
				end)
			end

			msgSelf("info", tostring(target and target.Name or "Player") .. " is now sitting.")
		end,

	})

	table.insert(commands, {
		Name = "doge",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 1,
		RankLock = false,
		Tags = {"Character"},
		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Doge", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local targets = {}
			local selLower = string.lower(selectionArg)

			if selLower == "me" or selLower == "self" or selLower == "" then
				table.insert(targets, speaker)
			elseif selLower == "all" then
				targets = game.Players:GetPlayers()
			elseif selLower == "others" then
				for _, plr in ipairs(game.Players:GetPlayers()) do
					if plr ~= speaker then
						table.insert(targets, plr)
					end
				end
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				table.insert(targets, pl)
			end

			for _, target in ipairs(targets) do
				local char = target.Character
				if not char then
					msgSelf("error", target.Name .. " has no character loaded.")
				else
					local ok, err = pcall(function()

						for _, accessory in ipairs(char:GetChildren()) do
							if accessory:IsA("Accessory") then
								accessory:Destroy()
							end
						end

						local shirt = char:FindFirstChildOfClass("Shirt") or Instance.new("Shirt", char)
						local pants = char:FindFirstChildOfClass("Pants") or Instance.new("Pants", char)

						shirt.ShirtTemplate = "http://www.roblox.com/asset/?id=7374514554"
						pants.PantsTemplate = "http://www.roblox.com/asset/?id=6601037954"

						local dogeModel = script.Accessories:FindFirstChild("DOGE")
						if dogeModel and dogeModel:IsA("Accessory") then
							dogeModel:Clone().Parent = char
						else
							warn("DOGE accessory not found or invalid.")
						end
					end)

					if not ok then
						msgSelf("error", "Failed to apply Doge outfit to " .. target.Name .. ": " .. tostring(err))
					else
						msgSelf("info", target.Name .. " has become Doge!")
					end
				end
			end

			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";doge " .. selectionArg) end)
			end
		end,
	})

	table.insert(commands, {
		Name = "notify",
		Aliases = {"msg", "message"},
		Prefixes = { settings.Prefix },
		Rank = 1,
		RankLock = false,
		Tags = {"utility"},
		Args = {"string"},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Notify", kind = kind, text = text })
				end
			end

			if #args < 1 then
				msgSelf("warn", "Usage: ;notify [message]")
				return
			end

			local message = table.concat(args, " ")

			msgSelf("info", message)

			if main and typeof(main.addLog) == "function" then
				pcall(function()
					main.addLog(speaker, ";notify " .. message)
				end)
			end
		end,

	})

	table.insert(commands, {
		Name = "respawn",
		Aliases = {"reload","re","reset"},
		Prefixes = { settings.Prefix },
		Rank = 1,
		RankLock = false,
		Tags = {"Character"},
		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "respawn", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local targets = {}
			local selLower = string.lower(selectionArg)

			if selLower == "me" or selLower == "self" or selLower == "" then
				table.insert(targets, speaker)
			elseif selLower == "all" then
				targets = game.Players:GetPlayers()
			elseif selLower == "others" then
				for _, plr in ipairs(game.Players:GetPlayers()) do
					if plr ~= speaker then
						table.insert(targets, plr)
					end
				end
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				table.insert(targets, pl)
			end

			for _, target in ipairs(targets) do
				local char = target.Character
				local pos = (char and char:FindFirstChild("HumanoidRootPart")) and char.HumanoidRootPart.Position
				target:LoadCharacter()
				if pos then
					local newChar = target.Character
					if newChar and newChar:FindFirstChild("HumanoidRootPart") then
						newChar.HumanoidRootPart.CFrame = CFrame.new(pos)
					end
				end
				msgSelf("info", "Respawned " .. target.Name .. ".")
			end

			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";respawn " .. selectionArg) end)
			end
		end,
	})

	table.insert(commands, {
		Name = "sword",
		Aliases = {"linkedsword"},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = {"tools"},

		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "sword", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local targets = {}

			local selLower = string.lower(selectionArg)
			if selLower == "me" or selLower == "self" or selLower == "" then
				table.insert(targets, speaker)
			elseif selLower == "all" then
				targets = game.Players:GetPlayers()
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				table.insert(targets, pl)
			end

			for _, target in ipairs(targets) do
				local char = target.Character
				if not char then
					msgSelf("error", "Target " .. target.Name .. " has no character loaded.")
				else
					local backpack = target:FindFirstChildOfClass("Backpack")
					if not backpack then
						msgSelf("error", "No backpack found for " .. target.Name .. ".")
					else
						local ok, err = pcall(function()
							local tool = script:WaitForChild("Gears"):WaitForChild("ClassicSword")
							tool:Clone().Parent = backpack
						end)
						if not ok then
							msgSelf("error", "Failed to give sword to " .. target.Name .. ": " .. tostring(err))
						else
							msgSelf("info", "Gave sword to " .. target.Name .. ".")
						end
					end
				end
			end

			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";sword " .. selectionArg) end)
			end
		end,
	})

	table.insert(commands, {
		Name = "kill",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = {"combat"},

		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "kill", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local targets = {}
			local selLower = string.lower(selectionArg)

			if selLower == "me" or selLower == "self" or selLower == "" then
				table.insert(targets, speaker)
			elseif selLower == "all" then
				targets = game.Players:GetPlayers()
			elseif selLower == "others" then
				for _, plr in ipairs(game.Players:GetPlayers()) do
					if plr ~= speaker then
						table.insert(targets, plr)
					end
				end
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				table.insert(targets, pl)
			end

			for _, target in ipairs(targets) do
				local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = 0
					msgSelf("info", "Killed " .. target.Name .. ".")
				else
					msgSelf("warn", target.Name .. " has no humanoid or character.")
				end
			end

			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";kill " .. selectionArg) end)
			end
		end,
	})

	table.insert(commands, {
		Name = "explode",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = {"combat"},

		Args = {},
		Function = function(speaker, args)
			if speaker and speaker.Character and speaker.Character:FindFirstChild("HumanoidRootPart") then

				local explosion = Instance.new("Explosion")
				explosion.Position = speaker.Character.HumanoidRootPart.Position
				explosion.BlastRadius = 10
				explosion.BlastPressure = 500000
				explosion.Parent = workspace

				if speaker.Character:FindFirstChild("Humanoid") then
					speaker.Character.Humanoid.Health = 0
				end

				if main and typeof(main.addLog) == "function" then
					pcall(function() main.addLog(speaker, ";explode") end)
				end
			end
		end,

	})

	table.insert(commands, {
		Name = "speed",
		Aliases = {"walkspeed"},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"movement"},
		Args = {"number"},
		Function = function(speaker, args)
			local speed = tonumber(args[1])
			if not speed then
				return
			end

			if speaker and speaker.Character and speaker.Character:FindFirstChild("Humanoid") then
				speaker.Character.Humanoid.WalkSpeed = speed
				if main and typeof(main.addLog) == "function" then
					pcall(function() main.addLog(speaker, ";speed "..speed) end)
				end
			end
		end,

	})

	table.insert(commands, {
		Name = "jump",
		Aliases = {"jumppower"},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"movement"},
		Args = {"number"},
		Function = function(speaker, args)
			local jumpPower = tonumber(args[1])
			if not jumpPower then
				return
			end

			if speaker and speaker.Character and speaker.Character:FindFirstChild("Humanoid") then
				speaker.Character.Humanoid.JumpPower = jumpPower
				if main and typeof(main.addLog) == "function" then
					pcall(function() main.addLog(speaker, ";jump "..jumpPower) end)
				end
			end
		end,

		table.insert(commands, {
			Name = "hat",
			Aliases = {},
			Prefixes = { settings.Prefix },
			Rank = 2,
			RankLock = false,
			Tags = {"utility", "hat"},
			Args = {},
			Function = function(speaker, args)
				local function msgSelf(kind, text)
					local evt = main.Remotes and main.Remotes.AdminMessage
					if evt and evt:IsA("RemoteEvent") then
						evt:FireClient(speaker, { header = "Hat", kind = kind, text = text })
					end
				end

				local hatId, target
				if #args == 0 then
					msgSelf("error", "You must provide a hat Asset ID.")
					return
				elseif #args == 1 then
					hatId = tonumber(args[1])
					target = speaker
				else
					local pl, findErr = main.Utils.findPlayerByNameOrId(args[1])
					if not pl then
						local kind = (findErr == "Ambiguous name") and "warn" or "error"
						msgSelf(kind, findErr or "Player not found or not online.")
						return
					end
					target = pl
					hatId = tonumber(args[2])
				end

				if not hatId then
					msgSelf("error", "Invalid hat Asset ID.")
					return
				end

				if not target.Character or not target.Character:FindFirstChild("Humanoid") then
					msgSelf("error", "Target player has no character loaded.")
					return
				end

				local success, hatModel = pcall(function()
					return game:GetService("InsertService"):LoadAsset(hatId)
				end)
				if not success or not hatModel then
					msgSelf("error", "Failed to load hat with ID: " .. tostring(hatId))
					return
				end

				for _, item in pairs(hatModel:GetChildren()) do
					if item:IsA("Accessory") then
						item.Parent = target.Character
					end
				end
				hatModel:Destroy()

				if main and typeof(main.addLog) == "function" then
					pcall(function() main.addLog(speaker, ";hat " .. target.Name .. " " .. tostring(hatId)) end)
				end
				msgSelf("info", "Equipped hat ID " .. hatId .. " on " .. target.Name)
			end,

		})
	})

	table.insert(commands, {
		Name = "gear",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"utility", "gear"},
		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Gear", kind = kind, text = text })
				end
			end

			local gearId, target
			if #args == 0 then
				msgSelf("error", "You must provide a Gear ID.")
				return
			elseif #args == 1 then
				gearId = tonumber(args[1])
				target = speaker
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(args[1])
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				target = pl
				gearId = tonumber(args[2])
			end

			if not gearId then
				msgSelf("error", "Invalid Gear ID.")
				return
			end

			if not target.Backpack then
				msgSelf("error", "Target player has no Backpack.")
				return
			end

			local success, gearModel = pcall(function()
				return game:GetService("InsertService"):LoadAsset(gearId)
			end)
			if not success or not gearModel then
				msgSelf("error", "Failed to load gear with ID: " .. tostring(gearId))
				return
			end

			for _, item in pairs(gearModel:GetChildren()) do
				if item:IsA("Tool") then
					item.Parent = target.Backpack
				end
			end
			gearModel:Destroy()

			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";gear " .. target.Name .. " " .. tostring(gearId)) end)
			end
			msgSelf("info", "Added gear ID " .. gearId .. " to " .. target.Name .. "'s Backpack.")
		end,

	})

	table.insert(commands, {
		Name = "fling",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 1,
		RankLock = false,
		Tags = {"movement"},
		Args = {},
		Function = function(speaker, args)
			if speaker and speaker.Character and speaker.Character:FindFirstChild("HumanoidRootPart") then
				local hrp = speaker.Character.HumanoidRootPart

				local bv = Instance.new("BodyVelocity")
				bv.Velocity = Vector3.new(math.random(-300,300), 250, math.random(-300,300))
				bv.MaxForce = Vector3.new(1e6,1e6,1e6)
				bv.P = 1e5
				bv.Parent = hrp

				local bav = Instance.new("BodyAngularVelocity")
				bav.AngularVelocity = Vector3.new(math.random(-20,20), math.random(-20,20), math.random(-20,20))
				bav.MaxTorque = Vector3.new(1e6,1e6,1e6)
				bav.P = 1e5
				bav.Parent = hrp

				game:GetService("Debris"):AddItem(bv, 0.7)
				game:GetService("Debris"):AddItem(bav, 0.7)
			end
		end,

	})

	table.insert(commands, {
		Name = "gravity",
		Aliases = {"grav"},
		Prefixes = { settings.Prefix },
		Rank = 1,
		RankLock = false,
		Tags = {"movement", "environment"},
		Args = {"number"},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Gravity", kind = kind, text = text })
				end
			end

			if #args == 0 then
				msgSelf("error", "You must provide a gravity value (e.g. 50, 196.2).")
				return
			end

			local newGravity = tonumber(args[1])
			if not newGravity then
				msgSelf("error", "Invalid gravity value. Please provide a number.")
				return
			end

			local workspace = game:GetService("Workspace")
			workspace.Gravity = newGravity

			if main and typeof(main.addLog) == "function" then
				pcall(function()
					main.addLog(speaker, ";gravity " .. tostring(newGravity))
				end)
			end

			msgSelf("info", "Gravity has been set to " .. tostring(newGravity) .. ".")
		end,
	})

	table.insert(commands, {
		Name = "shutdown",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 3,
		RankLock = false,
		Tags = { "utility", "server" },
		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Shutdown", kind = kind, text = text })
				end
			end

			msgSelf("info", "Shutting down server...")

			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";shutdown ") end)
			end

			task.delay(3, function()
				pcall(function()
					for _, player in ipairs(game.Players:GetPlayers()) do
						player:Kick("The server was shutdown by " .. speaker.Name)
					end
				end)
			end)
		end,
	})

	table.insert(commands, {
		Name = "Place",
		Aliases = { "TeleportPlace", "tpplace" },
		Prefixes = { settings.Prefix },
		Rank = 4,
		RankLock = false,
		Tags = { "utility", "teleport" },
		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Place", kind = kind, text = text })
				end
			end

			if #args < 1 then
				msgSelf("error", "Usage: :place <player|all> <PlaceId>")
				return
			end

			local TeleportService = game:GetService("TeleportService")

			local targetPlayers = {}
			local placeId

			if args[1]:lower() == "all" then
				placeId = tonumber(args[2])
				if not placeId then
					msgSelf("error", "Invalid Place ID.")
					return
				end
				targetPlayers = game.Players:GetPlayers()
			else

				local pl, findErr = main.Utils.findPlayerByNameOrId(args[1])
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				table.insert(targetPlayers, pl)

				placeId = tonumber(args[2])
				if not placeId then
					msgSelf("error", "Invalid Place ID.")
					return
				end
			end

			local success, placeInfo = pcall(function()
				return TeleportService:GetPlayerPlaceInstanceAsync(placeId)
			end)

			if not success or not placeInfo or not placeInfo.UniverseId then
				msgSelf("error", "Failed to get place info. Check the Place ID.")
				return
			end

			local currentUniverseId = game.GameId
			if placeInfo.UniverseId ~= currentUniverseId then
				msgSelf("error", "Cannot teleport to a third-party game. Target place is outside this universe.")
				return
			end

			msgSelf("info", "Teleporting " .. (#targetPlayers == #game.Players:GetPlayers() and "all players" or tostring(#targetPlayers) .. " player(s)") .. " to place " .. tostring(placeId) .. "...")

			for _, player in ipairs(targetPlayers) do
				pcall(function()
					TeleportService:Teleport(placeId, player)
				end)
			end

			if main and typeof(main.addLog) == "function" then
				pcall(function()
					main.addLog(speaker, ";place " .. (args[1] or "") .. " " .. tostring(placeId))
				end)
			end
		end,
	})

	table.insert(commands, {
		Name = "globalmessage",
		Aliases = {"globalannounce", "gannounce", "gmsg", "broadcastall","ga","globalmessage"},
		Prefixes = { settings.Prefix },
		Rank = 4,
		RankLock = false,
		Tags = {"moderation", "utility", "broadcast", "global"},

		Args = {},
		Function = function(speaker, args)
			local MessagingService = game:GetService("MessagingService")

			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Global Announcement", kind = kind, text = text })
				end
			end

			if typeof(args) ~= "table" or #args < 1 then
				msgSelf("error", "Usage: ;globalmessage <message>")
				return
			end

			local text = table.concat(args, " ")
			text = string.gsub(text, "^%s*(.-)%s*$", "%1")
			if text == "" then
				msgSelf("error", "Provide a message to broadcast globally.")
				return
			end
			if #text > 300 then
				text = string.sub(text, 1, 300)
			end

			local filtered, filterErr = main.Utils.filterBroadcastText(speaker, text)
			if not filtered then
				msgSelf("error", "Message blocked by content filter.")
				return
			end

			local payload = {
				title = "Message From " .. speaker.Name,
				subtitle = "Global Announcement",
				text = filtered,
				duration = 8,
				senderUserId = speaker.UserId,
				senderName = speaker.Name,
				timestamp = os.time(),
			}

			local success, err = pcall(function()
				MessagingService:PublishAsync("GlobalAdminAnnouncement", payload)
			end)
			if not success then
				msgSelf("error", "Failed to send global message: " .. tostring(err))
				return
			end
			msgSelf("info", "Sending Global announcement please wait..")
			task.wait(1.45)
			msgSelf("info", "Global announcement sent!")

			local evt = main.Remotes and main.Remotes.AdminAnnouncement
			if evt and evt:IsA("RemoteEvent") then
				evt:FireAllClients(payload)
			end

			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";globalmessage " .. filtered) end)
			end
		end,
	})

	table.insert(commands, {
		Name = "rejoin",
		Aliases = {"place", "game"},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"fun", "utility", "view"},

		Args = {},
		Function = function(speaker: Player, args)
			local TeleportService = game:GetService("TeleportService")
			local PlaceId = game.PlaceId
			local JobId = game.JobId

			TeleportService:TeleportToPlaceInstance(PlaceId, JobId, speaker)
		end,
	})
	
	table.insert(commands, {
		Name = "freeze",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"admin", "utility"},

		Args = {"player"},
		Function = function(speaker, args)
			local TweenService = game:GetService("TweenService")

			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Freeze", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local targets = {}

			local selLower = string.lower(selectionArg)
			if selLower == "all" then
				targets = game.Players:GetPlayers()
			elseif selLower == "others" then
				for _, plr in ipairs(game.Players:GetPlayers()) do
					if plr ~= speaker then
						table.insert(targets, plr)
					end
				end
			elseif selLower == "me" or selLower == "" then
				table.insert(targets, speaker)
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				table.insert(targets, pl)
			end

			for _, plr in ipairs(targets) do
				if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
					local hrp = plr.Character.HumanoidRootPart

					-- Anchor player before freezing
					for _, part in ipairs(plr.Character:GetDescendants()) do
						if part:IsA("BasePart") then
							part.Anchored = true
						end
					end

					-- Create ice block
					local iceBlock = Instance.new("Part")
					iceBlock.Name = "FreezeBlock_" .. plr.Name
					iceBlock.Size = Vector3.new(8, 10, 8)
					iceBlock.Anchored = true
					iceBlock.CanCollide = true
					iceBlock.Material = Enum.Material.Ice
					iceBlock.BrickColor = BrickColor.new("Pastel light blue")
					iceBlock.Reflectance = 0.25
					iceBlock.Transparency = 1 -- Start invisible
					iceBlock.CFrame = hrp.CFrame
					iceBlock.Parent = workspace

					-- Tween ice transparency (fade in)
					local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					local goal = { Transparency = 0.35 }
					local tween = TweenService:Create(iceBlock, tweenInfo, goal)
					tween:Play()

					-- Center player exactly in the ice
					hrp.CFrame = iceBlock.CFrame

					-- Play frozen sound if it exists
					local frozenSound = script:FindFirstChild("Sounds") and script.Sounds:FindFirstChild("Freeze")
					if frozenSound then
						local soundClone = frozenSound:Clone()
						soundClone.Parent = iceBlock
						soundClone:Play()
						game:GetService("Debris"):AddItem(soundClone, 3)
					end

					-- Frost particle effect
					local particle = Instance.new("ParticleEmitter")
					particle.Texture = "rbxassetid://284361850"
					particle.Rate = 15
					particle.Lifetime = NumberRange.new(1)
					particle.Speed = NumberRange.new(0)
					particle.Size = NumberSequence.new(0.25)
					particle.Transparency = NumberSequence.new(0.5)
					particle.Parent = iceBlock
				end
			end

			msgSelf("info", "Froze " .. selectionArg .. ".")
			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";freeze " .. selectionArg) end)
			end
		end,
	})
	
	table.insert(commands, {
		Name = "unfreeze",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"admin", "utility"},

		Args = {"player"},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Unfreeze", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local targets = {}

			local selLower = string.lower(selectionArg)
			if selLower == "all" then
				targets = game.Players:GetPlayers()
			elseif selLower == "others" then
				for _, plr in ipairs(game.Players:GetPlayers()) do
					if plr ~= speaker then
						table.insert(targets, plr)
					end
				end
			elseif selLower == "me" or selLower == "" then
				table.insert(targets, speaker)
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				table.insert(targets, pl)
			end

			for _, plr in ipairs(targets) do
				if plr.Character then
					-- Unanchor all parts
					for _, part in ipairs(plr.Character:GetDescendants()) do
						if part:IsA("BasePart") then
							part.Anchored = false
						end
					end

					-- Delete ice block if it exists
					local iceBlock = workspace:FindFirstChild("FreezeBlock_" .. plr.Name)
					if iceBlock then
						iceBlock:Destroy()
					end
				end
			end

			msgSelf("info", "Unfroze " .. selectionArg .. ".")
			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";unfreeze " .. selectionArg) end)
			end
		end,
	})
	
	table.insert(commands, {
		Name = "noob",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 2,
		RankLock = false,
		Tags = {"Character"},
		Args = {},
		Function = function(speaker, args)
			local function msgSelf(kind, text)
				local evt = main.Remotes and main.Remotes.AdminMessage
				if evt and evt:IsA("RemoteEvent") then
					evt:FireClient(speaker, { header = "Noob", kind = kind, text = text })
				end
			end

			local selectionArg = (#args >= 1) and tostring(args[1]) or "me"
			local targets = {}
			local selLower = string.lower(selectionArg)

			if selLower == "me" or selLower == "self" or selLower == "" then
				table.insert(targets, speaker)
			elseif selLower == "all" then
				targets = game.Players:GetPlayers()
			elseif selLower == "others" then
				for _, plr in ipairs(game.Players:GetPlayers()) do
					if plr ~= speaker then
						table.insert(targets, plr)
					end
				end
			else
				local pl, findErr = main.Utils.findPlayerByNameOrId(selectionArg)
				if not pl then
					local kind = (findErr == "Ambiguous name") and "warn" or "error"
					msgSelf(kind, findErr or "Player not found or not online.")
					return
				end
				table.insert(targets, pl)
			end

			local noobRig = game:GetService("ServerScriptService")
				:WaitForChild("AlfieMain")
				:WaitForChild("AssetsReplicated")
				:WaitForChild("AlfieReplicated")
				:WaitForChild("Noob")

			if not noobRig then
				msgSelf("error", "NoobRig not found.")
				return
			end

			local noobColors = noobRig:FindFirstChildOfClass("BodyColors")
			if not noobColors then
				msgSelf("error", "Noob rig has no BodyColors!")
				return
			end

			for _, player in ipairs(targets) do
				local char = player.Character
				if not char then
					msgSelf("error", player.Name .. " has no character loaded.")
				else
					-- Remove all accessories
					for _, acc in ipairs(char:GetChildren()) do
						if acc:IsA("Accessory") then
							acc:Destroy()
						end
					end

					-- Apply Noob body colors
					local playerColors = char:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors", char)
					playerColors.HeadColor = noobColors.HeadColor
					playerColors.TorsoColor = noobColors.TorsoColor
					playerColors.LeftArmColor = noobColors.LeftArmColor
					playerColors.RightArmColor = noobColors.RightArmColor
					playerColors.LeftLegColor = noobColors.LeftLegColor
					playerColors.RightLegColor = noobColors.RightLegColor
					
					char:FindFirstChild("Shirt"):Destroy()
					char:FindFirstChild("Pants"):Destroy()

					msgSelf("info", player.Name .. " is now a Noob!")
				end
			end

			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";noob " .. selectionArg) end)
			end
		end,
	})

	return commands
end