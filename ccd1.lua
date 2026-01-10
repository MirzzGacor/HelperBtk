-- test.lua (Bothax-compatible rewrite)
-- Adapted from original VanzCya script, preserves original features

-- =========================
-- Compatibility shim
-- =========================
local function find_fn(names)
    for _, n in ipairs(names) do
        if type(_G[n]) == "function" then return _G[n] end
    end
    return nil
end

-- sleep fallback (some executors use Sleep or other names)
if type(sleep) ~= "function" then
    sleep = find_fn({"Sleep", "sleep_ms", "sleep_ms"}) or function(ms) end
end
local function SleepS(sec) sleep(sec * 1000) end

-- SendVariant / SendPacket / SendPacketRaw aliases
if type(SendVariant) ~= "function" then
    SendVariant = find_fn({"SendVariant", "sendVariant", "SendVariantList", "sendvariant"})
end

if type(SendPacket) ~= "function" then
    SendPacket = find_fn({"SendPacket", "sendPacket", "sendpacket"}) or function() end
end

if type(SendPacketRaw) ~= "function" then
    local alt = find_fn({"SendPacketRaw", "sendPacketRaw", "sendpacketraw"})
    if alt then
        SendPacketRaw = alt
    else
        if type(SendPacket) == "function" then
            SendPacketRaw = function(flag_or_type, pkt)
                if type(flag_or_type) == "boolean" then
                    if type(pkt) == "table" and pkt.type then
                        SendPacket(pkt.type, tostring(pkt.value or ""))
                    else
                        SendPacket(0, tostring(pkt or ""))
                    end
                else
                    SendPacket(flag_or_type, tostring(pkt and (pkt.value or pkt.netid or "") or ""))
                end
            end
        else
            SendPacketRaw = function() end
        end
    end
end

-- Getters aliases
GetLocal = GetLocal or find_fn({"GetLocal", "getLocal", "GetPlayerInfo", "GetPlayer"}) or function() return nil end
GetObjectList = GetObjectList or find_fn({"GetObjectList", "GetWorldObject", "getWorldObject", "getObjectList"}) or function() return {} end
GetInventory = GetInventory or find_fn({"GetInventory", "getInventory", "getinventory"}) or function() return {} end
GetTiles = GetTiles or find_fn({"GetTiles", "getTiles"}) or function() return {} end
GetPlayerList = GetPlayerList or find_fn({"GetPlayerList", "getPlayerList"}) or function() return {} end
GetWorld = GetWorld or find_fn({"GetWorld", "getWorld"}) or function() return { name = "" } end

-- Logging
LogToConsole = LogToConsole or find_fn({"LogToConsole", "logToConsole"}) or function() end
local function Log(msg) LogToConsole("`o[`#BothaxProxy`o] `6" .. tostring(msg)) end
local function Overlay(msg)
    if type(SendVariant) == "function" then
        SendVariant({ [0] = "OnTextOverlay", [1] = "`9[`#BothaxProxy`9] " .. tostring(msg) })
    else
        Log("Overlay: " .. tostring(msg))
    end
end

-- ImGui safe stubs
ImGui = ImGui or {}
ImGui.Begin = ImGui.Begin or function() end
ImGui.End = ImGui.End or function() end
ImGui.Text = ImGui.Text or function() end

-- =========================
-- State (preserve original)
-- =========================
Tax = Tax or 5

leftd = false
rightd = false
local PX1, PY1, PX2, PY2 = nil, nil, nil, nil

placeset = false
gem1 = false
gem2 = false
local xgem1, ygem1, xgem2, ygem2, xgem3, ygem3
local xgemm1, ygemm1, xgemm2, ygemm2, xgemm3, ygemm3

count = 0
data = {}
Amount = 0

cvdl = false
pull = false
kick = false
bx = 0
by = 0
ban = false
autosb = false
punchset = false
AutoBtk = false
resetchand1 = false
resetchand2 = false
relog = false
bgl, dl, wl, drop = 0, 0, 0, 0

