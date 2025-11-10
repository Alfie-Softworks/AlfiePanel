local UiUtils = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local function findDescendant(root: Instance?, name: string)
	if not root then return nil end
	if root.Name == name then return root end
	for _, d in ipairs(root:GetDescendants()) do
		if d.Name == name then return d end
	end
	return nil
end

function UiUtils.findDescendant(root: Instance?, name: string)
	return findDescendant(root, name)
end

function UiUtils.ensurePanel(rootScript: Instance?)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local existing = playerGui:FindFirstChild("AlfiePanel")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	local source
	if rootScript and rootScript.Parent then
		source = rootScript.Parent:FindFirstChild("AlfiePanel")
	end
	if not source then
		local assets = ReplicatedStorage:FindFirstChild("AlfieAssets")
		if assets then
			source = assets:FindFirstChild("AlfiePanel")
		end
	end
	if not source then
		source = ReplicatedStorage:FindFirstChild("AlfiePanel")
	end
	if not (source and source:IsA("ScreenGui")) then
		warn("[UiUtils] AlfiePanel ScreenGui not found next to AdminClient or in ReplicatedStorage")
		return nil
	end

	local clone = source:Clone()
	clone.ResetOnSpawn = false
	clone.IgnoreGuiInset = true
	clone.Enabled = true
	clone.Parent = playerGui

	local function hide(name: string)
		local inst = findDescendant(clone, name)
		if inst and inst:IsA("Frame") or (inst and inst:IsA("TextLabel")) or (inst and inst:IsA("ImageLabel")) then
			inst.Visible = false
		elseif inst and inst:IsA("ScreenGui") then
			inst.Enabled = false
		end
	end
	hide("Cmdbar")
	hide("BanlandBG")
	hide("RankBG")
	hide("CommandsBG")
	hide("LoggingBG")
	hide("ChatLoggingBG")
	hide("Notice")
	hide("CreditsBG")

	return clone
end

return UiUtils