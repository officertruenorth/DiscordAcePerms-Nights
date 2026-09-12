Config = {}

Config.Debug = false
Config.RefreshCommand = 'refreshPerms'
Config.RefreshCooldown = 30
Config.RefreshAce = 'command.refreshperms'
Config.ConnectRetryAttempts = 10
Config.ConnectRetryDelayMs = 1000

Config.Messages = {
    Prefix = '^3[Talos]^7:',
    MissingDiscord = 'No Discord identifier was found for your account.',
    Refreshed = 'Your Discord permissions have been refreshed.',
    WaitRefresh = 'Please wait %s seconds before refreshing again.',
    RefreshDenied = 'You do not have permission to use this command.'
}

Config.NightsAPI = {
    -- "export" for a Nights resource export, "http" for direct HTTP API requests.
    Mode = 'export',

    -- Export mode settings.
    Resource = 'nights_discord_api',
    Export = 'GetDiscordRoles',

    -- HTTP mode settings.
    Method = 'GET',
    Endpoint = '',
    Token = '',
    AuthHeader = 'Authorization',
    AuthPrefix = 'Bearer ',
    AdditionalHeaders = {},
}

-- Discord role ID => ACE principal(s)
Config.RoleList = {
    -- ["123456789012345678"] = { "group.admin", "group.staff" },
    -- ["234567890123456789"] = "group.moderator",
}
