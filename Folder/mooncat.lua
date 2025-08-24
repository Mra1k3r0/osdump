--// GaG 
--// Open Sauce - Complete Script with Auto Cook & Fixed Auto Rejoin
if game.PlaceId ~= 126884695634066 then return end

--// Prevent script multiplication
if getgenv().scriptRunning then 
    print("Script already running, preventing duplicate...")
    return 
end
getgenv().scriptRunning = true

--// grant grant grant
if getgenv().uiUpd then
    getgenv().uiUpd:Unload()
end

--// Library and Config
local repo = "https://raw.githubusercontent.com/Mra1k3r0/saikidesu_data/refs/heads/main/"
local repo2 = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo2 .. "addons/ThemeManager.lua"))()
local http = game:GetService("HttpService")
local folder, path = "grangrant", "grant/config.json"

--// Defaults
local defaults = {
    AutoIdle = false,
    AutoIdleToggle = false,
    selectedPets = {},
    PetKgInput = 0,
    autoSellEnabled = false,
    idleDrop = {},
    idleInput = 80,
    autoRejoinEnabled = false,
    rejoinDelay = 15,
    maxRetries = 5,
    serverHopEnabled = false,
    forceReturnToOriginal = true,
    smartServerDetection = true,
    waitForServerSpace = true,
    autoEquipEnabled = false,
    equipCount = 7,
    equipThreshold = 80,
    unequipTimer = 40,
    savedDropPosition = nil,
    usePositionDrop = false,
    useFastEquip = true,
    equipRetries = 3,
    equipDelay = 0,
    autoCookEnabled = false,
    cookIngredient1 = "",
    cookIngredient2 = "",
    cookIngredient3 = "",
    cookIngredient4 = "",
    cookIngredient5 = "",
    mutationsOnly = false,
    cookCooldownMinutes = 7, -- Default 7 minute cooldown
}

--// Save/Load Functions
local function save()
    if not isfolder(folder) then
        makefolder(folder)
    end
    writefile(path, http:JSONEncode(config))
end

--// Load Config
local config = isfile(path) and http:JSONDecode(readfile(path)) or {}

--// Apply Config
for k, v in pairs(defaults) do
    config[k] = config[k] == nil and v or config[k]
    getgenv()[k] = config[k]
end

--// Runtime Reset
getgenv().AutoIdle = false
getgenv().AutoIdleToggle = config.AutoIdleToggle or false

--// Store Config
getgenv().config = config

--// Library
Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
    Title = "Grant",
    Footer = "v2.0 - Auto Cook Cooldown Added",
    MobileButtonsSide = "Left",
    NotifySide = "Right",
    Center = true,
    Size = Library.IsMobile and UDim2.fromOffset(450, 300) or UDim2.fromOffset(650, 500),
    ShowCustomCursor = false,
})

getgenv().uiUpd = Library

--// Tabs
local Tabs = {
    Changelog = Window:AddTab("Changelog", "file-clock"),
    Misc = Window:AddTab("Misc", "notebook-pen"),
    Vuln = Window:AddTab("Vuln", "focus"),
    ["Settings"] = Window:AddTab("Settings", "settings"),
}

--// uiActive
local uiActive = true

--// Services & Setup
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- Handle character respawning
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    backpack = player:WaitForChild("Backpack")
end)

--// Services & Modules
local GetPetCooldown = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("GetPetCooldown")
local IdleHandler = require(ReplicatedStorage.Modules.PetServices.PetActionUserInterfaceService.PetActionsHandlers.Idle)
local ActivePetsService = require(ReplicatedStorage.Modules.PetServices.ActivePetsService)
local PetsService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetsService")
local CookingPotService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("CookingPotService_RE")

--// Get Active Pet Types Function
local function getActivePetTypes()
    local petTypes = {}
    local seen = {}
    
    for _, petPart in pairs(workspace.PetsPhysical:GetChildren()) do
        if petPart:IsA("BasePart") and petPart.Name == "PetMover" then
            local uuid = petPart:GetAttribute("UUID")
            local owner = petPart:GetAttribute("OWNER")
            
            if owner == player.Name and uuid then
                local petData = ActivePetsService:GetPetData(owner, uuid)
                if petData and petData.PetType and not seen[petData.PetType] then
                    seen[petData.PetType] = true
                    table.insert(petTypes, petData.PetType)
                end
            end
        end
    end
    
    -- Also check for Moon Cat using the old method
    for _, v in ipairs(workspace.PetsPhysical:GetChildren()) do
        if v:IsA("BasePart") and v.Name == "PetMover" then
            local model = v:FindFirstChild(v:GetAttribute("UUID"))
            if model and model:IsA("Model") and model:GetAttribute("CurrentSkin") == "Moon Cat" then
                if not seen["Moon Cat"] then
                    seen["Moon Cat"] = true
                    table.insert(petTypes, "Moon Cat")
                end
            end
        end
    end
    
    table.sort(petTypes)
    return petTypes
end

--// Auto Cook Functions with Enhanced Cooldown
local lastCookTime = 0
local nextCookTime = 0

local function formatTimeRemaining(seconds)
    if seconds <= 0 then return "Ready" end
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    if minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    else
        return string.format("%ds", secs)
    end
end

