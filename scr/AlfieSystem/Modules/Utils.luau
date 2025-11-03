local Utils = {}
local TextService = game:GetService("TextService")

function Utils.filterBroadcastText(fromPlayer, text)
	text = tostring(text or "")
	if text == "" then return "" end
	local userId = (fromPlayer and fromPlayer.UserId) or 0
	local ok, resultOrErr = pcall(function()
		local fr = TextService:FilterStringAsync(text, userId)
		return fr:GetNonChatStringForBroadcastAsync()
	end)
	if ok and typeof(resultOrErr) == "string" then
		return resultOrErr
	else
		warn("[Utils] Text filter failed:", tostring(resultOrErr))
		return nil, resultOrErr
	end
end

function Utils.safeCall(fn, ...)
	if typeof(fn) ~= "function" then
		return false, "Invalid function"
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		return false, result
	end
	return true, result
end

function Utils.isTransientDSError(err)
	local s = string.lower(tostring(err))
	if string.find(s, "throttl", 1, true) then return true end
	if string.find(s, "too many", 1, true) then return true end
	if string.find(s, "timeout", 1, true) then return true end
	if string.find(s, "timed out", 1, true) then return true end
	if string.find(s, "unavailable", 1, true) then return true end
	if string.find(s, "502", 1, true) or string.find(s, "503", 1, true) then return true end
	return false
end

function Utils.dataStoreCallWithRetry(callFn, opts)
	local attempts = (typeof(opts) == "table" and tonumber(opts.attempts)) or 5
	local baseDelay = (typeof(opts) == "table" and tonumber(opts.baseDelay)) or 0.5
	local maxDelay = (typeof(opts) == "table" and tonumber(opts.maxDelay)) or 5
	for i = 1, attempts do
		local ok, res = pcall(callFn)
		if ok then return true, res end
		local err = res
		if i >= attempts or not Utils.isTransientDSError(err) then
			return false, err
		end
		local delay = math.min(maxDelay, baseDelay * (2 ^ (i - 1))) * (0.5 + math.random())
		task.wait(delay)
	end
	return false, "Retry failed"
end

function Utils.throttleCheck(map, key, windowSeconds)
	if typeof(map) ~= "table" or key == nil then return true, 0 end
	local window = tonumber(windowSeconds) or 8
	local now = os.time()
	local last = map[key]
	if typeof(last) == "number" then
		local diff = now - last
		if diff < window then
			return false, window - diff
		end
	end
	map[key] = now
	return true, 0
end

function Utils.computeDesiredPower(viewerPower, maxPower, requestedPower)
	local vp = tonumber(viewerPower) or 0
	local mp = tonumber(maxPower) or 0
	local maxAllowed = (vp == mp) and mp or (vp - 1)
	local desired
	if requestedPower == nil then
		desired = maxAllowed
	else
		desired = tonumber(requestedPower) or 0
	end
	if desired > maxAllowed then desired = maxAllowed end
	if desired < 0 then desired = 0 end
	return desired
end

function Utils.canChangeRank(viewerPower, targetCurrentPower)
	local vp = tonumber(viewerPower) or 0
	local tp = tonumber(targetCurrentPower) or 0
	if tp >= vp then
		return false, "You cannot change rank of equal/higher power."
	end
	return true
end

function Utils.resolvePlayerRank(player, settings)
	local ranks = (settings and settings.Ranks) or {}
	local nameLower = string.lower(player.Name)
	local userId = player.UserId
	local best = 0
	for _, entry in ipairs(ranks) do
		local rankNumber = entry[1]
		local includes = entry[3]
		if type(includes) == "table" then
			for _, ident in ipairs(includes) do
				if type(ident) == "string" and ident ~= "" then
					if string.lower(ident) == nameLower then
						best = math.max(best, rankNumber)
					end
				elseif type(ident) == "number" and ident ~= 0 then
					if ident == userId then
						best = math.max(best, rankNumber)
					end
				end
			end
		end
	end
	local creatorType = game.CreatorType
	local creatorId = game.CreatorId
	local maxPower = Utils.getMaxPower(settings)
	if creatorType == Enum.CreatorType.User then
		if userId == creatorId then
			best = math.max(best, maxPower)
		end
	elseif creatorType == Enum.CreatorType.Group then
		local okRank, rankVal = pcall(function()
			return player:GetRankInGroup(creatorId)
		end)
		if okRank and tonumber(rankVal) == 255 then
			best = math.max(best, maxPower)
		end
	end
	local permRanks = settings and settings.PermRanks
	if typeof(permRanks) == "table" then
		local pr = permRanks[userId]
		if typeof(pr) == "number" then
			best = math.max(best, pr)
		end
	end
	local tempRanks = settings and settings.TempRanks
	if typeof(tempRanks) == "table" then
		local rec = tempRanks[userId]
		if typeof(rec) == "table" then
			local pwr = tonumber(rec.power) or 0
			local exp = rec.expiresAt
			if exp == nil or os.time() < exp then
				best = math.max(best, pwr)
			elseif exp ~= nil and os.time() >= exp then
				tempRanks[userId] = nil
			end
		end
	end
	return best
