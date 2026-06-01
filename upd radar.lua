--- Drawing Player Radar
--- Made by topit
--- Modified (v1.3.4): Added Mobile Drag, Dynamic Sizing, Custom Start Pos, fixed Cardinal Math
local scriptver = 'v1.3.4-Player'

if ( _G.RadarKill ) then
    _G.RadarKill()
end

if ( not game:IsLoaded() ) then
    game.Loaded:Wait()
end

--- Settings ---
local existingSettings = _G.RadarSettings2 or {}
local settings = {
    --- Radar settings
    RADAR_LINES = true; 
    RADAR_LINE_DISTANCE = 50; 
    RADAR_SCALE = 1; 
    RADAR_RADIUS = 125; 
    RADAR_START_POS = Vector2.new(300, 250); -- Tọa độ hiển thị mặc định của tâm Radar khi chạy script
    RADAR_ROTATION = true; 
    SMOOTH_ROT = true; 
    SMOOTH_ROT_AMNT = 30; 
    CARDINAL_DISPLAY = true; 
    
    --- Marker settings
    DISPLAY_OFFSCREEN = true; 
    DISPLAY_TEAMMATES = true; 
    DISPLAY_TEAM_COLORS = true; 
    DISPLAY_FRIEND_COLORS = true; 
    DISPLAY_RGB_COLORS = false; 
    MARKER_SCALE_BASE = 1.25; 
    MARKER_SCALE_MAX = 1.25; 
    MARKER_SCALE_MIN = 0.75; 
    MARKER_FALLOFF = true; 
    MARKER_FALLOFF_AMNT = 125; 
    OFFSCREEN_TRANSPARENCY = 0.3; 
    USE_FALLBACK = false; 
    USE_QUADS = true; 
    USE_TEAM_COLORS = false; 
    VISIBLITY_CHECK = false; 
    
    --- Theme
    RADAR_THEME = {
        Outline = Color3.fromRGB(35, 35, 45); 
        Background = Color3.fromRGB(25, 25, 35); 
        DragHandle = Color3.fromRGB(50, 50, 255); 
        Cardinal_Lines = Color3.fromRGB(110, 110, 120); 
        Distance_Lines = Color3.fromRGB(65, 65, 75); 
        Generic_Marker = Color3.fromRGB(255, 25, 115); 
        Local_Marker = Color3.fromRGB(115, 25, 255); 
        Team_Marker = Color3.fromRGB(25, 115, 255); 
        Friend_Marker = Color3.fromRGB(25, 255, 115); 
    };
}

for k, v in pairs(existingSettings) do 
    if ( v ~= nil ) then settings[k] = v end
end

local RADAR_LINES = settings.RADAR_LINES
local RADAR_LINE_DISTANCE = settings.RADAR_LINE_DISTANCE
local RADAR_SCALE = settings.RADAR_SCALE
local RADAR_RADIUS = settings.RADAR_RADIUS
local RADAR_ROTATION = settings.RADAR_ROTATION
local SMOOTH_ROT = settings.SMOOTH_ROT
local SMOOTH_ROT_AMNT = settings.SMOOTH_ROT_AMNT
local CARDINAL_DISPLAY = settings.CARDINAL_DISPLAY

local DISPLAY_OFFSCREEN = settings.DISPLAY_OFFSCREEN
local DISPLAY_TEAMMATES = settings.DISPLAY_TEAMMATES
local DISPLAY_TEAM_COLORS = settings.DISPLAY_TEAM_COLORS
local DISPLAY_FRIEND_COLORS = settings.DISPLAY_FRIEND_COLORS
local DISPLAY_RGB_COLORS = settings.DISPLAY_RGB_COLORS
local MARKER_SCALE_BASE = settings.MARKER_SCALE_BASE
local MARKER_SCALE_MAX = settings.MARKER_SCALE_MAX
local MARKER_SCALE_MIN = settings.MARKER_SCALE_MIN
local MARKER_FALLOFF = settings.MARKER_FALLOFF
local MARKER_FALLOFF_AMNT = settings.MARKER_FALLOFF_AMNT
local OFFSCREEN_TRANSPARENCY = settings.OFFSCREEN_TRANSPARENCY
local USE_FALLBACK = settings.USE_FALLBACK
local USE_QUADS = settings.USE_QUADS
local USE_TEAM_COLORS = settings.USE_TEAM_COLORS
local VISIBLITY_CHECK = settings.VISIBLITY_CHECK

if ( DISPLAY_RGB_COLORS and DISPLAY_TEAM_COLORS ) then DISPLAY_TEAM_COLORS = false end
local RADAR_THEME = settings.RADAR_THEME 

--- Services ---
local inputService = game:GetService('UserInputService')
local playerService = game:GetService('Players')
local runService = game:GetService('RunService')
local starterGui = game:GetService('StarterGui')

local newV2 = Vector2.new
local newV3 = Vector3.new
local mathSin = math.sin
local mathCos = math.cos
local mathExp = math.exp

local scriptCns = {}
local radarObjects = {}

local markerScale = math.clamp(RADAR_SCALE, MARKER_SCALE_MIN, MARKER_SCALE_MAX) * MARKER_SCALE_BASE
local scaleVec = newV2(markerScale, markerScale)
local quadPointA = newV2(0, 5)   * scaleVec
local quadPointB = newV2(4, -5)  * scaleVec
local quadPointC = newV2(0, -3)  * scaleVec
local quadPointD = newV2(-4, -5) * scaleVec

--- Drawing setup ---
local drawObjects = {}
local function newDrawObj(objectClass, objectProperties)
    local obj = Drawing.new(objectClass)
    table.insert(drawObjects, obj)
    for i, v in pairs(objectProperties) do obj[i] = v end
    return obj
