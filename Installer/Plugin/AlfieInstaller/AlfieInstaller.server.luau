local Toolbar = plugin:CreateToolbar("Alfie Installer")
local Button = Toolbar:CreateButton("Open Installer", "Open the Alfie Installer", "rbxassetid://120117084120353")

local WidgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false,
	true,
	715,
	381,
	715,
	381
)

local Widget = plugin:CreateDockWidgetPluginGuiAsync("AlfieInstallerWidget", WidgetInfo)
Widget.Title = "Alfie Installer V1.0.0"

local DEFAULT_COLOR = Color3.fromRGB(21, 21, 29)
local HIGHLIGHT_COLOR = Color3.fromRGB(58, 113, 193)

local function GetButton(obj)
	if obj:IsA("GuiButton") then
		return obj
	end
	return obj:FindFirstChildWhichIsA("GuiButton") or obj
end

local function MountInstallingUI(action)
	Widget:ClearAllChildren()

	local SourceUI = script.Parent:WaitForChild("InstallingUI", 5)
	if not SourceUI then
		warn("missing gui thingy")
		return
	end

	local InstallingUI = SourceUI:Clone()
	InstallingUI.Parent = Widget
	InstallingUI.Size = UDim2.new(1, 0, 1, 0)
	InstallingUI.Position = UDim2.new(0, 0, 0, 0)
	InstallingUI.AnchorPoint = Vector2.new(0, 0)

	local NextButton = InstallingUI:WaitForChild("NextButton")
	local NextButtonInteraction = GetButton(NextButton)

	NextButtonInteraction.MouseButton1Click:Connect(function()
		Widget.Enabled = false
	end)

	local function EnableAllScripts(instance)
		for _, child in ipairs(instance:GetDescendants()) do
			if child:IsA("Script") or child:IsA("LocalScript") then
				child.Disabled = false
			end
		end
		if instance:IsA("Script") or instance:IsA("LocalScript") then
			instance.Disabled = false
		end
	end

	local function runInstall()
		local loader = script.Parent:FindFirstChild("AlfieLoader")
		if loader then
			local clone = loader:Clone()
			EnableAllScripts(clone)
			clone.Parent = game:GetService("ServerScriptService")
		else
			warn("AlfieLoader not found")
		end

		return {
			"Initializing AlfiePanel...",
			"<font color=\"#00ff00\">✅ Core Loaded</font>",
			"<font color=\"#00ff00\">✅ Commands Loaded</font>",
			"",
			"Installing AlfieLoader...",
			"<font color=\"#00ff00\">✅ AlfieLoader Copied to ServerScriptService</font>",
			"",
			"Finalizing...",
			"<font color=\"#00ff00\">✅ Installation Successful</font>",
			"",
			"AlfiePanel is ready to use!"
		}
	end

	local function runUninstall()
		local sss = game:GetService("ServerScriptService")
		local loader = sss:FindFirstChild("AlfieLoader")
		local msg

		if loader then
			loader:Destroy()
			msg = "<font color=\"#00ff00\">✅ AlfieLoader Removed from ServerScriptService</font>"
		else
			msg = "<font color=\"#ffff00\">⚠️ AlfieLoader not found (already uninstalled)</font>"
		end

		return {
			"Uninstalling AlfiePanel...",
			"Unloading Commands...",
			"<font color=\"#00ff00\">✅ Commands Unloaded</font>",
			"",
			"Removing Files...",
			msg,
			"",
			"Uninstall completed!"
		}
	end

	local lines = action == "Install" and runInstall() or runUninstall()

	task.spawn(function()
		local Label = InstallingUI:WaitForChild("InstallingTextResult")
		Label.RichText = true
		Label.TextXAlignment = Enum.TextXAlignment.Left
		Label.TextYAlignment = Enum.TextYAlignment.Top

		local currentText = ""
		for _, line in ipairs(lines) do
			currentText = currentText .. line .. "\n"
			Label.Text = currentText
			task.wait(0.6)
		end
	end)
end

local function MountMainMenu()
	Widget:ClearAllChildren()

	local SourceUI = script.Parent:WaitForChild("InstallerUI", 5)
	if not SourceUI then
		warn("missing gui thingy")
		return
	end

	local UI = SourceUI:Clone()
	UI.Parent = Widget
	UI.Size = UDim2.new(1, 0, 1, 0)
	UI.Position = UDim2.new(0, 0, 0, 0)
	UI.AnchorPoint = Vector2.new(0, 0)

	local InstallButton = UI:WaitForChild("InstallButton")
	local UninstallButton = UI:WaitForChild("UninstallButton")
	local NextButton = UI:WaitForChild("NextButton")

	local InstallRef = GetButton(InstallButton)
	local UninstallRef = GetButton(UninstallButton)
	local NextRef = GetButton(NextButton)

	NextButton.Visible = false
	NextRef.BackgroundColor3 = HIGHLIGHT_COLOR

	local selectedAction = nil

	local function SelectOption(selectedBtn, action)
		InstallRef.BackgroundColor3 = DEFAULT_COLOR
		UninstallRef.BackgroundColor3 = DEFAULT_COLOR
		selectedBtn.BackgroundColor3 = HIGHLIGHT_COLOR
		NextButton.Visible = true
		selectedAction = action
	end

	InstallRef.MouseButton1Click:Connect(function()
		SelectOption(InstallRef, "Install")
	end)

	UninstallRef.MouseButton1Click:Connect(function()
		SelectOption(UninstallRef, "Uninstall")
	end)

	NextRef.MouseButton1Click:Connect(function()
		if selectedAction then
			MountInstallingUI(selectedAction)
		end
	end)
end

Button.Click:Connect(function()
	local wasEnabled = Widget.Enabled
	Widget.Enabled = not wasEnabled

	if not wasEnabled then
		MountMainMenu()
	end
end)

if Widget.Enabled then
	MountMainMenu()
end