-- =========================
-- UI / Dialog strings
-- =========================
local function lmo(setx, sety)
    if not setx and not sety then return "`4Did You Done Set This?``" end
    return tostring(setx) .. "," .. tostring(sety)
end

local function pos_dialog()
    local var = {}
    var[0] = "OnDialogRequest"
    var[1] = [[
add_label_with_icon|big|Set Our Pos To Host|left|1422|
add_button|pos|Set Take Pos [`4TAP`o]|NOFLAGS|0|
add_textbox|Left Take Pos (]]..lmo(PX1, PY1)..[[)|
add_textbox|Right Take Pos (]]..lmo(PX2, PY2)..[[)|
add_spacer|small|
add_button|gems|Set Pos gems? [`4TAP`o]|NOFLAGS|0|
add_textbox|Left Gems (]]..lmo(xgem1, ygem1)..[[)(]]..lmo(xgem2, ygem2)..[[)(]]..lmo(xgem3, ygem3)..[[)|
add_textbox|Right Gems (]]..lmo(xgemm1, ygemm1)..[[)(]]..lmo(xgemm2, ygemm2)..[[)(]]..lmo(xgemm3, ygemm3)..[[)|
add_quick_exit|
]]
    if type(SendVariant) == "function" then SendVariant(var) else Log("SendVariant not available") end
end

local wrenchop = [[add_label_with_icon|big|`5Wrench|left|11816|
add_spacer|small|
text_scaling_string|asdasdasdsaas|
add_button_with_icon|wdef|`wWrench Default|staticBlueFrame|278||
add_button_with_icon|wpull|`wWrench Pull|staticBlueFrame|274||
add_button_with_icon|wkick|`wWrench Kick|staticBlueFrame|276||
add_button_with_icon|wban|`wWrench Ban|staticBlueFrame|732||
add_button_with_icon||END_LIST|noflags|0||
add_spacer|small|
end_dialog|wh|Ok|
]]

local tap = [[
add_label_with_icon|big|BTK|left|340|
add_button_with_icon|tk|Take Bets|staticBlueFrame|6140|
add_button_with_icon|ck|Check Gems|staticBlueFrame|6016|
add_button_with_icon||END_LIST|noflags|0||
add_button_with_icon|w1|Pos 1 Win!!|staticBlueFrame|1440|
add_button_with_icon|w2|Pos 2 Win!!|staticBlueFrame|1440|
add_button_with_icon||END_LIST|noflags|0||
add_button_with_icon|ra|Reset Chand Vertical|staticBlueFrame|340|
add_button_with_icon|rd|Reset Chand Horizontal|staticBlueFrame|340|
add_quick_exit|
]]

local lol = [[add_player_info|Hi Pekuy|500000|500000|
add_spacer|small|
add_spacer|small|
add_button_with_icon|Wrench|Wrench List|staticBlueFrame|32|
add_button_with_icon|cbgl|`wC Bgl Mode|staticBlueFrame|7188||
add_button_with_icon|Proxy|Proxy Command|staticBlueFrame|10864|
add_button_with_icon|blockSDB|`4Block Sdb|staticBlueFrame|2480|
end_dialog|kk||
add_quick_exit|
]]

local proxy = [[end_dialog|bye|exit?|Serius bro?|
add_quick_exit|
add_spacer|big|
add_label_with_icon|big|Feature Script Masze|left|32|
add_spacer|big|
add_textbox|Feature Drop Item VVVVVVVVVVVV|
add_textbox|/cd [brapa mau drop] ya tau lah fungsinya apa ga work for ireng|
add_textbox|/bd [Brapa Mau Drop] Drop `eBlue Gem Lock|
add_textbox|/dd [Brapa Mau Drop] Drop `1Diamond Lock|
add_textbox|/wd [Brapa Mau Drop] Drop `9World Lock|
add_textbox|/bb [Brapa Mau Drop] Drop `bBlack Gem Lock|
add_spacer|big|
add_label_with_icon|big|`oBtk Helperrrrrrrrr|left|340|
add_textbox|Tap Ae Gems Store Nanti Show menu|
]]

