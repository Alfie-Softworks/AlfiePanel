local Movement = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local _noclipState = { active = false, connDA = nil }
local _flyState = {
	active = false,
	force = nil,
	gyro = nil,
	conn = nil,
	connIB = nil,
	connIE = nil,
	lockType = "PlatformStand",
	noclip = false,
	speed = 50,
}

local function applyNoclipToCharacter(char, active)
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = not active and true or false
		end
	end
	if _noclipState.connDA then _noclipState.connDA:Disconnect() _noclipState.connDA = nil end
	if active then
		_noclipState.connDA = char.DescendantAdded:Connect(function(inst)
			if _noclipState.active and inst:IsA("BasePart") then
				inst.CanCollide = false
			end
		end)
	end
end

function Movement.init()
	player.CharacterAdded:Connect(function(char)
		if _noclipState.active then
			applyNoclipToCharacter(char, true)
		end
	end)
end

local function setCharacterCollide(char, enabled)
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = enabled
		end
	end
end

local function stopFly()
	_flyState.active = false
	if _flyState.conn then _flyState.conn:Disconnect() _flyState.conn = nil end
	if _flyState.connIB then _flyState.connIB:Disconnect() _flyState.connIB = nil end
	if _flyState.connIE then _flyState.connIE:Disconnect() _flyState.connIE = nil end
	if _flyState.force then _flyState.force:Destroy() _flyState.force = nil end
	if _flyState.gyro then _flyState.gyro:Destroy() _flyState.gyro = nil end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		pcall(function() humanoid[_flyState.lockType] = false end)
	end
	if _flyState.noclip and not _noclipState.active then
		setCharacterCollide(player.Character, true)
	end
end