end

local tweenExp, tweenQuad do
    local function numLerp(a, b, c) return (1 - c) * a + c * b end
    local tweenTypes = { Vector2 = Vector2.zero.Lerp, number = numLerp, Color3 = Color3.new().Lerp }
    
    function tweenExp(obj, property, dest, duration) 
        task.spawn(function()
            local initialVal = obj[property]
            local tweenTime = 0
            local lerpFunc = tweenTypes[typeof(dest)]
            while ( tweenTime < duration ) do 
                obj[property] = lerpFunc(initialVal, dest, 1 - math.pow(2, -10 * tweenTime / duration))
                tweenTime += task.wait()
            end
            obj[property] = dest
        end)
    end
    function tweenQuad(obj, property, dest, duration, func) 
        task.spawn(function()
            local initialVal = obj[property]
            local tweenTime = 0
            local lerpFunc = tweenTypes[typeof(dest)]
            while ( tweenTime < duration ) do 
                obj[property] = lerpFunc(initialVal, dest, 1 - (1 - tweenTime / duration) * (1 - tweenTime / duration))
                if ( func ) then func(obj[property]) end
                tweenTime += task.wait()
            end
            obj[property] = dest
        end)
    end
end

local errMessage = 'Failed to get the %s instance. Your game may be unsupported, or simply has not finished loading.'
local clientPlayer = playerService.LocalPlayer

if ( not clientPlayer ) then
    for _, con in pairs(scriptCns) do con:Disconnect() end
    return messagebox(string.format(errMessage, 'LocalPlayer'), 'Player Radar', 0)
end

local clientRoot do 
    scriptCns.charRespawn = clientPlayer.CharacterAdded:Connect(function(newChar) 
        clientRoot = newChar:WaitForChild('HumanoidRootPart')
        if ( clientRoot ) then
            radarObjects.loadText.Visible = false 
            radarObjects.loadOverlay.Visible = false  
        else
            radarObjects.loadText.Visible = true 
            radarObjects.loadOverlay.Visible = true  
        end
    end)
    if ( clientPlayer.Character ) then clientRoot = clientPlayer.Character:FindFirstChild('HumanoidRootPart') end
end

local clientCamera = workspace.CurrentCamera or workspace:FindFirstChildOfClass('Camera')
scriptCns.cameraUpdate = workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function() 
    clientCamera = workspace.CurrentCamera or workspace:FindFirstChildOfClass('Camera')
end)

local clientTeam = clientPlayer.Team
scriptCns.teamUpdate = clientPlayer:GetPropertyChangedSignal('Team'):Connect(function() clientTeam = clientPlayer.Team end)

--- PlaceID Check & Notification --- 
do
    local thisId = game.PlaceId
    local retardedGames = {292439477; 3233893879; 8130299583; 9570110925;}
    local gameNotes = {[379614936] = 'This game is known to fuck up the radar - waiting a round should fix'; [2474168535] = 'Players that are lassoed don\'t appear on the radar properly';}
    
    local halfWidth = clientCamera.ViewportSize.X / 2
    local notif = Drawing.new('Text')
    notif.Center = true; notif.Color = Color3.fromRGB(255, 255, 255); notif.Font = Drawing.Fonts.UI; notif.Outline = true
    notif.Position = newV2(halfWidth, 200); notif.Size = 18; notif.Transparency = 0; notif.Visible = true; notif.ZIndex = 500 
    
    if ( table.find(retardedGames, thisId) ) then
        notif.Text = 'Games with custom character systems\naren\'t supported. Sorry!'
        tweenExp(notif, 'Transparency', 1, 0.25)
        tweenExp(notif, 'Position', newV2(halfWidth, 150), 0.25)
        task.wait(5)
        for _, con in pairs(scriptCns) do con:Disconnect() end
        notif:Remove()
        return
    else
        notif.Text = ('Loaded Drawing Radar %s\n[PC] [-/+] Tăng giảm Zoom | [[ / ]] Co giãn Radar\n[PC & MOBILE] Chạm giữ/Click vào tâm Radar để Kéo Thả vị trí!'):format(scriptver) 
        local gameWarning = gameNotes[thisId]
        if ( gameWarning ) then notif.Text = notif.Text .. string.format('\n\nGame warning: %s', gameWarning) end
        
        task.spawn(function()
            tweenExp(notif, 'Transparency', 1, 0.25)
            tweenExp(notif, 'Position', newV2(halfWidth, 150), 0.25)
            task.wait(gameWarning and 10 or 7)
            tweenExp(notif, 'Position', newV2(halfWidth, 200), 0.25)
            tweenExp(notif, 'Transparency', 0, 0.25)
            task.wait(0.5)
            if ( workspace.StreamingEnabled ) then
                notif.Text = 'It looks like this game uses StreamingEnabled - Fallback mode is now enabled.'
                tweenExp(notif, 'Transparency', 1, 0.25); tweenExp(notif, 'Position', newV2(halfWidth, 150), 0.25); task.wait(5)
                tweenExp(notif, 'Position', newV2(halfWidth, 200), 0.25); tweenExp(notif, 'Transparency', 0, 0.25); task.wait(1)
            end
            notif:Remove()
        end)
    end
end

--- Player managers --- 
if ( workspace.StreamingEnabled ) then 
    USE_FALLBACK = true 
    warn("Radar: StreamingEnabled detected, using robust tracking.")
end