-- =========================
-- Core helpers
-- =========================
local function DropItem(id, count)
    SendPacket(2, "action|dialog_return\ndialog_name|drop\nitem_drop|"..tostring(id).."|\nitem_count|"..tostring(count).."\n")
end

local function Data()
    Amount = 0
    for _, list in pairs(data) do
        local Name = ""
        if list.id == 7188 then
            Name = "Blue Gem Lock"
            Amount = Amount + list.count * 10000
        elseif list.id == 1796 then
            Name = "Diamond Lock"
            Amount = Amount + list.count * 100
        elseif list.id == 242 then
            Name = "World Lock"
            Amount = Amount + list.count
        end
        Log("Collected "..tostring(list.count).." "..Name)
    end
    data = {}
end

local function colect()
    local tiles = { {PX1, PY1}, {PX2, PY2} }
    local objects = GetObjectList()
    if not objects then return end
    for _, obj in pairs(objects) do
        for _, t in pairs(tiles) do
            if obj.pos and obj.pos.x and obj.pos.y and (math.floor(obj.pos.x/32) == t[1]) and (math.floor(obj.pos.y/32) == t[2]) then
                SendPacketRaw(false, { type = 11, value = obj.oid or obj.netid, x = obj.pos.x, y = obj.pos.y })
                table.insert(data, { id = obj.id, count = obj.amount or 1 })
            end
        end
    end
    Data()
    data = {}
end

local function checkitm(id)
    for _, inv in pairs(GetInventory()) do
        if inv.id == id then return inv.amount end
    end
    return 0
end

local function wear(id)
    SendPacketRaw(false, { type = 10, value = id })
end

local function ovlay(str)
    if type(SendVariant) == "function" then
        SendVariant({ [0] = "OnTextOverlay", [1] = "`9[`#VanzCyaScript#001`9] " .. tostring(str) })
    else
        Log(str)
    end
end

local function tol(txt) Log(txt) end

