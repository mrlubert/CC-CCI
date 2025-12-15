## Command To Run To Install

Run this on a CC:Tweaked Command Computer:

    shell.run("wget https://raw.githubusercontent.com/mrlubert/CC-CCI/main/install.lua install.lua && lua install.lua")

This will:
- Download the installer
- Download the main script
- Download .env.example
- NOT overwrite your .env if it already exists

NOTE: HTTP must be enabled in CC:Tweaked (http.enabled = true)

---

# Twitch Bits → Chance Cubes (CC:Tweaked)

A 100% CC:Tweaked script that listens for Twitch Bits (cheers) using Twitch EventSub WebSockets, converts them into Chance Cubes, and awards them in-game.

- Every X bits = 1 cube (configurable)
- Leftover bits are banked per user
- All commands are configurable via .env
- No hard-coded /give or /tellraw
- Debug output to CC terminal
- Designed for Stoneblock 4, but works in any pack with Chance Cubes

---

## Requirements

Minecraft:
- CC:Tweaked
- Command Computer (required — normal computers cannot run commands)
- Chance Cubes mod installed
- HTTP enabled in CC config

Twitch:
- A Twitch Developer App
- Access to Bits / Cheers on your channel

---

## File Layout

    /computer/
    ├── twitch_bits_cubes.lua
    ├── .env
    ├── twitch_tokens.json   (auto-created)
    └── bits_bank.json       (auto-created)

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

    # Twitch app creds (from dev console)
    TWITCH_CLIENT_ID=xxxxxxxx
    TWITCH_CLIENT_SECRET=xxxxxxxx

    # Must match a redirect URI you set in the Twitch dev console
    TWITCH_REDIRECT_URI=http://localhost

    # Your channel login (lowercase recommended)
    TWITCH_BROADCASTER_LOGIN=yourchannelname

    # Minecraft player to receive cubes + tellraw
    MC_PLAYER=YourMinecraftName

    # Chance Cube item ID (use JEI → Copy Item ID if unsure)
    CUBE_ITEM_ID=chancecubes:chance_cube

    # Bits conversion (every X bits = 1 cube)
    BITS_PER_CUBE=100

    # Commands used to output messages and give items
    # These are the ACTUAL commands (not wrappers)
    MC_TELLRAW_PREFIX=tellraw
    MC_GIVE_PREFIX=give

    # Optional execute examples:
    # MC_TELLRAW_PREFIX=execute as YourMinecraftName run tellraw
    # MC_GIVE_PREFIX=execute as YourMinecraftName run give

    # Print every command the computer runs to the CC terminal
    DEBUG_COMMANDS=true

IMPORTANT:
TWITCH_BROADCASTER_LOGIN must be your channel login, not your display name.

---

## 3) Install the Script (Manual Alternative)

If not using the installer:

    edit twitch_bits_cubes.lua

Paste the full script file.

---

## 4) First Run (Authorization)

Run the script:

    lua twitch_bits_cubes.lua

On first launch:
- The terminal will print a Twitch authorization URL
- Open it in a browser
- Log in as the broadcaster
- Approve the app
- You’ll be redirected to:
      http://localhost/?code=XXXXXXXX
- Copy the code value
- Paste it into the CC terminal when prompted

The script will:
- Exchange the code for tokens
- Save them to twitch_tokens.json
- Auto-refresh them in the future

You only do this once.

---

## What You’ll See on Startup

Every boot prints a config summary to the terminal:

    ========== Twitch Bits → Cubes ==========
    • Broadcaster Login: yourchannelname
    • MC Player: YourMinecraftName
    • Cube Item ID: chancecubes:chance_cube
    • Bits Per Cube: 100
    • Tellraw Command: tellraw
    • Give Command: give
    • Debug Commands: ON
    =========================================

This makes it easy to confirm:
- Correct player
- Correct item ID
- Correct commands
- Debug status

---

## How It Works (Logic)

- Twitch EventSub WebSocket listens for channel.cheer
- Each cheer event provides a bits amount
- For each user:

      total_bits = previous_remainder + new_bits
      cubes      = floor(total_bits / BITS_PER_CUBE)
      remainder  = total_bits % BITS_PER_CUBE

- Cubes are awarded using your configured command
- Messages are sent using your configured tellraw command
- Leftover bits are saved in:

      bits_bank.json

---

## Debug Output

With DEBUG_COMMANDS=true, every command run is printed:

    [CMD] give YourMinecraftName chancecubes:chance_cube 6

If a command fails, it prints in red:

    [CMD FAIL] give YourMinecraftName chancecubes:chance_cube 1
      ↳ Insufficient permission

---

## Common Fixes

Give command fails:
- Check CUBE_ITEM_ID
- Use JEI → Copy Item ID
- Try an execute as ... run give prefix

No bits triggering:
- Make sure Bits are enabled on your channel
- Ensure the Twitch app was authorized with bits:read
- Restart the script if Twitch disconnected

Permissions on servers:
- Use execute wrappers:
      MC_TELLRAW_PREFIX=execute as YourMinecraftName run tellraw
      MC_GIVE_PREFIX=execute as YourMinecraftName run give

---

## Notes

- This must run on a Command Computer
- The computer must stay loaded
- Internet access must be allowed for CC
- Works in singleplayer, LAN, and servers