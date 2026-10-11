-- MM2 Coin Farm — MainCoin scan, 27 studs/sec fly, in-map bounds, no inter-coin wait

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
    ceilingPad    = 5,
    floorPad      = 5,
    floatY        = nil,
    floatAmp      = 1.5,
    floatFreq     = 0.8,
}

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
    if #coins == 0 then return nil end
    local minY, maxY = math.huge, -math.huge
    for _, c in ipairs(coins) do
        local y = c.Position.Y
        if y < minY then minY = y end
        if y > maxY then maxY = y end
    end
    return {
        minY = minY - state.floorPad,
        maxY = maxY + state.ceilingPad,
    }
end

local function nearestCoin()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local coins = resolveCoins()
    local best, bestDist = nil, math.huge
    for _, c in ipairs(coins) do
        local d = (hrp.Position - c.Position).Magnitude
        if d < bestDist then best, bestDist = c, d end
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

RunService.Stepped:Connect(function()
    if not state.noclip then return end
    local char = player.Character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d.CanCollide then
            d.CanCollide = false
        end
    end
end)

player.CharacterAdded:Connect(function(char)
    if not state.noclip then return end
    task.wait(0.1)
    applyNoclipToCharacter(char, true)
    suppressCollisionStates()
end)

applyNoclipToCharacter(player.Character, state.noclip)

------------------------------------------------------------
-- FLY (no wait between coins)
------------------------------------------------------------
local function getHRP()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function clampToMap(pos, bounds)
    if not bounds then return pos end
    local y = math.clamp(pos.Y, bounds.minY, bounds.maxY)
    return Vector3.new(pos.X, y, pos.Z)
end

local function flyTo(targetPos, bounds)
    local hrp = getHRP()
    if not hrp then return false end

    local goal = clampToMap(targetPos + state.offset, bounds)

    hrp.AssemblyLinearVelocity  = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero

    local done = false
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if done then return end
        local cur = hrp.Position
        local delta = goal - cur
        local dist = delta.Magnitude

        if dist < 1.5 then
            hrp.CFrame = CFrame.new(clampToMap(goal, bounds))
            done = true
            return
        end

        local step = math.min(state.flySpeed * dt, dist)
        local newPos = clampToMap(cur + delta.Unit * step, bounds)
        hrp.CFrame = CFrame.new(newPos, newPos + delta.Unit)
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)

    local timeout = tick() + 20
    while not done and tick() < timeout do
        task.wait(0.03)
        if not state.farming then break end
    end
    conn:Disconnect()
    return done
end

------------------------------------------------------------
-- IDLE FLOAT (only used when no coin exists)
------------------------------------------------------------
local function floatTick()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if state.floatY == nil then state.floatY = hrp.Position.Y end

    local t = tick() * state.floatFreq * math.pi * 2
    local bob = math.sin(t) * state.floatAmp
    local targetY = state.floatY + bob

    local cur = hrp.Position
    hrp.CFrame = CFrame.new(Vector3.new(cur.X, targetY, cur.Z))
    hrp.AssemblyLinearVelocity  = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
end

------------------------------------------------------------
-- FARM LOOP
------------------------------------------------------------
local farmConn

local function startFarm()
    if farmConn then return end

    applyNoclipToCharacter(player.Character, true)
    suppressCollisionStates()

    farmConn = task.spawn(function()
        while state.farming do
            local coin, dist, count = nearestCoin()
            if coin then
                local bounds = computeBounds()
                status.Text = string.format("coins: %d | fly %.0f", count or 0, dist or 0)
                if state.noclip then
                    applyNoclipToCharacter(player.Character, true)
                    suppressCollisionStates()
                end
                -- fly straight to the next coin, no wait
                flyTo(coinPos(coin), bounds)
            else
                status.Text = "no MainCoin — floating"
                floatTick()
                task.wait(0.05)
            end
        end
    end)
end

local function stopFarm()
    state.farming = false
    if farmConn then
        pcall(function() task.cancel(farmConn) end)
        farmConn = nil
    end
    state.floatY = nil
    state.noclip = false
    applyNoclipToCharacter(player.Character, false)
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum.PlatformStand = false end)
    end
end

------------------------------------------------------------
-- WIRING
------------------------------------------------------------
track.MouseButton1Click:Connect(function()
    state.farming = not state.farming
    render(state.farming)
    if state.farming then
        state.noclip = true
        applyNoclipToCharacter(player.Character, true)
        startFarm()
    else
        stopFarm()
        status.Text = "stopped — noclip off"
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
    applyNoclipToCharacter(player.Character, b)
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
    print("[MM2] bounds y:", b.minY, "to", b.maxY)
end

function goNearestOnce()
    local coin, dist = nearestCoin()
    if not coin then print("[MM2] no MainCoin") return end
    local bounds = computeBounds()
    print("[MM2] nearest:", coin:GetFullName(), dist)
    applyNoclipToCharacter(player.Character, true)
    suppressCollisionStates()
    flyTo(coinPos(coin), bounds)
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
_G.listCoins        = listCoins
_G.showBounds       = showBounds
_G.goNearestOnce    = goNearestOnce
_G.noclipStatus     = noclipStatus

print("[MM2] loaded. continuous fly, no inter-coin wait.")
