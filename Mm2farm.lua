-- MM2 Coin Farm — idle-normal mode when no coins in range

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local CoreGui      = game:GetService("CoreGui")
local VirtualUser  = game:GetService("VirtualUser")
local player       = Players.LocalPlayer

if CoreGui:FindFirstChild("MM2CoinFarm") then
    CoreGui.MM2CoinFarm:Destroy()
end

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local state = {
    farming       = false,
    flySpeed      = 27,
    offset        = Vector3.new(0, 3, 0),
    noclip        = true,
    antiAFK       = true,
    platformStand = true,
    ceilingPad    = 3,
    floorPad      = 3,
    floatY        = nil,
    floatAmp      = 1.5,
    floatFreq     = 0.8,
    flatFlight    = true,
    underMapDrop  = 60,
    transitRadius = 8,
    maxRange      = 1000,
    bounds        = nil,
    collected     = {},
    paused        = false,
    idleNormal    = false,       -- true = no coins in range, effects off
}

------------------------------------------------------------
-- ALIVE CHECK
------------------------------------------------------------
local function isAlive()
    local char = player.Character
    if not char or char.Parent ~= workspace then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if hum.Health <= 0 then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    return true
end

------------------------------------------------------------
-- MAINCOIN RESOLVER
------------------------------------------------------------
local function resolveCoins()
    local found = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "MainCoin" then
            if obj:IsA("BasePart") then
                table.insert(found, obj)
            elseif obj:IsA("Model") then
                local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                if p then table.insert(found, p) end
            end
        end
    end
    return found
end

local function coinPos(coin) return coin.Position end

local function computeBounds()
    local coins = resolveCoins()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")

    local minY, maxY = math.huge, -math.huge
    for _, c in ipairs(coins) do
        local y = c.Position.Y
        if y < minY then minY = y end
        if y > maxY then maxY = y end
    end

    if hrp then
        local py = hrp.Position.Y
        if py < minY then minY = py end
        if py > maxY then maxY = py end
    end

    if minY == math.huge then return nil end

    return {
        minY = minY - state.floorPad,
        maxY = maxY + state.ceilingPad,
        coinMinY = minY,
    }
end

local function nearestCoin()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local coins = resolveCoins()
    local best, bestDist = nil, math.huge
    for _, c in ipairs(coins) do
        if not state.collected[c] then
            local d = (hrp.Position - c.Position).Magnitude
            if d <= state.maxRange and d < bestDist then
                best, bestDist = c, d
            end
        end
    end
    return best, bestDist, #coins
end

------------------------------------------------------------
-- GUI
------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "MM2CoinFarm"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9999
gui.Parent = CoreGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 250, 0, 140)
frame.Position = UDim2.new(0, 20, 0, 120)
frame.BackgroundColor3 = Color3.fromRGB(12, 14, 18)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 220, 40)
stroke.Thickness = 1
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 22)
title.Position = UDim2.new(0, 8, 0, 4)
title.BackgroundTransparency = 1
title.Text = "MM2 COIN FARM"
title.TextColor3 = Color3.fromRGB(255, 220, 40)
title.Font = Enum.Font.Code
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local track = Instance.new("TextButton")
track.Size = UDim2.new(0, 42, 0, 20)
track.Position = UDim2.new(1, -54, 0, 34)
track.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
track.BorderSizePixel = 0
track.Text = ""
track.AutoButtonColor = false
track.Parent = frame

local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(1, 0) tc.Parent = track

local knob = Instance.new("Frame")
knob.Size = UDim2.new(0, 16, 0, 16)
knob.Position = UDim2.new(0, 2, 0, 2)
knob.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
knob.BorderSizePixel = 0
knob.Parent = track

local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1, 0) kc.Parent = knob

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, -70, 0, 20)
label.Position = UDim2.new(0, 8, 0, 34)
label.BackgroundTransparency = 1
label.Text = "Farm: OFF"
label.TextColor3 = Color3.fromRGB(160, 160, 160)
label.Font = Enum.Font.Code
label.TextSize = 12
label.TextXAlignment = Enum.TextXAlignment.Left
label.Parent = frame

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -16, 0, 60)
status.Position = UDim2.new(0, 8, 0, 62)
status.BackgroundTransparency = 1
status.Text = "ready"
status.TextColor3 = Color3.fromRGB(120, 120, 120)
status.Font = Enum.Font.Code
status.TextSize = 10
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Parent = frame