-- =========================
-- OnSendPacket handler (commands & dialog buttons)
-- =========================
AddHook("OnSendPacket", "packet", function(packet)
    if not packet then return false end
    local pkt = tostring(packet)

    if pkt:find("/test (.+)") then
        local yes = pkt:match("/test (.+)")
        if yes and type(SendVariant) == "function" then
            SendVariant({ [0] = "OnTalkBubble", [1] = GetLocal().netid, [2] = tostring(yes) })
        end
        return true
    end

    if pkt:find("buttonClicked|blockSDB") then
        blocksdb = not blocksdb
        ovlay(blocksdb and "`2Block Sdb Mode Enabled" or "`4Block Sdb Mode Disabled")
        return true
    end

    if pkt:find("action|dialog_return\ndialog_name|kk\nbuttonClicked|Wrench") then
        if type(SendVariant) == "function" then SendVariant({ [0] = "OnDialogRequest", [1] = wrenchop }) end
        Log("Wrench Option")
        return true
    end

    if pkt:find("buttonClicked|pos") then
        leftd = true; punchset = true; ovlay("`4Punch Left Display"); return true
    end

    if pkt:find("buttonClicked|gems") then
        gem1 = true; placeset = true
        ovlay("`oPlace Left Chandelier instructions")
        tol("Place Left Chandelier instructions shown")
        return true
    end

    if pkt:find("action|dialog_return\ndialog_name|kk\nbuttonClicked|Proxy") then
        if type(SendVariant) == "function" then SendVariant({ [0] = "OnDialogRequest", [1] = proxy }) end
        Log("Feature list")
        return true
    end

    if pkt:find("/ac") then
        for _, tile in pairs(GetTiles()) do
            if tile.fg == 3898 then
                local x = tile.x; local y = tile.y
                SendPacket(2, "action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|" .. tostring(x) .. "|\ny|" .. tostring(y) .. "|\nbuttonClicked|bglconvert")
                return true
            end
        end
    end

    local txt = pkt:match("action|input\n|text|/d (%d+)") or pkt:match("/d (%d+)")
    if txt then DropItem(1796, txt); tol("Succes Drop `0"..txt.." `2Diamond Lock"); return true end

    txt = pkt:match("action|input\n|text|/w (%d+)") or pkt:match("/w (%d+)")
    if txt then DropItem(242, txt); tol("Succes Drop `0"..txt.." `2World Lock"); return true end

    txt = pkt:match("action|input\n|text|/b (%d+)") or pkt:match("/b (%d+)")
    if txt then DropItem(7188, txt); tol("`2Succes Drop `0"..txt.." `2Blue Gem Lock"); return true end

    txt = pkt:match("action|input\n|text|/bb (%d+)") or pkt:match("/bb (%d+)")
    if txt then
        if checkitm(11550) == 0 then
            SendPacket(2,"action|dialog_return\ndialog_name|info_box\nbuttonClicked|make_bgl\n")
            return true
        end
        DropItem(11550, txt); tol("`2Succes Drop `0"..txt.." `bBlack Gem Lock"); return true
    end

    if pkt:find("/ww (.+)") then
        local namew = pkt:match("/ww (.+)")
        if namew then ovlay("`#Warping To `6"..namew); SendPacket(3, "action|join_request\n|name|"..tostring(namew).."\n|invitedWorld|0"); return true end
    end

    if pkt:find("/bdl") then cvdl = not cvdl; ovlay(cvdl and "`2Buy Dl Mode Enable" or "`4Buy Dl Mode Disable"); return true end

    if pkt:find("/help") or pkt:find("/fitur") then
        tol("Commands: /w /d /b /bb /cd /ac /ww /pos /setb /stax")
        return true
    end

    if pkt:find("/setb") then
        bx = math.floor(GetLocal().pos.x / 32); by = math.floor(GetLocal().pos.y / 32)
        ovlay("Succes Set Back Pos ("..tostring(bx)..", "..tostring(by)..")"); return true
    end

    if pkt:find("\nbuttonClicked|ra") then
        if by == 0 then ovlay("U Didnt Set Back Pos Lol Do /setb") else resetchand1 = true; ovlay("Put Chand Wait"); return true end
    end
    if pkt:find("\nbuttonClicked|rd") then
        if by == 0 then ovlay("U Didnt Set Back Pos Lol Do /setb") else resetchand2 = true; ovlay("Put Chand Wait"); return true end
    end

    if pkt:find("friends") then if type(SendVariant) == "function" then SendVariant({ [0] = "OnDialogRequest", [1] = lol }) end; tol("Proxy List"); return true end
    if pkt:find("store") then if type(SendVariant) == "function" then SendVariant({ [0] = "OnDialogRequest", [1] = tap }) end; tol("Btk Helperr"); return true end
    if pkt:find("/pos") then pos_dialog(); return true end

    if pkt:find("/cd (%d+)") then
        Amount = tonumber(pkt:match("/cd (%d+)")) or 0
        Log("Use Fitur : /cd")
        bgl = math.floor(Amount/10000)
        local rem = Amount - bgl*10000
        dl = math.floor(rem/100)
        wl = rem % 100
        AutoBtk = true
        local hasil = (bgl ~= 0 and bgl.." BGL " or "") .. (dl ~= 0 and dl.." DL " or "") .. (wl ~= 0 and wl.." WL " or "")
        tol("Total drop : "..hasil)
        return true
    end

    if pkt:find("/stax (%d+)") then Tax = pkt:match("/stax (%d+)") or Tax; ovlay("Tax : "..tostring(Tax).."%"); return true end

    if pkt:find("\nbuttonClicked|tk") then
        if Tax == 0 then ovlay("`4Set Tax First"); return true end
        colect()
        local tax = math.floor(Amount * Tax / 100)
        local dropv = Amount - tax
        local bets = math.floor(Amount / 2)
        tol("Tax : "..tostring(Tax).."%, Total drop : "..tostring(dropv))
        tol("Succes Take")
        SendPacket(2,"action|input\n|text|[`#VanzCya`] "..tostring(bets).." (wl) Bets Are and tax is "..tostring(Tax).."% Total Drop: "..tostring(dropv).." (wl)")
        return true
    end

    if pkt:find("\nbuttonClicked|w1") then
        if Tax == 0 then ovlay("`4Set Tax First"); return true end
        bgl = math.floor(drop/10000); drop = drop - bgl*10000
        dl = math.floor(drop/100); wl = drop % 100
        SendPacketRaw(false, { type = 0, x = (PX1 - 2) * 32, y = (PY1) * 32, state = 32 })
        AutoBtk = true
        tol("Amount Lock : "..tostring(Amount))
        tol("Tax : "..tostring(Tax).."%")
        tol("Total drop : reset")
        return true
    end

    if pkt:find("\nbuttonClicked|w2") then
        if Tax == 0 then ovlay("`4Set Tax first"); return true end
        bgl = math.floor(drop/10000); drop = drop - bgl*10000
        dl = math.floor(drop/100); wl = drop % 100
        SendPacketRaw(false, { type = 0, x = (PX2 + 2) * 32, y = (PY2) * 32, state = 48 })
        AutoBtk = true
        tol("Amount Lock : "..tostring(Amount))
        tol("Tax : "..tostring(Tax).."%")
        tol("Total drop : reset")
        return true
    end

    return false
end)

