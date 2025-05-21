--// Short Aliases
local rs, ps, hs = game:GetService("ReplicatedStorage"), game:GetService("Players"), game:GetService("HttpService")
local plr, name = ps.LocalPlayer, ps.LocalPlayer.DisplayName
local buyEv = rs:WaitForChild("GameEvents"):WaitForChild("BuyEventShopStock")
local req = (syn and syn.request) or http_request or request

--// Config
local wU, uID = _G.webhookUrl or "", _G.userId or ""
local bl = {}; for _, v in ipairs(_G.blacklist or {}) do bl[v] = true end

--// Prevent Double Execution
if _G._connectionTable then
	for _, c in pairs(_G._connectionTable) do pcall(function() c:Disconnect() end) end
end
_G._connectionTable, _G._sessionID = {}, tick() .. math.random(1e6)
_G._totalBought, _G._bloodTriggered, _G._nightTriggered = {}, false, false

local messageId = nil

--// Embed Builders
local function createFields()
	local itemNames, itemCounts = "", ""
	for name, count in pairs(_G._totalBought) do
		itemNames ..= name .. "\n"
		itemCounts ..= "× " .. count .. "\n"
	end
	return {
		{ name = "**Item**", value = itemNames == "" and "None" or itemNames, inline = true },
		{ name = "**Count**", value = itemCounts == "" and "0" or itemCounts, inline = true }
	}
end

local function createEmbed()
	return {
		title = "📦 Event Shop Tracker",
		description = "Purchases during the Event",
		color = 0x7289DA,
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		footer = { text = name },
		fields = createFields()
	}
end

local function sendInitialEmbed()
	if wU == "" or not req then return end
	local result = req({
		Url = wU .. "?wait=true",
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = hs:JSONEncode({ embeds = { createEmbed() } })
	})
	local ok, parsed = pcall(hs.JSONDecode, hs, result and result.Body or "")
	if ok and parsed and parsed.id then
		messageId = parsed.id
	end
end

local function updateEmbed()
	if wU == "" or not messageId then return end
	local baseUrl = wU:match("(.+)%?wait=true") or wU
	local editUrl = baseUrl .. "/messages/" .. messageId
	req({
		Url = editUrl,
		Method = "PATCH",
		Headers = { ["Content-Type"] = "application/json" },
		Body = hs:JSONEncode({ embeds = { createEmbed() } })
	})
end

local function wh(title, fields, color)
	if not req or wU == "" then return end
	local body = {
		embeds = {{
			title = title,
			color = color or 0x00FF00,
			fields = fields,
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
		}}
	}
	pcall(function()
		req({
			Url = wU,
			Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = hs:JSONEncode(body)
		})
	end)
end

--// New slick embed for events
local function whEvent(title, description, color)
	if not req or wU == "" then return end
	local body = {
		embeds = {{
			title = title,
			description = description,
			color = color or 0x00FF00,
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
			footer = { text = name }
		}}
	}
	pcall(function()
		req({
			Url = wU,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = hs:JSONEncode(body)
		})
	end)
end

local DataService = require(rs.Modules:WaitForChild("DataService"))

--// Purchase Function
local function buy()
	local stocks = DataService:GetData().EventShopStock.Stocks
	for name, _ in pairs(stocks) do
		if not bl[name] then
			buyEv:FireServer(name)
			_G._totalBought[name] = (_G._totalBought[name] or 0) + 1
			updateEmbed()
			task.wait(0.05)
		end
	end
end

--// Event Hooks
local function onNight()
	if _G._nightTriggered then return end
	_G._nightTriggered = true
	whEvent(
		"🌙 Night Event Started",
		"Triggered by: **" .. name .. "**",
		0x0000FF
	)
end

local function onBlood()
	if _G._bloodTriggered then return end
	_G._bloodTriggered = true
	whEvent(
		"🩸 BloodMoon Event Started",
		"Triggered by: **" .. name .. "**\n\nStarting purchases...",
		0xFF0000
	)

	for i = 1, (_G.purchaseCount or 20) do
		buy()
	end
end

--// Connect to attribute changes
table.insert(_G._connectionTable, workspace:GetAttributeChangedSignal("NightEvent"):Connect(function()
	if workspace:GetAttribute("NightEvent") then onNight() end
end))

table.insert(_G._connectionTable, workspace:GetAttributeChangedSignal("BloodMoonEvent"):Connect(function()
	if workspace:GetAttribute("BloodMoonEvent") then onBlood() end
end))

--// Initial checks
if workspace:GetAttribute("NightEvent") then onNight() end
if workspace:GetAttribute("BloodMoonEvent") then onBlood() end

--// Initial webhook logs
sendInitialEmbed()
wh("Script Started", {
	{ name = "User", value = name },
	{ name = "Session", value = _G._sessionID }
}, 0xFFFFFF)
