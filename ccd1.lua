-- test.lua (Bothax-ready fixed)
-- Paste entire file into your Bothax scripts folder

-- =========================
-- Compatibility shim
-- =========================
local function find_fn(names)
    for _, n in ipairs(names) do
        if type(_G[n]) == "function" then return _G[n] end
    end
    return nil
end

-- Ensure SendVariant exists
if type(SendVariant) ~= "function" then
    SendVariant = find_fn({"SendVariant", "sendVariant", "SendVariantList", "sendvariant"})
end

-- Ensure SendPacketRaw exists (wrap common variants)
if type(SendPacketRaw) ~= "function" then
    local alt = find_fn({"SendPacketRaw", "sendPacketRaw", "sendpacketraw"})
    if alt then
        SendPacketRaw = alt
    else
        local sp = find_fn({"SendPacket", "sendPacket", "sendpacket"})
        if sp then
            SendPacketRaw = function(t, pkt)
                if type(pkt) == "table" then
                    local s = tostring(pkt.value or pkt.netid or pkt.x or "")
                    sp(t, s)
                else
                    sp(t, tostring(pkt))
                end
            end
        else
            SendPacketRaw = function() end
        end
    end
end

-- Ensure SendPacket exists
if type(SendPacket) ~= "function" then
    SendPacket = find_fn({"SendPacket", "sendPacket", "sendpacket"}) or function() end
end

-- Ensure getters exist
GetPlayerInfo = GetPlayerInfo or find_fn({"GetPlayerInfo", "GetLocal", "getLocal", "getPlayerInfo"})
GetLocal = GetLocal or GetPlayerInfo
GetObjectList = GetObjectList or find_fn({"GetObjectList", "GetWorldObject", "getWorldObject", "getObjectList"})
GetInventory = GetInventory or find_fn({"GetInventory", "getInventory", "getinventory"})

-- Ensure LogToConsole exists
LogToConsole = LogToConsole or find_fn({"LogToConsole", "logToConsole", "logtoConsole"}) or function() end

-- Ensure ImGui safe functions
ImGui = ImGui or {}
ImGui.Begin = ImGui.Begin or function() end
ImGui.End = ImGui.End or function() end
ImGui.Text = ImGui.Text or function() end

-- =========================
-- Utilities & Metadata
-- =========================
local function sleep_s(sec) sleep(sec * 1000) end
local function safe_tostring(v) if v == nil then return "nil" end return tostring(v) end
local function Log(msg) LogToConsole("`9[#Test] `o" .. safe_tostring(msg)) end
local function Overlay(msg)
    if type(SendVariant) == "function" then
        SendVariant({ [0] = "OnTextOverlay", [1] = "`9[#Test] " .. safe_tostring(msg) })
    else
        Log("Overlay: " .. safe_tostring(msg))
    end
end

-- =========================
-- State
-- =========================
local PlayerList = {}
local LogSpin = {}
local data = {}
local Amount = 0
local Tax = 0
local PX1, PY1, PX2, PY2 = 0, 0, 0, 0
local rfspin = true
local reme = true
local qeme = false
local lastGems = nil

-- =========================
-- Dialog strings
-- =========================
local loginp = [[
set_border_color|112,86,191,255
set_bg_color|43,34,74,200
set_default_color|`9
add_label_with_icon|big|[`c#Test`9]       `2Information|left|9474|
add_smalltext|             Version 1.0|
add_quick_exit|
end_dialog|loginpend|Close||
]]

local proxy_dialog = [[
set_border_color|112,86,191,255
set_bg_color|43,34,74,200
set_default_color|`9
add_label_with_icon|big|[`c#Test`9]        `2Features|left|9474|
add_smalltext|             Version 1.0|
add_spacer|small|
add_textbox|`2/commands `9[Show Commands]|
add_spacer|small|
end_dialog|bye|Close|
add_quick_exit|
]]

local function dext(realfakes, remeg, qemeg)
    return "set_border_color|112,86,191,255\nset_bg_color|43,34,74,200\nset_default_color|`9\nadd_label_with_icon|big|`2Spin Cheats   |left|758|\nadd_spacer|small|\nadd_checkbox|realfakespin|`2REAL`0-`4FAKE `0Spin Detector|" .. tostring(realfakes) .. "|\nadd_checkbox|gamereme|`^REME `0Spin Counter|" .. tostring(remeg) .. "|\nadd_checkbox|gameqeme|`9QEME `0Spin Counter|" .. tostring(qemeg) .. "|\nadd_spacer|small|\nend_dialog|proxywrenchend|Close|Enable|\n"