local function findFruitInInventory(fruitName, mutationsOnly)
    if not fruitName or fruitName == "" then return nil end
    
    -- List of cooked foods to ignore
    local cookedFoods = {
        "salad", "sandwich", "pie", "waffle", "hotdog", "ice cream", "donut", 
        "pizza", "sushi", "cake", "burger", "smoothie", "candy apple", 
        "sweet tea", "porridge", "spaghetti", "corndog", "soup"
    }
    
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local toolName = tool.Name:lower()
            local searchName = fruitName:lower()
            
            -- Skip if this doesn't have KG (not a fruit/food item)
            if not toolName:find("kg") then
                continue
            end
            
            -- Skip if this contains "seed" (it's a seed, not fruit)
            if toolName:find("seed") then
                continue
            end
            
            -- Skip if this is a cooked food
            local isCookedFood = false
            for _, cookedFood in ipairs(cookedFoods) do
                if toolName:find(cookedFood) then
                    isCookedFood = true
                    break
                end
            end
            
            if not isCookedFood then
                -- Check if the tool contains the fruit name
                if toolName:find(searchName) then
                    -- If mutations only is enabled, check for mutations (brackets at start)
                    if mutationsOnly then
                        if toolName:match("^%[.-%]") then -- Has mutations at start
                            return tool
                        end
                    else
                        return tool
                    end
                end
            end
        end
    end
    return nil
end

local function equipFruit(fruit)
    if not fruit then return false end
    
    pcall(function()
        fruit.Parent = character
        task.wait(0.2)
        if humanoid then
            humanoid:EquipTool(fruit)
            task.wait(0.3)
        end
    end)
    
    return fruit.Parent == character
end

local function submitFruit()
    local args = {
        "SubmitHeldPlant",
        "OLD_KITCHEN_COOKING_EVENT"
    }
    CookingPotService:FireServer(unpack(args))
    task.wait(0.5)
end

local function cookBest()
    local args = {
        "CookBest",
        "OLD_KITCHEN_COOKING_EVENT"
    }
    CookingPotService:FireServer(unpack(args))
    task.wait(1)
end

local function performAutoCook()
    if not getgenv().autoCookEnabled then return end
    
    local ingredients = {
        getgenv().cookIngredient1,
        getgenv().cookIngredient2,
        getgenv().cookIngredient3,
        getgenv().cookIngredient4,
        getgenv().cookIngredient5
    }
    
    local submitted = 0
    local mutationsOnly = getgenv().mutationsOnly or false
    
    -- Submit ALL ingredients first before cooking
    for i, ingredient in ipairs(ingredients) do
        if ingredient and ingredient ~= "" then
            local fruit = findFruitInInventory(ingredient, mutationsOnly)
            if fruit then
                if equipFruit(fruit) then
                    submitFruit()
                    submitted = submitted + 1
                    print("Auto Cook: Submitted " .. fruit.Name)
                else
                    print("Auto Cook: Failed to equip " .. fruit.Name)
                end
            else
                local mutationText = mutationsOnly and " (mutations only)" or ""
                print("Auto Cook: " .. ingredient .. " not found" .. mutationText)
            end
        end
    end
    
    -- Only cook if we submitted at least 1 ingredient
    if submitted > 0 then
        cookBest()
        
        -- Set the cooldown timer AFTER cooking
        local cooldownMinutes = getgenv().cookCooldownMinutes or 7
        local cooldownSeconds = cooldownMinutes * 60
        lastCookTime = tick()
        nextCookTime = tick() + cooldownSeconds
        
        Library:Notify({ 
            Title = "Auto Cook Complete", 
            Description = "Cooked with " .. submitted .. " ingredients", 
            Time = 3 
        })
        print("Auto Cook: Completed with " .. submitted .. " ingredients. Cooldown: " .. cooldownMinutes .. " minutes")
        
        -- Wait for cooking to complete before next cycle
        task.wait(3)
    end
end

--// Changelog
local CGL = Tabs.Changelog:AddFullGroupbox("Updates", "file-clock")

CGL:AddLabel("v2.0 - Auto Cook Cooldown", true)
CGL:AddLabel("- Added 7 minute cooldown after cooking")
CGL:AddLabel("- Prevents cooking spam and server overload")
CGL:AddLabel("- Shows remaining cooldown time")
CGL:AddDivider()

CGL:AddLabel("v1.9 - Auto Cook & Fixed Rejoin", true)
CGL:AddLabel("- Auto cook runs continuously when enabled")
CGL:AddLabel("- Fixed ingredient search to ignore cooked foods")
CGL:AddLabel("- Fixed auto rejoin to retry same server")
CGL:AddLabel("- Server hop only when enabled")
CGL:AddLabel("- Keeps trying full servers until success")

--// Pet Functions
local function getUniquePetNames()
    local names = {}
    local seen = {}
    
    for _, container in ipairs({ backpack, character }) do
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") and tool.Name:find("Age") then
                local base = tool.Name:match("^(.-) %[%d") or tool.Name
                if not seen[base] then
                    seen[base] = true
                    table.insert(names, base)
                end
            end
        end
    end
    
    table.sort(names)
    return names
end

--// Misc Tab
local MSC = Tabs.Misc:AddLeftGroupbox("Sell Pets")

local petDropdown = MSC:AddDropdown("SellPet", {
    Values = getUniquePetNames(),
    Default = {},
    Multi = true,
    Text = "Select Pets",
    Callback = function(selected)
        getgenv().selectedPets = selected
        config.selectedPets = selected
        save()
    end,
})

MSC:AddInput("PetKgInput", {
    Text = "Min Weight (KG)",
    Default = tostring(getgenv().PetKgInput or 0),
    Numeric = true,
    Finished = true,
    Placeholder = "0",
    Callback = function(value)
        getgenv().PetKgInput = tonumber(value) or 0
        config.PetKgInput = getgenv().PetKgInput
        save()
    end,
})

MSC:AddToggle("SellPetToggle", {
    Text = "Auto Sell",
    Default = getgenv().autoSellEnabled or false,
    Callback = function(val)
        getgenv().autoSellEnabled = val
        config.autoSellEnabled = val
        save()
    end,
})

--// Auto Sell Logic
task.spawn(function()
    while uiActive do
        task.wait(1)
        
        if not getgenv().autoSellEnabled or not getgenv().selectedPets then
            continue
        end
        
        local weightThreshold = tonumber(getgenv().PetKgInput) or 0
        if weightThreshold <= 0 then
            continue
        end
        
        for petName, isSelected in pairs(getgenv().selectedPets) do
            if isSelected then
                for _, tool in ipairs(backpack:GetChildren()) do
                    if tool:IsA("Tool") and tool.Name:find("^" .. petName) then
                        local weightStr = tool.Name:match("%[(%d+%.?%d*) KG%]")
                        local weight = tonumber(weightStr or "0")
                        
                        if weight and weight >= weightThreshold then
                            pcall(function()
                                tool.Parent = character
                                humanoid:EquipTool(tool)
                                task.wait(0.1)
                                ReplicatedStorage.GameEvents.SellPet_RE:FireServer(tool)
                                task.wait(0.5)
                            end)
                        end
                    end
                end
            end
        end
    end
end)

--// Auto Rejoin Section
local MSC2 = Tabs.Misc:AddRightGroupbox("Auto Rejoin")

MSC2:AddToggle("AutoRejoinToggle", {
    Text = "Auto Rejoin",
    Default = getgenv().autoRejoinEnabled or false,
    Callback = function(val)
        getgenv().autoRejoinEnabled = val
        config.autoRejoinEnabled = val
        save()
    end
})

MSC2:AddInput("RejoinDelay", {
    Text = "Delay (sec)",
    Default = tostring(getgenv().rejoinDelay or 15),
    Numeric = true,
    Finished = true,
    Placeholder = "15",
    Callback = function(value)
        local delay = tonumber(value) or 15
        if delay < 5 then delay = 5 end
        getgenv().rejoinDelay = delay
        config.rejoinDelay = delay
        save()
    end
})

MSC2:AddInput("MaxRetries", {
    Text = "Max Retries",
    Default = tostring(getgenv().maxRetries or 5),
    Numeric = true,
    Finished = true,
    Placeholder = "5",
    Callback = function(value)
        local retries = tonumber(value) or 5
        if retries < 1 then retries = 1 end
        getgenv().maxRetries = retries
        config.maxRetries = retries
        save()
    end
})

MSC2:AddToggle("ServerHopToggle", {
    Text = "Server Hop",
    Default = getgenv().serverHopEnabled or false,
    Callback = function(val)
        getgenv().serverHopEnabled = val
        config.serverHopEnabled = val
        save()
    end
})

MSC2:AddToggle("ForceReturnToggle", {
    Text = "Return After Hop",
    Default = getgenv().forceReturnToOriginal or true,
    Callback = function(val)
        getgenv().forceReturnToOriginal = val
        config.forceReturnToOriginal = val
        save()
    end
})

MSC2:AddToggle("SmartServerDetection", {
    Text = "Log Server Status",
    Default = getgenv().smartServerDetection or true,
    Callback = function(val)
        getgenv().smartServerDetection = val
        config.smartServerDetection = val
        save()
    end
})

MSC2:AddToggle("PersistentRejoin", {
    Text = "Persistent Rejoin",
    Default = getgenv().persistentRejoin or true,
    Callback = function(val)
        getgenv().persistentRejoin = val
        config.persistentRejoin = val
        save()
    end
})

MSC2:AddButton("ForceRejoin", {
    Text = "Force Rejoin Now",
    Func = function()
        Library:Notify({
            Title = "Force Rejoin",
            Description = "Rejoining immediately...",
            Time = 2,
        })
        rejoinSameServer(1)
    end,
    DoubleClick = false
})

--// Pet List Updater
task.spawn(function()
    while uiActive do
        task.wait(5)
        local updatedList = getUniquePetNames()
        local preserved = {}
        
        if getgenv().selectedPets then
            for _, name in ipairs(updatedList) do
                if getgenv().selectedPets[name] then
                    preserved[name] = true
                end
            end
        end
        
        if petDropdown then
            petDropdown:SetValues(updatedList)
            petDropdown:SetValue(preserved)
        end
        
        getgenv().selectedPets = preserved
    end
end)

--// Auto Rejoin Logic (Fixed to retry same server)
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local rejoinAttempts = 0
local currentJobId = game.JobId -- This is the SAME server we want to rejoin

--// Queue script for persistence across teleports
local function queueRejoinScript()
    local queueFunction = (syn and syn.queue_on_teleport)
        or queue_on_teleport
        or (fluxus and fluxus.queue_on_teleport)
        or function() end
    local queueScript = string.format(
        [[
        if getgenv().scriptAlreadyQueued then return end
        getgenv().scriptAlreadyQueued = true
        task.wait(5)
        if game.PlaceId == %d then
            loadstring(game:HttpGet("%s"))()
        end
    ]],
        game.PlaceId,
        "https://raw.githubusercontent.com/Mra1k3r0/osdump/refs/heads/main/Folder/mooncat.lua"
    )
    queueFunction(queueScript)
end

--// Function to check server space
local function checkOriginalServerSpace()
    if not getgenv().smartServerDetection then
        return
    end
    
    pcall(function()
        local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        if not req then return end
        
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
        local response = req({Url = url})
        
        if response.StatusCode ~= 200 then return end
        
        local data = HttpService:JSONDecode(response.Body)
        if not data or not data.data then return end
        
        for _, server in pairs(data.data) do
            if server.id == currentJobId then
                local playing = tonumber(server.playing) or 0
                local maxPlayers = tonumber(server.maxPlayers) or 0
                Library:Notify({
                    Title = "Server Status",
                    Description = string.format("Target server: %d/%d players", playing, maxPlayers),
                    Time = 3,
                })
                break
            end
        end
    end)
end

--// Function to rejoin the SAME server (will keep trying even if full)
function rejoinSameServer(retryCount)
    retryCount = retryCount or 1
    local maxRetries = getgenv().maxRetries or 5
    local retryDelay = math.max(getgenv().rejoinDelay or 15, 5)
    
    Library:Notify({
        Title = "Rejoining Same Server",
        Description = "Attempt " .. retryCount .. "/" .. maxRetries .. "...",
        Time = 3,
    })
    
    if retryCount == 1 then
        checkOriginalServerSpace()
    end
    
    queueRejoinScript()
    
    task.wait(retryDelay)
    
    local success = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, currentJobId, player)
    end)
    
    if not success then
        if retryCount < maxRetries then
            Library:Notify({
                Title = "Rejoin Failed",
                Description = "Retrying... (" .. (retryCount + 1) .. "/" .. maxRetries .. ")",
                Time = 3,
            })
            rejoinSameServer(retryCount + 1)
        else
            -- After max retries, decide what to do
            if getgenv().serverHopEnabled then
                Library:Notify({
                    Title = "Max Retries Reached",
                    Description = "Server hopping...",
                    Time = 3,
                })
                performServerHop()
            else
                Library:Notify({
                    Title = "Max Retries Reached",
                    Description = "Will keep trying same server...",
                    Time = 3,
                })
                task.wait(retryDelay * 2) 
                rejoinSameServer(1) 
            end
        end
    end