local playerManagers = {}
if ( game.PlaceId == 292439477 ) then 
    local function removePlayer(player) end
    local function readyPlayer(thisPlayer) end
    for _, player in ipairs(playerService:GetPlayers()) do if ( player ~= clientPlayer ) then readyPlayer(player) end end
    scriptCns.pm_playerAdd = playerService.PlayerAdded:Connect(readyPlayer)
    scriptCns.pm_playerRemove = playerService.PlayerRemoving:Connect(removePlayer)
else
    local function removePlayer(player) 
        local thisName = player.Name
        local thisManager = playerManagers[thisName]
        if ( not thisManager ) then return end
        local thisPlayerCns = thisManager.Cns
        if ( thisManager.onLeave ) then thisManager.onLeave() end
        for _, con in pairs(thisPlayerCns) do con:Disconnect() end
        thisManager.onDeath = nil; thisManager.onLeave = nil; thisManager.onRemoval = nil; thisManager.onRespawn = nil; thisManager.onTeamChange = nil; thisManager.Player = nil
        playerManagers[thisName] = nil 
    end
    
    local function readyPlayer(thisPlayer) 
        if playerManagers[thisPlayer.Name] then return end -- Tránh add trùng
        
        local thisName = thisPlayer.Name
        local thisManager = {}
        local thisPlayerCns = {}
        
        local function deathFunc() if ( thisManager.onDeath ) then thisManager.onDeath() end end

        thisPlayerCns['chr-add'] = thisPlayer.CharacterAdded:Connect(function(newChar)
            if ( USE_FALLBACK ) then thisManager.Character = newChar return end
            local RootPart = newChar:WaitForChild('HumanoidRootPart')
            local Humanoid = newChar:WaitForChild('Humanoid')
            if ( thisManager.onRespawn ) then thisManager.onRespawn() end
            thisManager.Character = newChar; thisManager.RootPart = RootPart; thisManager.Humanoid = Humanoid
            if ( thisPlayerCns['chr-die'] ) then thisPlayerCns['chr-die']:Disconnect() end
            thisPlayerCns['chr-die'] = Humanoid.Died:Connect(deathFunc)
        end)

        thisPlayerCns['chr-remove'] = thisPlayer.CharacterRemoving:Connect(function()
            if ( USE_FALLBACK ) then thisManager.Character = nil return end
            if ( thisManager.onRemoval ) then thisManager.onRemoval() end
            thisManager.Character = nil; thisManager.RootPart = nil; thisManager.Humanoid = nil 
        end)
        
        thisPlayerCns['team'] = thisPlayer:GetPropertyChangedSignal('Team'):Connect(function()
            thisManager.Team = thisPlayer.Team
            if ( thisManager.onTeamChange ) then thisManager.onTeamChange(thisManager.Team) end
        end)
        
        if ( thisPlayer.Character ) then
            local Character = thisPlayer.Character
            local Humanoid = Character:FindFirstChild('Humanoid')
            local RootPart = Character:FindFirstChild('HumanoidRootPart')
            thisManager.Character = Character; thisManager.RootPart = RootPart; thisManager.Humanoid = Humanoid 
            if ( Humanoid ) then thisPlayerCns['chr-die'] = Humanoid.Died:Connect(deathFunc) end
        end
        
        thisManager.Team = thisPlayer.Team; thisManager.Player = thisPlayer; thisManager.Name = thisName; thisManager.DisplayName = thisPlayer.DisplayName  
        thisManager.Friended = clientPlayer:IsFriendsWith(thisPlayer.UserId)
        
        -- Hàm định vị cải tiến của bạn
        thisManager.GetCFrame = function()
            local root = thisManager.RootPart
            if root and root.Parent then return root.CFrame end

            local char = thisManager.Player.Character
            if char and char.Parent then
                local newRoot = char:FindFirstChild("HumanoidRootPart")
                if newRoot then
                    thisManager.RootPart = newRoot
                    return newRoot.CFrame
                end
                return char:GetPivot()
            end
            return nil
        end
        
        thisManager.Cns = thisPlayerCns 
        playerManagers[thisName] = thisManager
    end
    
    -- Khởi tạo ban đầu
    for _, player in ipairs(playerService:GetPlayers()) do if ( player ~= clientPlayer ) then readyPlayer(player) end end
    scriptCns.pm_playerAdd = playerService.PlayerAdded:Connect(readyPlayer)
    scriptCns.pm_playerRemove = playerService.PlayerRemoving:Connect(removePlayer)

    -- Vòng lặp quét dự phòng (Fix lỗi người chơi mới vào ko hiện)
    task.spawn(function()
        while true do
            task.wait(3)
            for _, player in ipairs(playerService:GetPlayers()) do
                if (player ~= clientPlayer and not playerManagers[player.Name]) then
                    readyPlayer(player)
                end
            end
        end
    end)
end


--- Radar UI --- 
local radarLines = {}
local radarPosition = settings.RADAR_START_POS or newV2(300, 250)

