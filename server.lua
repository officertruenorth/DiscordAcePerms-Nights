local grantedPrincipals = {}
local refreshThrottle = {}

local function getPrefix()
    return (Config.Messages and Config.Messages.Prefix) or '^3[Talos]^7:'
end

local function logDebug(message)
    if Config.Debug then
        print(('%s %s'):format(getPrefix(), message))
    end
end

local function sendMessage(source, message)
    if source == 0 then
        print(('%s %s'):format(getPrefix(), message))
        return
    end

    TriggerClientEvent('chat:addMessage', source, {
        args = { getPrefix(), message }
    })
end

local function getDiscordIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source)
    for i = 1, #identifiers do
        local identifier = identifiers[i]
        if identifier:sub(1, 8) == 'discord:' then
            return identifier:sub(9), identifier
        end
    end
end

local function normalizeRoleId(role)
    if role == nil then
        return nil
    end

    if type(role) == 'string' or type(role) == 'number' then
        return tostring(role)
    end

    if type(role) == 'table' then
        local candidate = role.id or role.role_id or role.roleId or role.discord_role_id or role.discordRoleId
        if candidate ~= nil then
            return tostring(candidate)
        end

        if type(role.role) == 'table' and role.role.id ~= nil then
            return tostring(role.role.id)
        end
    end

    return nil
end

local function getRoleContainer(payload)
    if type(payload) ~= 'table' then
        return {}
    end

    if payload.roles ~= nil then
        return payload.roles
    end

    if type(payload.data) == 'table' then
        if payload.data.roles ~= nil then
            return payload.data.roles
        end
        if payload.data.member and payload.data.member.roles ~= nil then
            return payload.data.member.roles
        end
    end

    if payload.member and payload.member.roles ~= nil then
        return payload.member.roles
    end

    return payload
end

local function parseRoleSet(payload)
    local roles = getRoleContainer(payload)
    local roleSet = {}

    if type(roles) ~= 'table' then
        return roleSet
    end

    for _, role in pairs(roles) do
        local roleId = normalizeRoleId(role)
        if roleId then
            roleSet[roleId] = true
        end
    end

    return roleSet
end

local function requestHttpRoles(discordId)
    local api = Config.NightsAPI or {}
    if not api.Endpoint or api.Endpoint == '' then
        return false, nil, 'Nights API endpoint is not configured.'
    end

    local endpoint = api.Endpoint
    if endpoint:find('%%s') then
        endpoint = endpoint:format(discordId)
    elseif endpoint:sub(-1) == '/' then
        endpoint = endpoint .. discordId
    else
        endpoint = endpoint .. '/' .. discordId
    end

    local headers = {}
    if api.Token and api.Token ~= '' then
        headers[api.AuthHeader or 'Authorization'] = (api.AuthPrefix or 'Bearer ') .. api.Token
    end

    if type(api.AdditionalHeaders) == 'table' then
        for key, value in pairs(api.AdditionalHeaders) do
            headers[key] = value
        end
    end

    local p = promise.new()
    PerformHttpRequest(endpoint, function(statusCode, body)
        p:resolve({ statusCode = statusCode, body = body })
    end, api.Method or 'GET', '', headers)

    local response = Citizen.Await(p)
    local statusCode = tonumber(response.statusCode) or 0
    if statusCode < 200 or statusCode > 299 then
        return false, nil, ('Nights API request failed with status %s'):format(statusCode)
    end

    local decoded = {}
    if response.body and response.body ~= '' then
        local ok, value = pcall(json.decode, response.body)
        if not ok or type(value) ~= 'table' then
            return false, nil, 'Nights API returned invalid JSON payload.'
        end
        decoded = value
    end

    return true, decoded
end

local function requestExportRoles(discordId)
    local api = Config.NightsAPI or {}
    if not api.Resource or not api.Export or api.Resource == '' or api.Export == '' then
        return false, nil, 'Nights export configuration is incomplete.'
    end

    if GetResourceState(api.Resource) ~= 'started' then
        return false, nil, ('Nights resource "%s" is not started.'):format(api.Resource)
    end

    local ok, roles = pcall(function()
        return exports[api.Resource][api.Export](discordId)
    end)

    if not ok then
        return false, nil, 'Nights export role fetch failed.'
    end

    return true, roles
end

local function fetchRoleSet(discordId)
    local mode = ((Config.NightsAPI and Config.NightsAPI.Mode) or 'export'):lower()
    local ok, payload, err

    if mode == 'http' then
        ok, payload, err = requestHttpRoles(discordId)
    else
        ok, payload, err = requestExportRoles(discordId)
    end

    if not ok then
        return nil, err
    end

    return parseRoleSet(payload)
end

local function clearPrincipals(source)
    local principals = grantedPrincipals[source]
    if not principals then
        return
    end

    for i = 1, #principals do
        ExecuteCommand(('remove_principal player.%s %s'):format(source, principals[i]))
    end

    grantedPrincipals[source] = nil
end

local function getMappedPrincipals(roleSet)
    local mapped = {}
    local roleList = Config.RoleList or {}

    for roleId, principalOrList in pairs(roleList) do
        if roleSet[roleId] then
            if type(principalOrList) == 'table' then
                for i = 1, #principalOrList do
                    mapped[#mapped + 1] = principalOrList[i]
                end
            elseif type(principalOrList) == 'string' then
                mapped[#mapped + 1] = principalOrList
            end
        end
    end

    return mapped
end

local function applyDiscordPerms(source, notify)
    clearPrincipals(source)

    local discordId = getDiscordIdentifier(source)
    if not discordId then
        if notify then
            sendMessage(source, (Config.Messages and Config.Messages.MissingDiscord) or 'No Discord identifier was found for your account.')
        end
        return
    end

    local roleSet, err = fetchRoleSet(discordId)
    if not roleSet then
        print(('%s %s'):format(getPrefix(), err))
        return
    end

    local principals = getMappedPrincipals(roleSet)
    grantedPrincipals[source] = principals

    for i = 1, #principals do
        ExecuteCommand(('add_principal player.%s %s'):format(source, principals[i]))
    end

    logDebug(('Applied %s principal(s) to player %s (discord %s).'):format(#principals, source, discordId))

    if notify then
        sendMessage(source, (Config.Messages and Config.Messages.Refreshed) or 'Your Discord permissions have been refreshed.')
    end
end

AddEventHandler('playerJoining', function()
    applyDiscordPerms(source, false)
end)

AddEventHandler('playerDropped', function()
    clearPrincipals(source)
    refreshThrottle[source] = nil
end)

RegisterCommand(Config.RefreshCommand, function(source)
    if source == 0 then
        for _, playerId in ipairs(GetPlayers()) do
            applyDiscordPerms(tonumber(playerId), false)
        end
        print(('%s Refreshed Discord permissions for all online players.'):format(getPrefix()))
        return
    end

    if Config.RefreshAce and Config.RefreshAce ~= '' and not IsPlayerAceAllowed(source, Config.RefreshAce) then
        sendMessage(source, (Config.Messages and Config.Messages.RefreshDenied) or 'You do not have permission to use this command.')
        return
    end

    local now = os.time()
    local cooldown = tonumber(Config.RefreshCooldown) or 0
    local nextAllowed = (refreshThrottle[source] or 0) + cooldown
    if now < nextAllowed then
        local secondsLeft = nextAllowed - now
        sendMessage(source, ((Config.Messages and Config.Messages.WaitRefresh) or 'Please wait %s seconds before refreshing again.'):format(secondsLeft))
        return
    end

    refreshThrottle[source] = now
    applyDiscordPerms(source, true)
end, false)
