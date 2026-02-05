<div align="center">
  <h1><code>HubCore</code></h1>
  <p>
    <strong>A comprehensive hub system for TF2 servers with credits, shop, and cosmetics</strong>
  </p>
  <p style="margin-bottom: 0.5ex;">
    <img
        src="https://img.shields.io/github/downloads/Tolfx/HubCore/total"
    />
    <img
        src="https://img.shields.io/github/last-commit/Tolfx/HubCore"
    />
    <img
        src="https://img.shields.io/github/issues/Tolfx/HubCore"
    />
    <img
        src="https://img.shields.io/github/issues-closed/Tolfx/HubCore"
    />
    <img
        src="https://img.shields.io/github/repo-size/Tolfx/HubCore"
    />
    <img
        src="https://img.shields.io/github/workflow/status/Tolfx/HubCore/Compile%20and%20release"
    />
  </p>
</div>

## Features ##

- **Credits System** - Players earn credits over time and through kills
- **Coinflip** - Gamble credits with configurable multipliers
- **Shop System** - Database-driven shop with categories and items
- **Cosmetics System** - Integrated cosmetics including:
  - **Tags** - Custom chat tags with colors
  - **Trails** - Player trails with special effects (spectrum, breathing, bow)
  - **Footprints** - Temporary ground effects on player movement
  - **Spawn Particles** - Particle effects on player spawn
- **Inventory** - View and equip owned items
- **Preferences** - Player-configurable settings
- **Database Integration** - MySQL with caching for optimal performance
- **Audit Logging** - Track all player transactions

## Requirements ##
- SourceMod 1.11+
- Metamod:Source
- MySQL Database


## Installation ##
1. Grab the latest release from the release page and unzip it in your sourcemod folder.
2. Configure your database in `addons/sourcemod/configs/databases.cfg`:
   ```
   "hub"
   {
       "driver"      "mysql"
       "host"        "localhost"
       "database"    "hub"
       "user"        "your_user"
       "pass"        "your_password"
   }
   ```
3. Restart the server or type `sm plugins load hub` in the console to load the plugin.
4. The config file will be automatically generated in `cfg/sourcemod/`

## Configuration ##

### CVars ###
Once the plugin has been loaded, you can modify the cvars in `cfg/sourcemod/hub.cfg`:

| CVar | Default | Description |
|------|---------|-------------|
| `hub_credits_minute` | 5 | Minutes between automatic credit rewards |
| `hub_credits_amount` | 25 | Credits given per interval |
| `hub_credits_coinflip_multiplier` | 1.2 | Multiplier for coinflip wins |
| `hub_credits_kill_for_credits` | 0 | Enable credits on kill |
| `hub_credits_kill_for_credits_points` | 5 | Credits per kill |
| `sm_hub_trails_enabled` | 1 | Enable trails system |
| `sm_hub_trails_force_cheap` | 0 | Force low-quality trails |
| `sm_hub_trails_remove_on_respawn` | 0 | Remove trail on respawn |
| `sm_hub_trails_allow_hide` | 1 | Allow hiding other players' trails |

### Translation Files ###
- `translations/hub.phrases.txt` - Main translation file
- `translations/hub-shop.phrases.txt` - Shop-specific phrases

### Config Files ###

All cosmetic configuration files are located in `configs/hub/`:

#### Tags Configuration (`configs/hub/tags.cfg`)
```cfg
"tags-list"
{
    "0"
    {
        "name"      "[VIP]"     // Tag text displayed in chat
        "color"     "FFD700"    // Hex color (without #)
        "enabled"   "1"         // 1 = enabled, 0 = disabled
    }
    "1"
    {
        "name"      "[MVP]"
        "color"     "00FF00"
        "enabled"   "1"
    }
    // Use "{empty}" for spacers in menus
    "2"
    {
        "name"      "{empty}"
    }
}
```