radarObjects.main = newDrawObj('Circle', {Color = RADAR_THEME.Background; Position = radarPosition; Filled = true; Visible = true; NumSides = 40; Radius = RADAR_RADIUS; ZIndex = 300;})
radarObjects.outline = newDrawObj('Circle', {Color = RADAR_THEME.Outline; Position = radarPosition; Filled = false; Visible = true; NumSides = 40; Thickness = 10; Radius = RADAR_RADIUS; ZIndex = 299;})
radarObjects.dragHandle = newDrawObj('Circle', {Color = RADAR_THEME.DragHandle; Position = radarPosition; Filled = false; Visible = false; NumSides = 40; Radius = RADAR_RADIUS; Thickness = 3; ZIndex = 325;})
radarObjects.loadOverlay = newDrawObj('Circle', {Color = Color3.new(0, 0, 0); Filled = true; NumSides = 40; Position = radarPosition; Radius = RADAR_RADIUS; Transparency = 0.5; Visible = clientRoot == nil; ZIndex = 319;})
radarObjects.loadText = newDrawObj('Text', {Center = true; Color = Color3.fromRGB(255, 255, 255); Font = Drawing.Fonts.UI; Outline = true; Position = radarPosition - newV2(0, 15); Size = 20; Text = 'Waiting for you to spawn in...'; Transparency = 1; Visible = clientRoot == nil; ZIndex = 320;})
radarObjects.zoomText = newDrawObj('Text', {Center = true; Color = Color3.fromRGB(255, 255, 255); Font = Drawing.Fonts.UI; Outline = true; Size = 16; Transparency = 0; Visible = false; ZIndex = 306;})
radarObjects.hoverText = newDrawObj('Text', {Center = true; Color = Color3.fromRGB(255, 255, 255); Font = Drawing.Fonts.UI; Outline = true; Position = radarPosition; Size = 16; Transparency = 1; Visible = false; ZIndex = 306;})

if ( USE_QUADS ) then 
    radarObjects.localMark = newDrawObj('Quad', {Color = RADAR_THEME.Local_Marker; Filled = true; Thickness = 2; Visible = true; ZIndex = 305;})
    radarObjects.localMarkStroke = newDrawObj('Quad', {Color = RADAR_THEME.Local_Marker; Filled = false; Thickness = 2; Visible = true; ZIndex = 304;})
else
    radarObjects.localMark = newDrawObj('Circle', {Color = RADAR_THEME.Local_Marker; Filled = true; NumSides = 20; Thickness = 2; Visible = true; ZIndex = 305;})
    radarObjects.localMarkStroke = newDrawObj('Circle', {Color = RADAR_THEME.Local_Marker; Filled = false; NumSides = 20; Thickness = 1; Visible = true; ZIndex = 304;})
end

local function updateRadarLines()
    for _, l in ipairs(radarLines) do l:Remove() end
    radarLines = {}
    if not RADAR_LINES then return end
    local lineCount = math.floor(RADAR_RADIUS / (RADAR_SCALE * RADAR_LINE_DISTANCE))
    for i = 1, lineCount do
        local lineRadius = i * (RADAR_SCALE * RADAR_LINE_DISTANCE)
        if lineRadius < RADAR_RADIUS then
            local thisLine = newDrawObj('Circle', {
                Color = RADAR_THEME.Distance_Lines; Position = radarPosition; Radius = lineRadius;
                Filled = false; Visible = true; Transparency = (i % 4 == 0) and 0.8 or 0.2; NumSides = 40; Thickness = 1; ZIndex = 300;
            })
            table.insert(radarLines, thisLine)
        end
    end
end

if RADAR_LINES then 
    radarObjects.horizontalLine = newDrawObj('Line', {Color = RADAR_THEME.Cardinal_Lines; Visible = true; Thickness = 1; Transparency = 0.2; ZIndex = 300;})
    radarObjects.verticalLine = newDrawObj('Line', {Color = RADAR_THEME.Cardinal_Lines; Visible = true; Thickness = 1; Transparency = 0.2; ZIndex = 300;})
    updateRadarLines()
end

if CARDINAL_DISPLAY then
    radarObjects.directionN = newDrawObj('Text', {Center = true; Color = Color3.fromRGB(255, 75, 75); Font = Drawing.Fonts.UI; Outline = true; Size = 16; Text = 'N'; Visible = true; ZIndex = 303;})
    radarObjects.directionS = newDrawObj('Text', {Center = true; Color = Color3.new(1,1,1); Font = Drawing.Fonts.UI; Outline = true; Size = 14; Text = 'S'; Visible = true; ZIndex = 303;})
    radarObjects.directionW = newDrawObj('Text', {Center = true; Color = Color3.new(1,1,1); Font = Drawing.Fonts.UI; Outline = true; Size = 14; Text = 'W'; Visible = true; ZIndex = 303;})
    radarObjects.directionE = newDrawObj('Text', {Center = true; Color = Color3.new(1,1,1); Font = Drawing.Fonts.UI; Outline = true; Size = 14; Text = 'E'; Visible = true; ZIndex = 303;})
end

local destroying = false 
local function killScript()
    if ( destroying ) then return end 
    destroying = true
    for _, con in pairs(scriptCns) do con:Disconnect() end
    task.wait()
    for name, manager in pairs(playerManagers) do 
        for _, con in pairs(manager.Cns) do con:Disconnect() end
        manager.onDeath = nil; manager.onLeave = nil; manager.onRespawn = nil; manager.onRemoval = nil; manager.onTeamChange = nil; playerManagers[name] = nil 
    end
    for _, obj in ipairs(drawObjects) do tweenExp(obj, 'Transparency', 0, 0.5) end
    task.wait(1)
    if ( not drawObjects ) then return end
    for _, obj in ipairs(drawObjects) do obj:Remove() end
    _G.RadarKill = nil; drawObjects = nil
end

local function setRadarScale() 
    markerScale = math.clamp(RADAR_SCALE, MARKER_SCALE_MIN, MARKER_SCALE_MAX) * MARKER_SCALE_BASE
    updateRadarLines()
    if ( USE_QUADS ) then 
        scaleVec = newV2(markerScale, markerScale)
        quadPointA = newV2(0, 5)   * scaleVec
        quadPointB = newV2(4, -5)  * scaleVec
        quadPointC = newV2(0, -3)  * scaleVec
        quadPointD = newV2(-4, -5) * scaleVec
    else
        radarObjects.localMark.Radius = markerScale * 3
        radarObjects.localMarkStroke.Radius = markerScale * 3 
    end
end