end

--// Server search function
local function findServers(cursor, attempts)
    attempts = attempts or 1
    if attempts > 5 then return {} end
    
    local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if not req then return {} end
    
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
    if cursor and cursor ~= "" then
        url = url .. "&cursor=" .. cursor
    end
    
    local success, response = pcall(function() return req({Url = url}) end)
    if not success or response.StatusCode ~= 200 then return {} end
    
    local parseSuccess, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
    if not parseSuccess or not data or not data.data then return {} end
    
    local servers = {}
    for _, server in pairs(data.data) do
        if type(server) == "table" and server.id and server.playing and server.maxPlayers and
           server.playing < server.maxPlayers and server.id ~= currentJobId then
            table.insert(servers, {
                id = server.id,
                playing = tonumber(server.playing),
                fullness = tonumber(server.playing) / tonumber(server.maxPlayers)
            })
        end
    end
    
    if data.nextPageCursor and #servers < 20 then
        for _, s in ipairs(findServers(data.nextPageCursor, attempts + 1)) do
            table.insert(servers, s)
        end
    end
    
    return servers
end

--// Function to server hop (only when enabled)
function performServerHop()
    local servers = findServers()
    if #servers > 0 then
        table.sort(servers, function(a, b) return a.fullness < b.fullness end)
        Library:Notify({ Title = "Server Hopping", Description = "Found " .. #servers .. " servers, joining best one...", Time = 2 })
        
        local success = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[1].id, player)
        end)
        
        if success and getgenv().forceReturnToOriginal then
            local queueFunction = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport) or function() end
            local returnScript = string.format([[
                if getgenv().returnScriptQueued then return end
                getgenv().returnScriptQueued = true
                task.wait(60)
                if game.PlaceId == %d then
                    pcall(function() 
                        game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game:GetService("Players").LocalPlayer) 
                    end)
                    task.wait(5)
                    loadstring(game:HttpGet("%s"))()
                end
            ]], game.PlaceId, game.PlaceId, currentJobId, "https://raw.githubusercontent.com/Mra1k3r0/osdump/refs/heads/main/Folder/mooncat.lua")
            queueFunction(returnScript)
        end
    else
        Library:Notify({ Title = "No Servers Found", Description = "Falling back to same server...", Time = 2 })
        rejoinSameServer(1)
    end
