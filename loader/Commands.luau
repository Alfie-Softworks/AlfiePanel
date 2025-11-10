return function(main, settings)
	local commands = {}
	table.insert(commands, {
		Name = "test",
		Aliases = {},
		Prefixes = { settings.Prefix },
		Rank = 0,
		Tags = {"fun", "utility"},

		Args = {},
		Function = function(speaker, _)
			print("[Commands] Running 'test' for", speaker and speaker.Name or "?" )

			local evt = main.Remotes and main.Remotes.AdminMessage
			if evt and evt:IsA("RemoteEvent") then
				evt:FireClient(speaker, { header = "Test", kind = "info", text = "Test command executed." })
				print("[Commands] 'test' sent via AdminMessage")
			else
				warn("[Commands] AdminMessage RemoteEvent missing; ensure Remotes.provision ran.")
			end
		end,
	})
	return commands
end