end

function Utils.findPlayerByNameOrId(query)
	query = tostring(query or "")
	if query == "" then return nil, "Empty query" end

	local Players = game:GetService("Players")
	local num = tonumber(query)
	if num then
		local pl = Players:GetPlayerByUserId(num)
		if pl then return pl, nil else return nil, "UserId not online" end
	end

	local lower = string.lower(query)
	local exact
	local partial = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local nameLower = string.lower(pl.Name)
		if nameLower == lower then
			exact = pl
			break
		end
		if string.find(nameLower, lower, 1, true) then
			table.insert(partial, pl)
		end
	end
	if exact then return exact, nil end
	if #partial == 1 then return partial[1], nil end
	if #partial > 1 then return nil, "Ambiguous name" end
	return nil, "Player not found"
end

function Utils.parseDuration(text)
	text = tostring(text or "")
	if text == "" then return nil end
	local num = tonumber(text)
	if num then return math.max(0, math.floor(num)) end
	local value = tonumber(string.match(text, "^(%d+)%s*[smhdSMHD]$"))
	local unit = string.match(text, "^%d+%s*([smhdSMHD])$")
	if value and unit then
		unit = string.lower(unit)
		if unit == "s" then return value end
		if unit == "m" then return value * 60 end
		if unit == "h" then return value * 3600 end
		if unit == "d" then return value * 86400 end
	end
	return nil
end

function Utils.cleanupExpiredTempRanks(settings)
	local tempRanks = settings and settings.TempRanks
	if typeof(tempRanks) ~= "table" then return end
	local now = os.time()
	for uid, rec in pairs(tempRanks) do
		if typeof(rec) == "table" then
			local exp = rec.expiresAt
			if exp ~= nil and now >= exp then
				tempRanks[uid] = nil
			end
		end
	end
end

function Utils.buildRankPayload(speaker: Player?, settings)
	local Players = game:GetService("Players")
	local ranks = (settings and settings.Ranks) or {}
	local payload = { ranks = {} }

	local onlinePlayers = Players:GetPlayers()
	local onlineByName = {}
	for _, pl in ipairs(onlinePlayers) do
		onlineByName[string.lower(pl.Name)] = pl
	end

	local occurrence = {}
	for _, entry in ipairs(ranks) do
		local includes = entry[3]
		if typeof(includes) == "table" then
			for _, ident in ipairs(includes) do
				if typeof(ident) == "string" and ident ~= "" then
					local key = "name:" .. string.lower(ident)
					occurrence[key] = (occurrence[key] or 0) + 1
				elseif typeof(ident) == "number" and ident ~= 0 then
					local key = "id:" .. tostring(ident)
					occurrence[key] = (occurrence[key] or 0) + 1
				end
			end
		end
	end

	local maxPower = 0
	for _, entry in ipairs(ranks) do
		local pwr = tonumber(entry[1]) or 0
		if pwr > maxPower then maxPower = pwr end
	end
	local viewerPower = 0
	if speaker then
		viewerPower = Utils.resolvePlayerRank(speaker, settings)
	end
	payload.maxPower = maxPower
	payload.viewerPower = viewerPower
	payload.viewerId = (speaker and speaker.UserId) or nil

	for _, entry in ipairs(ranks) do
		local power = tonumber(entry[1]) or 0
		local name = tostring(entry[2] or "")
		local includes = entry[3]
		local users = {}
		local seen = {}

		if typeof(includes) == "table" then
			for _, ident in ipairs(includes) do
				local u
				if typeof(ident) == "string" and ident ~= "" then
					local uname = ident
					local lower = string.lower(uname)
					local online = onlineByName[lower] ~= nil
					local uid
					local pl = onlineByName[lower]
					if pl then uid = pl.UserId end
					local keyName = "name:" .. lower
					local keyId = uid and ("id:" .. tostring(uid)) or nil
					local multi = ((occurrence[keyName] or 0) + (keyId and (occurrence[keyId] or 0) or 0)) > 1
					u = { name = uname, userId = uid, online = online, multi = multi, status = "Server" }
				elseif typeof(ident) == "number" and ident ~= 0 then
					local uid = ident
					local pl = Players:GetPlayerByUserId(uid)
					local online = pl ~= nil
					local uname = pl and pl.Name or tostring(uid)
					local keyId = "id:" .. tostring(uid)
					local keyName = "name:" .. string.lower(uname)
					local multi = ((occurrence[keyId] or 0) + (occurrence[keyName] or 0)) > 1
					u = { name = uname, userId = uid, online = online, multi = multi, status = "Server" }
				end
				if u and not seen[string.lower(u.name)] then
					seen[string.lower(u.name)] = true
					table.insert(users, u)
				end
			end
		end

		for _, pl in ipairs(onlinePlayers) do
			local pr = Utils.resolvePlayerRank(pl, settings)
			if pr == power then
				local lower = string.lower(pl.Name)
				if not seen[lower] then
					local keyId = "id:" .. tostring(pl.UserId)
					local keyName = "name:" .. lower
					local multi = ((occurrence[keyId] or 0) + (occurrence[keyName] or 0)) > 1

					local status: string? = nil
					local tempRanks = settings and settings.TempRanks
					local rec = tempRanks and tempRanks[pl.UserId]
					if typeof(rec) == "table" then
						local exp = rec.expiresAt
						if exp == nil or os.time() < exp then
							status = "Temp"
						end
					end
					if not status then
						local permRanks = settings and settings.PermRanks
						local prval = permRanks and permRanks[pl.UserId]
						if typeof(prval) == "number" then
							status = "Perm"
						end
					end
					table.insert(users, { name = pl.Name, userId = pl.UserId, online = true, multi = multi, status = status })
					seen[lower] = true
				end
			end
		end

		table.insert(payload.ranks, { power = power, name = name, users = users })
	end

	return payload
