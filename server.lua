local ESX

if GetResourceState('es_extended') == 'started' then
    ESX = exports["es_extended"]:getSharedObject()
else
    print('ESX is missing; script will not function properly.')
    return
end

local Functions = {}

Functions.GetPlayer = function(src)
    return ESX.GetPlayerFromId(src)
end

Functions.GetCash = function(player)
    return player.getMoney() or 0 
end

Functions.GetBank = function(player)
    local account = player.getAccount('bank')
    return account and account.money or 0 
end

Functions.RemoveMoney = function(player, type, amount)
    if type == 'cash' then
        player.removeMoney(amount)
    elseif type == 'bank' then
        player.removeAccountMoney('bank', amount)
    end
end

Functions.GetJob = function(player)
    return player.getJob().name
end

Functions.Owned = function(vehicleplate)
    local result = MySQL.scalar.await('SELECT 1 FROM owned_vehicles WHERE plate = ?', {vehicleplate})
    return result ~= nil
end

Functions.Update = function(vehicleProps)
    MySQL.update('UPDATE owned_vehicles SET vehicle = ? WHERE plate = ?', {json.encode(vehicleProps), vehicleProps.plate})
end

---@return number
local function getModPrice(mod, level)
    if mod == 'cosmetic' or mod == 'colors' or mod == 18 then
        return Config.Prices[mod] --[[@as number]]
    else
        return Config.Prices[mod][level] or 0 
    end
end

---@param source number
---@param amount number
---@return boolean
local function removeMoney(source, amount)
    local player = Functions.GetPlayer(source)
    local cashBalance = Functions.GetCash(player)
    local bankBalance = Functions.GetBank(player)

    if cashBalance >= amount then
        Functions.RemoveMoney(player, 'cash', amount)
        lib.notify(source, {
            title = 'Customs',
            description = ('You paid $%s in cash'):format(amount),
            type = 'success',
        })
        return true
    elseif bankBalance >= amount then
        Functions.RemoveMoney(player, 'bank', amount)
        lib.notify(source, {
            title = 'Customs',
            description = ('You paid $%s from your bank account'):format(amount),
            type = 'success',
        })
        return true
    end

    lib.notify(source, {
        title = 'Customs',
        description = ('Not enough money! You need $%s.'):format(amount),
        type = 'error',
    })
    return false
end

lib.callback.register('customs:server:pay', function(source, mod, level)
    local zone = lib.callback.await('customs:client:zone', source)

    for i, v in ipairs(Config.Zones) do
        if i == zone and v.freeMods then
            local player = Functions.GetPlayer(source)
            local playerJob = Functions.GetJob(player)
            for _, job in ipairs(v.freeMods) do
                if playerJob == job then
                    return true
                end
            end
        end
    end

    local price = getModPrice(mod, level)
    return removeMoney(source, price)
end)

lib.callback.register('customs:server:repair', function(source, bodyHealth)
    local zone = lib.callback.await('customs:client:zone', source)

    for i, v in ipairs(Config.Zones) do
        if i == zone and v.freeRepair then
            local player = Functions.GetPlayer(source)
            local playerJob = Functions.GetJob(player)
            for _, job in ipairs(v.freeRepair) do
                if playerJob == job then
                    return true 
                end
            end
        end
    end

    local price = math.ceil(1000 - bodyHealth)
    return removeMoney(source, price)
end)

RegisterNetEvent('customs:server:saveVehicleProps', function()
    local src = source --[[@as number]]
    local vehicleProps = lib.callback.await('customs:client:vehicle', src)
    if Functions.Owned(vehicleProps.plate) then
        Functions.Update(vehicleProps)
    end
end)