end

-- =========================
-- Inventory / drop / wear helpers
-- =========================
local function CheckItem(id)
    local inv = GetInventory()
    if not inv then return 0 end
    for _, v in pairs(inv) do
        if v.id == id then return v.amount or 0 end
    end
    return 0
end

local function DropItem(id, count)
    SendPacket(2, "action|dialog_return\ndialog_name|drop\nitem_drop|" .. tostring(id) .. "|\nitem_count|" .. tostring(count) .. "\n")
end

local function Wear(id)
    SendPacketRaw(10, { type = 10, value = id })
end

-- =========================
-- Data aggregation & collect
-- =========================
local function AggregateData()
    Amount = 0
    for _, it in pairs(data) do
        if it.id == 7188 then Amount = Amount + (it.count * 10000)
        elseif it.id == 1796 then Amount = Amount + (it.count * 100)
        elseif it.id == 242 then Amount = Amount + it.count end
    end
end

local function collect()
    if PX1 == nil or PY1 == nil or PX2 == nil or PY2 == nil then
        Log("collect(): positions not set")
        return
    end
    data = {}
    local objects = GetObjectList()
    if not objects then
        Log("collect(): GetObjectList returned nil")
        return
    end
    for _, obj in pairs(objects) do
        if obj.pos and obj.pos.x and obj.pos.y and obj.id then
            local tx = math.floor(obj.pos.x / 32)
            local ty = math.floor(obj.pos.y / 32)
            if (tx == PX1 and ty == PY1) or (tx == PX2 and ty == PY2) then
                SendPacketRaw(11, { type = 11, netid = obj.netid or 0, value = obj.oid or obj.netid or 0, x = obj.pos.x, y = obj.pos.y })
                table.insert(data, { id = obj.id, count = obj.amount or 1 })
            end
        end
    end
    AggregateData()
    Log("collect(): Amount = " .. tostring(Amount))
end

-- =========================
-- Player list & spin log
-- =========================
local function AddOrUpdatePlayer(name, netid)
    if not netid then return end
    if PlayerList[netid] == nil or PlayerList[netid].name ~= name then
        PlayerList[netid] = { name = name, netid = netid }
    end
end

local function GetNameByNetid(id)
    if PlayerList[id] then return PlayerList[id].name end
    return nil
end

local function logspin()
    local dialogSpin = {}
    for _, spin in pairs(LogSpin) do table.insert(dialogSpin, spin.spin) end
    local var = {}
    var[0] = "OnDialogRequest"
    var[1] = "set_border_color|112,86,191,255\nset_bg_color|43,34,74,200\nset_default_color|`0\nadd_label_with_icon|big|`2Spin History|left|1436|\nadd_spacer|small|\n" .. table.concat(dialogSpin) .. "\nadd_quick_exit|||\nend_dialog|world_spin|Close||"
    SendVariant(var, -1, 200)
end

local function filterspin(id)
    local filterLog = {}
    for _, log in pairs(LogSpin) do
        if log.netid == id then table.insert(filterLog, "\nadd_label_with_icon_button|small|" .. log.spin .. "|left|758|\n") end
    end
    local var = {}
    var[0] = "OnDialogRequest"
    var[1] = "set_border_color|112,86,191,255\nset_bg_color|43,34,74,200\nset_default_color|`0\nadd_label_with_icon|big|" .. (GetNameByNetid(id) or "Player") .. "`2's Spin History|left|1436|\nadd_spacer|small|\n" .. table.concat(filterLog) .. "\nadd_spacer|small|\nadd_quick_exit|||\nadd_button|backtospin|Back||"
    SendVariant(var, -1, 200)
end

-- =========================
-- Reme / Qeme logic
-- =========================
local function remefunc(number)
    number = tonumber(number) or 0
    if number == 19 or number == 28 or number == 0 then return 0 end
    local num1 = math.floor(number / 10)
    local num2 = number % 10
    local hasil = tostring(num1 + num2)
    return tonumber(string.sub(hasil, -1))
end

local function qemefunc(number)
    number = tonumber(number) or 0
    if number >= 10 then return tonumber(string.sub(tostring(number), -1)) end
    return number
end