end

function Utils.getMaxPower(settings)
	local ranks = (settings and settings.Ranks) or {}
	local maxP = 0
	for _, entry in ipairs(ranks) do
		local pwr = tonumber(entry[1]) or 0
		if pwr > maxP then maxP = pwr end
	end
	return maxP
end

function Utils.getRankName(settings, power)
	local ranks = (settings and settings.Ranks) or {}
	for _, entry in ipairs(ranks) do
		local pwr = tonumber(entry[1]) or 0
		local name = tostring(entry[2] or "")
		if pwr == power then
			if name ~= "" then return name end
			break
		end
	end
	return "Rank " .. tostring(power)
end

function Utils.parseDesiredPowerArg(argValue, settings)
	local s = tostring(argValue or "")
	if s == "" then return nil end
	local n = tonumber(s)
	if n then return math.floor(n) end
	local ranks = (settings and settings.Ranks) or {}
	local sl = string.lower(s)
	for _, entry in ipairs(ranks) do
		local power = tonumber(entry[1]) or 0
		local name = tostring(entry[2] or "")
		if string.lower(name) == sl then
			return power
		end
	end
	return nil
end

function Utils.findCurrentRankFor(userId, userName, settings)
	local ranks = (settings and settings.Ranks) or {}
	local nameLower = userName and string.lower(userName) or nil
	for _, entry in ipairs(ranks) do
		local power = tonumber(entry[1]) or 0
		local includes = entry[3]
		if typeof(includes) == "table" then
			for _, ident in ipairs(includes) do
				if typeof(ident) == "number" and userId and ident == userId then
					return power
				elseif typeof(ident) == "string" and nameLower and nameLower ~= "" and string.lower(ident) == nameLower then
					return power
				end
			end
		end
	end
	return 0
end

function Utils.buildCommandsPayload(settings, commandsList, filter)
	local raw = commandsList or {}
	local out = { commands = {}, open = true }
	local matchLower = filter and string.lower(tostring(filter)) or nil

	for _, c in ipairs(raw) do
		local name = tostring(c.Name or "")
		local include = true
		if matchLower and matchLower ~= "" then
			include = (string.lower(name) == matchLower)
			if not include and typeof(c.Aliases) == "table" then
				for _, a in ipairs(c.Aliases) do
					if string.lower(tostring(a)) == matchLower then
						include = true
						break
					end
				end
			end
		end
		if include then
			local r = tonumber(c.Rank) or 0
			table.insert(out.commands, {
				name = name,
				aliases = (typeof(c.Aliases) == "table" and c.Aliases) or {},
				rank = r,
				rankName = Utils.getRankName(settings, r),
				tags = (typeof(c.Tags) == "table" and c.Tags) or {},
			})
		end
	end

	table.sort(out.commands, function(a, b)
		return string.lower(a.name) < string.lower(b.name)
	end)
	return out
end

