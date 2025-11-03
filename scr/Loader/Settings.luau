local Settings = {}

Settings.Prefix = ";"

-- Chat rate-limit configuration (seconds)
Settings.ChatRateLimitSeconds = 0.75
-- Cooldown for showing rate-limit Notice UI (seconds)
Settings.NoticeRateLimitSeconds = 2

Settings.ChatBurstWindowSeconds = 3
Settings.ChatBurstLimitCount = 2

Settings.Ranks = { -- renameable ranks
	{4, "DogeMaster", {0}},
	{4, "DogeAdmin", {0}},
	{3, "Admin", {0}},
	{2, "Moderator", {"", 0}},
	{1, "VIP", {"", 0}},
	{0, "NonAdmin"},
}

Settings.RankDataStoreName = "AlfiePermRanks"
Settings.BanDataStoreName = "AlfieBans"
Settings.BanIndexKey = "BannedUsers"

Settings.BannedUsers = Settings.BannedUsers or {}

return Settings