local function updateRadarSize()
    radarObjects.main.Radius = RADAR_RADIUS
    radarObjects.outline.Radius = RADAR_RADIUS
    radarObjects.dragHandle.Radius = RADAR_RADIUS
    radarObjects.loadOverlay.Radius = RADAR_RADIUS
    setRadarScale()
end

local function setRadarPosition(newPosition)
    radarPosition = newPosition
    radarObjects.main.Position = newPosition
    radarObjects.outline.Position = newPosition
    radarObjects.loadOverlay.Position = newPosition
    radarObjects.loadText.Position = newPosition - newV2(0, 15)
    updateRadarLines()
    radarObjects.hoverText.Position = newPosition
end

--- Input and drag handling (PC & Mobile Drag v1.3.4) ---
do
    local radarDragging = false
    local currentTouchInput = nil
    
    scriptCns.inputBegan = inputService.InputBegan:Connect(function(io) 
        local inputType = io.UserInputType.Name

        if ( inputType == 'Keyboard' ) then
            local keyCode = io.KeyCode.Name
            if ( keyCode == 'End' ) then
                killScript() 
            elseif ( keyCode == 'Equals' ) then
                radarObjects.zoomText.Position = radarPosition + newV2(0, RADAR_RADIUS + 20)
                radarObjects.zoomText.Visible = true
                scriptCns.zoomInCn = runService.Heartbeat:Connect(function(dt) 
                    RADAR_SCALE = math.clamp(RADAR_SCALE + (dt * 1.2), 0.05, 5)
                    radarObjects.zoomText.Text = ('Scale: %.2f'):format(RADAR_SCALE)
                    setRadarScale()
                end)
            elseif ( keyCode == 'Minus' ) then
                radarObjects.zoomText.Position = radarPosition + newV2(0, RADAR_RADIUS + 20)
                radarObjects.zoomText.Visible = true
                scriptCns.zoomOutCn = runService.Heartbeat:Connect(function(dt) 
                    RADAR_SCALE = math.clamp(RADAR_SCALE - (dt * 1.2), 0.05, 5)
                    radarObjects.zoomText.Text = ('Scale: %.2f'):format(RADAR_SCALE)
                    setRadarScale()
                end)    
            elseif ( keyCode == 'LeftBracket' ) then 
                radarObjects.zoomText.Position = radarPosition + newV2(0, RADAR_RADIUS + 20)
                radarObjects.zoomText.Visible = true
                scriptCns.sizeDownCn = runService.Heartbeat:Connect(function(dt)
                    RADAR_RADIUS = math.clamp(RADAR_RADIUS - (dt * 60), 50, 400)
                    radarObjects.zoomText.Text = ('Radar Size: %d'):format(RADAR_RADIUS)
                    updateRadarSize()
                end)
            elseif ( keyCode == 'RightBracket' ) then 
                radarObjects.zoomText.Position = radarPosition + newV2(0, RADAR_RADIUS + 20)
                radarObjects.zoomText.Visible = true
                scriptCns.sizeUpCn = runService.Heartbeat:Connect(function(dt)
                    RADAR_RADIUS = math.clamp(RADAR_RADIUS + (dt * 60), 50, 400)
                    radarObjects.zoomText.Text = ('Radar Size: %d'):format(RADAR_RADIUS)
                    updateRadarSize()
                end)
            end
            
        elseif ( inputType == 'MouseButton1' or inputType == 'Touch' ) then
            local startPos = (inputType == 'Touch') and newV2(io.Position.X, io.Position.Y) or inputService:GetMouseLocation()
            if ( (startPos - radarPosition).Magnitude < RADAR_RADIUS ) then
                radarDragging = true
                if inputType == 'Touch' then currentTouchInput = io end
                
                radarObjects.dragHandle.Position = radarPosition
                radarObjects.dragHandle.Visible = true
                
                scriptCns.dragCn = inputService.InputChanged:Connect(function(i) 
                    if (i.UserInputType.Name == 'MouseMovement' and not currentTouchInput) or (i.UserInputType.Name == 'Touch' and i == currentTouchInput) then
                        local movePos = (i.UserInputType.Name == 'Touch') and newV2(i.Position.X, i.Position.Y) or inputService:GetMouseLocation()
                        radarObjects.dragHandle.Position = movePos
                        setRadarPosition(movePos) 
                    end
                end)
            end
        end
    end)

    scriptCns.inputEnded = inputService.InputEnded:Connect(function(io) 
        local inputType = io.UserInputType.Name
        if ( inputType == 'Keyboard' ) then
            if ( scriptCns.zoomInCn ) then scriptCns.zoomInCn:Disconnect() end
            if ( scriptCns.zoomOutCn ) then scriptCns.zoomOutCn:Disconnect() end
            if ( scriptCns.sizeDownCn ) then scriptCns.sizeDownCn:Disconnect() end
            if ( scriptCns.sizeUpCn ) then scriptCns.sizeUpCn:Disconnect() end
            task.delay(1.5, function() if not radarDragging then radarObjects.zoomText.Visible = false end end)
            
        elseif ( (inputType == 'MouseButton1' and not currentTouchInput) or (inputType == 'Touch' and io == currentTouchInput) ) then
            if ( radarDragging ) then
                if scriptCns.dragCn then scriptCns.dragCn:Disconnect() end
                radarDragging = false 
                currentTouchInput = nil
                setRadarPosition(radarObjects.dragHandle.Position)
                radarObjects.dragHandle.Visible = false 
            end
        end
    end)
end