-- =========================
-- OnVariant handler
-- =========================
AddHook("OnVariant", "var", function(var)
    if not var or type(var) ~= "table" then return false end

    if var[0] == "OnConsoleMessage" and tostring(var[1] or ""):find("commands.") then
        tol("`cIDK What Command U Use There Was No Have Command Like That ")
        tol("`9Type /fitur to show feature")
        return true
    end

    if tostring(var[0] or ""):find("OnDialogRequest") and tostring(var[1] or ""):find("end_dialog|telephone") then
        if cvdl == true then
            SendPacket(2, "action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|"..tostring(var[1]:match("embed_data|x|(%d+)")).."|\ny|"..tostring(var[1]:match("embed_data|y|(%d+)")).."|\nbuttonClicked|dlconvert")
            return true
        end
    end

    if var[0] == "OnTalkBubble" and tostring(var[2] or ""):find("spun the wheel and got") and
       (tostring(var[2]):find("`4(%d+)``!") or tostring(var[2]):find("`b(%d+)``!") or tostring(var[2]):find("`2(%d+)``!")) then
        local SpunNumber = tostring(var[2]):match("`4(%d+)``!") or tostring(var[2]):match("`b(%d+)``!") or tostring(var[2]):match("`2(%d+)``!")
        local Num1, Num2 = math.floor(tonumber(SpunNumber)/10), tonumber(SpunNumber) % 10
        local Reme = Num1 + Num2
        if Reme > 10 then Reme = Reme % 10 elseif Reme == 10 then Reme = "`20" end
        var[0] = "OnTalkBubble"
        var[1] = var[1]
        var[2] = tostring(var[2]) .. " (cool)Fast `0 `2Reme`0 [ " .. tostring(Reme) .. "`0 ]"
        if type(SendVariant) == "function" then SendVariant(var) end
        return true
    end

    if var[0] == "OnSDBroadcast" and blocksdb == true then
        ovlay("`#Va:VanzCya `9I Blocked Sdb Say Thanks To me")
        return true
    end

    if tostring(var[0] or ""):find("OnDialogRequest") and tostring(var[1] or ""):find("Wow, that's fast delivery.") then
        ovlay("Block Dialog Telephone")
        return true
    end

    return false
end)

