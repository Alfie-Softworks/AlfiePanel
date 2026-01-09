local UiUtils = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage") -- Where shared assets are stored for all players
local Players = game:GetService("Players") -- Gives access to player instances

-- Looks through a root instance and all its descendants to find the first instance with a given name
-- Returns the instance if found, otherwise nil
local function findDescendant(root: Instance?, name: string)
	if not root then return nil end -- Can't search if root is nil
	if root.Name == name then return root end -- Root itself matches
	for _, d in ipairs(root:GetDescendants()) do -- Go through everything under root
		if d.Name == name then return d end -- Return as soon as we find a match
	end
	return nil -- Nothing found
end

-- Make the function available outside the module
function UiUtils.findDescendant(root: Instance?, name: string)
	return findDescendant(root, name)
end

-- Ensures the player has the AlfiePanel GUI
-- If it's already there, returns it; otherwise searches for a source and clones it
function UiUtils.ensurePanel(rootScript: Instance?)
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") -- Wait until PlayerGui is ready

	-- If the panel already exists for this player, return it immediately
	local existing = playerGui:FindFirstChild("AlfiePanel")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	-- Try to find the original panel in a few possible places
	local source
	if rootScript and rootScript.Parent then
		source = rootScript.Parent:FindFirstChild("AlfiePanel") -- Look next to AdminClient script
	end
	if not source then
		local assets = ReplicatedStorage:FindFirstChild("AlfieAssets")
		if assets then
			source = assets:FindFirstChild("AlfiePanel") -- Look inside AlfieAssets folder
		end
	end
	if not source then
		source = ReplicatedStorage:FindFirstChild("AlfiePanel") -- Last fallback: directly in ReplicatedStorage
	end

	if not (source and source:IsA("ScreenGui")) then
		warn("[UiUtils] AlfiePanel not found") -- Warn if the panel is missing completely
		return nil
	end

	-- Clone the panel so each player has their own independent copy
	local clone = source:Clone()
	clone.ResetOnSpawn = false -- Prevent it from disappearing when the player respawns
	clone.IgnoreGuiInset = true -- Make it cover the whole screen, ignoring Roblox top bar
	clone.Enabled = true -- Make sure it starts enabled
	clone.Parent = playerGui -- Put it in the player's GUI so it’s visible

	-- Function to hide specific sub-elements of the panel
	-- Useful for sections of the UI that should be hidden by default
	local function hide(name: string)
		local inst = findDescendant(clone, name)
		if inst and (inst:IsA("Frame") or inst:IsA("TextLabel") or inst:IsA("ImageLabel")) then
			inst.Visible = false -- Just hide this element
		elseif inst and inst:IsA("ScreenGui") then
			inst.Enabled = false -- If it's a ScreenGui, disable it completely
		end
	end

	-- Hide default panels we don’t want visible right away
	hide("Cmdbar")
	hide("BanlandBG")
	hide("RankBG")
	hide("CommandsBG")
	hide("LoggingBG")
	hide("ChatLoggingBG")
	hide("Notice")
	hide("CreditsBG")

	-- Return the fully prepared panel
	return clone
end

return UiUtils
