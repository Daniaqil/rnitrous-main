RegisterNetEvent("nitro:syncStartFlames", function(veh)
    TriggerClientEvent("nitro:clientStartFlames", -1, veh)
end)

RegisterNetEvent("nitro:syncStopFlames", function(veh)
    TriggerClientEvent("nitro:clientStopFlames", -1, veh)
end)
