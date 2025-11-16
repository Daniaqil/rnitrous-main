local durability = 1.0
local boosting = false
local cooldown = false

local ptfxLoaded = false
local exhaustFx = {}
local exhaustBones = {
    "exhaust","exhaust_2","exhaust_3","exhaust_4",
    "exhaust_5","exhaust_6","exhaust_7","exhaust_8"
}

-- Load PTFX (same as original)
local function ensurePtfx()
    if ptfxLoaded then return end

    if Config.UseArenaPtfxIfAvailable then
        RequestNamedPtfxAsset("veh_xs_vehicle_mods")
        local expire = GetGameTimer() + 2000
        while not HasNamedPtfxAssetLoaded("veh_xs_vehicle_mods") 
            and GetGameTimer() < expire do
            Wait(0)
        end
        ptfxLoaded = HasNamedPtfxAssetLoaded("veh_xs_vehicle_mods")
    end

    if not ptfxLoaded then
        RequestNamedPtfxAsset("core")
        while not HasNamedPtfxAssetLoaded("core") do 
            Wait(0) 
        end
        ptfxLoaded = true
    end
end

-- START FLAMES (local)
local function localStartFlames(veh)
    if not Config.UseFlames then return end
    
    ensurePtfx()
    local arena = HasNamedPtfxAssetLoaded("veh_xs_vehicle_mods")

    for _, boneName in ipairs(exhaustBones) do
        local idx = GetEntityBoneIndexByName(veh, boneName)
        if idx ~= -1 then
            UseParticleFxAssetNextCall(arena and "veh_xs_vehicle_mods" or "core")
            local fx = StartParticleFxLoopedOnEntityBone(
                arena and "veh_nitrous" or "veh_backfire",
                veh,
                0.0, 0.0, 0.05,
                0.0, 0.0, 0.0,
                idx, 1.0,
                false, false, false
            )
            if fx ~= 0 then
                exhaustFx[#exhaustFx + 1] = fx
            end
        end
    end
end

-- STOP FLAMES (local)
local function localStopFlames()
    for _, fx in ipairs(exhaustFx) do
        StopParticleFxLooped(fx, 0)
    end
    exhaustFx = {}
end

-- RECEIVER for server broadcast
RegisterNetEvent("nitro:clientStartFlames", function(veh)
    localStartFlames(veh)
end)

RegisterNetEvent("nitro:clientStopFlames", function(veh)
    localStopFlames()
end)

-- Nitro logic
local function StartNitro()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    if boosting or cooldown then return end
    if durability <= 0.0 then return end

    local veh = GetVehiclePedIsIn(ped, false)
    boosting = true

    -- Durability based duration
    local duration = Config.FullDuration * durability
    durability = math.max(0.0, durability - 0.25)

    -- Boosting physics
    SetVehicleEnginePowerMultiplier(veh, Config.EnginePowerMultiplier)
    SetVehicleEngineTorqueMultiplier(veh, Config.EngineTorqueMultiplier)

    -- Sync flames to everyone
    TriggerServerEvent("nitro:syncStartFlames", veh)

    --ShakeGameplayCam("SMALL_EXPLOSION_SHAKE", 0.15)

    local endAt = GetGameTimer() + math.floor(duration * 1000)
    while GetGameTimer() < endAt do
        Wait(0)
    end

    StopNitro()
end

function StopNitro()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)

        SetVehicleEnginePowerMultiplier(veh, 0.0)
        SetVehicleEngineTorqueMultiplier(veh, 1.0)

        TriggerServerEvent("nitro:syncStopFlames", veh)
    end

    boosting = false
    cooldown = true

    SetTimeout(Config.Cooldown * 1000, function()
        cooldown = false
    end)
end

-- Keybind + durability regen
CreateThread(function()
    while true do
        Wait(0)

        if IsControlJustPressed(0, Config.Key) then
            StartNitro()
        end

        -- Slow regen
        if not boosting and not cooldown then
            durability = math.min(1.0, durability + 0.0003)
        end
    end
end)
