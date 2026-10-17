-- Paste into the Roblox Studio MCP `execute_luau` tool (datamodel_type "Edit").
-- Returns JSON {"<mirror path>": "<lines>:<djb2 hash>"} for every script in the place,
-- using the same paths as roblox_src/. Compare against roblox_src/.sync_manifest.json.
local HttpService = game:GetService("HttpService")
local out = {}
for _, d in ipairs(game:GetDescendants()) do
	if d:IsA("LuaSourceContainer") then
		local ok, src = pcall(function()
			return d.Source
		end)
		if ok then
			local parts = string.split(d:GetFullName(), ".")
			local suffix = d:IsA("LocalScript") and ".client.luau" or (d:IsA("Script") and ".server.luau" or ".luau")
			parts[#parts] = parts[#parts] .. suffix
			local h = 5381
			for i = 1, #src do
				h = (h * 33 + string.byte(src, i)) % 4294967296
			end
			local lines = select(2, src:gsub("\n", "")) + 1
			out[table.concat(parts, "/")] = lines .. ":" .. string.format("%08x", h)
		end
	end
end
return HttpService:JSONEncode(out)