local function getGame(num)
    if reme and not qeme then return " `^REME `6" .. tostring(remefunc(tonumber(num))) end
    if not reme and qeme then return " `9QEME `6" .. tostring(qemefunc(tonumber(num))) end
    if reme and qeme then return " `^REME `6" .. tostring(remefunc(num)) .. " `0| `9QEME `6" .. tostring(qemefunc(num)) end
    return ""
end

-- =========================
-- Hooks: OnVarlist
-- =========================
AddHook("OnVarlist", "VarlistHandler", function(var)
    if not var or type(var) ~= "table" then return false end
    local ev = var[0]
    if ev == "OnConsoleMessage" then
        local msg = tostring(var[1] or "")
        if msg:find("Collected") and msg:find("(%d+) Blue Gem Lock") then
            local bgl = msg:match("(%d+) Blue Gem Lock")
            Log("Collected " .. bgl .. " Blue Gem Lock")
            Overlay("Collected " .. bgl .. " Blue Gem Lock")
            return true
        end
        if msg:find("Collected") and msg:find("(%d+) Diamond Lock") then
            local dl = msg:match("(%d+) Diamond Lock")
            Log("Collected " .. dl .. " Diamond Lock")
            Overlay("Collected " .. dl .. " Diamond Lock")
            return true
        end
        if msg:find("Collected") and msg:find("(%d+) World Lock") then
            local wl = msg:match("(%d+) World Lock")
            Log("Collected " .. wl .. " World Lock")
            Overlay("Collected " .. wl .. " World Lock")
            Wear(242)
            return true
        end
    elseif ev == "OnDialogRequest" then
        local content = tostring(var[1] or "")
        if content:find("Drop Blue Gem Lock") or content:find("Drop Diamond Lock") or content:find("Drop World Lock") then
            return true
        end
        if content:find("Telephone") then
            SendPacket(2, "action|dialog_return\ndialog_name|3898\nbuttonClicked|chc2_2_1\n\n")
            return true
        end
    elseif ev == "OnTalkBubble" and rfspin then
        local netid = var[1]
        local text = tostring(var[2] or "")
        if text:find("spun the wheel") then
            if text:find("OID:") then
                SendVariant({ [0] = "OnTalkBubble", [1] = netid, [2] = "[`4FAKE``] " .. text:match("player_chat=(.+)"), [3] = 0 }, -1)
                table.insert(LogSpin, { spin = "\nadd_label_with_icon_button|small|[`4FAKE``] " .. text .. "|left|758|" .. netid .. "|\n", netid = netid, spins = "[`4FAKE``] " .. text })
                return true
            else
                local num = text:match("and got (.+)")
                if num then
                    local onlynumber = string.sub(num, 2)
                    local clearspace = string.gsub(onlynumber, " ", "")
                    local h = string.gsub(string.gsub(clearspace, "!7", ""), "]", "")
                    if netid ~= GetLocal().netid then
                        table.insert(PlayerList, { name = text:match("%[``(.+) spun the"), netid = netid })
                    else
                        AddOrUpdatePlayer(GetLocal().name:gsub("%[(.+)%]", ""), netid)
                    end
                    local namePacket = {}
                    namePacket[0] = "OnNameChanged"
                    namePacket[1] = (GetNameByNetid(netid) or "") .. " `b[`c" .. h .. "``]"
                    SendVariant(namePacket, tonumber(netid))
                    if netid ~= GetLocal().netid then
                        SendVariant({ [0] = "OnTalkBubble", [1] = netid, [2] = "[`2REAL``] " .. text .. getGame(tonumber(h)), [3] = 0 }, -1)
                    else
                        SendVariant({ [0] = "OnTalkBubble", [1] = GetLocal().netid, [2] = "[`2REAL``] " .. GetLocal().name:gsub("%[(.-)%]", ""):gsub("`.","") .. " spun the wheel and got " .. text:match("and got (.+)%!]") .. "!]" .. getGame(tonumber(h)) }, -1)
                    end
                    table.insert(LogSpin, { spin = "\nadd_label_with_icon_button|small|[`2REAL``] " .. text .. "|left|758|" .. netid .. "|\n", netid = netid, spins = text })
                    return true
                end
            end
        end
    end
    return false
end)