-- =========================
-- OnSendPacketRaw handler (tile clicks / placements)
-- =========================
AddHook("OnSendPacketRaw", "rawr", function(a)
    if not a or type(a) ~= "table" then return false end

    if a.type == 3 and a.value == 18 then
        if punchset == true then
            for _, display in pairs(GetTiles()) do
                if (display.fg == 1422 or display.fg == 2488) and display.x == a.px and display.y == a.py then
                    if leftd and not rightd then
                        PX1 = a.px; PY1 = a.py
                        SendPacket(2,"action|input\n|text|Succes Set Left Pos")
                        ovlay("Success Set Left Display `2(" .. tostring(a.px) .. "," .. tostring(a.py) .. ") `4Punch Right Display")
                        leftd = false; rightd = true
                    elseif rightd and not leftd then
                        PX2 = a.px; PY2 = a.py
                        ovlay("Success Set Right Display `2(" .. tostring(a.px) .. "," .. tostring(a.py) .. ")")
                        rightd = false; punchset = false
                        SendPacket(2,"action|input\n|text|Succes Set Right Pos")
                        tol("`2Done Set Take Pos")
                        pos_dialog()
                    end
                end
            end
        end
        return true
    end

    if a.type == 3 and a.value == 5640 then
        if placeset == true then
            for _, display in pairs(GetTiles()) do
                if display.x == a.px and display.y == a.py then
                    if gem1 and not gem2 and not leftd and not rightd then
                        xgem1 = a.px; ygem1 = a.py
                        xgem2 = xgem1 + 1; ygem2 = ygem1 - 1
                        xgem3 = xgem1 - 1; ygem3 = ygem1 - 2
                        tile = {
                            pos1 = {
                                { x = xgem1, y = ygem1 }, { x = xgem1, y = ygem2 }, { x = xgem1, y = ygem3 },
                                { x = xgem2, y = ygem1 }, { x = xgem3, y = ygem1 }
                            },
                            pos2 = {
                                { x = xgemm1, y = ygemm1 }, { x = xgemm1, y = ygemm2 }, { x = xgemm1, y = ygemm3 },
                                { x = xgemm2, y = ygemm1 }, { x = xgemm3, y = ygemm1 }
                            }
                        }
                        gem1 = false; gem2 = true
                        SendPacket(2,"action|input\n|text|Succes Set Left GEMS")
                        ovlay("Success Set Left Gems `2(" .. tostring(a.px) .. "," .. tostring(a.py) .. ") (" .. tostring(xgem2) .. "," .. tostring(ygem2) .. ") (" .. tostring(xgem3) .. "," .. tostring(ygem3) .. ")")
                    elseif gem2 and not gem1 then
                        xgemm1 = a.px; ygemm1 = a.py
                        xgemm2 = xgemm1 + 1; ygemm2 = ygemm1 - 1
                        xgemm3 = xgemm1 - 1; ygemm3 = ygemm1 - 2
                        tile = {
                            pos1 = {
                                { x = xgem1, y = ygem1 }, { x = xgem1, y = ygem2 }, { x = xgem1, y = ygem3 },
                                { x = xgem2, y = ygem1 }, { x = xgem3, y = ygem1 }
                            },
                            pos2 = {
                                { x = xgemm1, y = ygemm1 }, { x = xgemm1, y = ygemm2 }, { x = xgemm1, y = ygemm3 },
                                { x = xgemm2, y = ygemm1 }, { x = xgemm3, y = ygemm1 }
                            }
                        }
                        gem2 = false; placeset = false
                        SendPacket(2,"action|input\n|text|Succes Set Right GEMS")
                        pos_dialog()
                        ovlay("`2Done Set Pos Gems")
                        ovlay("Success Set Right Gems `2(" .. tostring(a.px) .. "," .. tostring(a.py) .. ") (" .. tostring(xgemm2) .. "," .. tostring(ygemm2) .. ") (" .. tostring(xgemm3) .. "," .. tostring(ygemm3) .. ")")
                    end
                end
            end
            return true
        end
    end

    return false
end)

