-- File: src/twitch_bits_cubes.lua
-- twitch_bits_cubes.lua
-- Pure CC:Tweaked Twitch Bits -> Chance Cubes
-- EVERYTHING command-related comes from .env
-- Startup echo + debug command printing
-- Requires: Command Computer + http enabled

local ENV_PATH   = ".env"
local TOKEN_FILE = "twitch_tokens.json"
local BANK_FILE  = "bits_bank.json"

-------------------------------------------------
-- Utils
-------------------------------------------------
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function normalize(s)
  s = trim(s or "")
  if s:sub(1,1) == "/" then s = s:sub(2) end
  return s
end

-------------------------------------------------
-- .env loader
-------------------------------------------------
local function loadEnv()
  if not fs.exists(ENV_PATH) then
    error("Missing .env file", 0)
  end

  local f = fs.open(ENV_PATH, "r")
  local txt = f.readAll()
  f.close()

  local env = {}
  for line in txt:gmatch("[^\r\n]+") do
    line = trim(line)
    if line ~= "" and not line:match("^#") then
      local k, v = line:match("^([A-Z0-9_]+)%s*=%s*(.*)$")
      if k then
        v = trim(v):gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1")
        env[k] = v
      end
    end
  end
  return env
end

local ENV = loadEnv()

local function requireEnv(k)
  if ENV[k] == nil then
    error("Missing .env key: " .. k, 0)
  end
  return ENV[k]
end

local function envBool(v)
  v = tostring(v):lower()
  return (v == "1" or v == "true" or v == "yes" or v == "on")
end

-------------------------------------------------
-- REQUIRED ENV VALUES
-------------------------------------------------
local CLIENT_ID     = requireEnv("TWITCH_CLIENT_ID")
local CLIENT_SECRET = requireEnv("TWITCH_CLIENT_SECRET")
local REDIRECT_URI  = requireEnv("TWITCH_REDIRECT_URI")
local BROADCASTER   = requireEnv("TWITCH_BROADCASTER_LOGIN")

local MC_PLAYER     = requireEnv("MC_PLAYER")
local CUBE_ITEM     = requireEnv("CUBE_ITEM_ID")
local BITS_PER_CUBE = tonumber(requireEnv("BITS_PER_CUBE"))

-- THESE ARE THE ACTUAL COMMANDS
local TELLRAW_CMD = normalize(requireEnv("MC_TELLRAW_PREFIX"))
local GIVE_CMD    = normalize(requireEnv("MC_GIVE_PREFIX"))

local DEBUG_COMMANDS = envBool(requireEnv("DEBUG_COMMANDS"))

-------------------------------------------------
-- Terminal helpers
-------------------------------------------------
local function color(c)
  if term.isColor() then term.setTextColor(c) end
end

local function debugCmd(cmd)
  if not DEBUG_COMMANDS then return end
  color(colors.gray)
  print("[CMD] " .. cmd)
  color(colors.white)
end

local function errorCmd(cmd, err)
  color(colors.red)
  print("[CMD FAIL] " .. cmd)
  if err ~= nil then
    print("  ↳ " .. tostring(err))
  end
  color(colors.white)
end

-------------------------------------------------
-- Startup echo
-------------------------------------------------
color(colors.cyan)
print("========== Twitch Bits → Cubes ==========")
color(colors.white)

local function echo(k, v)
  color(colors.lightGray)
  write("• " .. k .. ": ")
  color(colors.white)
  print(v)
end

echo("Broadcaster Login", BROADCASTER)
echo("MC Player", MC_PLAYER)
echo("Cube Item ID", CUBE_ITEM)
echo("Bits Per Cube", BITS_PER_CUBE)
echo("Tellraw Command", TELLRAW_CMD)
echo("Give Command", GIVE_CMD)
echo("Debug Commands", DEBUG_COMMANDS and "ON" or "OFF")

color(colors.cyan)
print("=========================================")
color(colors.white)

-------------------------------------------------
-- Command execution
-------------------------------------------------
local function runCommand(cmd)
  cmd = normalize(cmd)
  debugCmd(cmd)

  local ok, out = commands.exec(cmd)
  if not ok then
    errorCmd(cmd, out)
  end
  return ok
end

-------------------------------------------------
-- Minecraft actions (NO hard-coded commands)
-------------------------------------------------
local function tellraw(msg)
  msg = msg:gsub("\\", "\\\\"):gsub('"', '\\"')
  runCommand(string.format(
    "%s %s {\"text\":\"%s\"}",
    TELLRAW_CMD,
    MC_PLAYER,
    msg
  ))
end

local function giveCubes(count)
  if count <= 0 then return end
  local ok = runCommand(string.format(
    "%s %s %s %d",
    GIVE_CMD,
    MC_PLAYER,
    CUBE_ITEM,
    count
  ))

  if not ok then
    tellraw("[Bits→Cubes] Give failed")
  end
