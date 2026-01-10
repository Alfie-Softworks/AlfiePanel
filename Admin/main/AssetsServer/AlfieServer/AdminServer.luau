local AdminServer = {}

local MessagingService = game:GetService("MessagingService")

AdminServer._main = nil

function AdminServer.bind(main)
	AdminServer._main = main

	if main then
		pcall(function()
			MessagingService:SubscribeAsync("GlobalAdminAnnouncement", function(data)
				local payload = data.Data
				local remotes = main.Remotes
				local evt = remotes and remotes.AdminAnnouncement
				if evt and evt:IsA("RemoteEvent") then
					evt:FireAllClients(payload)
				else
					warn("[AdminServer] AdminAnnouncement RemoteEvent missing.")
				end
			end)
		end)
	end

	return AdminServer
end

local function getRemotes(main)
	local m = main or AdminServer._main
	if m and m.Remotes then
		return m.Remotes
	end
	return nil
end

function AdminServer.SendClientMessage(player, messageOrPayload, main)
	local remotes = getRemotes(main)
	local evt = remotes and remotes.AdminMessage
	if not (evt and evt:IsA("RemoteEvent")) then
		warn("[AdminServer] AdminMessage RemoteEvent missing; ensure Main.init provisioned remotes.")
		return false, "AdminMessage missing"
	end

	local payload = messageOrPayload
	if typeof(messageOrPayload) ~= "table" then
		payload = { header = "Info", kind = "info", text = tostring(messageOrPayload) }
	end
	evt:FireClient(player, payload)
	return true
end

return AdminServer