local function render(on)
    track.BackgroundColor3 = on and Color3.fromRGB(255, 220, 40) or Color3.fromRGB(40, 40, 46)
    knob.Position = on and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
    knob.BackgroundColor3 = on and Color3.fromRGB(20, 20, 20) or Color3.fromRGB(180, 180, 180)
    label.Text = on and "Farm: ON" or "Farm: OFF"
    label.TextColor3 = on and Color3.fromRGB(255, 220, 40) or Color3.fromRGB(160, 160, 160)
end

render(false)

------------------------------------------------------------
-- ANTI-AFK
------------------------------------------------------------
player.Idled:Connect(function()
    if not state.antiAFK then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

------------------------------------------------------------
-- NOCLIP
------------------------------------------------------------
local function applyNoclipToCharacter(char, on)
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            d.CanCollide = not on
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if on then
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end)
        else
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end)
            pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true) end)
        end
    end
end

local function suppressCollisionStates()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if state.platformStand and state.noclip then
        pcall(function() hum.PlatformStand = true end)
    end
    if state.noclip then
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end)
    end
end

local function releaseNormalState()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum.PlatformStand = false end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true) end)
    end
    applyNoclipToCharacter(char, false)
end

RunService.Stepped:Connect(function()
    if not state.noclip then return end
    if state.paused then return end
    if state.idleNormal then return end
    if not isAlive() then return end
    local char = player.Character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d.CanCollide then
            d.CanCollide = false
        end
    end
end)

player.CharacterAdded:Connect(function(char)
    if not state.noclip or not state.farming then return end
    task.wait(0.15)
    if isAlive() and not state.idleNormal then
        applyNoclipToCharacter(char, true)
        suppressCollisionStates()
    end
end)

------------------------------------------------------------
-- ORIENTATION
------------------------------------------------------------
local function writeFlat(hrp, look)
    if not hrp then return end
    if not look or look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
    look = Vector3.new(look.X, 0, look.Z)
    if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
    look = look.Unit
    hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + look, Vector3.new(0, 1, 0))
end

local function writeUpright(hrp, look)
    if not hrp then return end
    if not look or look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
    look = Vector3.new(look.X, 0, look.Z)
    if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
    look = look.Unit
    hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + look, Vector3.new(0, 1, 0))
end

------------------------------------------------------------
-- FLY
------------------------------------------------------------
local function getHRP()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function flyToward(goal, bounds, orientation)
    local hrp = getHRP()
    if not hrp then return false end

    local goalY = goal.Y
    if bounds and orientation ~= "undermap" then
        goalY = math.clamp(goalY, bounds.minY, bounds.maxY)
    end

    local done = false
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if done then return end
        if state.paused then done = true return end
        if state.idleNormal then done = true return end
        if not isAlive() then done = true return end

        local cur = hrp.Position
        local target = Vector3.new(goal.X, goalY, goal.Z)
        local delta = target - cur
        local dist = delta.Magnitude

        if dist < 1.5 then
            local fy = goalY
            if bounds and orientation ~= "undermap" then
                fy = math.clamp(fy, bounds.minY, bounds.maxY)
            end
            local look = Vector3.new(delta.X, 0, delta.Z)
            local pos = Vector3.new(goal.X, fy, goal.Z)

            if orientation == "flat" then
                writeFlat(hrp, look)
            else
                writeUpright(hrp, look)
            end
            hrp.CFrame = CFrame.new(pos) * (hrp.CFrame - hrp.CFrame.Position)
            done = true
            return
        end

        local step = math.min(state.flySpeed * dt, dist)
        local newPos = cur + delta.Unit * step
        local ny = newPos.Y
        if bounds and orientation ~= "undermap" then
            ny = math.clamp(ny, bounds.minY, bounds.maxY)
        end
        newPos = Vector3.new(newPos.X, ny, newPos.Z)

        local look = Vector3.new(delta.X, 0, delta.Z)
        if orientation == "flat" then
            writeFlat(hrp, look)
        else
            writeUpright(hrp, look)
        end
        hrp.CFrame = CFrame.new(newPos) * (hrp.CFrame - hrp.CFrame.Position)

        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)

    local timeout = tick() + 25
    while not done and tick() < timeout do
        task.wait(0.03)
        if not state.farming then break end
        if state.paused then break end
        if state.idleNormal then break end
    end
    conn:Disconnect()
    return done