end

--// Main rejoin function
function performRejoin()
    if not getgenv().autoRejoinEnabled then return end
    rejoinAttempts = rejoinAttempts + 1
    rejoinSameServer(1)
end

--// Handle teleport failures (including server full)
TeleportService.TeleportInitFailed:Connect(function(plr, teleportResult)
    if plr == player and getgenv().autoRejoinEnabled then
        if teleportResult == Enum.TeleportResult.GameFull then
            Library:Notify({ 
                Title = "Server Full", 
                Description = "Target server is full. Will keep trying...", 
                Time = 3 
            })
        else
            Library:Notify({ 
                Title = "Teleport Failed", 
                Description = "Reason: " .. tostring(teleportResult.Name), 
                Time = 3 
            })
        end
        performRejoin()
    end
end)

--// Detect kick/disconnect messages
local function setupKickDetection()
    local function checkAndDismissKickGui()
        for _, gui in pairs(CoreGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                for _, frame in pairs(gui:GetDescendants()) do
                    if frame:IsA("TextLabel") then
                        local text = frame.Text and frame.Text:lower() or ""
                        if text:find("kicked") or text:find("disconnected") or text:find("lost connection") or 
                           text:find("reconnect") or text:find("server") or text:find("closing") or text:find("leave") then
                            if getgenv().autoRejoinEnabled then
                                Library:Notify({ Title = "Disconnect Detected", Description = "Auto rejoining same server...", Time = 2 })
                                pcall(function() gui:Destroy() end)
                                performRejoin()
                                return true
                            end
                        end
                    end
                end
            end
        end
        return false
    end
    
    CoreGui.ChildAdded:Connect(function(child)
        if child:IsA("ScreenGui") then
            task.wait(0.5)
            checkAndDismissKickGui()
        end
    end)
    
    task.spawn(function()
        while uiActive do
            if getgenv().autoRejoinEnabled then
                checkAndDismissKickGui()
            end
            task.wait(1)
        end
    end)
end

--// Handle game shutdown/removal
game:GetService("Players").PlayerRemoving:Connect(function(plr)
    if plr == player and getgenv().autoRejoinEnabled then
        performRejoin()
    end
end)

--// Anti-AFK
task.spawn(function()
    local VirtualUser = game:GetService("VirtualUser")
    player.Idled:Connect(function()
        if getgenv().autoRejoinEnabled then
            VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            Library:Notify({ Title = "Anti-AFK", Description = "Prevented idle kick", Time = 1 })
        end
    end)
end)

-- Initialize detection
setupKickDetection()

-- Reset attempts on successful connection
task.spawn(function()
    while uiActive do
        task.wait(60)
        if player.Parent and game:GetService("RunService").Heartbeat and rejoinAttempts > 0 then
            rejoinAttempts = 0
            Library:Notify({ Title = "Auto Rejoin", Description = "Connection stable - attempts reset", Time = 2 })
        end
    end
end)

--// Vuln Tab
local VLN = Tabs.Vuln:AddLeftGroupbox("Idle")

local idleDropdown = VLN:AddDropdown("IdleDropdown", {
    Values = getActivePetTypes(),
    Default = getgenv().idleDrop or {},
    Multi = true,
    Text = "Select Pet",
    Callback = function(selected)
        getgenv().idleDrop = selected
        config.idleDrop = selected
        save()
    end,
})

VLN:AddButton("RefreshPets", {
    Text = "Refresh",
    Func = function()
        local activePets = getActivePetTypes()
        local preserved = {}
        
        if getgenv().idleDrop then
            for _, petType in ipairs(activePets) do
                if getgenv().idleDrop[petType] then
                    preserved[petType] = true
                end
            end
        end
        
        if idleDropdown then
            idleDropdown:SetValues(activePets)
            idleDropdown:SetValue(preserved)
        end
        
        getgenv().idleDrop = preserved
        
        Library:Notify({
            Title = "Refreshed",
            Description = "Found " .. #activePets .. " pets",
            Time = 2,
        })
    end,
    DoubleClick = false,
})

VLN:AddInput("IdleInput", {
    Text = "Idle Time",
    Default = tostring(getgenv().idleInput or 80),
    Numeric = true,
    Finished = true,
    Placeholder = "80",
    Callback = function(value)
        getgenv().idleInput = tonumber(value) or 80
        config.idleInput = getgenv().idleInput
        save()
    end,
})

if getgenv().idleDrop and next(getgenv().idleDrop) then
    Library.Options.IdleDropdown:SetValue(getgenv().idleDrop)
end

VLN:AddToggle("MoonCat", {
    Text = "Auto Idle",
    Default = getgenv().AutoIdleToggle,
    Callback = function(val)
        getgenv().AutoIdleToggle = val
        config.AutoIdleToggle = val
        save()
        if not val then
            getgenv().AutoIdle = false
        end
    end,
})

VLN:AddDivider()

VLN:AddButton("ShovelSprinkler", {
    Text = "Remove Sprinklers",
    Func = function()
        local DeleteObject = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DeleteObject")
        
        local function EquipShovel()
            local equippedTool = character:FindFirstChildWhichIsA("Tool")
            if equippedTool and equippedTool.Name == "Shovel [Destroy Plants]" then
                return true
            end
            local shovel = character:FindFirstChild("Shovel [Destroy Plants]")
                or backpack:FindFirstChild("Shovel [Destroy Plants]")
            if shovel then
                shovel.Parent = character
                humanoid:EquipTool(shovel)
                return true
            end
            return false
        end
        
        local function UnequipShovel()
            local equippedTool = character:FindFirstChildWhichIsA("Tool")
            if equippedTool and equippedTool.Name == "Shovel [Destroy Plants]" then
                equippedTool.Parent = backpack
            end
        end
        
        local garden
        for _, plot in pairs(workspace.Farm:GetChildren()) do
            if
                plot:FindFirstChild("Important")
                and plot.Important:FindFirstChild("Data")
                and plot.Important.Data.Owner.Value == player.Name
            then
                garden = plot
                break
            end
        end
        if not garden then
            return
        end
        
        if not EquipShovel() then
            return
        end
        
        local objectsFolder = garden.Important:FindFirstChild("Objects_Physical")
        if not objectsFolder then
            return
        end
        
        local sprinklersRemoved = 0
        for _, model in ipairs(objectsFolder:GetChildren()) do
            if model:IsA("Model") and string.find(model.Name, "Sprinkler") then
                DeleteObject:FireServer(model)
                sprinklersRemoved = sprinklersRemoved + 1
                task.wait(0.2)
            end
        end
        
        UnequipShovel()
        
        Library:Notify({
            Title = "Removed",
            Description = sprinklersRemoved .. " sprinklers",
            Time = 2,
        })
    end,
    DoubleClick = false,
})

--// Auto Cook Section with Enhanced Cooldown UI
local VLN_COOK = Tabs.Vuln:AddLeftGroupbox("Auto Cook")
VLN_COOK:AddToggle("AutoCookToggle", { 
    Text = "Auto Cook", 
    Default = getgenv().autoCookEnabled or false, 
    Callback = function(val) 
        getgenv().autoCookEnabled = val
        config.autoCookEnabled = val
        save()
        if val then
            Library:Notify({ Title = "Auto Cook", Description = "Enabled", Time = 2 })
        else
            Library:Notify({ Title = "Auto Cook", Description = "Disabled", Time = 2 })
        end
    end 
})

VLN_COOK:AddToggle("MutationsOnly", { 
    Text = "Mutations Only", 
    Default = getgenv().mutationsOnly or false, 
    Callback = function(val) 
        getgenv().mutationsOnly = val
        config.mutationsOnly = val
        save()
    end 
})

VLN_COOK:AddDivider()
VLN_COOK:AddInput("CookIngredient1", { 
    Text = "Ingredient 1", 
    Default = getgenv().cookIngredient1 or "", 
    Finished = true, 
    Placeholder = "e.g. serenity", 
    Callback = function(value) 
        getgenv().cookIngredient1 = value
        config.cookIngredient1 = value
        save()
    end 
})

VLN_COOK:AddInput("CookIngredient2", { 
    Text = "Ingredient 2", 
    Default = getgenv().cookIngredient2 or "", 
    Finished = true, 
    Placeholder = "e.g. apple", 
    Callback = function(value) 
        getgenv().cookIngredient2 = value
        config.cookIngredient2 = value
        save()
    end 
})

VLN_COOK:AddInput("CookIngredient3", { 
    Text = "Ingredient 3", 
    Default = getgenv().cookIngredient3 or "", 
    Finished = true, 
    Placeholder = "e.g. banana", 
    Callback = function(value) 
        getgenv().cookIngredient3 = value
        config.cookIngredient3 = value
        save()
    end 
})

VLN_COOK:AddInput("CookIngredient4", { 
    Text = "Ingredient 4", 
    Default = getgenv().cookIngredient4 or "", 
    Finished = true, 
    Placeholder = "e.g. orange", 
    Callback = function(value) 
        getgenv().cookIngredient4 = value
        config.cookIngredient4 = value
        save()
    end 
})

VLN_COOK:AddInput("CookIngredient5", { 
    Text = "Ingredient 5", 
    Default = getgenv().cookIngredient5 or "", 
    Finished = true, 
    Placeholder = "e.g. grape", 
    Callback = function(value) 
        getgenv().cookIngredient5 = value
        config.cookIngredient5 = value
        save()
    end 
})

--// Auto Cook Loop with Enhanced Cooldown
task.spawn(function()
    while uiActive do
        if getgenv().autoCookEnabled then
            local currentTime = tick()
            if currentTime >= nextCookTime then
                local hasIngredients = false
                for i = 1, 5 do
                    local ingredient = getgenv()["cookIngredient" .. i]
                    if ingredient and ingredient ~= "" then
                        hasIngredients = true
                        break
                    end
                end
                
                if hasIngredients then
                    performAutoCook()
                    task.wait(10)
                else
                    task.wait(30)
                end
            else
                task.wait(10)
            end
        else
            task.wait(30)
        end
    end
end)

--// Auto Equip Pets Section
local VLN2 = Tabs.Vuln:AddRightGroupbox("Auto Equip")
VLN2:AddToggle("AutoEquipToggle", { 
    Text = "Auto Equip Mooncat", 
    Default = getgenv().autoEquipEnabled or false, 
    Callback = function(val) 
        getgenv().autoEquipEnabled = val
        config.autoEquipEnabled = val
        save()
    end 
})

VLN2:AddInput("EquipCount", { 
    Text = "Pet Count", 
    Default = tostring(getgenv().equipCount or 6), 
    Numeric = true, 
    Finished = true, 
    Placeholder = "6", 
    Callback = function(value) 
        getgenv().equipCount = math.max(1, math.min(10, tonumber(value) or 6))
        config.equipCount = getgenv().equipCount
        save()
    end 
})

VLN2:AddInput("EquipThreshold", { 
    Text = "Trigger (sec)", 
    Default = tostring(getgenv().equipThreshold or 80), 
    Numeric = true, 
    Finished = true, 
    Placeholder = "80", 
    Callback = function(value) 
        getgenv().equipThreshold = tonumber(value) or 80
        config.equipThreshold = getgenv().equipThreshold
        save()
    end 
})

VLN2:AddInput("UnequipTimer", { 
    Text = "Cleanup (sec)", 
    Default = tostring(getgenv().unequipTimer or 40), 
    Numeric = true, 
    Finished = true, 
    Placeholder = "40", 
    Callback = function(value) 
        getgenv().unequipTimer = math.max(10, tonumber(value) or 40)
        config.unequipTimer = getgenv().unequipTimer
        save()
    end 
})

VLN2:AddDivider()
VLN2:AddInput("EquipRetries", { 
    Text = "Retries", 
    Default = tostring(getgenv().equipRetries or 3), 
    Numeric = true, 
    Finished = true, 
    Placeholder = "3", 
    Callback = function(value) 
        getgenv().equipRetries = math.max(1, math.min(5, tonumber(value) or 3))
        config.equipRetries = getgenv().equipRetries
        save()
    end 
})

VLN2:AddInput("EquipDelay", { 
    Text = "Delay", 
    Default = tostring(getgenv().equipDelay or 0.8), 
    Numeric = true, 
    Finished = true, 
    Placeholder = "0.8", 
    Callback = function(value) 
        getgenv().equipDelay = math.max(0.3, math.min(2.0, tonumber(value) or 0.8))
        config.equipDelay = getgenv().equipDelay
        save()
    end 
})

VLN2:AddDivider()
local positionLabel = VLN2:AddLabel("Position: Not Set")

local function updatePositionLabel()
    if getgenv().savedDropPosition then
        local pos = getgenv().savedDropPosition
        positionLabel:SetText(string.format("Position: %.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z))
    else
        positionLabel:SetText("Position: Not Set")
    end
end

VLN2:AddButton("ShowCurrentPos", { 
    Text = "Show Position", 
    Func = function()
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local pos = player.Character.HumanoidRootPart.Position
            Library:Notify({ 
                Title = "Position", 
                Description = string.format("%.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z), 
                Time = 3 
            })
        end
    end 
})

VLN2:AddButton("SaveCurrentPos", { 
    Text = "Save Position", 
    Func = function()
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            getgenv().savedDropPosition = player.Character.HumanoidRootPart.Position
            config.savedDropPosition = {
                X = getgenv().savedDropPosition.X,
                Y = getgenv().savedDropPosition.Y,
                Z = getgenv().savedDropPosition.Z
            }
            save()
            updatePositionLabel()
            Library:Notify({ 
                Title = "Saved", 
                Description = "Position saved", 
                Time = 2 
            })
        end
    end 
})

VLN2:AddToggle("UsePositionDrop", { 
    Text = "Use Position", 
    Default = getgenv().usePositionDrop or false, 
    Callback = function(val) 
        getgenv().usePositionDrop = val
        config.usePositionDrop = val
        save()
    end 
})

VLN2:AddToggle("UseFastEquip", { 
    Text = "Fast Equip", 
    Default = getgenv().useFastEquip or true, 
    Callback = function(val) 
        getgenv().useFastEquip = val
        config.useFastEquip = val
        save()
    end 
})

if config.savedDropPosition then
    getgenv().savedDropPosition = Vector3.new(
        config.savedDropPosition.X,
        config.savedDropPosition.Y,
        config.savedDropPosition.Z
    )
end
updatePositionLabel()

--// Enhanced Auto Equip Logic with Reliability
local unequipTimers = {}

local function getMoonCatsFromBackpack()
    local moonCats = {}
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:find("Moon Cat") then
            table.insert(moonCats, tool)
        end
    end
    return moonCats
end

local function verifyPetSpawned(toolName, timeout)
    timeout = timeout or 3
    local startTime = tick()
    
    while tick() - startTime < timeout do
        for _, petPart in pairs(workspace.PetsPhysical:GetChildren()) do
            if petPart:IsA("BasePart") and petPart.Name == "PetMover" and petPart:GetAttribute("OWNER") == player.Name then
                local uuid = petPart:GetAttribute("UUID")
                if uuid then
                    local petData = ActivePetsService:GetPetData(player.Name, uuid)
                    if petData and petData.PetType and petData.PetType == "Moon Cat" then
                        return true
                    end
                end
            end
        end
        task.wait(0.1)
    end
    return false
end

local function equipSingleMoonCat(tool, dropPosition, retryCount)
    retryCount = retryCount or 1
    local maxRetries = getgenv().equipRetries or 3
    local equipDelay = getgenv().equipDelay or 0.8
    
    print(string.format("Equipping %s (%d/%d)", tool.Name, retryCount, maxRetries))
    
    local success = false
    local usedFastMethod = false
    
    if getgenv().useFastEquip then
        local fastSuccess = pcall(function()
            if dropPosition and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                player.Character.HumanoidRootPart.CFrame = CFrame.new(dropPosition)
                task.wait(0.3)
            end
            
            local commands = {"EquipPet", "DeployPet", "ActivatePet", "SummonPet"}
            for _, command in ipairs(commands) do
                local args = {command, tool.Name}
                PetsService:FireServer(unpack(args))
                task.wait(0.2)
            end
        end)
        
        if fastSuccess then
            task.wait(1) -- Wait for spawn
            if verifyPetSpawned(tool.Name, 2) then
                usedFastMethod = true
                success = true
                print("Fast method OK: " .. tool.Name)
            else
                print("Fast method failed: " .. tool.Name)
            end
        end
    end
    
    if not success then
        local traditionalSuccess = pcall(function()
            if tool.Parent ~= backpack then
                tool.Parent = backpack
                task.wait(0.2)
            end
            
            if dropPosition and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                player.Character.HumanoidRootPart.CFrame = CFrame.new(dropPosition)
                task.wait(0.3)
            end
            
            tool.Parent = character
            task.wait(0.2)
            
            if humanoid and humanoid.Parent then
                humanoid:EquipTool(tool)
                task.wait(equipDelay)
                
                if tool.Parent == character then
                    local activated = false
                    
                    if tool:FindFirstChild("RemoteEvent") then
                        tool.RemoteEvent:FireServer()
                        activated = true
                    end
                    
                    if not activated and tool:FindFirstChild("Remote") then
                        tool.Remote:FireServer()
                        activated = true
                    end
                    
                    if not activated then
                        tool:Activate()
                    end
                    
                    task.wait(0.5)
                    
                    if verifyPetSpawned(tool.Name, 3) then
                        success = true
                        print("Traditional OK: " .. tool.Name)
                    else
                        print("Traditional failed: " .. tool.Name)
                    end
                else
                    print("Equip failed: " .. tool.Name)
                end
            else
                print("No humanoid: " .. tool.Name)
            end
        end)
        
        if not traditionalSuccess then
            print("Error: " .. tool.Name)
        end
    end
    
    if not success and retryCount < maxRetries then
        print(string.format("Retry %s in 1s...", tool.Name))
        task.wait(1)
        return equipSingleMoonCat(tool, dropPosition, retryCount + 1)
    end
    
    return success, usedFastMethod
end

local function equipAndDropMoonCats(count)
    local moonCats = getMoonCatsFromBackpack()
    if #moonCats == 0 then
        Library:Notify({ Title = "No Mooncats", Description = "None found in backpack", Time = 2 })
        return
    end
    
    local dropPosition = nil
    if getgenv().usePositionDrop and getgenv().savedDropPosition then
        dropPosition = getgenv().savedDropPosition
    end
    
    local equipped = 0
    local failed = 0
    local toolsToUnequip = {}
    local usedFastMethod = false
    
    Library:Notify({ 
        Title = "Equipping", 
        Description = string.format("Deploying %d mooncats", math.min(count, #moonCats)), 
        Time = 2 
    })
    
    for i = 1, math.min(count, #moonCats) do
        local tool = moonCats[i]
        
        if not player.Character or not player.Character:FindFirstChild("Humanoid") then
            player.CharacterAdded:Wait()
            character = player.Character
            humanoid = character:WaitForChild("Humanoid")
            task.wait(1)
        end
        
        local success, fastMethod = equipSingleMoonCat(tool, dropPosition)
        
        if success then
            equipped = equipped + 1
            if fastMethod then
                usedFastMethod = true
            else
                table.insert(toolsToUnequip, tool)
            end
        else
            failed = failed + 1
        end
        
        task.wait(0.3)
    end
    
    if equipped > 0 then
        local methodUsed = usedFastMethod and "fast" or "normal"
        local positionText = dropPosition and "at position" or "here"
        
        Library:Notify({ 
            Title = "Mooncat Deploy", 
            Description = string.format("Success: %d, Failed: %d", equipped, failed), 
            Time = 3 
        })
        
        local timerId = tick()
        unequipTimers[timerId] = true
        task.delay(getgenv().unequipTimer or 40, function()
            if unequipTimers[timerId] then
                unequipTimers[timerId] = nil
                local unequipped = 0
                local collected = 0        

                for _, tool in ipairs(toolsToUnequip) do
                    if tool and tool.Parent == character then
                        pcall(function()
                            tool.Parent = backpack
                            unequipped = unequipped + 1
                        end)
                    end
                end
                
                pcall(function()
                    local CollectPet = ReplicatedStorage:FindFirstChild("GameEvents"):FindFirstChild("CollectPet")
                    if not CollectPet then
                        CollectPet = ReplicatedStorage:FindFirstChild("GameEvents"):FindFirstChild("PickupPet") or
                                   ReplicatedStorage:FindFirstChild("GameEvents"):FindFirstChild("DeleteObject")
                    end
                    
                    if CollectPet then
                        for _, petPart in pairs(workspace.PetsPhysical:GetChildren()) do
                            if petPart:IsA("BasePart") and petPart.Name == "PetMover" and petPart:GetAttribute("OWNER") == player.Name then
                                local uuid = petPart:GetAttribute("UUID")
                                if uuid then
                                    local petData = ActivePetsService:GetPetData(player.Name, uuid)
                                    if petData and petData.PetType then
                                        if petData.PetType ~= "Triceratops" and petData.PetType ~= "Echo Frog" then
                                            CollectPet:FireServer(petPart)
                                            collected = collected + 1
                                            task.wait(0.1)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
                
                if unequipped > 0 or collected > 0 then
                    Library:Notify({ Title = "Cleanup", Description = "Unequipped " .. unequipped .. ", collected " .. collected, Time = 2 })
                end
            end
        end)
    else
        Library:Notify({ 
            Title = "Deploy Failed", 
            Description = "No mooncats equipped", 
            Time = 2 
        })
    end
end

--// Auto Equip Monitor
task.spawn(function()
    while uiActive do
        task.wait(1)
        if getgenv().autoEquipEnabled then
            for _, mover in pairs(workspace.PetsPhysical:GetChildren()) do
                if mover:IsA("BasePart") and mover.Name == "PetMover" then
                    local uuid = mover:GetAttribute("UUID")
                    local owner = mover:GetAttribute("OWNER")
                    if uuid and owner == player.Name then
                        local petData = ActivePetsService:GetPetData(owner, uuid)
                        if petData and (petData.PetType == "Echo Frog" or petData.PetType == "Triceratops") then
                            local ok, cooldowns = pcall(GetPetCooldown.InvokeServer, GetPetCooldown, uuid)
                            if ok and typeof(cooldowns) == "table" then
                                for _, cd in pairs(cooldowns) do
                                    local time = tonumber(cd.Time)
                                    local targetTime = tonumber(getgenv().equipThreshold) or 80
                                    if time and time >= targetTime - 1 and time <= targetTime + 1 then
                                        local moonCats = getMoonCatsFromBackpack()
                                        if #moonCats > 0 then
                                            local equipCount = getgenv().equipCount or 6
                                            equipAndDropMoonCats(equipCount)
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

--// Auto Idle
task.spawn(function()
    while uiActive do
        if getgenv().AutoIdle then
            for _, v in ipairs(workspace.PetsPhysical:GetChildren()) do
                if v:IsA("BasePart") and v.Name == "PetMover" then
                    local uuid = v:GetAttribute("UUID")
                    local owner = v:GetAttribute("OWNER")
                    local isMoonCat = false
                    
                    local model = v:FindFirstChild(uuid)
                    if model and model:IsA("Model") and model:GetAttribute("CurrentSkin") == "Moon Cat" then
                        isMoonCat = true
                    end
                    
                    if not isMoonCat and owner == player.Name and uuid then
                        local petData = ActivePetsService:GetPetData(owner, uuid)
                        if petData and petData.PetType == "Moon Cat" then
                            isMoonCat = true
                        end
                    end
                    
                    if isMoonCat then
                        task.spawn(IdleHandler.Activate, v)
                    end
                end
            end
        end
        task.wait()
    end
end)

--// Unified Pet Idle Logic
task.spawn(function()
    while uiActive do
        if getgenv().AutoIdleToggle and getgenv().idleDrop then
            for _, petPart in pairs(workspace.PetsPhysical:GetChildren()) do
                if petPart:IsA("BasePart") and petPart.Name == "PetMover" then
                    local uuid = petPart:GetAttribute("UUID")
                    local owner = petPart:GetAttribute("OWNER")
                    
                    if owner == player.Name and uuid then
                        local model = petPart:FindFirstChild(uuid)
                        if
                            model
                            and model:IsA("Model")
                            and model:GetAttribute("CurrentSkin") == "Moon Cat"
                            and getgenv().idleDrop["Moon Cat"]
                        then
                            task.spawn(IdleHandler.Activate, petPart)
                        else
                            local petData = ActivePetsService:GetPetData(owner, uuid)
                            if petData and petData.PetType and getgenv().idleDrop[petData.PetType] then
                                task.spawn(IdleHandler.Activate, petPart)
                            end
                        end
                    end
                end
            end
        end
        task.wait(1)
    end
end)

--// Echo Frog Logic
task.spawn(function()
    while uiActive do
        if getgenv().AutoIdleToggle then
            for _, mover in pairs(workspace.PetsPhysical:GetChildren()) do
                if mover:IsA("BasePart") and mover.Name == "PetMover" then
                    local uuid = mover:GetAttribute("UUID")
                    local owner = mover:GetAttribute("OWNER")
                    
                    if uuid and owner == player.Name then
                        local petData = ActivePetsService:GetPetData(owner, uuid)
                        if petData and (petData.PetType == "Echo Frog" or petData.PetType == "Triceratops") then
                            local ok, cooldowns = pcall(GetPetCooldown.InvokeServer, GetPetCooldown, uuid)
                            if ok and typeof(cooldowns) == "table" then
                                for _, cd in pairs(cooldowns) do
                                    local time = tonumber(cd.Time)
                                    local targetTime = tonumber(getgenv().idleInput) or 80
                                    if
                                        time
                                        and time >= targetTime - 1
                                        and time <= targetTime + 1
                                        and not getgenv().AutoIdle
                                    then
                                        Library:Notify({
                                            Title = "Auto Idle: " .. petData.PetType,
                                            Description = "True",
                                            Time = 3,
                                        })
                                        getgenv().AutoIdle = true
                                        task.delay(10, function()
                                            getgenv().AutoIdle = false
                                            Library:Notify({
                                                Title = "Auto Idle: " .. petData.PetType,
                                                Description = "False",
                                                Time = 3,
                                            })
                                        end)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        else
            getgenv().AutoIdle = false
        end
        task.wait(1)
    end
end)

--// Active Pet List Updater
task.spawn(function()
    while uiActive do
        task.wait(3)
        local activePets = getActivePetTypes()
        local preserved = {}
        
        if getgenv().idleDrop then
            for _, petType in ipairs(activePets) do
                if getgenv().idleDrop[petType] then
                    preserved[petType] = true
                end
            end
        end
        
        if idleDropdown then
            idleDropdown:SetValues(activePets)
            idleDropdown:SetValue(preserved)
        end
        
        getgenv().idleDrop = preserved
    end
end)

--// Menu
local MenuGroup = Tabs["Settings"]:AddFullGroupbox("Menu", "settings")

MenuGroup:AddDropdown("NotificationSide", {
    Values = { "Left", "Right" },
    Default = "Right",
    Text = "Notifications",
    Callback = function(Value)
        Library:SetNotifySide(Value)
    end,
})

MenuGroup:AddDropdown("DPIDropdown", {
    Values = { "50%", "75%", "100%", "125%", "150%" },
    Default = "100%",
    Text = "UI Scale",
    Callback = function(Value)
        Value = Value:gsub("%%", "")
        local DPI = tonumber(Value)
        Library:SetDPIScale(DPI)
    end,
})

MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "LeftControl",
    NoUI = true,
    Text = "Menu key",
})

MenuGroup:AddButton("Unload", function()
    uiActive = false
    Library:Unload()
end)

Library.ToggleKeybind = Library.Options.MenuKeybind

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("hikochairs")
ThemeManager:ApplyToTab(Tabs["Settings"])

Library:OnUnload(function()
    uiActive = false
    getgenv().uiUpd = nil
    getgenv().scriptRunning = false
end)

-- BAAKKA 