#### Trails Configuration (`configs/hub/trails.cfg`)
```cfg
"trails-list"
{
    "0"
    {
        "name"                  "Rainbow"           // Display name
        "color_type"            "1"                 // 0=solid, 1=spectrum, 2=velocity
        "red"                   "255"               // Red channel (0-255)
        "green"                 "0"                 // Green channel (0-255)
        "blue"                  "0"                 // Blue channel (0-255)
        "alpha"                 "128"               // Opacity (0-255)
        "width"                 "1.5"               // Beam width
        "duration"              "1.5"               // Trail fade duration
        "cheap"                 "0"                 // 1 = low quality render
        "admins_only"           "0"                 // 1 = admin only
        
        // Breathing effect (pulsing alpha)
        "breathing_min_alpha"   "64"
        "breathing_max_alpha"   "192"
        "breathing_speed"       "1"
        
        // Bow effect (pulsing width)
        "bow_min_width"         "1.0"
        "bow_max_width"         "3.0"
        "bow_transform_speed"   "0.1"
        
        // Spectrum cycle speed
        "spectrum_cycle_speed"  "1"
    }
}
```

## Commands ##

### Player Commands ###
| Command | Description |
|---------|-------------|
| `sm_hub` | Opens the main hub menu |
| `sm_credits` | Shows your current credits |
| `sm_coinflip <amount>` | Gamble credits |
| `sm_shop` | Opens the shop |
| `sm_inventory` | Opens your inventory |
| `sm_tags` | Opens the tags menu |
| `sm_trails` / `sm_trail` | Opens the trails menu |
| `sm_hidetrail` | Toggle hiding other players' trails |
| `sm_footprints` / `sm_footsteps` | Opens the footprints menu |
| `sm_sp` / `sm_spawnparticles` | Opens the spawn particles menu |

### Admin Commands ###
| Command | Description |
|---------|-------------|
| `sm_givecredits <target> <amount>` | Give credits to a player |
| `sm_setcredits <target> <amount>` | Set a player's credits |
| `sm_removecredits <target> <amount>` | Remove credits from a player |

## Natives ##

HubCore provides natives for other plugins to interact with:

```sourcepawn
// Check if the database is ready
native bool Hub_IsDatabaseReady();

// Check if player data is loaded
native bool Hub_IsPlayerDataLoaded(int client);

// Credit management
native int Hub_GetPlayerCredits(int client);
native void Hub_SetPlayerCredits(int client, int credits, const char[] source = "", const char[] reason = "");
native void Hub_AddPlayerCredits(int client, int amount, const char[] source = "", const char[] reason = "");
native void Hub_RemovePlayerCredits(int client, int amount, const char[] source = "", const char[] reason = "");

// Player selection (cosmetics)
native bool Hub_GetPlayerSelection(int client, const char[] type, char[] buffer, int maxlen);
native void Hub_SetPlayerSelection(int client, const char[] type, const char[] value);
native void Hub_ClearPlayerSelection(int client, const char[] type);

// Player settings
native bool Hub_GetPlayerSettingBool(int client, const char[] key, bool defaultValue = false);
native void Hub_SetPlayerSettingBool(int client, const char[] key, bool value);
native int Hub_GetPlayerSettingInt(int client, const char[] key, int defaultValue = 0);
native void Hub_SetPlayerSettingInt(int client, const char[] key, int value);
native void Hub_GetPlayerSettingString(int client, const char[] key, char[] buffer, int maxlen, const char[] defaultValue = "");
native void Hub_SetPlayerSettingString(int client, const char[] key, const char[] value);

// Shop integration
native bool Hub_HasPlayerItemName(int client, const char[] categoryName, const char[] itemName);

// Utility
native void Hub_GetPlayerSteamID(int client, char[] buffer, int maxlen);
native void Hub_GetPlayerSteamID64(int client, char[] buffer, int maxlen);
native int Hub_GetPlayerPlayTime(int client);
native int Hub_GetPlayerSessionTime(int client);
native void Hub_FlushPlayerCache(int client);

// Tags
native void Tags_GetPlayerTag(int client, char[] buffer, int maxlen);
native int Tags_GetPlayerTagColor(int client);
native void Tags_SetPlayerTag(int client, int tagIndex);
native void Tags_ClearPlayerTag(int client);
native void Tags_OpenMenu(int client);

// Trails
native int Trails_GetPlayerTrail(int client);
native void Trails_SetPlayerTrail(int client, int trailIndex);
native void Trails_ClearPlayerTrail(int client);
native void Trails_ToggleHideTrails(int client);
native bool Trails_IsHidingTrails(int client);
native void Trails_OpenMenu(int client);

// Footprints
native int Footprints_GetPlayerFootprint(int client);
native void Footprints_SetPlayerFootprint(int client, int footprintIndex);
native void Footprints_ClearPlayerFootprint(int client);
native void Footprints_OpenMenu(int client);
```

## Usage ##
