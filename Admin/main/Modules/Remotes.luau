local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local Validators = {}

local function validateAdminUnrank(payload)
	if typeof(payload) ~= "table" then
		return false, "Payload must be a table"
	end
	local allowed = { userId = true, userName = true }
	for k, _ in pairs(payload) do
		if not allowed[k] then
			return false, "Unknown key '" .. tostring(k) .. "'"
		end
	end
	if payload.userId ~= nil and typeof(payload.userId) ~= "number" then
		return false, "userId must be a number"
	end
	if payload.userName ~= nil and typeof(payload.userName) ~= "string" then
		return false, "userName must be a string"
	end
	local hasId = payload.userId ~= nil
	local hasName = (payload.userName ~= nil and payload.userName ~= "")
	if not hasId and not hasName then
		return false, "Provide userId or userName"
	end
	return true
end

Validators.AdminUnrank = validateAdminUnrank

local function validateAdminRunCommand(payload)
	if typeof(payload) ~= "table" then
		return false, "Payload must be a table"
	end
	for k, _ in pairs(payload) do
		if k ~= "text" then
			return false, "Unknown key '" .. tostring(k) .. "'"
		end
	end
	if typeof(payload.text) ~= "string" then
		return false, "text must be a string"
	end
	local trimmed = string.gsub(payload.text, "^%s*(.-)%s*$", "%1")
	if trimmed == "" then
		return false, "Empty command"
	end
	if #trimmed > 200 then
		return false, "Command too long"
	end
	return true
end
Validators.AdminRunCommand = validateAdminRunCommand

local function validateAdminUnban(payload)
	if typeof(payload) ~= "table" then
		return false, "Payload must be a table"
	end
	local hasId = (typeof(payload.userId) == "number")
	local hasName = (typeof(payload.userName) == "string" and payload.userName ~= "")
	if not hasId and not hasName then
		return false, "Provide userId or userName"
	end
	return true
end
Validators.AdminUnban = validateAdminUnban

function Remotes.provision()
	local container = ReplicatedStorage:FindFirstChild("AdminEvents")
	if not container then
		container = Instance.new("Folder")
		container.Name = "AdminEvents"
		container.Parent = ReplicatedStorage
	end

	local function ensureEvent(name)
		local evt = container:FindFirstChild(name)
		if not evt then
			evt = Instance.new("RemoteEvent")
			evt.Name = name
			evt.Parent = container
		end
		return evt
	end

	local AdminMessage = ensureEvent("AdminMessage")
	local AdminLogs = ensureEvent("AdminLogs")
	local AdminChatLogs = ensureEvent("AdminChatLogs")
	local AdminRanks = ensureEvent("AdminRanks")
	local AdminCommands = ensureEvent("AdminCommands")
	local AdminUnrank = ensureEvent("AdminUnrank")
	local AdminCmdbar = ensureEvent("AdminCmdbar")
	local AdminRunCommand = ensureEvent("AdminRunCommand")
	local AdminBanland = ensureEvent("AdminBanland")
	local AdminUnban = ensureEvent("AdminUnban")
	local AdminCredits = ensureEvent("AdminCredits")
	local AdminAnnouncement = ensureEvent("AdminAnnouncement")
	local AdminFly = ensureEvent("AdminFly")
	local AdminNoclip = ensureEvent("AdminNoclip")

	return {
		Container = container,
		AdminMessage = AdminMessage,
		AdminLogs = AdminLogs,
		AdminChatLogs = AdminChatLogs,
		AdminRanks = AdminRanks,
		AdminCommands = AdminCommands,
		AdminUnrank = AdminUnrank,
		AdminCmdbar = AdminCmdbar,
		AdminRunCommand = AdminRunCommand,
		AdminBanland = AdminBanland,
		AdminUnban = AdminUnban,
		AdminAnnouncement = AdminAnnouncement,
		AdminFly = AdminFly,
		AdminCredits = AdminCredits,
		AdminNoclip = AdminNoclip,
	}
end

function Remotes.validatePayload(remoteName: string, payload: any)
	local validator = Validators[remoteName]
	if typeof(validator) ~= "function" then
		return false, "No validator defined for remote '" .. tostring(remoteName) .. "'"
	end
	local ok, validOrErr, extra = pcall(function()
		return validator(payload)
	end)
	if not ok then
		return false, tostring(validOrErr)
	end
	if validOrErr == true then
		return true
	elseif validOrErr == false then
		return false, extra or "Invalid payload"
	end
	return validOrErr, extra
end

return Remotes