--- Player marker setup ---
local playerMarks = {} do 
    local function initMark(thisPlayer)
        local thisName = thisPlayer.Name 
        local thisManager = playerManagers[thisName]
        
        if ( not thisManager ) then 
            for i = 1, 10 do 
                thisManager = playerManagers[thisName]
                if ( thisManager ) then break end
                task.wait(0.5)
            end 
            if ( not thisManager ) then return end
        end
        
        local markers = {} 
        local markMain
        local markStroke
        
        if ( USE_QUADS ) then 
            markMain = Drawing.new('Quad'); markMain.Filled = true; markMain.Thickness = 2; markMain.Visible = true; markMain.ZIndex = 303
            markStroke = Drawing.new('Quad'); markStroke.Filled = false; markStroke.Thickness = 2; markStroke.Transparency = 0; markStroke.ZIndex = 302
        else
            markMain = Drawing.new('Circle'); markMain.Filled = true; markMain.NumSides = 20; markMain.Radius = markerScale * 3; markMain.Thickness = 2; markMain.Visible = true; markMain.ZIndex = 303
            markStroke = Drawing.new('Circle'); markStroke.Filled = false; markStroke.NumSides = 20; markStroke.Radius = markerScale * 3; markStroke.Thickness = 1; markStroke.Visible = true; markStroke.ZIndex = 302
        end
        
        table.insert(drawObjects, markMain); table.insert(drawObjects, markStroke)
        
        thisManager.onDeath = function() markMain.Filled = false end
        thisManager.onRespawn = function() markMain.Filled = true; markMain.Visible = true; markStroke.Visible = true end
        thisManager.onRemoval = function() markMain.Visible = false; markStroke.Visible = false end
        thisManager.onLeave = function()
            table.remove(drawObjects, table.find(drawObjects, markMain))
            table.remove(drawObjects, table.find(drawObjects, markStroke))
            task.spawn(function() tweenExp(markMain, 'Transparency', 0, 1); tweenExp(markStroke, 'Transparency', 0, 1); task.wait(1.5); markMain:Remove(); markStroke:Remove() end)
            playerMarks[thisName] = nil
        end
        
                -- [ĐÃ SỬA] Hàm lấy màu tự động theo Team thời gian thực
        local function getPlayerColor(player, manager, team)
            if DISPLAY_FRIEND_COLORS and manager.Friended then return RADAR_THEME.Friend_Marker end
            
            -- Ưu tiên hiển thị màu tự động theo màu gốc của Team trong game
            if DISPLAY_TEAM_COLORS then
                if team and team:IsA("Team") then
                    return team.TeamColor.Color -- Lấy trực tiếp màu của Team đó
                elseif player.TeamColor then
                    return player.TeamColor.Color -- Fallback theo TeamColor của Player
                end
                
                -- Nếu không bật chọn màu tự động của game thì mới dùng màu Theme cố định
                if team == clientTeam then 
                    return RADAR_THEME.Team_Marker
                else 
                    return RADAR_THEME.Generic_Marker 
                end
            end
            return RADAR_THEME.Generic_Marker
        end

        -- [ĐÃ SỬA] Kích hoạt sự kiện đổi màu Marker ngay khi Player đổi Team
        if ( DISPLAY_TEAM_COLORS ) then 
            thisManager.onTeamChange = function(team) 
                if ( DISPLAY_FRIEND_COLORS and thisManager.Friended ) then return end
                local color = getPlayerColor(thisPlayer, thisManager, team)
                markMain.Color = color; markStroke.Color = color
            end
        end 
        
        -- Khởi tạo màu ban đầu khi cài đặt Marker
        local initColor = getPlayerColor(thisPlayer, thisManager, thisPlayer.Team)
        markMain.Color = initColor; markStroke.Color = initColor 

        
        markers.main = markMain; markers.stroke = markStroke
        if ( thisManager.Humanoid and thisManager.Humanoid.Health == 0 ) then thisManager.onDeath() end
        playerMarks[thisName] = markers
        return markers
    end
    
    for _, manager in pairs(playerManagers) do initMark(manager.Player) end
    scriptCns.addMarks = playerService.PlayerAdded:Connect(function(player) task.wait(0.3); initMark(player) end)
end

local hoverPlayer
-- Hover display hỗ trợ PC & Mobile Touch
do 
    local lastCheckTime = 0
    scriptCns.inputChanged = inputService.InputChanged:Connect(function(input) 
        local nowTime = tick() 
        local inputType = input.UserInputType.Name

        if ( nowTime - lastCheckTime > 0.03 and (inputType == 'MouseMovement' or inputType == 'Touch') ) then
            lastCheckTime = nowTime
            local mousePos = (inputType == 'Touch') and newV2(input.Position.X, input.Position.Y) or inputService:GetMouseLocation()
            
            if ( (mousePos - radarPosition).Magnitude < RADAR_RADIUS ) then
                local distanceThresh = 20 
                hoverPlayer = nil
                
                for thisName in pairs(playerManagers) do 
                    local thisMark = playerMarks[thisName]
                    if ( not thisMark ) then continue end
                    
                    local markPos = thisMark.main[USE_QUADS and 'PointD' or 'Position']
                    local distance = (mousePos - markPos).Magnitude

                    if ( distance < distanceThresh ) then
                        distanceThresh = distance
                        hoverPlayer = thisName
                    end
                end
                if ( hoverPlayer == nil ) then radarObjects.hoverText.Visible = false end
            else
                hoverPlayer = nil; radarObjects.hoverText.Visible = false 
            end
        end
    end)
end

--- Main radar loop ---
local function cartToPolar(x, y) return math.sqrt(x^2 + y^2), math.atan2(y, x) end
local function polarToCart(r, t) return r * mathCos(t), r * mathSin(t) end

