local zoneId
local ESX = nil
local allowAccess = false

if GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
else
    print('You are not using ESX. The script will not function properly.')
    return
end

local Functions = {}

Functions.GetPlayer = function(src)
    return ESX.GetPlayerFromId(src)
end

Functions.GetJob = function(player)
    return player.getJob().name
end

---@param vertices vector3[]
---@return vector3
local function calculatePolyzoneCenter(vertices)
    local xSum, ySum, zSum = 0, 0, 0

    for i = 1, #vertices do
        xSum = xSum + vertices[i].x
        ySum = ySum + vertices[i].y
        zSum = zSum + vertices[i].z
    end

    return vec3(xSum / #vertices, ySum / #vertices, zSum / #vertices)
end

CreateThread(function()
    for _, v in ipairs(Config.Zones) do
        lib.zones.poly({
            points = v.points,
            onEnter = function(s)
                zoneId = s.id
                if not cache.vehicle then return end
                local hasJob = true

                if v.job then
                    hasJob = false
                    local player = Functions.GetPlayer(source)
                    local playerJob = Functions.GetJob(player)

                    for _, job in ipairs(v.job) do
                        if playerJob == job then
                            hasJob = true
                            break
                        end
                    end
                end

                allowAccess = hasJob
                if not hasJob then return end

                lib.showTextUI('Press [E] to tune your car', {
                    icon = 'fa-solid fa-car',
                    position = 'left-center',
                })
            end,
            onExit = function()
                zoneId = nil
                lib.hideTextUI()
            end,
            inside = function()
                if IsControlJustPressed(0, 38) and cache.vehicle and allowAccess then
                    SetEntityVelocity(cache.vehicle, 0.0, 0.0, 0.0)
                    lib.hideTextUI()
                    require('client.menus.main')()
                end
            end,
        })

        if not v.hideBlip then
            local center = calculatePolyzoneCenter(v.points)
            local blip = AddBlipForCoord(center.x, center.y, center.z)
            SetBlipSprite(blip, 72)
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName('Customs')
            EndTextCommandSetBlipName(blip)
        end
    end
end)

lib.callback.register('customs:client:zone', function()
    return zoneId
end)
