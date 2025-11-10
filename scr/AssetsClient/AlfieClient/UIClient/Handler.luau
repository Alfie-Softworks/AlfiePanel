local Players = game:GetService("Players")
local scrollBG = script.Parent.ScrollBG

local typeTemplate = scrollBG.TemplateType
local userTemplate = scrollBG.TemplateUsername

local data = {
	["Lead Programmers"] = {1623606021, 525753514},
	["Beta Tester"] = {2270131201, 2308561134, 8627996547, 816646413, 1441387531, 6172842853, 6173199333},
}

local rankPower = 5

for typeName, users in pairs(data) do
	local typeClone = typeTemplate:Clone()
	typeClone.RankName.Text = typeName
	typeClone.RankPowerBG.RankPowerText.Text = tostring(rankPower)
	typeClone.Visible = true
	typeClone.Parent = scrollBG

	rankPower -= 1
	if rankPower < 1 then rankPower = 1 end

	for _, userId in ipairs(users) do
		local userName = Players:GetNameFromUserIdAsync(userId)
		local userClone = userTemplate:Clone()
		userClone.UserName.Text = userName
		userClone.Visible = true
		userClone.Parent = scrollBG
		userClone.UserAvatar.Image = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	end
end
