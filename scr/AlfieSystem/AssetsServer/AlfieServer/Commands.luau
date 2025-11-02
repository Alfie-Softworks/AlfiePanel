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
			print("[CoreCommands] Running 'logs' for", speaker and speaker.Name or "?")

			local logs = main.Logs or {}
			local max = (main.MaxLogs or 50)
			if #logs > max then
				logs = { table.unpack(logs, #logs - max + 1, #logs) }
			end

			local evt = main.Remotes and main.Remotes.AdminLogs
			if evt and evt:IsA("RemoteEvent") then
				evt:FireClient(speaker, logs)
				print("[CoreCommands] 'logs' sent", #logs, "entries via AdminLogs")
			else
				warn("[CoreCommands] AdminLogs RemoteEvent missing; ensure Remotes.provision ran.")
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
			print("[CoreCommands] Running 'kick' for", speaker and speaker.Name or "?")

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
				print("[CoreCommands] Kicked:", target.Name, "by", speaker and speaker.Name or "?")
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
							prev[targetUserId] = { userId = targetUserId, name = targetName, at = os.time() }
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
			print("[CoreCommands] Running 'rank' for", speaker and speaker.Name or "?")
			local payload = main.Utils.buildRankPayload(speaker, settings)

			local evt = main.Remotes and main.Remotes.AdminRanks
			if evt and evt:IsA("RemoteEvent") then
				evt:FireClient(speaker, payload)
				print("[CoreCommands] 'rank' payload sent via AdminRanks")
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
		Name = "m",
		Aliases = {"msg", "announce", "broadcast"},
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
				msgSelf("error", "Usage: ;m <message>")
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

			local payload = {
				title = "Message From " .. speaker.Name,
				subtitle = "Server Message",
				text = text,
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

			print("[CoreCommands] Broadcast announcement by", speaker and speaker.Name or "?", "text:", text)
		end,
	})

	table.insert(commands, {
		Name = "h",
		Aliases = {"hint"},
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

			local who = speaker and tostring(speaker.Name) or "Admin"
			local text = who .. " : " .. message

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

			print("[CoreCommands] Broadcast hint by", speaker and speaker.Name or "?", "text:", text)
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

			local ok, err = main.Utils(target, "R15")
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
				local tool = script:WaitForChild("Building Tools")
				
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
				local tool = script:WaitForChild("Building Tools")

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

			local ok, err = pcall(function()
				-- Remove accessories
				for _, accessory in ipairs(char:GetChildren()) do
					if accessory:IsA("Accessory") then
						accessory:Destroy()
					end
				end

				-- Change shirt and pants
				local shirt = char:FindFirstChildOfClass("Shirt")
				local pants = char:FindFirstChildOfClass("Pants")

				if not shirt then
					shirt = Instance.new("Shirt")
					shirt.Parent = char
				end
				if not pants then
					pants = Instance.new("Pants")
					pants.Parent = char
				end

				shirt.ShirtTemplate = "http://www.roblox.com/asset/?id=7374514554"
				pants.PantsTemplate = "http://www.roblox.com/asset/?id=6601037954"

				-- Add Doge accessory
				local dogeModel = script:FindFirstChild("DOGE")
				if dogeModel and dogeModel:IsA("Accessory") then
					local clone = dogeModel:Clone()
					clone.Parent = char
				else
					warn("DOGE accessory not found inside the script or not an Accessory.")
				end
			end)

			if not ok then
				msgSelf("error", "Failed to apply Doge outfit: " .. tostring(err))
				return
			end

			if main and typeof(main.addLog) == "function" then
				pcall(function()
					main.addLog(speaker, ";doge " .. selectionArg)
				end)
			end

			msgSelf("info", tostring(target and target.Name or "Player") .. " has become Doge!")
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
			if speaker and speaker:FindFirstChild("PlayerGui") then
				local player = speaker
				local character = player.Character
				if character then
					-- Save current position
					local pos = character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart.Position
					-- Destroy character to force respawn
					player.Character = nil
					player:LoadCharacter()
					-- Optional: move to previous position after respawn
					if pos then
						local newChar = player.Character
						if newChar and newChar:FindFirstChild("HumanoidRootPart") then
							newChar.HumanoidRootPart.CFrame = CFrame.new(pos)
						end
					end
				end

				if main and typeof(main.addLog) == "function" then
					pcall(function()
						main.addLog(speaker, ";respawn")
					end)
				end
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

			local function giveSword()
				local tool = script:WaitForChild("Gears"):WaitForChild("ClassicSword")

				tool:Clone().Parent = backpack
			end

			local ok, err = pcall(giveSword)
			if not ok then
				msgSelf("error", "Failed to give sword: " .. tostring(err))
				return
			end

			if main and typeof(main.addLog) == "function" then
				pcall(function() main.addLog(speaker, ";sword " .. selectionArg) end)
			end

			msgSelf("info", "Gave sword to " .. tostring(target and target.Name or "player") .. ".")
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
			if speaker and speaker.Character and speaker.Character:FindFirstChild("Humanoid") then
				speaker.Character.Humanoid.Health = 0
				if main and typeof(main.addLog) == "function" then
					pcall(function() main.addLog(speaker, ";kill") end)
				end
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
				-- Create explosion
				local explosion = Instance.new("Explosion")
				explosion.Position = speaker.Character.HumanoidRootPart.Position
				explosion.BlastRadius = 10
				explosion.BlastPressure = 500000
				explosion.Parent = workspace

				-- Kill the player
				if speaker.Character:FindFirstChild("Humanoid") then
					speaker.Character.Humanoid.Health = 0
				end

				if main and typeof(main.addLog) == "function" then
					pcall(function() main.addLog(speaker, ";explode") end)
				end
			end
		end,

	})
	
	}
	-- Speed Command
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

-- Jump Command
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

})

	return commands
end
