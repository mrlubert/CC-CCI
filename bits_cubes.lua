-- twitch_bits_cubes.lua
-- Pure CC:Tweaked Twitch Bits/Subs/Chat -> Chance Cubes
-- EVERYTHING command-related comes from .env
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

local function clampLen(s, n)
  s = tostring(s or "")
  if n and n > 0 and #s > n then
    return s:sub(1, n - 3) .. "..."
  end
  return s
end

-- Make chat safe for JSON + avoid unicode weirdness
local function sanitizeText(s)
  s = tostring(s or "")
  -- strip non-ascii to avoid encoding garble in some servers/packs
  s = s:gsub("[^\x20-\x7E]", "?")
  -- escape for JSON string
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"')
  return s
end

-------------------------------------------------
-- .env loader
-------------------------------------------------
local function loadEnv()
  if not fs.exists(ENV_PATH) then error("Missing .env file", 0) end
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
  if ENV[k] == nil then error("Missing .env key: " .. k, 0) end
  return ENV[k]
end

local function envBool(v)
  v = tostring(v or ""):lower()
  return (v == "1" or v == "true" or v == "yes" or v == "on")
end

local function envNumRequired(k)
  local v = tonumber(requireEnv(k))
  if v == nil then error("Invalid number for .env key: " .. k, 0) end
  return v
end

local function envNumOptional(k, def)
  local raw = ENV[k]
  if raw == nil or raw == "" then return def end
  local v = tonumber(raw)
  if v == nil then return def end
  return v
end

local function envStrOptional(k, def)
  local v = ENV[k]
  if v == nil or v == "" then return def end
  return v
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
local BITS_PER_CUBE = envNumRequired("BITS_PER_CUBE")

-- These are the actual command strings (can be wrappers too)
local TELLRAW_CMD = normalize(requireEnv("MC_TELLRAW_PREFIX"))
local GIVE_CMD    = normalize(requireEnv("MC_GIVE_PREFIX"))

local DEBUG_COMMANDS = envBool(requireEnv("DEBUG_COMMANDS"))

-- Sub cube values (configurable per tier)
local CUBES_SUB_PRIME = envNumRequired("CUBES_SUB_PRIME")
local CUBES_SUB_T1    = envNumRequired("CUBES_SUB_T1")
local CUBES_SUB_T2    = envNumRequired("CUBES_SUB_T2")
local CUBES_SUB_T3    = envNumRequired("CUBES_SUB_T3")

-- Twitch chat relay (toggle)
local RELAY_TWITCH_CHAT = envBool(requireEnv("RELAY_TWITCH_CHAT"))
local CHAT_RELAY_PREFIX = envStrOptional("CHAT_RELAY_PREFIX", "[Twitch]")
local CHAT_RELAY_MAXLEN = envNumOptional("CHAT_RELAY_MAXLEN", 180)

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
  if err ~= nil then print("  -> " .. tostring(err)) end
  color(colors.white)
end

-------------------------------------------------
-- Startup echo
-------------------------------------------------
color(colors.cyan)
print("========== Twitch Bits -> Cubes ==========")
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
echo("Sub Cubes Prime", CUBES_SUB_PRIME)
echo("Sub Cubes Tier1", CUBES_SUB_T1)
echo("Sub Cubes Tier2", CUBES_SUB_T2)
echo("Sub Cubes Tier3", CUBES_SUB_T3)
echo("Relay Twitch Chat", RELAY_TWITCH_CHAT and "ON" or "OFF")
if RELAY_TWITCH_CHAT then
  echo("Chat Relay Prefix", CHAT_RELAY_PREFIX)
  echo("Chat Relay MaxLen", CHAT_RELAY_MAXLEN)
end
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
  if not ok then errorCmd(cmd, out) end
  return ok
end

-------------------------------------------------
-- Minecraft actions
-------------------------------------------------
local function tellraw(msg)
  msg = sanitizeText(msg)
  runCommand(string.format(
    "%s %s {\"text\":\"%s\"}",
    TELLRAW_CMD,
    MC_PLAYER,
    msg
  ))
end

local function giveCubes(count)
  count = tonumber(count) or 0
  if count <= 0 then return end

  local ok = runCommand(string.format(
    "%s %s %s %d",
    GIVE_CMD,
    MC_PLAYER,
    CUBE_ITEM,
    count
  ))

  if not ok then tellraw("§0[§bCubes§0]§f Give failed") end
end

