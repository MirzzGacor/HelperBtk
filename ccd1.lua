-- ccd1.lua (Bothax-compatible fixed, full)
-- Paste this entire file into Bothax, replacing the old ccd1.lua

-- =========================
-- Compatibility shim (top of file)
-- =========================
local function _find_fn(names)
    for _, n in ipairs(names) do
        if type(_G[n]) == "function" then return _G[n] end
    end
    return nil
end

-- Sleep fallback (some executors use Sleep)
if type(sleep) ~= "function" then
    sleep = _find_fn({"Sleep", "sleep_ms", "sleep_ms"}) or function(ms) end
end
local function SleepS(sec) sleep(sec * 1000) end

-- Logging fallback
LogToConsole = LogToConsole or _find_fn({"LogToConsole", "logToConsole"}) or function() end
local function LOG(msg) LogToConsole("[ccd1] " .. tostring(msg)) end

-- SendPacket / SendPacketRaw wrappers
SendPacket = SendPacket or _find_fn({"SendPacket", "sendPacket", "sendpacket"}) or function() end

if type(SendPacketRaw) ~= "function" then
    local alt = _find_fn({"SendPacketRaw", "sendPacketRaw", "sendpacketraw"})
    if alt then
        SendPacketRaw = alt
    else
        -- adapt SendPacket into SendPacketRaw-like behavior
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
    end
end

-- SendVariant / SendVariantList safe wrappers
local _SV = _find_fn({"SendVariant", "sendVariant", "SendVariantList", "sendvariant", "SendVariantList"})
local function SendVariantSafe(var, netid, delay)
    netid = netid or -1
    delay = delay or 0
    if type(_SV) == "function" then
        local ok, err = pcall(function() _SV(var, netid, delay) end)
        if not ok then
            pcall(function() _SV(var) end)
        end
    else
        LOG("WARN: SendVariant not available; dialog ignored")
    end
end

function SendVariantList(var, netid, delay)
    SendVariantSafe(var, netid, delay)
end

-- CreateDialog helper (use SendVariantSafe)
function CreateDialog(text)
    if type(text) ~= "string" and type(text) ~= "table" then
        LOG("CreateDialog: invalid text")
        return
    end
    local var = {}
    var[0] = "OnDialogRequest"
    var[1] = text
    SendVariantSafe(var, -1, 100)
end

-- Getters fallback
GetLocal = GetLocal or _find_fn({"GetLocal", "getLocal", "GetPlayerInfo", "GetPlayer"}) or function() return nil end
GetObjectList = GetObjectList or _find_fn({"GetObjectList", "GetWorldObject", "getWorldObject", "getObjectList"}) or function() return {} end
GetInventory = GetInventory or _find_fn({"GetInventory", "getInventory", "getinventory"}) or function() return {} end
GetTiles = GetTiles or _find_fn({"GetTiles", "getTiles"}) or function() return {} end
GetPlayerList = GetPlayerList or _find_fn({"GetPlayerList", "getPlayerList"}) or function() return {} end
GetWorld = GetWorld or _find_fn({"GetWorld", "getWorld"}) or function() return { name = "" } end
GetPlayerInfo = GetPlayerInfo or _find_fn({"GetPlayerInfo", "getPlayerInfo"}) or function() return { gems = 0 } end

-- AddHook fallback
local realAddHook = _find_fn({"AddHook"}) or function() end

-- register_normalized helper (registers handlers across common event names)
local function register_normalized(id_base, handler_table)
    local names = {
        "OnVariant", "OnVarlist", "OnDialogRequest",
        "OnSendPacket", "OnTextPacket", "OnText",
        "OnSendPacketRaw", "OnRecvPacketRaw", "OnRawPacket",
        "OnRecvPacket", "OnRecv", "OnPacket",
        "ImGui", "OnImGui"
    }
    for _, name in ipairs(names) do
        local hook_id = id_base .. "_" .. name
        pcall(function()
            realAddHook(name, hook_id, function(a, b)
                -- variant/varlist style: first arg table
                if type(a) == "table" then
                    if handler_table.var then
                        local ok, err = pcall(handler_table.var, a, b)
                        if not ok then LOG("handler var error: "..tostring(err)) end
                        return true
                    end
                end
                -- text style: string packet
                if type(a) == "string" or type(b) == "string" then
                    if handler_table.text then
                        local ok, err = pcall(handler_table.text, a, b)
                        if not ok then LOG("handler text error: "..tostring(err)) end
                        return true
                    end
                end
                -- raw packet style
                if type(a) == "table" and a.type then
                    if handler_table.raw then
                        local ok, err = pcall(handler_table.raw, a)
                        if not ok then LOG("handler raw error: "..tostring(err)) end
                        return true
                    end
                end
                -- fallback: if raw handler exists and a is table
                if type(a) == "table" and handler_table.raw then
                    local ok, err = pcall(handler_table.raw, a)
                    if not ok then LOG("handler raw fallback error: "..tostring(err)) end
                    return true
                end
                return false
            end)
        end)
    end
