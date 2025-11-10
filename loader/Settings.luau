local Settings = {}

Settings.Prefix = ";"

Settings.ChatRateLimitSeconds = 0.75
Settings.NoticeRateLimitSeconds = 2
Settings.ChatBurstWindowSeconds = 3
Settings.ChatBurstLimitCount = 2

Settings.Ranks = {
	{5, "DogeMaster", {0}},
	{4, "DogeAdmin", {0}},
	{3, "Admin", {0}},
	{2, "Moderator", {"", 0}},
	{1, "VIP", {"", 0}},
	{0, "NonAdmin"},
}

Settings.RankDataStoreName = "AlfiePermRanks"
Settings.RankIndexKey = "PermRankUsers"
Settings.BanDataStoreName = "AlfieBans"
Settings.BanIndexKey = "BannedUsers"
Settings.BanIndexRefreshSeconds = 10

Settings.BannedUsers = Settings.BannedUsers or {}
Settings.PermRanksIndex = Settings.PermRanksIndex or {}

return Settings