-------------------------------------------------
-- Persistence
-------------------------------------------------
local function readJson(p)
  if not fs.exists(p) then return nil end
  local f = fs.open(p, "r")
  local raw = f.readAll()
  f.close()
  if not raw or raw == "" then return nil end
  local ok, obj = pcall(textutils.unserializeJSON, raw)
  return ok and obj or nil
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

local function awardBits(user, bits)
  local total = (bank.remainder[user] or 0) + bits
  local cubes = math.floor(total / BITS_PER_CUBE)

  bank.remainder[user] = total % BITS_PER_CUBE
  writeJson(BANK_FILE, bank)

  if cubes > 0 then giveCubes(cubes) end
  tellraw(string.format("§0[§bCubes§0]§f %s cheered %d -> %d cube(s)", user, bits, cubes))
end

-------------------------------------------------
-- Subs handling
-------------------------------------------------
local function cubesForSubEvent(ev)
  if ev.is_prime == true then return CUBES_SUB_PRIME end
  local tier = tostring(ev.tier or "1000")
  if tier == "3000" then return CUBES_SUB_T3 end
  if tier == "2000" then return CUBES_SUB_T2 end
  return CUBES_SUB_T1
end

local function handleSubscribeEvent(ev)
  local perSub = cubesForSubEvent(ev)
  local isGift = (ev.is_gift == true)

  if isGift then
    local count = tonumber(ev.total or 1) or 1
    local cubes = count * perSub
    giveCubes(cubes)

    local gifter = ev.gifter_name or ev.gifter_login or "Someone"
    tellraw(string.format("§0[§bCubes§0]§f %s gifted %d sub(s) -> %d cube(s)", gifter, count, cubes))
  else
    local user = ev.user_name or ev.user_login or "Someone"
    giveCubes(perSub)
    tellraw(string.format("§0[§bCubes§0]§f %s subscribed -> %d cube(s)", user, perSub))
  end
end

-------------------------------------------------
-- Twitch chat relay handling
-------------------------------------------------
local function handleChatMessageEvent(ev)
  if not RELAY_TWITCH_CHAT then return end

  -- EventSub chat payload typically includes user_name and message.text
  local name = ev.chatter_user_name or ev.user_name or ev.chatter_user_login or ev.user_login or "chat"
  local text = ""

  if ev.message and ev.message.text then
    text = ev.message.text
  elseif ev.text then
    text = ev.text
  end

  text = clampLen(text, CHAT_RELAY_MAXLEN)

  -- Example: [Twitch] user: hello
  tellraw(string.format("%s %s: %s", CHAT_RELAY_PREFIX, name, text))
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
  if not ok or not r or r == "" then return nil end
  local ok2, obj = pcall(textutils.unserializeJSON, r)
  return ok2 and obj or nil
end

-------------------------------------------------
-- OAuth token handling
-------------------------------------------------
local function saveToken(t, scopeStr)
  if not t or not t.expires_in then error("OAuth token response missing expires_in", 0) end
  t.expires_at = os.epoch("utc")/1000 + t.expires_in - 30
  -- record what scopes this token was authorized with (based on current .env)
  t._requested_scopes = scopeStr
  writeJson(TOKEN_FILE, t)
  return t
end

local function buildScopes()
  -- Always required
  local scopes = {
    "bits:read",
    "channel:read:subscriptions"
  }
  -- Only request chat scope if relay is enabled
  if RELAY_TWITCH_CHAT then
    table.insert(scopes, "user:read:chat")
  end
  return table.concat(scopes, " ")
end

local function scopesChanged(token, desiredScopeStr)
  if not token then return true end
  -- We store the previously requested scope string ourselves.
  local old = token._requested_scopes
  if type(old) ~= "string" or old == "" then
    -- Older token file (before we stored scopes) -> treat as changed once.
    return true
  end
  return old ~= desiredScopeStr
end