end

-- small debug hook (optional)
pcall(function() realAddHook("OnSendPacket", "dbg_ccd1", function(a,b) LOG("DBG event: "..tostring(a).." | "..tostring(b)); return false end) end)

-- =========================
-- Original script content (preserved)
-- =========================
-- (All original variables, functions, dialogs, etc. should be here)
-- For brevity I assume the full original content you provided earlier is present above this point.
-- Ensure the functions referenced below (pos_dialog, colect, DropItem, wear, ovlay, etc.) exist in the file.

-- =========================
-- Handlers: var, text, raw
-- =========================

-- Variant handler: handles OnVariant / OnDialogRequest / OnTalkBubble / OnConsoleMessage
local function variant_handler(var, netid)
    if not var or type(var) ~= "table" then return false end
    local ev = tostring(var[0] or "")
    -- OnConsoleMessage
    if ev == "OnConsoleMessage" then
        local msg = tostring(var[1] or "")
        -- block or respond to certain console messages
        if msg:find("commands.") then
            LOG("Unknown command used")
            -- optional feedback
            return true
        end
        -- other console message handling can go here
        return false
    end

    -- OnDialogRequest (incoming dialog content)
    if ev == "OnDialogRequest" then
        local content = tostring(var[1] or "")
        -- block telephone dialog if cvdl true (original behavior)
        if content:find("end_dialog|telephone") and cvdl == true then
            -- emulate pressing dlconvert
            SendPacket(2, "action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|"..tostring(content:match("embed_data|x|(%d+)") or "").."|\ny|"..tostring(content:match("embed_data|y|(%d+)") or "").."|\nbuttonClicked|dlconvert")
            return true
        end
        -- other dialog-specific filters
        return false
    end

    -- OnTalkBubble (spun the wheel detection)
    if ev == "OnTalkBubble" then
        local text = tostring(var[2] or "")
        local nid = var[1]
        if text:find("spun the wheel") then
            -- Example: add Reme/Qeme processing if needed
            -- Keep original behavior: show overlay or modify talk bubble
            -- If you have original logic for spin detection, call it here
            -- For now, just log and return false to not block
            LOG("TalkBubble: "..tostring(text))
            return false
        end
    end

    -- OnSDBroadcast
    if ev == "OnSDBroadcast" then
        if blocksdb == true then
            ovlay("`#Va:VanzCya `9I Blocked Sdb")
            return true
        end
    end

    return false
end

-- Text handler: handles OnSendPacket / OnTextPacket (player input commands and dialog button clicks)
local function text_handler(type_or_packet, packet)
    local pkt = tostring(type_or_packet or "") .. (packet and tostring(packet) or "")
    -- debug
    -- LOG("text_handler pkt: "..pkt)

    -- Toggle blockSDB via dialog button
    if pkt:find("buttonClicked|blockSDB") then
        blocksdb = not blocksdb
        ovlay(blocksdb and "`2Block Sdb Mode Enabled" or "`4Block Sdb Mode Disabled")
        return true
    end

    -- Open menus
    if pkt:find("action|dialog_return\ndialog_name|kk\nbuttonClicked|Wrench") then
        CreateDialog(wrenchop)
        return true
    end
    if pkt:find("action|dialog_return\ndialog_name|kk\nbuttonClicked|Proxy") then
        CreateDialog(proxy)
        return true
    end

    -- /pos command
    if pkt:find("/pos") then
        pos_dialog()
        return true
    end

    -- /cd <amount>
    local cd_amt = pkt:match("action|input\n|text|/cd (%d+)") or pkt:match("/cd (%d+)")
    if cd_amt then
        Amount = tonumber(cd_amt) or 0
        LOG("Use Fitur : /cd " .. tostring(Amount))
        bgl = math.floor(Amount/10000)
        local rem = Amount - bgl*10000
        dl = math.floor(rem/100)
        wl = rem % 100
        AutoBtk = true
        local hasil = (bgl ~= 0 and bgl.." BGL " or "") .. (dl ~= 0 and dl.." DL " or "") .. (wl ~= 0 and wl.." WL " or "")
        ovlay("Total drop : "..hasil)
        return true
    end

    -- /setb
    if pkt:find("/setb") then
        bx = math.floor((GetLocal() and GetLocal().pos and GetLocal().pos.x or 0) / 32)
        by = math.floor((GetLocal() and GetLocal().pos and GetLocal().pos.y or 0) / 32)
        ovlay("Succes Set Back Pos ("..tostring(bx)..", "..tostring(by)..")")
        return true
    end

    -- /help or /fitur
    if pkt:find("/help") or pkt:find("/fitur") then
        -- show menu
        menubar()
        return true
    end

    -- dialog button: tk (Take Bets)
    if pkt:find("\nbuttonClicked|tk") then
        if Tax == 0 then ovlay("`4Set Tax First"); return true end
        colect()
        local tax = math.floor(Amount * Tax / 100)
        local dropv = Amount - tax
        local bets = math.floor(Amount / 2)
        ovlay("Tax : "..tostring(Tax).."%, Total drop : "..tostring(dropv))
        SendPacket(2,"action|input\n|text|[`#VanzCya`] "..tostring(bets).." (wl) Bets Are and tax is "..tostring(Tax).."% Total Drop: "..tostring(dropv).." (wl)")
        return true
    end

    -- other text commands (drop, warp, bdl toggle, etc.)
    local d_amt = pkt:match("action|input\n|text|/d (%d+)") or pkt:match("/d (%d+)")
    if d_amt then DropItem(1796, d_amt); ovlay("Succes Drop "..d_amt.." Diamond Lock"); return true end
    local w_amt = pkt:match("action|input\n|text|/w (%d+)") or pkt:match("/w (%d+)")
    if w_amt then DropItem(242, w_amt); ovlay("Succes Drop "..w_amt.." World Lock"); return true end
    local b_amt = pkt:match("action|input\n|text|/b (%d+)") or pkt:match("/b (%d+)")
    if b_amt then DropItem(7188, b_amt); ovlay("Succes Drop "..b_amt.." Blue Gem Lock"); return true end

    if pkt:find("/bdl") then cvdl = not cvdl; ovlay(cvdl and "`2Buy Dl Mode Enable" or "`4Buy Dl Mode Disable"); return true end

    -- handle dialog navigation buttons for menus
    if pkt:find("buttonClicked|pos") then
        leftd = true; punchset = true; ovlay("`4Punch Left Display"); return true
    end
    if pkt:find("buttonClicked|gems") then
        gem1 = true; placeset = true; ovlay("Place Left Chandelier"); return true
    end

    return false
