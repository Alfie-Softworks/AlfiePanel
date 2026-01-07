local ServerScriptService = game:GetService("ServerScriptService")

local Settings = require(script:WaitForChild("Settings"))
local CommandsBuilder = require(script:WaitForChild("Commands"))
local MainModule = require(ServerScriptService.AlfieMain)

MainModule.init(Settings, CommandsBuilder)