local function ensureToken()
  local desiredScopes = buildScopes()
  local t = readJson(TOKEN_FILE)
  -- If token exists but scopes no longer match current config, force re-auth ONCE.
  if t and scopesChanged(t, desiredScopes) then
    local backup = "twitch_tokens.old_" .. tostring(math.floor(os.epoch("utc")/1000)) .. ".json"
    print("Token scopes changed (config updated). Re-authorization required.")
    print("Backing up old token file to: " .. backup)
    if fs.exists(TOKEN_FILE) then
      fs.copy(TOKEN_FILE, backup)
      fs.delete(TOKEN_FILE)
    end
    t = nil
  end
  -- No token -> do full authorization flow
  if not t then
    print("Authorize this app:")
    print(
      "https://id.twitch.tv/oauth2/authorize"
      .. "?client_id=" .. textutils.urlEncode(CLIENT_ID)
      .. "&redirect_uri=" .. textutils.urlEncode(REDIRECT_URI)
      .. "&response_type=code"
      .. "&scope=" .. textutils.urlEncode(desiredScopes)
    )
    write("> Paste code: ")
    local code = read()
    local resp = httpJson(
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
    )
    if not resp or not resp.access_token then
      error("Failed to exchange auth code for tokens.", 0)
    end
    return saveToken(resp, desiredScopes)
  end
  -- Token still valid
  if os.epoch("utc")/1000 < (t.expires_at or 0) then
    return t
  end
  -- Refresh token (scopes stay the same)
  local resp = httpJson(
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
  )
  if not resp or not resp.access_token then
    error("Failed to refresh tokens. Delete twitch_tokens.json and re-authorize.", 0)
  end
  -- Preserve the scopes we requested before saving refreshed token
  return saveToken(resp, desiredScopes)
end

-------------------------------------------------
-- EventSub
-------------------------------------------------
if not commands or not commands.exec then
  error("This must run on a Command Computer", 0)
end

if not http then
  error("HTTP is disabled. Enable it in CC:Tweaked config (http.enabled=true).", 0)
end

local token = ensureToken()
local headers = {
  ["Client-Id"] = CLIENT_ID,
  ["Authorization"] = "Bearer " .. token.access_token
}

local function getBroadcasterId()
  local data = httpJson(
    "GET",
    "https://api.twitch.tv/helix/users?login=" .. textutils.urlEncode(BROADCASTER),
    headers
  )
  if not data or not data.data or not data.data[1] or not data.data[1].id then
    error("Failed to fetch broadcaster id for TWITCH_BROADCASTER_LOGIN=" .. BROADCASTER, 0)
  end
  return data.data[1].id
end

local broadcasterId = getBroadcasterId()

tellraw("§0[§bCubes§0]§f Online")

local WS = "wss://eventsub.wss.twitch.tv/ws"
http.websocketAsync(WS)

while true do
  local e,_,payload = os.pullEvent()

  if e == "websocket_message" then
    local ok, d = pcall(textutils.unserializeJSON, payload)
    if ok and type(d) == "table" then
      local mtype = d.metadata and d.metadata.message_type

      if mtype == "session_welcome" then
        local sessionId = d.payload and d.payload.session and d.payload.session.id
        if sessionId then
          -- Subscribe to bits
          httpJson("POST", "https://api.twitch.tv/helix/eventsub/subscriptions", headers, {
            type="channel.cheer",
            version="1",
            condition={broadcaster_user_id=broadcasterId},
            transport={method="websocket",session_id=sessionId}
          })

          -- Subscribe to subs
          httpJson("POST", "https://api.twitch.tv/helix/eventsub/subscriptions", headers, {
            type="channel.subscribe",
            version="1",
            condition={broadcaster_user_id=broadcasterId},
            transport={method="websocket",session_id=sessionId}
          })

          -- Subscribe to chat messages (optional)
          if RELAY_TWITCH_CHAT then
            -- channel.chat.message condition requires broadcaster_user_id AND user_id. :contentReference[oaicite:2]{index=2}
            httpJson("POST", "https://api.twitch.tv/helix/eventsub/subscriptions", headers, {
              type="channel.chat.message",
              version="1",
              condition={broadcaster_user_id=broadcasterId, user_id=broadcasterId},
              transport={method="websocket",session_id=sessionId}
            })
          end

          tellraw("§0[§bCubes§0]§f Subscribed")
        end

      elseif mtype == "notification" then
        local sub = d.payload and d.payload.subscription
        local ev  = d.payload and d.payload.event
        if sub and ev and sub.type then
          if sub.type == "channel.cheer" and ev.bits then
            local bits = tonumber(ev.bits) or 0
            if bits > 0 then
              local user = ev.is_anonymous and "Anonymous" or (ev.user_name or ev.user_login or "Someone")
              awardBits(user, bits)
            end

          elseif sub.type == "channel.subscribe" then
            handleSubscribeEvent(ev)

          elseif sub.type == "channel.chat.message" then
            handleChatMessageEvent(ev)
          end
        end
      end
    end

  elseif e == "websocket_closed" then
    http.websocketAsync(WS)
  end
end
