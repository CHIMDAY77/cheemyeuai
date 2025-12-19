
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Camera = workspace.CurrentCamera

local LP = Players.LocalPlayer

--// ================= CONFIG =================
local cfg = {
    ESP = true,
    BOX = true,
    AIM = true,
    TEAM_CHECK = true,

    -- Aim trigger
    SHOOT_ONLY = true,
    FIRE_BUTTON = Enum.UserInputType.MouseButton1,

    -- Base FOV (dynamic overrides below)
    FOV_BASE = 200,
    FOV_VISIBLE = true,

    -- Smooth range (dynamic)
    SMOOTH_MIN = 0.14,
    SMOOTH_MAX = 0.24,

    -- Head logic
    HEADSHOT_CLOSE = 85,
    HEADSHOT_MID   = 180,

    DEFAULT_PART = "HumanoidRootPart",
    HEAD_PART    = "Head",

    -- Prediction
    PREDICT_FACTOR = 0.12,   -- light, legit

    -- Legit randomization (keep hit rate > 90%)
    MISS_CHANCE = 0.08,      -- 8% intentional soft miss
    DELAY_CHANCE = 0.10,     -- 10% micro delay
    DELAY_MIN = 0.015,
    DELAY_MAX = 0.045,

    -- Adaptive perf
    FPS_LOW = 40,
    FPS_MED = 55,

    -- Admin protection
    AUTO_DISABLE_ON_ADMIN = true,
    ADMIN_KEYWORDS = {"admin","mod","staff","dev"},
}

--// ================= UTILS =================
local function isEnemy(plr)
    if not cfg.TEAM_CHECK then return true end
    if not LP.Team or not plr.Team then return true end
    return plr.Team ~= LP.Team
end

local function hrp()
    return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
end

local function distFromMe(pos)
    local r = hrp()
    if not r then return math.huge end
    return (r.Position - pos).Magnitude
end

-- FPS estimator
local fps, frames, last = 60, 0, tick()
RunService.RenderStepped:Connect(function()
    frames += 1
    if tick() - last >= 1 then
        fps = frames / (tick() - last)
        frames = 0
        last = tick()
    end
end)

-- Dynamic smooth & FOV
local function dynParams(distance)
    local fov = cfg.FOV_BASE
    local smooth
    if distance < 80 then
        fov = 160; smooth = 0.14
    elseif distance < 180 then
        fov = 200; smooth = 0.18
    else
        fov = 260; smooth = 0.24
    end
    -- Adaptive perf
    if fps < cfg.FPS_LOW then
        fov -= 30; smooth += 0.04; cfg.BOX = false
    elseif fps < cfg.FPS_MED then
        smooth += 0.02
    end
    return math.max(120,fov), math.clamp(smooth, cfg.SMOOTH_MIN, cfg.SMOOTH_MAX)
end

-- Legit randomization helpers
local function shouldMiss() return math.random() < cfg.MISS_CHANCE end
local function maybeDelay()
    if math.random() < cfg.DELAY_CHANCE then
        task.wait(math.random()*(cfg.DELAY_MAX-cfg.DELAY_MIN)+cfg.DELAY_MIN)
    end
end

--// ================= GUI (Modern / Rounded + Sliders + Presets) =================
local gui = Instance.new("ScreenGui", LP.PlayerGui)
gui.Name = "CombatArenaLegitUI"
gui.ResetOnSpawn = false

-- Main panel
local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 320, 0, 360)
frame.Position = UDim2.new(0.5, -160, 0.5, -180)
frame.BackgroundColor3 = Color3.fromRGB(18,18,26)
frame.Active = true
frame.Draggable = true
frame.Visible = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,18)

local stroke = Instance.new("UIStroke", frame)
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(70,70,95)

-- Header
local header = Instance.new("Frame", frame)
header.Size = UDim2.new(1,0,0,46)
header.BackgroundColor3 = Color3.fromRGB(28,28,40)
header.BorderSizePixel = 0
Instance.new("UICorner", header).CornerRadius = UDim.new(0,18)

local title = Instance.new("TextLabel", header)
title.Size = UDim2.new(1,-60,1,0)
title.Position = UDim2.new(0,18,0,0)
title.Text = "🎯 Combat Arena LEGIT++"
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.new(1,1,1)
title.BackgroundTransparency = 1
title.TextXAlignment = Left

local close = Instance.new("TextButton", header)
close.Size = UDim2.new(0,34,0,34)
close.Position = UDim2.new(1,-44,0.5,-17)
close.Text = "✕"
close.Font = Enum.Font.GothamBold
close.TextSize = 16
close.BackgroundColor3 = Color3.fromRGB(45,45,60)
close.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", close).CornerRadius = UDim.new(1,0)

