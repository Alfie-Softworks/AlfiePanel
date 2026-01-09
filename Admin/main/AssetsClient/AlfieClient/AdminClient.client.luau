-- Roblox service for storing shared assets
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Require utility modules for UI, notifications, logs, ranks, bans, commands, movement, etc.
-- Using WaitForChild ensures the module scripts exist before trying to require them
local UiUtils = require(script:WaitForChild("UiUtils"))
local Notifications = require(script:WaitForChild("Notifications"))
local LogsView = require(script:WaitForChild("LogsView"))
local ChatLogsView = require(script:WaitForChild("ChatLogsView"))
local RanksView = require(script:WaitForChild("RanksView"))
local BanlandView = require(script:WaitForChild("BanlandView"))
local CreditsView = require(script:WaitForChild("CreditsView"))
local CommandsView = require(script:WaitForChild("CommandsView"))
local Cmdbar = require(script:WaitForChild("Cmdbar"))
local Movement = require(script:WaitForChild("Movement"))

-- Function to play a sound by name
-- Looks for a Sound object under this script and plays it if found
local function playSound(name: string)
	local s = script:FindFirstChild(name)
	if s and s:IsA("Sound") then
		s:Play()
	end
end

-- Initialize Notifications module with the playSound function
-- This lets notifications play sounds when triggered
Notifications.init({ playSound = playSound })
-- Connect notifications to RemoteEvents/RemoteFunctions under this script
Notifications.wireRemotes(script)

-- Connect all other UI views to their respective remotes
-- Ensures each view can respond to server events or updates
LogsView.wireRemotes(script)
ChatLogsView.wireRemotes(script)
RanksView.wireRemotes(script)
BanlandView.wireRemotes(script)
CreditsView.wireRemotes(script)
CommandsView.wireRemotes(script)
Cmdbar.wireRemotes(script)

-- Initialize and connect player movement handling
Movement.init() -- Set up movement logic
Movement.wireRemotes() -- Connect movement logic to server events if needed