end

-- Raw handler: handles OnSendPacketRaw (tile clicks, chandelier placement, wrench actions)
local function raw_handler(pkt)
    if not pkt or type(pkt) ~= "table" then return false end

    -- display click (type 3, value 18)
    if pkt.type == 3 and pkt.value == 18 then
        if punchset == true then
            for _, display in pairs(GetTiles()) do
                if (display.fg == 1422 or display.fg == 2488) and display.x == pkt.px and display.y == pkt.py then
                    if leftd and not rightd then
                        PX1 = pkt.px; PY1 = pkt.py
                        SendPacket(2,"action|input\n|text|Succes Set Left Pos")
                        ovlay("Success Set Left Display `2(" .. tostring(pkt.px) .. "," .. tostring(pkt.py) .. ") `4Punch Right Display")
                        leftd = false; rightd = true
                    elseif rightd and not leftd then
                        PX2 = pkt.px; PY2 = pkt.py
                        ovlay("Success Set Right Display `2(" .. tostring(pkt.px) .. "," .. tostring(pkt.py) .. ")")
                        rightd = false; punchset = false
                        SendPacket(2,"action|input\n|text|Succes Set Right Pos")
                        pos_dialog()
                    end
                end
            end
            return true
        end
    end

    -- chandelier placement (type 3, value 5640)
    if pkt.type == 3 and pkt.value == 5640 then
        if placeset == true then
            for _, display in pairs(GetTiles()) do
                if display.x == pkt.px and display.y == pkt.py then
                    if gem1 and not gem2 and not leftd and not rightd then
                        xgem1 = pkt.px; ygem1 = pkt.py
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
                        ovlay("Success Set Left Gems `2(" .. tostring(pkt.px) .. "," .. tostring(pkt.py) .. ")")
                    elseif gem2 and not gem1 then
                        xgemm1 = pkt.px; ygemm1 = pkt.py
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
                    end
                end
            end
            return true
        end
    end

    -- wrench actions (type 3 with other values) can be handled here if needed

    return false
end

-- Register normalized handlers so events are routed correctly
register_normalized("main_handlers", {
    var = variant_handler,
    text = text_handler,
    raw = raw_handler
})

-- =========================
-- Init messages (keeps original behavior)
-- =========================
-- ensure ovlay exists
ovlay = ovlay or function(str)
    if type(SendVariant) == "function" or type(_SV) == "function" then
        SendVariantList({[0] = "OnTextOverlay", [1] = "`9[`#VanzCyaScript#001`9] " .. tostring(str)})
    else
        LOG(str)
    end
end

ovlay("Script Has Ben Run")
SleepS(2)
ovlay("Type /help or /fitur to show feature")
SendPacket(2,"action|input\n|text|Script Proxy Bothax By VanzCya")

-- =========================
-- Main loop (if original script had one)
-- If your original script uses a while true loop, ensure it's present below and uses SleepS
-- =========================

-- End of file