function Utils.buildBanlandPayload(settings)
	local bannedTable = (settings and settings.BannedUsers) or {}
	local out = { banned = {}, open = true }

	for uid, rec in pairs(bannedTable) do
		if typeof(rec) == "table" then
			table.insert(out.banned, {
				userId = tonumber(rec.userId) or tonumber(uid),
				name = tostring(rec.name or ""),
				at = tonumber(rec.at) or os.time(),
			})
		elseif typeof(uid) == "number" then
			table.insert(out.banned, { userId = uid, name = tostring(uid), at = os.time() })
		end
	end
	table.sort(out.banned, function(a, b)
		return string.lower(tostring(a.name or "")) < string.lower(tostring(b.name or ""))
	end)
	return out
end

function Utils.getHumanoidRoot(plr)
	local char = plr and plr.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then return hrp end
	end
	return nil
end

function Utils.getCharacterHead(plr)
	local char = plr and plr.Character
	if char then
		local head = char:FindFirstChild("Head")
		if head and head:IsA("BasePart") then return head end
	end
	return nil
end

function Utils.unSeatPlayer(plr)
	local char = plr and plr.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.Sit = false end
end

function Utils.teleportPlayers(plrsToTeleport, targetPlr)
	if typeof(plrsToTeleport) ~= "table" or not targetPlr then return false, "Invalid args" end
	local targetRoot = Utils.getHumanoidRoot(targetPlr) or Utils.getCharacterHead(targetPlr)
	if not targetRoot then return false, "Target not ready" end
	local total = #plrsToTeleport
	local gap = 2
	for i, plr in ipairs(plrsToTeleport) do
		if plr ~= targetPlr then
			local root = Utils.getHumanoidRoot(plr) or Utils.getCharacterHead(plr)
			if root then
				Utils.unSeatPlayer(plr)
				local offset = CFrame.new(-(total*(gap/2))+(i*gap)-(gap/2), 0, -4) * CFrame.Angles(0, math.rad(180), 0)
				root.CFrame = targetRoot.CFrame * offset
			end
		end
	end
	return true
end

function Utils.convertCharacterToRig(plr, rigType)
	if not plr or not plr.Character then
		return false, "Player not ready"
	end
	local rt = tostring(rigType or ""):upper()
	if rt ~= "R6" and rt ~= "R15" then
		return false, "Invalid rig type"
	end

	local originalRoot = Utils.getHumanoidRoot(plr) or Utils.getCharacterHead(plr)
	local originalCFrame = originalRoot and originalRoot.CFrame or nil

	local nameWanted = "Rig" .. rt
	local ServerStorage = game:GetService("ServerStorage")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local function findRig(container)
		if not container then return nil end
		for _, inst in ipairs(container:GetDescendants()) do
			if inst:IsA("Model") and inst.Name == nameWanted then
				return inst
			end
		end
		return nil
	end

	local template = findRig(ServerStorage) or findRig(ReplicatedStorage)
	if not template then
		return false, "Rig asset '" .. nameWanted .. "' not found in ServerStorage/ReplicatedStorage"
	end

	local okClone, newRig = pcall(function()
		return template:Clone()
	end)
	if not okClone or not newRig then
		return false, "Failed to clone rig template"
	end

	newRig.Name = plr.Name
	local newHumanoid = newRig:FindFirstChildOfClass("Humanoid")
	if not newHumanoid then
		return false, "Rig template missing Humanoid"
	end

	local oldChar = plr.Character
	for _, child in ipairs(oldChar:GetChildren()) do
		if child:IsA("Accessory")
			or child:IsA("Pants")
			or child:IsA("Shirt")
			or child:IsA("ShirtGraphic")
			or child:IsA("BodyColors") then
			child.Parent = newRig
		elseif child.Name == "Head" then
			local face = child:FindFirstChild("face")
			local newHead = newRig:FindFirstChild("Head")
			if face and newHead and newHead:IsA("BasePart") then
				local newFace = newHead:FindFirstChild("face")
				if newFace and newFace:IsA("Decal") then
					newFace.Texture = face.Texture
				end
			end
		end
	end

	plr.Character = newRig
	newRig.Parent = workspace

	if originalCFrame then
		local newRoot = newRig:FindFirstChild("HumanoidRootPart") or newRig:FindFirstChild("Head")
		if newRoot and newRoot:IsA("BasePart") then
			newRoot.CFrame = originalCFrame
		end
	end

	local Players = game:GetService("Players")
	local okDesc, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(plr.UserId)
	end)
	if okDesc and desc then
		pcall(function()
			newHumanoid:ApplyDescription(desc)
		end)
	end

	return true
end

return Utils