local function startFly(payload)
	stopFly()
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not (hrp and humanoid) then return end

	local hasNoclip = (typeof(payload) == "table" and payload.noclip ~= nil)
	local noclip = hasNoclip and payload.noclip or _noclipState.active
	local speed = (typeof(payload) == "table" and tonumber(payload.speed)) or 50
	local lockType = (typeof(payload) == "table" and tostring(payload.lockType)) or "PlatformStand"

	_flyState.noclip = noclip
	_flyState.speed = speed
	_flyState.lockType = lockType

	local flyForce = Instance.new("BodyPosition")
	flyForce.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	flyForce.Position = hrp.Position + Vector3.new(0, 4, 0)
	flyForce.Name = "AlfieFlyForce"
	flyForce.Parent = hrp

	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.D = 50
	bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyGyro.P = noclip and 2000 or 200
	bodyGyro.Name = "AlfieFlyGyro"
	bodyGyro.CFrame = hrp.CFrame
	bodyGyro.Parent = hrp

	_flyState.force = flyForce
	_flyState.gyro = bodyGyro

	if noclip then
		setCharacterCollide(char, false)
	end

	local tiltMax = 25
	local tiltAmount = 0
	local tiltInc = 1
	local static = 0
	local lastUpdate = tick()
	local lastPosition = hrp.Position

	local movementKeysPressed = {}
	local function addDir(d) movementKeysPressed[d] = true end
	local function removeDir(d) movementKeysPressed[d] = nil end
	local function onInputBegan(io, gpe)
		if gpe then return end
		local kc = io.KeyCode
		if kc == Enum.KeyCode.W then addDir("Forwards")
		elseif kc == Enum.KeyCode.S then addDir("Backwards")
		elseif kc == Enum.KeyCode.A then addDir("Left")
		elseif kc == Enum.KeyCode.D then addDir("Right")
		elseif kc == Enum.KeyCode.Space then addDir("Up")
		elseif kc == Enum.KeyCode.LeftControl then addDir("Down") end
	end
	local function onInputEnded(io, _gpe)
		local kc = io.KeyCode
		if kc == Enum.KeyCode.W then removeDir("Forwards")
		elseif kc == Enum.KeyCode.S then removeDir("Backwards")
		elseif kc == Enum.KeyCode.A then removeDir("Left")
		elseif kc == Enum.KeyCode.D then removeDir("Right")
		elseif kc == Enum.KeyCode.Space then removeDir("Up")
		elseif kc == Enum.KeyCode.LeftControl then removeDir("Down") end
	end
	_flyState.connIB = UserInputService.InputBegan:Connect(onInputBegan)
	_flyState.connIE = UserInputService.InputEnded:Connect(onInputEnded)

	_flyState.active = true
	pcall(function() humanoid[lockType] = true end)

	local function GetNextMovement(deltaTime, speed)
		local nextMove = Vector3.new()
		local directions = {
			Left = Vector3.new(-1, 0, 0);
			Right = Vector3.new(1, 0, 0);
			Forwards = Vector3.new(0, 0, -1);
			Backwards = Vector3.new(0, 0, 1);
			Up = Vector3.new(0, 1, 0);
			Down = Vector3.new(0, -1, 0);
		}
		local isComputer = not UserInputService.TouchEnabled
		if isComputer then
			for k, _ in pairs(movementKeysPressed) do
				local v = directions[k]
				if v then nextMove = nextMove + v end
			end
		else
			local md = humanoid.MoveDirection
			for name, v in pairs(directions) do
				local worldVec = hrp.CFrame:VectorToWorldSpace(v)
				if (worldVec - md).Magnitude <= 1.05 and md ~= Vector3.new() then
					nextMove = nextMove + v
				end
			end
		end
		return CFrame.new(nextMove * speed * deltaTime), nextMove
	end

	_flyState.conn = RunService.RenderStepped:Connect(function()
		if not _flyState.active or not char or not hrp or not humanoid then
			stopFly()
			return
		end
		local now = tick()
		local delta = now - lastUpdate
		lastUpdate = now

		local cam = workspace.CurrentCamera
		local look = (cam and (cam.Focus.p - cam.CFrame.p).Unit) or (hrp and hrp.CFrame.LookVector) or Vector3.new(0, 0, -1)
		local pos = hrp.Position
		local move, directionalVector = GetNextMovement(delta, (_flyState.speed or 50) * 10)
		local targetCFrame = CFrame.new(pos, pos + look) * move

		local targetD = 750 + (_flyState.speed * 0.2)
		if _flyState.noclip then targetD = targetD / 2 end

		if move.p ~= Vector3.new() then
			static = 0
			_flyState.force.D = targetD
			tiltAmount = tiltAmount + tiltInc
			_flyState.force.Position = targetCFrame.p
		else
			static = static + 1
			tiltAmount = 1
			local maxMag = 6
			local mag = (hrp.Position - lastPosition).Magnitude
			if mag > maxMag and static >= 4 then
				_flyState.force.Position = hrp.Position
			end
		end

		if math.abs(tiltAmount) > tiltMax then tiltAmount = tiltMax end
		if _flyState.force.D == targetD then
			local tiltX = tiltAmount * directionalVector.X * -0.5
			local tiltZ = (_flyState.noclip and 0) or tiltAmount * directionalVector.Z
			_flyState.gyro.CFrame = targetCFrame * CFrame.Angles(math.rad(tiltZ), 0, 0)
		end
		lastPosition = hrp.Position

		pcall(function() humanoid[lockType] = true end)
	end)
end

function Movement.wireRemotes()
	local folderFly = ReplicatedStorage:WaitForChild("AdminEvents")
	local flyEvt = folderFly and folderFly:WaitForChild("AdminFly")
	if flyEvt then
		flyEvt.OnClientEvent:Connect(function(payload)
			local active = (typeof(payload) == "table" and payload.active)
			if active then
				startFly(payload)
			else
				stopFly()
			end
		end)
	else
		warn("[Movement] AdminFly RemoteEvent missing; did Remotes.provision run?")
	end

	local noclipEvt = folderFly and folderFly:FindFirstChild("AdminNoclip")
	if noclipEvt then
		noclipEvt.OnClientEvent:Connect(function(payload)
			if typeof(payload) ~= "table" then return end
			local active = (payload.active == true)
			_noclipState.active = active
			local char = player.Character
			applyNoclipToCharacter(char, active)
			if _flyState and _flyState.active then
				_flyState.noclip = active
				if _flyState.gyro then _flyState.gyro.P = active and 2000 or 200 end
			end
		end)
	else
		warn("[Movement] AdminNoclip RemoteEvent missing; did Remotes.provision run?")
	end
end

return Movement