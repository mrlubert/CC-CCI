-- install.lua
-- CC:Tweaked installer for Twitch Bits → Chance Cubes

local GITHUB_USER = "mrlubert"
local REPO_NAME   = "CC-CCI"
local BRANCH      = "main"

local BASE_RAW = "https://raw.githubusercontent.com/"
  .. GITHUB_USER .. "/"
  .. REPO_NAME .. "/"
  .. BRANCH .. "/"

local FILES = {
  {
    url = BASE_RAW .. "bits_cubes.lua",
    path = "bits_cubes.lua"
  },
  {
    url = BASE_RAW .. ".env.example",
    path = ".env.example"
  }
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

local function errorMsg(msg)
  color(colors.red)
  print("[ERROR] " .. msg)
  color(colors.white)
end

-------------------------------------------------
-- Checks
-------------------------------------------------
if not http then
  errorMsg("HTTP is disabled. Enable it in CC:Tweaked config.")
  return
end

-------------------------------------------------
-- Download files
-------------------------------------------------
status("Starting install...")

for _, file in ipairs(FILES) do
  status("Downloading " .. file.path)

  if fs.exists(file.path) then
    status("Overwriting existing " .. file.path)
    fs.delete(file.path)
  end

  local ok = http.get(file.url)
  if not ok then
    errorMsg("Failed to download: " .. file.url)
    return
  end

  local data = ok.readAll()
  ok.close()

  local f = fs.open(file.path, "w")
  f.write(data)
  f.close()
end

-------------------------------------------------
-- Done
-------------------------------------------------
color(colors.green)
print("========================================")
print(" Install complete!")
print("========================================")
color(colors.white)

print("")
print("Next steps:")
print("1) edit .env")
print("   (copy values from .env.example)")
print("")
print("2) lua twitch_bits_cubes.lua")
print("")
print("If this is your first run, you will be")
print("prompted to authorize the Twitch app.")
