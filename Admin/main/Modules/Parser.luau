local Parser = {}

function Parser.parseWithPrefix(text, prefix)
	text = tostring(text or "")
	prefix = tostring(prefix or ";")
	if string.sub(text, 1, #prefix) ~= prefix then
		return nil, {}
	end
	local body = string.sub(text, #prefix + 1)
	body = (string.gsub(body, "^%s*(.-)%s*$", "%1"))

	if body == "" then
		return nil, {}
	end

	local tokens = {}
	local i = 1
	while i <= #body do
		local c = string.sub(body, i, i)
		if c == '"' then
			local j = i + 1
			while j <= #body and string.sub(body, j, j) ~= '"' do
				j += 1
			end
			table.insert(tokens, string.sub(body, i + 1, j - 1))
			i = j + 1
		else
			local j = i
			while j <= #body and not string.match(string.sub(body, j, j), "%s") do
				j += 1
			end
			table.insert(tokens, string.sub(body, i, j - 1))
			i = j + 1
		end
		while i <= #body and string.match(string.sub(body, i, i), "%s") do
			i += 1
		end
	end

	local name = tokens[1]
	table.remove(tokens, 1)
	return name, tokens
end

return Parser