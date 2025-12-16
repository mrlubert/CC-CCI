## Command To Run To Install

Run this on a CC:Tweaked Command Computer:

    wget https://raw.githubusercontent.com/mrlubert/CC-CCI/main/install.lua install.lua 
    
    install.lua

This will:
- Download the installer
- Download the main script
- Download .env.example
- NOT overwrite your .env if it already exists

NOTE: HTTP must be enabled in CC:Tweaked (http.enabled = true)

---

# Twitch Bits -> Chance Cubes (CC:Tweaked)

A 100% CC:Tweaked Command Computer script that listens for Twitch events using EventSub WebSockets and rewards Minecraft items.

Supports:
- Twitch Bits -> Chance Cubes
- Twitch Subs & Gifted Subs -> Chance Cubes
- Optional Twitch Chat -> Minecraft relay

Designed for Stoneblock 4, but works in any modpack with Chance Cubes.

---

## Features

- Every X bits = 1 cube (configurable)
- Per-tier sub cube rewards (Prime / T1 / T2 / T3)
- Gifted subs scale correctly (1 gift = X cubes)
- Leftover bits are banked per user
- Optional Twitch chat relay into Minecraft
- Safe OAuth handling (auto-refresh, scope-aware re-auth)
- All commands configurable via .env
- No hard-coded /give or /tellraw
- Debug command output to CC terminal
- One-line installer

---

## Requirements

Minecraft:
- CC:Tweaked
- Command Computer (required)
- Chance Cubes mod
- HTTP enabled in CC config

Twitch:
- Twitch Developer App
- Bits enabled on your channel

---

## File Layout

    /computer/
    ├── bits_cubes.lua
    ├── .env
    ├── twitch_tokens.json        (auto-created)
    ├── twitch_tokens.old_*.json  (backup if scopes change)
    └── bits_bank.json            (auto-created)

---

## 1) Create a Twitch Developer App

1. Go to https://dev.twitch.tv/console/apps
2. Click Create Application
3. Set:
   - Name: Anything
   - OAuth Redirect URL:
         http://localhost
   - Category: Application Integration
4. Create the app
5. Copy:
   - Client ID
   - Client Secret

---

## 2) Create .env on the CC Computer

On the Command Computer:

    edit .env

Paste and fill this out:

    # Twitch app creds
    TWITCH_CLIENT_ID=xxxxxxxx
    TWITCH_CLIENT_SECRET=xxxxxxxx

    # Must match redirect URI in Twitch app
    TWITCH_REDIRECT_URI=http://localhost

    # Your channel login (NOT display name)
    TWITCH_BROADCASTER_LOGIN=yourchannelname

    # Minecraft player to receive cubes & chat
    MC_PLAYER=YourMinecraftName

    # Chance Cube item ID (use JEI -> Copy Item ID)
    CUBE_ITEM_ID=chancecubes:chance_cube

    # Bits conversion
    BITS_PER_CUBE=100

    # Command strings (actual commands)
    MC_TELLRAW_PREFIX=tellraw
    MC_GIVE_PREFIX=give

    # Optional execute wrappers:
    # MC_TELLRAW_PREFIX=execute as YourMinecraftName run tellraw
    # MC_GIVE_PREFIX=execute as YourMinecraftName run give

    # Sub cube rewards
    CUBES_SUB_PRIME=5
    CUBES_SUB_T1=5
    CUBES_SUB_T2=10
    CUBES_SUB_T3=25

    # Twitch chat -> Minecraft relay
    RELAY_TWITCH_CHAT=true
    CHAT_RELAY_PREFIX=[Twitch]
    CHAT_RELAY_MAXLEN=180

    # Debug command output
    DEBUG_COMMANDS=true

IMPORTANT:
TWITCH_BROADCASTER_LOGIN must be your channel LOGIN, not display name.

---

## OAuth Scopes & Safe Re-Authorization

This script automatically manages Twitch OAuth scopes.

Scopes requested:
- bits:read
- channel:read:subscriptions
- user:read:chat (ONLY if RELAY_TWITCH_CHAT=true)

Behavior:
- Tokens are automatically refreshed when they expire
- The script records which scopes were used to authorize the token
- If your .env changes required scopes:
  - The old token file is backed up (twitch_tokens.old_*.json)
  - You are prompted to re-authorize ONE time
- If scopes do not change:
  - No re-authorization prompts
  - Silent refresh only

This prevents unnecessary OAuth prompts while staying secure.

---

## 3) First Run (Authorization)

Run the script:

    lua bits_cubes.lua

On first launch:
- A Twitch authorization URL is printed
- Open it in a browser
- Log in as the broadcaster
- Approve the app
- You will be redirected to:
      http://localhost/?code=XXXXXXXX
- Copy ONLY the code value
- Paste it into the CC terminal

This only happens once unless:
- You delete twitch_tokens.json
- OR you change enabled features that require new scopes

---

## Twitch Chat Relay

If RELAY_TWITCH_CHAT=true:
- Every Twitch chat message appears in Minecraft
- Format:
      [Twitch] username: message
- Messages are ASCII-sanitized
- Length is capped to avoid spam

If you enable this AFTER first authorization:
- The script will detect the scope change
- Automatically prompt for re-authorization once

---

## What You’ll See on Startup

    ========== Twitch Bits -> Cubes ==========
    • Broadcaster Login: yourchannelname
    • MC Player: YourMinecraftName
    • Cube Item ID: chancecubes:chance_cube
    • Bits Per Cube: 100
    • Sub Cubes Prime: 5
    • Sub Cubes Tier1: 5
    • Sub Cubes Tier2: 10
    • Sub Cubes Tier3: 25
    • Relay Twitch Chat: ON
    • Debug Commands: ON
    =========================================

---

## How Rewards Work

Bits:
- Total bits are banked per user
- Cubes = floor(bits / BITS_PER_CUBE)

Subs:
- Prime uses CUBES_SUB_PRIME
- Tier 1/2/3 use configured values
- Gifted subs multiply per gift count

Chat:
- Relays live Twitch chat into Minecraft (optional)

---

## Debug Output

If DEBUG_COMMANDS=true, every command is printed:

    [CMD] give YourMinecraftName chancecubes:chance_cube 5

Failures print in red:

    [CMD FAIL] give ...
      -> permission denied

---

## Common Fixes

Give command fails:
- Check CUBE_ITEM_ID
- Use JEI -> Copy Item ID
- Try execute as ... run give

No chat showing:
- RELAY_TWITCH_CHAT must be true
- Token re-auth may be required (script will prompt)
- Ensure user:read:chat scope was approved

No bits/subs triggering:
- Bits must be enabled on channel
- Restart script if WebSocket reconnects

---

## Notes

- Must run on a Command Computer
- Computer must stay loaded
- Internet access must be allowed
- Works in singleplayer, LAN, and servers
