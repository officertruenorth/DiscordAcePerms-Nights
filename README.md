# DiscordAcePerms-Nights

Discord ACE permissions script adapted to use the Nights Software Discord API.

## Features

- Reads Discord identifier when players connect
- Fetches Discord roles through Nights API (export mode or HTTP mode)
- Maps Discord roles to ACE groups/principals
- Grants and removes ACE principals automatically
- Tracks granted permissions per player for clean disconnect handling
- Refresh command (default `/refreshPerms`, configurable via `Config.RefreshCommand`) with cooldown throttling
- Configurable debug logging

## Files

- `fxmanifest.lua`
- `config.lua`
- `server.lua`

## Setup

1. Ensure your Nights Discord API resource (or endpoint) is available.
2. Edit `config.lua`:
   - Set API mode (`export` or `http`)
   - Configure export name/resource or endpoint/token
   - Configure `Config.RoleList` for Discord role -> ACE groups
3. Add resource to your `server.cfg`:
   ```cfg
   ensure <your_resource_folder_name>
   ```
   (If your folder is named `DiscordAcePerms-Nights`, then use `ensure DiscordAcePerms-Nights`.)
4. Ensure your `chat` resource is running for in-game status messages.

## Role Mapping Example

```lua
Config.RoleList = {
  ["123456789012345678"] = { "group.admin", "group.staff" },
  ["234567890123456789"] = "group.moderator"
}
```

## Notes

- Message prefix is rebranded to `^3[Talos]^7:` for all chat/system notices.
- This resource keeps attribution to Jared Scar's original DiscordAcePerms concept and MIT licensing.

## License

MIT License (original attribution retained for Jared Scar's DiscordAcePerms).