-- =========================
-- collect / colecp helpers (safe)
-- =========================
local function collect_safe()
    local Count = 0
    data = {}
    local objects = GetObjectList()
    if not objects or not tile or not tile.pos1 or not tile.pos2 then return end

    for _, obj in pairs(objects) do
        for _, t in pairs(tile.pos1) do
            if obj.id == 112 and math.floor(obj.pos.x/32) == t.x and math.floor(obj.pos.y/32) == t.y then
                Count = Count + (obj.amount or 1)
                SendPacketRaw(true, { type = 11, value = obj.oid or obj.netid, x = obj.pos.x, y = obj.pos.y })
            end
        end
    end
    table.insert(data, Count); Count = 0

    for _, obj in pairs(objects) do
        for _, t in pairs(tile.pos2) do
            if obj.id == 112 and math.floor(obj.pos.x/32) == t.x and math.floor(obj.pos.y/32) == t.y then
                Count = Count + (obj.amount or 1)
                SendPacketRaw(true, { type = 11, value = obj.oid or obj.netid, x = obj.pos.x, y = obj.pos.y })
            end
        end
    end
    table.insert(data, Count); Count = 0

    if (data[1] or 0) > (data[2] or 0) then
        SendPacket(2,"action|input\n|text|`0 [`2Win`0] `1Gems : `9"..tostring(data[1]).." VS `4"..tostring(data[2]).." `0[`4Lose`0]")
    elseif (data[1] or 0) == (data[2] or 0) then
        SendPacket(2,"action|input\n|text|`0[`1Tie`0] `1Gems : `9"..tostring(data[1]).." VS `9"..tostring(data[2]).." `0[`1Tie`0]")
    else
        SendPacket(2,"action|input\n|text|`0 [`4Lose`0] `1Gems : `9"..tostring(data[1]).." VS `2"..tostring(data[2]).." `0[`2Win`0]")
    end
    data = {}
end

local function colecp1() if tile and tile.pos1 then for _, obj in pairs(GetObjectList()) do for _, t in pairs(tile.pos1) do if obj.id == 112 and math.floor(obj.pos.x/32) == t.x and math.floor(obj.pos.y/32) == t.y then SendPacketRaw(false, { type = 11, value = obj.oid or obj.netid, x = obj.pos.x, y = obj.pos.y }) end end end end end
local function colecp2() if tile and tile.pos2 then for _, obj in pairs(GetObjectList()) do for _, t in pairs(tile.pos2) do if obj.id == 112 and math.floor(obj.pos.x/32) == t.x and math.floor(obj.pos.y/32) == t.y then SendPacketRaw(false, { type = 11, value = obj.oid or obj.netid, x = obj.pos.x, y = obj.pos.y }) end end end end end
local function colecp3() colecp1() end
local function colecp4() colecp2() end

-- =========================
-- Init messages
-- =========================
ovlay("Script Has Ben Run")
SleepS(2)
ovlay("Type /help or /fitur to show feature")
SendPacket(2,"action|input\n|text|Script Proxy Bothax By VanzCya")