end

------------------------------------------------------------
-- COIN CYCLE
------------------------------------------------------------
local function approachCoin(coin, bounds)
    local hrp = getHRP()
    if not hrp then return end
    local cpos = coinPos(coin)

    local transitY = cpos.Y - state.underMapDrop
    if bounds then
        transitY = math.min(transitY, bounds.coinMinY - state.underMapDrop)
    end

    local startX = hrp.Position.X + state.transitRadius
    local startZ = hrp.Position.Z
    flyToward(Vector3.new(startX, transitY, startZ), bounds, "flat")
    flyToward(Vector3.new(cpos.X, transitY, cpos.Z), bounds, "flat")

    local finalY = cpos.Y + state.offset.Y
    if bounds then finalY = math.clamp(finalY, bounds.minY, bounds.maxY) end
    flyToward(Vector3.new(cpos.X, finalY, cpos.Z), bounds, "upright")
end

------------------------------------------------------------
-- ENTER / EXIT IDLE-NORMAL
------------------------------------------------------------
local function enterIdleNormal()
    if state.idleNormal then return end
    state.idleNormal = true
    -- turn off all effects
    releaseNormalState()
    status.Text = "no coins in range — normal mode"
end

local function exitIdleNormal()
    if not state.idleNormal then return end
    state.idleNormal = false
    -- effects will be reapplied by the farm loop on next tick
    if state.noclip and isAlive() then
        applyNoclipToCharacter(player.Character, true)
        suppressCollisionStates()
    end
end

------------------------------------------------------------
-- FARM LOOP
------------------------------------------------------------
local farmConn

local function startFarm()
    if farmConn then return end

    state.collected = {}
    state.paused = false
    state.idleNormal = false

    farmConn = task.spawn(function()
        while state.farming do
            if not isAlive() then
                state.paused = true
                status.Text = "dead / not spawned — paused"
                task.wait(0.5)
            else
                if state.paused then
                    state.paused = false
                    state.collected = {}
                    state.bounds = computeBounds()
                    state.floatY = nil
                    local hrp = getHRP()
                    if hrp then state.floatY = hrp.Position.Y end
                end

                local coin, dist, count = nearestCoin()
                if coin then
                    -- came back into range → exit idle normal
                    exitIdleNormal()

                    state.bounds = computeBounds()
                    local n = 0
                    for _ in pairs(state.collected) do n = n + 1 end
                    status.Text = string.format("coins: %d | fly %.0f | collected: %d",
                        count or 0, dist or 0, n)
                    if state.noclip then
                        applyNoclipToCharacter(player.Character, true)
                        suppressCollisionStates()
                    end
                    approachCoin(coin, state.bounds)
                    state.collected[coin] = true
                    task.wait(0.15)
                else
                    -- no reachable coin → strip all effects, wait normal
                    enterIdleNormal()
                    task.wait(0.5)
                end
            end
        end
    end)
end

local function stopFarm()
    state.farming = false
    state.paused = false
    if farmConn then
        pcall(function() task.cancel(farmConn) end)
        farmConn = nil
    end
    state.floatY = nil
    state.bounds = nil
    state.idleNormal = false
    state.noclip = false
    applyNoclipToCharacter(player.Character, false)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum.PlatformStand = false end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true) end)
    end
    local hrp = getHRP()
    if hrp then writeUpright(hrp, hrp.CFrame.LookVector) end
end

------------------------------------------------------------
-- WIRING
------------------------------------------------------------
track.MouseButton1Click:Connect(function()
    state.farming = not state.farming
    render(state.farming)
    if state.farming then
        state.noclip = true
        state.paused = false
        state.idleNormal = false
        if isAlive() then
            applyNoclipToCharacter(player.Character, true)
            suppressCollisionStates()
        end
        startFarm()
        status.Text = isAlive() and "farm on" or "waiting for spawn..."
    else
        stopFarm()
        status.Text = "stopped — noclip off"
    end
end)

