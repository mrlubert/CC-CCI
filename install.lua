-- install.lua
-- CC:Tweaked installer / updater for Twitch Bits -> Chance Cubes
-- - Downloads bits_cubes.lua, .env.example, README.md
-- - Creates .env if missing (never overwrites it)
-- - Leaves twitch_tokens.json + bits_bank.json untouched
-- - Safe to re-run any time to update

local GITHUB_USER = "mrlubert"
local REPO_NAME   = "CC-CCI"
local BRANCH      = "main"

local BASE_RAW = "https://raw.githubusercontent.com/"
  .. GITHUB_USER .. "/"
  .. REPO_NAME .. "/"
  .. BRANCH .. "/"

local FILES = {
  { url = BASE_RAW .. "bits_cubes.lua", path = "bits_cubes.lua" },
  { url = BASE_RAW .. ".env.example",   path = ".env.example"   },
  { url = BASE_RAW .. "README.md",      path = "README.md"      },
}

-------------------------------------------------
-- Helpers
-------------------------------------------------
local function color(c)
  if term.isColor() then term.setTextColor(c) end
end

local function status(msg)
  color(colors.cyan)
  print("[INSTALL] " .. msg)
  color(colors.white)
end

local function warn(msg)
  color(colors.yellow)
  print("[WARN] " .. msg)
  color(colors.white)
end

local function okMsg(msg)
  color(colors.green)
  print("[OK] " .. msg)
  color(colors.white)
end

local function errorMsg(msg)
  color(colors.red)
  print("[ERROR] " .. msg)
  color(colors.white)
end

local function readAll(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r")
  local d = f.readAll()
  f.close()
  return d
end

-------------------------------------------------
-- Checks
-------------------------------------------------
if not http then
  errorMsg("HTTP is disabled. Enable it in CC:Tweaked config (http.enabled=true).")
  return
end

-------------------------------------------------
-- Install / Update
-------------------------------------------------
status("Starting install/update...")

for _, file in ipairs(FILES) do
  status("Fetching " .. file.path)

  local h = http.get(file.url)
  if not h then
    errorMsg("Failed to download: " .. file.url)
    return
  end

  local data = h.readAll()
  h.close()

  if not data or data == "" then
    errorMsg("Downloaded empty file: " .. file.path)
    return
  end

  local old = readAll(file.path)

  -- Only write if changed (keeps disk writes lower and feels cleaner)
  if old == data then
    okMsg(file.path .. " is already up to date")
  else
    if fs.exists(file.path) then
      fs.delete(file.path)
    end
    local f = fs.open(file.path, "w")
    f.write(data)
    f.close()
    okMsg("Updated " .. file.path)
  end
end

-------------------------------------------------
-- Create .env if missing (never overwrite)
-------------------------------------------------
if fs.exists(".env") then
  warn(".env already exists - NOT overwriting.")
else
  if fs.exists(".env.example") then
    fs.copy(".env.example", ".env")
    okMsg("Created .env from .env.example")
  else
    warn("Missing .env.example - cannot create .env")
  end
end

-------------------------------------------------
-- Done
-------------------------------------------------
color(colors.green)
print("========================================")
print(" Install/update complete!")
print("========================================")
color(colors.white)

print("")
print("Next steps:")
print("1) edit .env (if needed)")
print("2) run: lua bits_cubes.lua")
print("")
print("Tip: You can re-run this installer any time")
print("to update files without touching .env/tokens/bank.")