-- =========================
-- Main loop
-- =========================
while true do
    SleepS(0.5)
    if AutoBtk then
        SleepS(0.2)
        if checkitm(1796) < (dl or 0) then wear(7188); SleepS(0.5) end
        if checkitm(242) < (wl or 0) then wear(1796); SleepS(0.5) end
        if (bgl or 0) > 0 then DropItem(7188, bgl); SleepS(0.5) end
        if (dl or 0) > 0 then DropItem(1796, dl); SleepS(0.5) end
        if (wl or 0) > 0 then DropItem(242, wl) end
        drop = ""; Amount = ""; AutoBtk = false
    end

    if resetchand1 then
        SleepS(0.5)
        if xgem1 and ygem2 then
            FindPath(xgem1, ygem2)
            ChangeFeature("Modfly", true)
            SleepS(0.2)
            SendPacketRaw(false, { type = 3, x = GetLocal().pos.x, y = GetLocal().pos.y, px = xgem1, py = ygem1, value = 5640, state = 16 })
            SleepS(0.2)
            SendPacketRaw(false, { type = 3, x = GetLocal().pos.x, y = GetLocal().pos.y, px = xgem1, py = ygem2, value = 5640, state = 16 })
            SleepS(0.2)
            SendPacketRaw(false, { type = 3, x = GetLocal().pos.x, y = GetLocal().pos.y, px = xgem1, py = ygem3, value = 5640, state = 16 })
            colecp1(); SleepS(0.2)
            FindPath(xgemm1, ygemm2); SleepS(0.2)
            SendPacketRaw(false, { type = 3, x = GetLocal().pos.x, y = GetLocal().pos.y, px = xgemm1, py = ygemm1, value = 5640, state = 16 })
            SleepS(0.2)
            SendPacketRaw(false, { type = 3, x = GetLocal().pos.x, y = GetLocal().pos.y, px = xgemm1, py = ygemm2, value = 5640, state = 16 })
            SleepS(0.2)
            SendPacketRaw(false, { type = 3, x = GetLocal().pos.x, y = GetLocal().pos.y, px = xgemm1, py = ygemm3, value = 5640, state = 16 })
            colecp2(); SleepS(0.2)
            FindPath(bx, by)
            ChangeFeature("Modfly", false)
        end
        resetchand1 = false
    end

    if resetchand2 then
        SleepS(0.5)
        if xgem1 and ygem1 and xgem2 and xgem3 and xgemm1 and xgemm2 and xgemm3 then
            FindPath(xgem1 + 2, ygem1); SleepS(0.1)
            FindPath(xgem1, ygem1); SleepS(0.25)
            SendPacketRaw(false, { type = 3, x = GetLocal().pos.x, y = GetLocal().pos.y, px = xgem1, py = ygem1, value = 5640, state = 16 })
            SleepS(0.25)
            SendPacketRaw(false, { type = 3, x = GetLocal().pos.x, y = GetLocal().pos.y, px = xgem2, py = ygem1, value = 5640, state = 16 })
            SleepS(0.25)
            SendPacketRaw(false, { type = 3, x = GetLocal().pos.x, y = GetLocal().pos.y, px = xgem3, py = ygem1, value = 5640, state = 16 })
            colecp3(); SleepS(0.5)
            FindPath(xgem1 + 4, ygem1); SleepS(0.1)
            FindPath(xgemm1 - 2, ygemm1); SleepS(0.1)
            FindPath(xgemm1, ygemm1); SleepS(0.25)
            SendPacketRaw(false, { type = 3, x = GetLocal().pos.x, y = GetLocal().pos.y, px = xgemm1, py = ygemm1, value = 5640, state = 16 })
            SleepS(0.25)
            SendPacketRaw(false, { type = 3, x = GetLocal().pos.x, y = GetLocal().pos.y, px = xgemm2, py = ygemm1, value = 5640, state = 16 })
            SleepS(0.25)
            SendPacketRaw(false, { type = 3, x = GetLocal().pos.x, y = GetLocal().pos.y, px = xgemm3, py = ygemm1, value = 5640, state = 16 })
            colecp4(); SleepS(0.5)
            FindPath(bx, by)
        end
        resetchand2 = false
    end

    if relog then
        SendPacket(3,"action|quit_to_exit")
        SleepS(0.1)
        SendPacket(3, "action|join_request\n|name|"..tostring(namew or "").."\n|invitedWorld|0")
        relog = false
    end
end