do
    local finalLookVec = Vector3.zero
    local textOffset = newV2(0, 5)
    local rad90 = math.rad(90)
    local rad180 = math.rad(180)
    
    local rayParams
    if ( VISIBLITY_CHECK ) then
        rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
        rayParams.FilterDescendantsInstances = { clientPlayer.Character }
        scriptCns.rayUpdate = clientPlayer.CharacterAdded:Connect(function(newChar) rayParams.FilterDescendantsInstances = { newChar } end)
    end
    
    scriptCns.radarLoop = runService.Heartbeat:Connect(function(deltaTime) 
        if ( not clientRoot ) then return end

        local selfPos = clientRoot.Position
        local cameraPos
        local camAngle = 0 

        -- Camera angle
        do 
            if ( RADAR_ROTATION ) then 
                local cameraLookVec = clientCamera.CFrame.LookVector
                local fixedLookVec = newV3(cameraLookVec.X, 0, cameraLookVec.Z).Unit
                if ( SMOOTH_ROT ) then
                    finalLookVec = finalLookVec:Lerp(fixedLookVec, 1 - mathExp(-SMOOTH_ROT_AMNT * deltaTime))
                else
                    finalLookVec = fixedLookVec
                end
                camAngle = math.atan2(finalLookVec.X, finalLookVec.Z)
            else
                camAngle = rad180
            end
            cameraPos = clientCamera.CFrame.Position 
        end
        
                -- Vertical and horizontal lines (Fixed Cardinal Math)
        do 
            if ( RADAR_LINES ) then
                local cosA, sinA = mathCos(-camAngle), mathSin(-camAngle)
                local posN = radarPosition + newV2(sinA, -cosA) * RADAR_RADIUS
                local posS = radarPosition + newV2(-sinA, cosA) * RADAR_RADIUS
                local posE = radarPosition + newV2(cosA, sinA) * RADAR_RADIUS
                local posW = radarPosition + newV2(-cosA, -sinA) * RADAR_RADIUS
                
                radarObjects.verticalLine.From = posN;   radarObjects.verticalLine.To = posS
                radarObjects.horizontalLine.From = posW; radarObjects.horizontalLine.To = posE
                
                if CARDINAL_DISPLAY then
                    -- Khoảng cách từ chữ đến rìa đường tròn (Thay đổi số 12 nếu muốn chữ xa/gần hơn)
                    local padding = 0
                    
                    -- Nhân khoảng cách trực tiếp với Vector xoay và trừ đi bán kính Font chữ để căn giữa chữ Y
                    radarObjects.directionN.Position = radarPosition + newV2(sinA, -cosA) * (RADAR_RADIUS + padding) - newV2(0, 8)
                    radarObjects.directionS.Position = radarPosition + newV2(-sinA, cosA) * (RADAR_RADIUS + padding) - newV2(0, 7)
                    radarObjects.directionE.Position = radarPosition + newV2(cosA, sinA) * (RADAR_RADIUS + padding) - newV2(0, 7)
                    radarObjects.directionW.Position = radarPosition + newV2(-cosA, -sinA) * (RADAR_RADIUS + padding) - newV2(0, 7)
                end
            end
        end

        
        -- Centermark
        do
            local localMark = radarObjects.localMark
            local localMarkStroke = radarObjects.localMarkStroke
            if ( USE_QUADS ) then
                local playerLookVec = clientRoot.CFrame.LookVector
                local angle = (math.atan2(playerLookVec.X, playerLookVec.Z) - camAngle) - rad90
                local angleCos = mathCos(angle)
                local angleSin = mathSin(angle)
                
                local fixedA = radarPosition + newV2((quadPointA.X * angleSin) - (quadPointA.Y * angleCos), (quadPointA.X * angleCos) + (quadPointA.Y * angleSin))
                local fixedB = radarPosition + newV2((quadPointB.X * angleSin) - (quadPointB.Y * angleCos), (quadPointB.X * angleCos) + (quadPointB.Y * angleSin))
                local fixedC = radarPosition + newV2((quadPointC.X * angleSin) - (quadPointC.Y * angleCos), (quadPointC.X * angleCos) + (quadPointC.Y * angleSin))
                local fixedD = radarPosition + newV2((quadPointD.X * angleSin) - (quadPointD.Y * angleCos), (quadPointD.X * angleCos) + (quadPointD.Y * angleSin))
                
                localMark.PointA = fixedA; localMark.PointB = fixedB; localMark.PointC = fixedC; localMark.PointD = fixedD
                localMarkStroke.PointA = fixedA; localMarkStroke.PointB = fixedB; localMarkStroke.PointC = fixedC; localMarkStroke.PointD = fixedD
            else
                localMark.Position = radarPosition; localMark.Radius = markerScale * 3
                localMarkStroke.Position = radarPosition; localMarkStroke.Radius = markerScale * 3
            end
        end
        
        -- Player marks
        do
            for thisName, thisManager in pairs(playerManagers) do 
                local thisMark = playerMarks[thisName]
                if ( not thisMark ) then continue end
                local main, stroke = thisMark.main, thisMark.stroke 
                
                if ( DISPLAY_TEAMMATES == false and thisManager.Team == clientTeam ) then 
                    thisMark.main.Visible = false; thisMark.stroke.Visible = false 
                    continue
                end
                
                local cframe = thisManager:GetCFrame()
                if ( not cframe ) then continue end 
                local position = cframe.Position 
                local posDelta = position - selfPos
                
                local radius, angle = cartToPolar(posDelta.X, posDelta.Z)
                local fixedRadius = radius * RADAR_SCALE 
                
                if ( fixedRadius > RADAR_RADIUS ) then
                    if ( DISPLAY_OFFSCREEN ) then 
                        main.Transparency = OFFSCREEN_TRANSPARENCY; stroke.Transparency = OFFSCREEN_TRANSPARENCY
                    else
                        main.Visible = false; stroke.Visible = false 
                        continue
                    end
                else
                    main.Visible = true; stroke.Visible = true 
                    main.Transparency = 1; stroke.Transparency = 1 
                end
                
                radius = math.clamp(fixedRadius, 0, RADAR_RADIUS)
                angle += (camAngle + rad180) 
                local x, y = polarToCart(radius, angle)
                local finalPos = radarPosition + newV2(x, y)
                
                if ( USE_QUADS ) then
                    local playerLookVec = cframe.LookVector
                    local angleQ = (math.atan2(playerLookVec.X, playerLookVec.Z)) - rad90 - camAngle
                    local angleCos = mathCos(angleQ)
                    local angleSin = mathSin(angleQ)
                    
                    local fixedA = newV2((quadPointA.X * angleSin) - (quadPointA.Y * angleCos), (quadPointA.X * angleCos) + (quadPointA.Y * angleSin))
                    local fixedB = newV2((quadPointB.X * angleSin) - (quadPointB.Y * angleCos), (quadPointB.X * angleCos) + (quadPointB.Y * angleSin))                
                    local fixedC = newV2((quadPointC.X * angleSin) - (quadPointC.Y * angleCos), (quadPointC.X * angleCos) + (quadPointC.Y * angleSin))  
                    local fixedD = newV2((quadPointD.X * angleSin) - (quadPointD.Y * angleCos), (quadPointD.X * angleCos) + (quadPointD.Y * angleSin))  
                    if ( MARKER_FALLOFF ) then
                        local scaleFalloff = math.clamp(MARKER_FALLOFF_AMNT / posDelta.Magnitude, 0.75, 1)
                        fixedA *= scaleFalloff; fixedB *= scaleFalloff; fixedC *= scaleFalloff; fixedD *= scaleFalloff
                    end
                    fixedA += finalPos; fixedB += finalPos; fixedC += finalPos; fixedD += finalPos
                    
                    main.PointA = fixedA; main.PointB = fixedB; main.PointC = fixedC; main.PointD = fixedD
                    stroke.PointA = fixedA; stroke.PointB = fixedB; stroke.PointC = fixedC; stroke.PointD = fixedD
                else                    
                    local dotRadius = markerScale * 3
                    if ( MARKER_FALLOFF ) then dotRadius *= math.clamp(MARKER_FALLOFF_AMNT / posDelta.Magnitude, 0.75, 1) end
                    main.Radius = dotRadius; main.Position = finalPos
                    stroke.Radius = dotRadius; stroke.Position = finalPos
                end
                
                if ( hoverPlayer == thisName ) then
                    local text = radarObjects.hoverText 
                    text.Text = string.format('%s\n(%d studs away)', thisManager.DisplayName, posDelta.Magnitude)
                    text.Size = math.clamp(16 * RADAR_SCALE, 16, 24)
                    text.Visible = true
                    text.Position = text.Position:Lerp(finalPos + textOffset, 1 - mathExp(-30 * deltaTime))
                end
                
                if ( VISIBLITY_CHECK ) then
                    local direction = ( position - cameraPos ).Unit * 12345
                    local raycast = workspace:Raycast(cameraPos, direction, rayParams)
                    if ( raycast ) then
                        if ( ( raycast.Position - position ).Magnitude > 4 ) then
                            main.Transparency /= 5; stroke.Transparency /= 5
                        end
                    else
                        main.Transparency /= 5; stroke.Transparency /= 5
                    end 
                end
            end
        end
    end)
    
    if ( DISPLAY_RGB_COLORS ) then
        local hue = 0
        scriptCns.rgbLoop = runService.Heartbeat:Connect(function(deltaTime) 
            hue += deltaTime / 20
            if ( hue > 1 ) then hue -= 1 end
            local color = Color3.fromHSV(hue, 0.9, 0.9)
            
            for thisName, thisManager in pairs(playerManagers) do 
                local thisMark = playerMarks[thisName]
                if ( not thisMark ) then continue end
                if ( DISPLAY_FRIEND_COLORS and thisManager.Friended ) then continue end
                thisMark.main.Color = color; thisMark.stroke.Color = color 
            end
        end)
    end