-- =========================
-- Hooks: OnTextPacket
-- =========================
AddHook("OnTextPacket", "TextPacketHandler", function(type, packet)
    local pkt = tostring(packet or "")

    if pkt:find("realfakespin|1") then rfspin = true; Log("REAL-FAKE Spin Detector Enabled") end
    if pkt:find("realfakespin|0") then rfspin = false; Log("REAL-FAKE Spin Detector Disabled") end
    if pkt:find("gamereme|1") then reme = true; Log("REME Enabled") end
    if pkt:find("gamereme|0") then reme = false; Log("REME Disabled") end
    if pkt:find("gameqeme|1") then qeme = true; Log("QEME Enabled") end
    if pkt:find("gameqeme|0") then qeme = false; Log("QEME Disabled") end

    if pkt:find("buttonClicked|proxylogspin") then logspin(); return true end
    if pkt:find("dialog_name|world_spin\nbuttonClicked|(%d+)") then local netid = pkt:match("buttonClicked|(%d+)"); filterspin(tonumber(netid)) end
    if pkt:find("buttonClicked|backtospin") then logspin(); return true end

    if pkt:find("action|input\n|text|/spin") then
        local realfakes = rfspin and "1" or "0"
        local remeg = reme and "1" or "0"
        local qemeg = qeme and "1" or "0"
        SendVariant({ [0] = "OnDialogRequest", [1] = dext(realfakes, remeg, qemeg) }, -1, 100)
        Log("/spin")
        return true
    end

    if pkt:find("action|input\n|text|/proxy") then SendVariant({ [0] = "OnDialogRequest", [1] = proxy_dialog }); Log("/proxy"); return true end
    if pkt:find("action|input\n|text|/news") then SendVariant({ [0] = "OnDialogRequest", [1] = loginp }); Log("/news"); return true end

    local db_amt = pkt:match("action|input\n|text|/db (%d+)")
    if db_amt then DropItem(7188, db_amt); Log("/db " .. db_amt); Overlay("Dropped " .. db_amt .. " Blue Gem Lock"); return true end
    local dd_amt = pkt:match("action|input\n|text|/dd (%d+)")
    if dd_amt then DropItem(1796, dd_amt); Log("/dd " .. dd_amt); Overlay("Dropped " .. dd_amt .. " Diamond Lock"); return true end
    local dw_amt = pkt:match("action|input\n|text|/dw (%d+)")
    if dw_amt then DropItem(242, dw_amt); Log("/dw " .. dw_amt); Overlay("Dropped " .. dw_amt .. " World Lock"); return true end

    local cd_amt = pkt:match("action|input\n|text|/cd (%d+)")
    if cd_amt then
        local total = tonumber(cd_amt) or 0
        local bgl = math.floor(total / 10000)
        local rem = total - bgl * 10000
        local dl = math.floor(rem / 100)
        local wl = rem % 100
        if CheckItem(242) < wl then Wear(1796) end
        if CheckItem(1796) < dl then Wear(7188) end
        if bgl > 0 then DropItem(7188, bgl) end
        if dl > 0 then DropItem(1796, dl) end
        if wl > 0 then DropItem(242, wl) end
        local hasil = (bgl ~= 0 and bgl .. " BGL " or "") .. (dl ~= 0 and dl .. " DL " or "") .. (wl ~= 0 and wl .. " WL " or "")
        Log("/cd " .. cd_amt)
        Overlay("Dropped " .. hasil)
        return true
    end

    if pkt:find("action|input\n|text|/daw") then
        if CheckItem(7188) > 0 then DropItem(7188, CheckItem(7188)) end
        if CheckItem(1796) > 0 then DropItem(1796, CheckItem(1796)) end
        if CheckItem(242) > 0 then DropItem(242, CheckItem(242)) end
        Log("/daw")
        Overlay("Dropped all locks")
        return true
    end

    if pkt:find("action|input\n|text|/pos 1") then
        local loc = GetLocal()
        if loc and loc.pos then PX1 = math.floor(loc.pos.x / 32); PY1 = math.floor(loc.pos.y / 32); Log("/pos 1 set to " .. PX1 .. "," .. PY1); Overlay("Set Position 1 to (" .. PX1 .. "," .. PY1 .. ")") end
        return true
    end
    if pkt:find("action|input\n|text|/pos 2") then
        local loc = GetLocal()
        if loc and loc.pos then PX2 = math.floor(loc.pos.x / 32); PY2 = math.floor(loc.pos.y / 32); Log("/pos 2 set to " .. PX2 .. "," .. PY2); Overlay("Set Position 2 to (" .. PX2 .. "," .. PY2 .. ")") end
        return true
    end

    local tax_amt = pkt:match("action|input\n|text|/tax (%d+)")
    if tax_amt then Tax = tonumber(tax_amt) or 0; Log("/tax " .. tostring(Tax)); Overlay("Set Tax to: " .. tostring(Tax) .. "%"); return true end
    local bet_amt = pkt:match("action|input\n|text|/bet (%d+)")
    if bet_amt then TotalBet = tonumber(bet_amt) or 0; Log("/bet " .. tostring(TotalBet)); Overlay("Set Bet to: " .. tostring(TotalBet)); return true end

    if pkt:find("action|input\n|text|/take") then
        data = {}
        collect()
        local tax = math.floor(Amount * Tax / 100)
        local drop = Amount - tax
        Log("/take")
        Overlay("Tax: " .. tostring(Tax) .. "% | Drop to Winner: " .. tostring(drop))
        return true
    end

    if pkt:find("action|input\n|text|/win 1") then
        local tax = math.floor(Amount * Tax / 100)
        local win = Amount - tax
        local drop = win
        local bgl = math.floor(drop / 10000); drop = drop - bgl * 10000
        local dl = math.floor(drop / 100); local wl = drop % 100
        SendPacketRaw(0, { type = 0, x = (PX1) * 32, y = (PY1) * 32, state = 48 })
        if CheckItem(242) < wl then Wear(1796) end
        if CheckItem(1796) < dl then Wear(7188) end
        if bgl > 0 then DropItem(7188, bgl) end
        if dl > 0 then DropItem(1796, dl) end
        if wl > 0 then DropItem(242, wl) end
        Log("/win 1")
        Overlay("Dropped to winner: " .. tostring(win))
        return true
    end

    if pkt:find("action|input\n|text|/win 2") then
        local tax = math.floor(Amount * Tax / 100)
        local win = Amount - tax
        local drop = win
        local bgl = math.floor(drop / 10000); drop = drop - bgl * 10000
        local dl = math.floor(drop / 100); local wl = drop % 100
        SendPacketRaw(0, { type = 0, x = (PX2) * 32, y = (PY2) * 32, state = 32 })
        if CheckItem(242) < wl then Wear(1796) end
        if CheckItem(1796) < dl then Wear(7188) end
        if bgl > 0 then DropItem(7188, bgl) end
        if dl > 0 then DropItem(1796, dl) end
        if wl > 0 then DropItem(242, wl) end
        Log("/win 2")
        Overlay("Dropped to winner: " .. tostring(win))
        return true
    end

    if pkt:find("action|input\n|text|/balance") then
        local loc = GetLocal()
        local gems = loc and loc.gems or 0
        Log("/balance")
        Overlay("Your Gems: " .. tostring(gems) .. " | BGL: " .. tostring(CheckItem(7188)) .. " DL: " .. tostring(CheckItem(1796)) .. " WL: " .. tostring(CheckItem(242)))
        return true
    end

    if pkt:find("action|input\n|text|/slog") then logspin(); return true end
    if pkt:find("action|input\n|text|/time") then local date = os.date("%D"); local time = os.date("%H:%M:%S"); Log("/time"); Overlay("Time: " .. time .. " | Date: " .. date); return true end

    return false
end)

-- =========================
-- Hook: OnRecvPacketRaw -> gems update
-- =========================
AddHook("OnRecvPacketRaw", "GemsUpdate", function(pkt)
    if not pkt then return end
    if pkt.type == 3 then
        local loc = GetLocal()
        if loc then
            local currentGems = tonumber(loc.gems) or 0
            if lastGems == nil or currentGems ~= lastGems then
                Log("Gems Balance: " .. tostring(currentGems))
                lastGems = currentGems
            end
        end
    end
end)

-- =========================
-- ImGui panel
-- =========================
AddHook("ImGui", "GemsPanel", function()
    local loc = GetLocal()
    local gems = loc and loc.gems or 0
    ImGui.Begin("Player Info")
    ImGui.Text("Gems Balance: " .. tostring(gems))
    ImGui.Text("Tax: " .. tostring(Tax) .. "%")
    ImGui.End()
end)

-- =========================
-- Init
-- =========================
if type(SendVariant) == "function" then
    SendVariant({ [0] = "OnDialogRequest", [1] = loginp }, -1, 3500)
end
Overlay("`2Activated")
sleep_s(2)
Overlay("`9Script ready")

-- End of file