-- Status
local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1,-32,0,26)
status.Position = UDim2.new(0,16,0,52)
status.Text = "Preset: NORMAL"
status.Font = Enum.Font.GothamBold
status.TextSize = 13
status.TextColor3 = Color3.fromRGB(120,255,120)
status.BackgroundTransparency = 1
status.TextXAlignment = Left

-- Button helper
local function makeBtn(text,y)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(1,-32,0,38)
    b.Position = UDim2.new(0,16,0,y)
    b.BackgroundColor3 = Color3.fromRGB(38,38,54)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 14
    b.Text = text
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,12)
    return b
end

-- Slider helper
local function makeSlider(labelText, y, min, max, default, callback)
    local lbl = Instance.new("TextLabel", frame)
    lbl.Size = UDim2.new(1,-32,0,20)
    lbl.Position = UDim2.new(0,16,0,y)
    lbl.Text = labelText..": "..default
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.fromRGB(200,200,220)
    lbl.BackgroundTransparency = 1
    lbl.TextXAlignment = Left

    local bar = Instance.new("Frame", frame)
    bar.Size = UDim2.new(1,-32,0,10)
    bar.Position = UDim2.new(0,16,0,y+22)
    bar.BackgroundColor3 = Color3.fromRGB(45,45,60)
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)

    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new((default-min)/(max-min),0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(255,120,120)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)

    local dragging = false
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local x = math.clamp((i.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
            fill.Size = UDim2.new(x,0,1,0)
            local val = math.floor(min + (max-min)*x)
            lbl.Text = labelText..": "..val
            callback(val)
        end
    end)
end

-- Preset button
local presetBtn = makeBtn("Preset: NORMAL", 86)

presetBtn.MouseButton1Click:Connect(function()
    if cfg.PRESET == "SAFE" then
        cfg.PRESET = "NORMAL"
        cfg.FOV_BASE = 200
        cfg.SMOOTH_MIN, cfg.SMOOTH_MAX = 0.16, 0.24
        cfg.MISS_CHANCE = 0.08
    elseif cfg.PRESET == "NORMAL" then
        cfg.PRESET = "RAGE"
        cfg.FOV_BASE = 260
        cfg.SMOOTH_MIN, cfg.SMOOTH_MAX = 0.10, 0.18
        cfg.MISS_CHANCE = 0.03
    else
        cfg.PRESET = "SAFE"
        cfg.FOV_BASE = 160
        cfg.SMOOTH_MIN, cfg.SMOOTH_MAX = 0.18, 0.28
        cfg.MISS_CHANCE = 0.12
    end
    presetBtn.Text = "Preset: "..cfg.PRESET
    status.Text = "Preset: "..cfg.PRESET
end)

-- Sliders
makeSlider("FOV", 132, 120, 300, cfg.FOV_BASE, function(v) cfg.FOV_BASE = v end)
makeSlider("Smooth", 176, 5, 30, math.floor(cfg.SMOOTH_MIN*100), function(v)
    cfg.SMOOTH_MIN = v/100
    cfg.SMOOTH_MAX = (v+8)/100
end)

local hide = makeBtn("Hide Menu", 226)

-- Mini reopen button
local mini = Instance.new("TextButton", gui)
mini.Size = UDim2.new(0,54,0,54)
mini.Position = UDim2.new(0,14,0.5,-27)
mini.Text = "🎯"
mini.Font = Enum.Font.GothamBold
mini.TextSize = 22
mini.BackgroundColor3 = Color3.fromRGB(30,30,44)
mini.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", mini).CornerRadius = UDim.new(1,0)

-- UI logic
close.MouseButton1Click:Connect(function() frame.Visible = false end)
hide.MouseButton1Click:Connect(function() frame.Visible = false end)
mini.MouseButton1Click:Connect(function() frame.Visible = true end)

-- default preset
cfg.PRESET = "NORMAL"

--// ================= FOV =================
local fov = Instance.new("Frame", gui)
fov.AnchorPoint = Vector2.new(0.5,0.5)
fov.BackgroundTransparency = 1
fov.BorderSizePixel = 0
local st = Instance.new("UIStroke", fov)
st.Thickness = 2
st.Color = Color3.fromRGB(255,120,120)
Instance.new("UICorner", fov).CornerRadius = UDim.new(1,0)

--// ================= ESP =================
local esp = {}
local function addESP(plr)
    if plr == LP then return end
    local char = plr.Character; if not char then return end
    local r = char:FindFirstChild("HumanoidRootPart"); if not r then return end
    if esp[plr] then return end
    local bill = Instance.new("BillboardGui", gui)
    bill.Adornee = r; bill.Size = UDim2.new(0,120,0,30); bill.AlwaysOnTop = true
    local txt = Instance.new("TextLabel", bill)
    txt.Size = UDim2.new(1,0,1,0); txt.BackgroundTransparency = 1
    txt.Font = Enum.Font.GothamBold; txt.TextSize = 14; txt.Text = plr.Name
    local box
    if cfg.BOX then
        box = Instance.new("BoxHandleAdornment", gui)
        box.Adornee = char; box.AlwaysOnTop = true; box.Size = Vector3.new(4,6,2); box.Transparency = 0.75
    end
    esp[plr] = {bill=bill, label=txt, box=box}
end

local function updateESP()
    for plr,d in pairs(esp) do
        if not plr.Character or not d.bill.Adornee then
            d.bill.Enabled = false
        else
            local enemy = isEnemy(plr)
            d.bill.Enabled = cfg.ESP and enemy
            d.label.TextTransparency = enemy and 0 or 0.7
            d.label.TextColor3 = enemy and Color3.fromRGB(255,80,80) or Color3.fromRGB(120,120,120)
            if d.box then d.box.Visible = cfg.ESP and cfg.BOX and enemy end
        end
    end
end

--// ================= AIM =================
local shooting = false
UserInputService.InputBegan:Connect(function(i) if i.UserInputType==cfg.FIRE_BUTTON then shooting=true end end)
UserInputService.InputEnded:Connect(function(i) if i.UserInputType==cfg.FIRE_BUTTON then shooting=false end end)

local function pickTarget()
    local best, bestScore, bestDist = nil, math.huge, math.huge
    local mouse = UserInputService:GetMouseLocation()
    for _,plr in pairs(Players:GetPlayers()) do
        if plr~=LP and isEnemy(plr) and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            local r = plr.Character:FindFirstChild("HumanoidRootPart")
            if hum and r and hum.Health>0 then
                local dist = distFromMe(r.Position)
                local part = r
                if dist<=cfg.HEADSHOT_MID then
                    local h = plr.Character:FindFirstChild(cfg.HEAD_PART); if h then part=h end
                end
                local pos,on = Camera:WorldToViewportPoint(part.Position)
                if on then
                    local fovDyn,_ = dynParams(dist)
                    local d2 = (Vector2.new(pos.X,pos.Y)-mouse).Magnitude
                    if d2 < fovDyn then
                        local score = d2 + dist*0.25
                        if score<bestScore then bestScore, best, bestDist = score, part, dist end
                    end
                end
            end
        end
    end
    return best, bestDist
end

--// ================= ADMIN PROTECT =================
local function isAdmin(plr)
    local n = plr.Name:lower(); for _,k in pairs(cfg.ADMIN_KEYWORDS) do if n:find(k) then return true end end
end
local function panic(reason)
    status.Text = "Status: PANIC ("..reason..")"; status.TextColor3 = Color3.fromRGB(255,80,80)
    cfg.AIM=false; cfg.ESP=false
    if cfg.AUTO_DISABLE_ON_ADMIN then task.wait(1.2); pcall(function() TeleportService:Teleport(game.PlaceId, LP) end) end
end
for _,p in pairs(Players:GetPlayers()) do if isAdmin(p) then panic("ADMIN") end end
Players.PlayerAdded:Connect(function(p) if isAdmin(p) then panic("ADMIN JOIN") end end)

--// ================= LOOP =================
RunService.RenderStepped:Connect(function()
    local m = UserInputService:GetMouseLocation()
    fov.Position = UDim2.fromOffset(m.X, m.Y)
    fov.Visible = cfg.FOV_VISIBLE

    updateESP()

    if cfg.AIM and (not cfg.SHOOT_ONLY or shooting) then
        local tgt, dist = pickTarget()
        if tgt and not shouldMiss() then
            maybeDelay()
            local fovDyn, smooth = dynParams(dist)
            fov.Size = UDim2.new(0,fovDyn*2,0,fovDyn*2)
            local camPos = Camera.CFrame.Position
            local vel = tgt.AssemblyLinearVelocity
            local aimPos = tgt.Position + (vel * cfg.PREDICT_FACTOR)
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(camPos, aimPos), smooth)
        end
    end
end)

--// ================= PLAYERS =================
for _,p in pairs(Players:GetPlayers()) do if p.Character then addESP(p) end; p.CharacterAdded:Connect(function() task.wait(0.3); addESP(p) end) end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() task.wait(0.3); addESP(p) end) end)

print("✅ Combat Arena LEGIT++ Loaded")