end

-------------------------------------------------
-- Persistence
-------------------------------------------------
local function readJson(p)
  if not fs.exists(p) then return nil end
  local f = fs.open(p, "r")
  local d = textutils.unserializeJSON(f.readAll())
  f.close()
  return d
end

local function writeJson(p, d)
  local f = fs.open(p, "w")
  f.write(textutils.serializeJSON(d))
  f.close()
end

-------------------------------------------------
-- Bits bank
-------------------------------------------------
local bank = readJson(BANK_FILE) or { remainder = {} }

local function award(user, bits)
  local total = (bank.remainder[user] or 0) + bits
  local cubes = math.floor(total / BITS_PER_CUBE)

  bank.remainder[user] = total % BITS_PER_CUBE
  writeJson(BANK_FILE, bank)

  giveCubes(cubes)
  tellraw(string.format(
    "[Bits→Cubes] %s cheered %d → %d cube(s)",
    user,
    bits,
    cubes
  ))
end

-------------------------------------------------
-- OAuth helpers
-------------------------------------------------
local function formEncode(t)
  local r = {}
  for k,v in pairs(t) do
    r[#r+1] = textutils.urlEncode(k).."="..textutils.urlEncode(v)
  end
  return table.concat(r,"&")
end

local function httpReq(o)
  http.request(o)
  while true do
    local e,u,h = os.pullEvent()
    if e=="http_success" and u==o.url then
      local b=h.readAll(); h.close(); return true,b
    elseif e=="http_failure" and u==o.url then
      return false,nil
    end
  end
end

local function httpJson(m,u,h,b,isForm)
  h = h or {}
  if b then
    h["Content-Type"] = isForm and "application/x-www-form-urlencoded" or "application/json"
    b = isForm and b or textutils.serializeJSON(b)
  end
  local ok,r = httpReq({url=u,method=m,headers=h,body=b})
  if not ok then return nil end
  return textutils.unserializeJSON(r)
end

-------------------------------------------------
-- OAuth token handling
-------------------------------------------------
local function saveToken(t)
  t.expires_at = os.epoch("utc")/1000 + t.expires_in - 30
  writeJson(TOKEN_FILE, t)
  return t
end

local function ensureToken()
  local t = readJson(TOKEN_FILE)

  if not t then
    print("Authorize this app:")
    print(
      "https://id.twitch.tv/oauth2/authorize"
      .. "?client_id=" .. CLIENT_ID
      .. "&redirect_uri=" .. REDIRECT_URI
      .. "&response_type=code"
      .. "&scope=bits:read"
    )
    write("> Paste code: ")
    local code = read()

    return saveToken(httpJson(
      "POST",
      "https://id.twitch.tv/oauth2/token",
      {},
      formEncode({
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET,
        code=code,
        grant_type="authorization_code",
        redirect_uri=REDIRECT_URI
      }),
      true
    ))
  end

  if os.epoch("utc")/1000 < t.expires_at then
    return t
  end

  return saveToken(httpJson(
    "POST",
    "https://id.twitch.tv/oauth2/token",
    {},
    formEncode({
      client_id=CLIENT_ID,
      client_secret=CLIENT_SECRET,
      grant_type="refresh_token",
      refresh_token=t.refresh_token
    }),
    true
  ))
end

-------------------------------------------------
-- EventSub
-------------------------------------------------
if not commands or not commands.exec then
  error("This must run on a Command Computer", 0)
end

local token = ensureToken()
local headers = {
  ["Client-Id"] = CLIENT_ID,
  ["Authorization"] = "Bearer " .. token.access_token
}

local function getBroadcasterId()
  return httpJson(
    "GET",
    "https://api.twitch.tv/helix/users?login=" .. BROADCASTER,
    headers
  ).data[1].id
end

local broadcasterId = getBroadcasterId()

tellraw("[Bits→Cubes] Online")

local WS = "wss://eventsub.wss.twitch.tv/ws"
http.websocketAsync(WS)

while true do
  local e,a,b = os.pullEvent()

  if e=="websocket_message" then
    local d = textutils.unserializeJSON(b)
    local t = d.metadata.message_type

    if t=="session_welcome" then
      httpJson(
        "POST",
        "https://api.twitch.tv/helix/eventsub/subscriptions",
        headers,
        {
          type="channel.cheer",
          version="1",
          condition={broadcaster_user_id=broadcasterId},
          transport={method="websocket",session_id=d.payload.session.id}
        }
      )
      tellraw("[Bits→Cubes] Subscribed")

    elseif t=="notification" then
      local ev = d.payload.event
      if ev and ev.bits then
        award(
          ev.is_anonymous and "Anonymous" or ev.user_name,
          ev.bits
        )
      end
    end

  elseif e=="websocket_closed" then
    http.websocketAsync(WS)
  end
end
