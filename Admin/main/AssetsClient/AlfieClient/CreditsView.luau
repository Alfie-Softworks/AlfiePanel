local CreditsView = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ui = require(script.Parent:WaitForChild("UiUtils"))

function CreditsView.showCredits(rootScript, payload)
	local panel = ui.ensurePanel(rootScript)
	if not panel then return end
	local creditsBG = ui.findDescendant(panel, "CreditsBG")
	if not creditsBG then
		warn("[CreditsView] CreditsBG element not found inside AlfiePanel")
		return
	end

	local header = ui.findDescendant(creditsBG, "Header")
	local closeBtn = ui.findDescendant(creditsBG, "CloseButton")
		or ui.findDescendant(creditsBG, "TextButton")
		or (header and ui.findDescendant(header, "CloseButton"))
		or (header and ui.findDescendant(header, "TextButton"))

	local label = ui.findDescendant(creditsBG, "TextLabel")
	local image = ui.findDescendant(creditsBG, "ImageLabel")
	local scrollBG = ui.findDescendant(creditsBG, "ScrollBG") or ui.findDescendant(creditsBG, "ScrollIBG")

	if label and (label:IsA("TextLabel") or label:IsA("TextButton")) and typeof(payload) == "table" then
		if typeof(payload.title) == "string" then
			label.Text = payload.title
		elseif typeof(payload.text) == "string" then
			label.Text = payload.text
		end
	end

	if image and (image:IsA("ImageLabel") or image:IsA("ImageButton")) and typeof(payload) == "table" then
		if typeof(payload.image) == "string" then
			image.Image = payload.image
		end
	end

	local shouldOpen = true
	if typeof(payload) == "table" and payload.open == false then
		shouldOpen = false
	end
	local wasVisible = creditsBG.Visible
	if not wasVisible and not shouldOpen then
		return
	end
	if shouldOpen then
		creditsBG.Visible = true
	end

	if closeBtn and closeBtn:IsA("TextButton") and not closeBtn:GetAttribute("_HookedCreditsClose") then
		closeBtn:SetAttribute("_HookedCreditsClose", true)
		closeBtn.MouseButton1Click:Connect(function()
			creditsBG.Visible = false
		end)
	end
end

function CreditsView.wireRemotes(rootScript)
	local folder = ReplicatedStorage:WaitForChild("AdminEvents")
	local creditsEvt = folder and folder:WaitForChild("AdminCredits")
	if creditsEvt then
		creditsEvt.OnClientEvent:Connect(function(payload)
			CreditsView.showCredits(rootScript, payload)
		end)
	else
		warn("[CreditsView] AdminCredits RemoteEvent missing; did Remotes.provision run?")
	end
end

return CreditsView