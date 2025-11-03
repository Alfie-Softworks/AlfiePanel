local ServerScriptService = game:GetService("ServerScriptService")

local Settings = require(script.Settings)
local CommandsBuilder = require(script.Commands)

local MainModule = ServerScriptService:FindFirstChild("AlfieMain")
require(MainModule).init(Settings, CommandsBuilder)