player.CharacterAdded:Connect(function()
    state.collected = {}
    state.bounds = nil
    state.floatY = nil
    if state.farming and state.noclip and not state.idleNormal then
        task.wait(0.2)
        if isAlive() then
            applyNoclipToCharacter(player.Character, true)
            suppressCollisionStates()
        end
    end
end)

------------------------------------------------------------
-- CONSOLE HELPERS
------------------------------------------------------------
function setFlySpeed(s)
    state.flySpeed = math.clamp(s, 1, 27)
    print("[MM2] flySpeed", state.flySpeed)
end
function setNoclip(b)
    state.noclip = b
    print("[MM2] noclip", b)
    if isAlive() and not state.idleNormal then
        applyNoclipToCharacter(player.Character, b)
    end
end
function setAntiAFK(b)      state.antiAFK = b print("[MM2] antiAFK", b) end
function setPlatformStand(b)
    state.platformStand = b
    print("[MM2] platformStand", b)
end
function setOffset(x, y, z)
    state.offset = Vector3.new(x, y, z)
    print("[MM2] offset", state.offset)
end
function setPads(floorPad, ceilingPad)
    state.floorPad = floorPad
    state.ceilingPad = ceilingPad
    print("[MM2] pads floor", floorPad, "ceil", ceilingPad)
end
function setFloat(amp, freq)
    state.floatAmp = amp
    state.floatFreq = freq
    print("[MM2] float amp", amp, "freq", freq)
end
function setFlatFlight(b)
    state.flatFlight = b
    print("[MM2] flatFlight", b)
end
function setTransit(drop, radius)
    state.underMapDrop = drop
    state.transitRadius = radius
    print("[MM2] underMapDrop", drop, "transitRadius", radius)
end
function setMaxRange(r)
    state.maxRange = r
    print("[MM2] maxRange", r)
end

function listCoins()
    local coins = resolveCoins()
    print("[MM2] MainCoin found:", #coins)
    for i, c in ipairs(coins) do
        if i <= 15 then print("  ", i, c:GetFullName(), c.Position) end
    end
end

function showBounds()
    local b = computeBounds()
    if not b then print("[MM2] no bounds — no coins") return end
    print("[MM2] bounds y:", b.minY, "to", b.maxY, "coinMinY:", b.coinMinY)
end

function clearCollected()
    state.collected = {}
    print("[MM2] collected set cleared")
end

function collectedCount()
    local n = 0
    for _ in pairs(state.collected) do n = n + 1 end
    print("[MM2] collected:", n)
end

function statusNow()
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    print("[MM2] farming:", state.farming,
          "paused:", state.paused,
          "idleNormal:", state.idleNormal,
          "alive:", isAlive(),
          "health:", hum and hum.Health or "n/a")
end

function goNearestOnce()
    if not isAlive() then print("[MM2] not alive") return end
    local coin, dist = nearestCoin()
    if not coin then
        print("[MM2] no uncollected MainCoin within", state.maxRange)
        return
    end
    exitIdleNormal()
    state.bounds = computeBounds()
    print("[MM2] nearest:", coin:GetFullName(), dist)
    applyNoclipToCharacter(player.Character, true)
    suppressCollisionStates()
    approachCoin(coin, state.bounds)
    state.collected[coin] = true
end

function noclipStatus()
    local char = player.Character
    if not char then print("[MM2] no character") return end
    local total, colliding = 0, 0
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then
            total = total + 1
            if d.CanCollide then colliding = colliding + 1 end
        end
    end
    print("[MM2] parts:", total, "colliding:", colliding)
end

_G.setFlySpeed      = setFlySpeed
_G.setNoclip        = setNoclip
_G.setAntiAFK       = setAntiAFK
_G.setPlatformStand = setPlatformStand
_G.setOffset        = setOffset
_G.setPads          = setPads
_G.setFloat         = setFloat
_G.setFlatFlight    = setFlatFlight
_G.setTransit       = setTransit
_G.setMaxRange      = setMaxRange
_G.listCoins        = listCoins
_G.showBounds       = showBounds
_G.clearCollected   = clearCollected
_G.collectedCount   = collectedCount
_G.statusNow        = statusNow
_G.goNearestOnce    = goNearestOnce
_G.noclipStatus     = noclipStatus

print("[MM2] loaded. idle-normal when no coins in range.")