end

--- Setup friend handling ---
do
    scriptCns.pm_friendAdd = starterGui:GetCore('PlayerFriendedEvent').Event:Connect(function(player)
        local name = player.Name
        local mark = playerMarks[name]
        local manager = playerManagers[name]
        if ( manager ) then 
            manager.Friended = true 
            if ( mark and DISPLAY_FRIEND_COLORS ) then mark.main.Color = RADAR_THEME.Friend_Marker; mark.stroke.Color = RADAR_THEME.Friend_Marker end
        end
    end)
    
    scriptCns.pm_friendRemove = starterGui:GetCore('PlayerUnfriendedEvent').Event:Connect(function(player)
        local name = player.Name
        local mark = playerMarks[name]
        local manager = playerManagers[name]
        if ( manager ) then 
            manager.Friended = false 
            if ( mark ) then 
                local color
                -- [ĐÃ SỬA] Trả về đúng màu tự động của Team khi hủy kết bạn
                if ( DISPLAY_TEAM_COLORS ) then  
                    if player.Team and player.Team:IsA("Team") then
                        color = player.Team.TeamColor.Color
                    else
                        color = player.TeamColor.Color
                    end
                else 
                    color = RADAR_THEME.Generic_Marker 
                end
                mark.main.Color = color; markStroke.Color = color
            end
        end
    end)

end

_G.RadarKill = killScript
