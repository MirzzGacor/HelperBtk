-- bothax_fixed.lua
-- Versi: kompatibel Bothax (safe wrappers + pkt_to_str)
-- Perhatian: paste seluruh file ini menggantikan file lama

-- =========================
-- Compatibility shim
-- =========================

-- Safe Sleep / sleep
if type(Sleep) ~= "function" and type(sleep) == "function" then
    Sleep = sleep
end
if type(sleep) ~= "function" and type(Sleep) == "function" then
    sleep = function(ms) Sleep(ms) end
end
if type(Sleep) ~= "function" then
    Sleep = function(ms) end
end
if type(sleep) ~= "function" then
    sleep = function(ms) end
end

-- Safe SendPacket / SendPacketRaw
if type(SendPacket) ~= "function" then
    SendPacket = function(...) end
end

if type(SendPacketRaw) ~= "function" then
    -- try to adapt if only SendPacket exists
    SendPacketRaw = function(flag_or_pkt, pkt)
        if type(flag_or_pkt) == "boolean" and type(pkt) == "table" and pkt.type then
            pcall(function() SendPacket(pkt.type, tostring(pkt.value or "")) end)
        elseif type(flag_or_pkt) == "table" and flag_or_pkt.type then
            pcall(function() SendPacket(flag_or_pkt.type, tostring(flag_or_pkt.value or "")) end)
        else
            -- no-op fallback
        end
    end
end

-- Safe SendVariant / SendVariantList
local _SendVariant = nil
if type(SendVariant) == "function" then
    _SendVariant = SendVariant
elseif type(SendVariantList) == "function" then
    _SendVariant = SendVariantList
else
    _SendVariant = function(...) end
end

local function SendVariantSafe(var, netid, delay)
    netid = netid or -1
    delay = delay or 0
    -- try call with (var, netid, delay) if supported, else fallback
    local ok, err = pcall(function() _SendVariant(var, netid, delay) end)
    if not ok then
        pcall(function() _SendVariant(var) end)
    end
end

-- Safe AddHook
if type(AddHook) ~= "function" then
    AddHook = function(...) end
end

-- Helper: convert packet/variant to string safely for pattern matching
local function pkt_to_str(p)
    if type(p) == "string" then
        return p
    end
    if type(p) == "table" then
        -- try common fields first
        if p[1] and type(p[1]) == "string" then
            return p[1]
        end
        -- concatenate values to a string for pattern matching
        local s = ""
        for k, v in pairs(p) do
            if type(v) == "string" then
                s = s .. v .. "|"
            else
                s = s .. tostring(v) .. "|"
            end
        end
        return s
    end
    return tostring(p)
end

-- Safe ovlay wrapper using SendVariantSafe
local function ovlay_safe(str)
    local var = {}
    var[0] = "OnTextOverlay"
    var[1] = str
    SendVariantSafe(var)
end

-- =========================
-- Original script (dengan penyesuaian pemanggilan SendVariantSafe, pkt_to_str)
-- =========================

Tax = 5

leftd = false
rightd = false
local PX1
local PY1
local PX2
local PY2

placeset = false
gem1 = false
gem2 = false
local xgem1
local ygem1
local xgem2
local ygem2
local xgem3
local ygem3
local xgemm1
local ygemm1
local xgemm2
local ygemm2
local xgemm3
local ygemm3

function lmo(setx, sety)
    local hasil
    if not setx and not sety then
        hasil = "`4Did You Done Set This?``"
    else
        hasil = setx .. "," .. sety
    end
    return hasil
end

count = 0;
data = {}

function pos()
    var = {}
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
    SendVariantSafe(var)
end

wrenchop = [[add_label_with_icon|big|`5Wrench|left|11816|
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

tap = [[
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

lol = [[add_player_info|Hi Pekuy|500000|500000|
add_spacer|small|
add_spacer|small|
add_button_with_icon|Wrench|Wrench List|staticBlueFrame|32|
add_button_with_icon|cbgl|`wC Bgl Mode|staticBlueFrame|7188||
add_button_with_icon|Proxy|Proxy Command|staticBlueFrame|10864|
add_button_with_icon|blockSDB|`4Block Sdb|staticBlueFrame|2480|
end_dialog|kk||
add_quick_exit|
]]

proxy = [[end_dialog|bye|exit?|Serius bro?|
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


cvdl = false
pull = false
kick = false
bx = 0
by = 0
ban = false
autosb = false
punchset = false

function DropItem(id, count)
    SendPacket(2, "action|dialog_return\ndialog_name|drop\nitem_drop|"..id.."|\nitem_count|"..count.."\n")
end

function Data()
    Amount = 0
    for _, list in pairs(data) do
        Name = ""
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
        tol("Collected `9"..list.count.." "..Name)
    end
    data = {}
end

function colect()
    tiles = {
        {PX1, PY1}, 
        {PX2, PY2}
    }
    objects = GetObjectList()
    for _, obj in pairs(objects) do
        for _, tiles in pairs(tiles) do
            if (obj.pos.x)//32 == tiles[1] and (obj.pos.y)//32 == tiles[2] then
                SendPacketRaw(false, {type=11,value=obj.oid,x=obj.pos.x,y=obj.pos.y})
                table.insert(data, {id=obj.id, count=obj.amount})
            end
        end
    end
    Data()
    data = {}
end

function checkitm(id)
    for _, inv in pairs(GetInventory()) do
        if inv.id == id then
            return inv.amount
        end
    end
    return 0
end

function wear(id)
    pkt = {}
    pkt.type = 10
    pkt.value = id
    SendPacketRaw(false, pkt)
end

function ovlay(str)
    local var = {}
    var[0] = "OnTextOverlay"
    var[1] = str
    SendVariantSafe(var)
end

function tol(txt)
    LogToConsole("`o[`#VanzCyaScript#001`o] `6"..txt)
end

-- Hook: OnSendPacket (safe: handle string or table)
AddHook("OnSendPacket", "packet",
function(packet)
    local pkt = pkt_to_str(packet)

    if pkt:find("/test (.+)") then
        yes = pkt:match("/test (.+)")
        var = {}
        var[0] = "OnTalkBubble"
        var[1] = (GetLocal() and GetLocal().netid) or 0
        var[2] = ""..yes..""
        SendVariantSafe(var)
        return true
    end

    if pkt:find("buttonClicked|blockSDB") then
        if blocksdb == false then
            blocksdb = true
            ovlay("`2Block Sdb Mode Enabled")
        else
            blocksdb = false
            ovlay("`4Block Sdb Mode Disabled")
        end
        return true
    end

    if pkt:find("action|dialog_return\ndialog_name|kk\nbuttonClicked|Wrench") then
        var = {}
        var[0] = "OnDialogRequest"
        var[1] = wrenchop
        SendVariantSafe(var)
        LogToConsole("Wrench Option")
        return true
    end

    if pkt:find("buttonClicked|pos") then
        leftd = true
        punchset = true
        ovlay("`4Punch Left Display")
    end

    if pkt:find("buttonClicked|gems") then
        gem1 = true
        placeset = true
        ovlay("`oPlace Left Chandelier\nif Horizontal\n[Chand][`4Put Chand Here`o][Chand]\nif Vertical VVVV\n[Chand]\n[Chand]\n[`4Put Chand Here`o]")
        tol("\n`oPlace Left Chandelier\nif Horizontal\n[Chand][`4Put Chand Here`o][Chand]\nif Vertical VVVV\n[Chand]\n[Chand]\n[`4Put Chand Here`o]")
    end

    if pkt:find("action|dialog_return\ndialog_name|kk\nbuttonClicked|Proxy") then
        var = {}
        var[0] = "OnDialogRequest"
        var[1] = proxy
        SendVariantSafe(var)
        LogToConsole("Fiture I Will Add")
        return true
    end

    if pkt:find("/ac") then
        for _, tile in pairs(GetTiles()) do
            if tile.fg == 3898 then
                x = tile.x
                y = tile.y
                SendPacket(2, "action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|" .. x .. "|\ny|" .. y .. "|\nbuttonClicked|bglconvert")
                return true
            end
        end
    end

    if pkt:find("/d (%d+)") then
        txt = pkt:match("/d (%d+)")
        DropItem(1796, txt)
        tol("Succes Drop `0"..txt.." `2Diamond Lock")
        return true
    end

    if pkt:find("/w (%d+)") then
        txt = pkt:match("/w (%d+)")
        DropItem(242, txt)
        tol("Succes Drop `0"..txt.." `2World Lock")
        return true
    end

    if pkt:find("/hitam") then
        SendPacket(2, [[
action|setSkin
color|0000000000]])
        SendPacket(2, [[
action|input
|text|`4ORA PERLU GANTENG SING PENTING IRENG!]])
        return true
    end

    if pkt:find("/putih") then
        SendPacket(2, [[
action|setSkin
color|510000000000]])
        SendPacket(2, [[
action|input
|text|`0ORA PERLU GANTENG SING PENTING PUTIH!]])
        return true
    end
      
    if pkt:find("/bdl") then
        if cvdl == false then
            cvdl = true
            ovlay("`2Buy Dl Mode Enable")
        else
            if cvdl == true then
                cvdl = false
                ovlay("`4Buy Dl Mode Disable")
                return true
            end
        end
    end

    if pkt:find("/b (%d+)") then
        txt = pkt:match("/b (%d+)")
        DropItem(7188, txt)
        tol("`2Succes Drop `0"..txt.." `2Blue Gem Lock")
        return true
    end

    if pkt:find("/ww (.+)") or pkt:find("/Ww (.+)") then
        namew = pkt:match("/ww (.+)") or pkt:match("/Ww (.+)")
        ovlay("`#Warping To `6"..namew)
        SendPacket(3, "action|join_request\n|name|"..namew.."\n|invitedWorld|0")
        return true
    end

    if pkt:find("/bb (%d+)") or pkt:find("/Bb (%d+)") then
        if checkitm(11550) == 0 then
            SendPacket(2,"action|dialog_return\ndialog_name|info_box\nbuttonClicked|make_bgl\n")
            return true
        end
    end

    if pkt:find("/bb (%d+)") or pkt:find("/Bb (%d+)") then
        txt = pkt:match("/bb (%d+)") or pkt:match("/Bb (%d+)")
        DropItem(11550, txt)
        tol("`2Succes Drop `0"..txt.." `bBlack Gem Lock")
        return true
    end

    if pkt:find("/help") or pkt:find("/Help") or pkt:find("/Fitur") or pkt:find("/fitur") then
        tol("`1\nDrop Command >> /w (amount) /d (amount) /b (amount) /bb (amount) drop ireng /cd (amount)\nConvert Command >> /ac Change BGL /bdl buy dl\nWarp Fast >> /ww (Name World)\nFun Fitur >> /hitam /putih /lgbt\nSet Pos To Host BTK >>/pos To Set Pos Gems And Take Bet\nSet Pos Back Command >>/setb For Set Back After Reset Chand\nFor Btk Helper Fitur Is Tap Gems Store\nMore Tap Friends Button\nMaybe Later I Will Add More Feature")
        return true
    end

    if pkt:find("/setb") or pkt:find("/Setb") then
        bx = (GetLocal() and GetLocal().pos and GetLocal().pos.x // 32) or 0
        by = (GetLocal() and GetLocal().pos and GetLocal().pos.y // 32) or 0
        ovlay("Succes Set Back Pos ("..bx..", "..by..")")
        return true
    end

    if pkt:find("\nbuttonClicked|ra") then
        if by == 0 then
            ovlay("U Didnt Set Back Pos Lol Do /setb")
        else
            ovlay("Put Chand Wait")
            resetchand1 = true
            return true
        end
    end

    if pkt:find("\nbuttonClicked|rd") then
        if by == 0 then
            ovlay("U Didnt Set Back Pos Lol Do /setb")
        else
            resetchand2 = true
            ovlay("Put Chand Wait")
            return true
        end
    end

    if pkt:find("friends") then
        var = {}
        var[0] = "OnDialogRequest"
        var[1] = lol
        SendVariantSafe(var)
        tol("Proxy List")
        return true
    end

    if pkt:find("store") then
        var = {}
        var[0] = "OnDialogRequest"
        var[1] = tap
        SendVariantSafe(var)
        tol("Btk Helperr")
        return true
    end

    if pkt:find("/pos") or pkt:find("/Pos") then
        pos()
        return true
    end

    if pkt:find("/cd (%d+)") or pkt:find("/Cd (%d+)") then
        Amount = pkt:match("/cd (%d+)") or pkt:match("/Cd (%d+)")
        LogToConsole("`9Use Fitur : /cd")
        bgl = math.floor(Amount/10000)
        Amount = Amount - bgl*10000 
        dl = math.floor(Amount/100)
        wl = Amount % 100
        AutoBtk = true
        hasil = (bgl ~= 0 and bgl.." `eBlue Gem Lock`0" or "").." "..(dl ~= 0 and dl.." `1Diamond Lock`0" or "").." "..(wl ~= 0 and wl.." `9World Lock`0" or "")
        tol("`9Total drop : `0"..hasil)
        return true
    end

    if pkt:find("/stax (%d+)") or pkt:find("/Stax (%d+)") then
        Tax = pkt:match("/stax (%d+)") or pkt:match("/Stax (%d+)")
        ovlay("Tax : "..Tax.."%") 
    end

    if pkt:find("\nbuttonClicked|tk") then
        if Tax == 0 then
            ovlay("`4Set Tax First")
        else
            colect()
            tax = math.floor(Amount * Tax / 100)
            drop = Amount - tax
            bets = Amount//2
            tol("`2Tax : `"..Tax.."%, `4Total drop : `9"..drop)
            tol("`9Succes Take")
            SendPacket(2,"action|input\n|text|[`#VanzCya`0]`1"..bets.."(wl)`9Bets Are and tax is "..Tax.."% Total Drop: "..drop.."(wl)")
            return true
        end
    end

    if pkt:find("\nbuttonClicked|w1") then
        if Tax == 0 then
            ovlay("`4Set Tax First")
        else
            bgl = math.floor(drop/10000)
            drop = drop - bgl*10000 
            dl = math.floor(drop/100)
            wl = drop % 100
            SendPacketRaw(false, { type = 0, x = (PX1 - 2) * 32, y = (PY1) * 32, state = 32 })
            AutoBtk = true
            hasil = (bgl ~= 0 and bgl.." `eBlue Gem Lock`0" or "").." "..(dl ~= 0 and dl.." `1Diamond Lock`0" or "").." "..(wl ~= 0 and wl.." `9World Lock`0" or "")
            tol("`9Amount Lock : "..Amount)
            tol("`9Tax : "..Tax.."%")
            tol("`9Total drop : `0"..hasil.." `4Tax Reset")
            return true
        end
    end

    if pkt:find("\nbuttonClicked|w2") then
        if Tax == 0 then
            ovlay("`4Set Tax first")
        else
            bgl = math.floor(drop/10000)
            drop = drop - bgl*10000 
            dl = math.floor(drop/100)
            wl = drop % 100
            SendPacketRaw(false, { type = 0, x = (PX2 + 2) * 32, y = (PY2) * 32, state = 48 })
            AutoBtk = true
            hasil = (bgl ~= 0 and bgl.." `eBlue Gem Lock`0" or "").." "..(dl ~= 0 and dl.." `1Diamond Lock`0" or "").." "..(wl ~= 0 and wl.." `9World Lock`0" or "")
            tol("`9Amount Lock : "..Amount)
            tol("`9Tax : "..Tax.."%")
            tol("`9Total drop : `0"..hasil.." `4Tax Reset")
            return true
        end
    end

    if pkt:find("/rr") then
        relog = true
        namew = GetWorld().name
        return true
    end

    return false
end)

-- Hook: OnVariant (already receives table)
AddHook("OnVariant", "var",
function(var)
    if not var then return false end

    if var[0] == "OnConsoleMessage" and tostring(var[1] or ""):find("commands.") then
        tol("`cIDK What Command U Use There Was No Have Command Like That ")
        tol("`9Type /fitur to show feature")
        return true
    end
      
    if tostring(var[0] or ""):find("OnDialogRequest") and tostring(var[1] or ""):find("end_dialog|telephone") then
        if cvdl == true then
            SendPacket(2, "action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|"..(var[1]:match("embed_data|x|(%d+)") or "").."|\ny|"..(var[1]:match("embed_data|y|(%d+)") or "").."|\nbuttonClicked|dlconvert")
            return true
        end
    end
    
    if var[0] == "OnTalkBubble" and tostring(var[2] or ""):find("spun the wheel and got") and
       (tostring(var[2] or ""):find("`4(%d+)``!") or tostring(var[2] or ""):find("`b(%d+)``!") or tostring(var[2] or ""):find("`2(%d+)``!")) then
        SpunNumber = tostring(var[2] or ""):match("`4(%d+)``!") or tostring(var[2] or ""):match("`b(%d+)``!") or tostring(var[2] or ""):match("`2(%d+)``!")
        Num1, Num2 = SpunNumber//10, SpunNumber%10
        Reme = Num1 + Num2
        if Reme > 10 then 
            Reme = Reme%10
        elseif Reme == 10 then
             Reme = "`20"
        end
        var[0] = "OnTalkBubble"
        var[1] = var[1]
        var[2] = var[2] .. " (cool)Fast `0 `2Reme`0 [ " .. Reme .. "`0 ]"
        SendVariantSafe(var)
        return true
    end

    if var[0] == "OnSDBroadcast" then
        if blocksdb == true then
            ovlay("`#Va:VanzCya `9I Blocked Sdb Say Thanks To me")
            return true
        end
    end

    if tostring(var[0] or ""):find("OnDialogRequest") then
        if tostring(var[1] or ""):find("Wow, that's fast delivery.") then
            ovlay("Block Dialog Telephone")
            return true
        end
    end

    return false
end)

-- Hook: OnSendPacketRaw (tile clicks, chand placement)
AddHook("OnSendPacketRaw", "rawr",
function(a)
    if not a or type(a) ~= "table" then return false end

    if a.type == 3 and a.value == 18 then
        if punchset == true then
            for _, display in pairs(GetTiles()) do
                if display.fg == 1422 or display.fg == 2488 then
                    if display.x == a.px and display.y == a.py then
                        if leftd and not rightd and not vertical and not vertical1 then
                            PX1 = a.px
                            PY1 = a.py
                            SendPacket(2,"action|input\n|text|Succes Set Left Pos")
                            ovlay("Success Set Left Display `2(" .. a.px .. "," .. a.py .. ") `4Punch Right Display")
                            leftd = false
                            rightd = true
                        elseif rightd and not leftd and not vertical and not vertical1 then
                            PX2 = a.px
                            PY2 = a.py
                            ovlay("Success Set Right Display `2(" .. a.px .. "," .. a.py .. ")")
                            rightd = false
                            punchset = false
                            SendPacket(2,"action|input\n|text|Succes Set Right Pos")
                            tol("`2Done Set Take Pos")
                            pos()
                        end
                    end
                end
            end
            return true
        end
    end

    if a.type == 3 and a.value == 5640 then
        if placeset == true then
            for _, display in pairs(GetTiles()) do
                if display.x == a.px and display.y == a.py then
                    if gem1 and not gem2 and not leftd and not rightd then
                        xgem1 = a.px
                        ygem1 = a.py
                        xgem2 = xgem1 + 1
                        ygem2 = ygem1 - 1
                        xgem3 = xgem1 - 1
                        ygem3 = ygem1 - 2
                        tile = {
                            pos1 = { 
                                {x = xgem1, y = ygem1}, {x = xgem1, y = ygem2}, {x = xgem1, y = ygem3}, {x = xgem2, y = ygem1}, {x = xgem3, y = ygem1} 
                            },
                            pos2 = {
                                {x = xgemm1, y = ygemm1}, {x = xgemm1, y = ygemm2}, {x = xgemm1, y = ygemm3}, {x = xgemm2, y = ygemm1}, {x = xgemm3, y = ygemm1} 
                            }
                        }
                        gem1 = false
                        gem2 = true
                        SendPacket(2,"action|input\n|text|Succes Set Left GEMS")
                        ovlay("Success Set Left Gems `2(" .. a.px .. "," .. a.py .. ") (" .. xgem2 .. "," .. ygem2 .. ") (" .. xgem3 .. "," .. ygem3 .. ")")
                    elseif gem2 and not gem1 then
                        xgemm1 = a.px
                        ygemm1 = a.py
                        xgemm2 = xgemm1 + 1
                        ygemm2 = ygemm1 - 1
                        xgemm3 = xgemm1 - 1
                        ygemm3 = ygemm1 - 2
                        tile = {
                            pos1 = { 
                                {x = xgem1, y = ygem1}, {x = xgem1, y = ygem2}, {x = xgem1, y = ygem3}, {x = xgem2, y = ygem1}, {x = xgem3, y = ygem1} 
                            },
                            pos2 = {
                                {x = xgemm1, y = ygemm1}, {x = xgemm1, y = ygemm2}, {x = xgemm1, y = ygemm3}, {x = xgemm2, y = ygemm1}, {x = xgemm3, y = ygemm1} 
                            }
                        }
                        gem2 = false
                        placeset = false
                        SendPacket(2,"action|input\n|text|Succes Set Right GEMS")
                        pos()
                        ovlay("`2Done Set Pos Gems")
                        ovlay("Success Set Left Gems `2(" .. a.px .. "," .. a.py .. ") (" .. xgemm2 .. "," .. ygemm2 .. ") (" .. xgemm3 .. "," .. ygemm3 .. ")")
                    end
                end
            end
            return true
        end
    end

    return false
end)

ovlay("Script Has Ben Run")
Sleep(2000)
ovlay("Type /help or /fitur to show feature")
SendPacket(2,"action|input\n|text|Script Proxy Bothax By VanzCya")

-- Main loop (preserve original behavior)
while true do
    Sleep(500)
    if AutoBtk then
        Sleep(200)
        if checkitm(1796) < dl then
            wear(7188)
            Sleep(500)
        end
        if checkitm(242) < wl then
            wear(1796)
            Sleep(500)
        end
        if bgl > 0 then
            DropItem(7188, bgl)
            Sleep(500)
        end
        if dl > 0 then
            DropItem(1796, dl)
            Sleep(500)
        end
        if wl > 0 then
            DropItem(242, wl)
        end
        drop = ""
        Amount = ""
        AutoBtk = false
    end

    if resetchand1 then
        Sleep(500)
        FindPath(xgem1, ygem2)
        ChangeFeature("Modfly", true)
        Sleep(200)
        pkt = {}
        pkt.type = 3
        pkt.x = GetLocal().pos.x
        pkt.y = GetLocal().pos.y
        pkt.px = xgem1
        pkt.py = ygem1
        pkt.value = 5640
        pkt.state = 16
        SendPacketRaw(false, pkt)
        Sleep(200)
        pkt = {}
        pkt.type = 3
        pkt.x = GetLocal().pos.x
        pkt.y = GetLocal().pos.y
        pkt.px = xgem1
        pkt.py = ygem2
        pkt.value = 5640
        pkt.state = 16
        SendPacketRaw(false, pkt)
        Sleep(200)
        pkt = {}
        pkt.type = 3
        pkt.x = GetLocal().pos.x
        pkt.y = GetLocal().pos.y
        pkt.px = xgem1
        pkt.py = ygem3
        pkt.value = 5640
        pkt.state = 16
        SendPacketRaw(false, pkt)
        colecp1()
        Sleep(200)
        FindPath(xgemm1, ygemm2)
        Sleep(200)
        pkt = {}
        pkt.type = 3
        pkt.x = GetLocal().pos.x
        pkt.y = GetLocal().pos.y
        pkt.px = xgemm1
        pkt.py = ygemm1
        pkt.value = 5640
        pkt.state = 16
        SendPacketRaw(false, pkt)
        Sleep(200)
        pkt = {}
        pkt.type = 3
        pkt.x = GetLocal().pos.x
        pkt.y = GetLocal().pos.y
        pkt.px = xgemm1
        pkt.py = ygemm2
        pkt.value = 5640
        pkt.state = 16
        SendPacketRaw(false, pkt)
        Sleep(200)
        pkt = {}
        pkt.type = 3
        pkt.x = GetLocal().pos.x
        pkt.y = GetLocal().pos.y
        pkt.px = xgemm1
        pkt.py = ygemm3
        pkt.value = 5640
        pkt.state = 16
        SendPacketRaw(false, pkt)
        colecp2()
        Sleep(200)
        FindPath(bx, by)
        ChangeFeature("Modfly", false)
        resetchand1 = false
    end

    if resetchand2 then
        Sleep(500)
        FindPath(xgem1 + 2, ygem1)
        Sleep(100)
        FindPath(xgem1, ygem1)
        Sleep(250)
        pkt = {}
        pkt.type = 3
        pkt.x = GetLocal().pos.x
        pkt.y = GetLocal().pos.y
        pkt.px = xgem1
        pkt.py = ygem1
        pkt.value = 5640
        pkt.state = 16
        SendPacketRaw(false, pkt)
        Sleep(250)
        pkt = {}
        pkt.type = 3
        pkt.x = GetLocal().pos.x
        pkt.y = GetLocal().pos.y
        pkt.px = xgem2
        pkt.py = ygem1
        pkt.value = 5640
        pkt.state = 16
        SendPacketRaw(false, pkt)
        Sleep(250)
        pkt = {}
        pkt.type = 3
        pkt.x = GetLocal().pos.x
        pkt.y = GetLocal().pos.y
        pkt.px = xgem3
        pkt.py = ygem1
        pkt.value = 5640
        pkt.state = 16
        SendPacketRaw(false, pkt)
        colecp3()
        Sleep(500)
        FindPath(xgem1 + 4, ygem1)
        Sleep(100)
        FindPath(xgemm1 - 2, ygemm1)
        Sleep(100)
        FindPath(xgemm1, ygemm1)
        Sleep(250)
        pkt = {}
        pkt.type = 3
        pkt.x = GetLocal().pos.x
        pkt.y = GetLocal().pos.y
        pkt.px = xgemm1
        pkt.py = ygemm1
        pkt.value = 5640
        pkt.state = 16
        SendPacketRaw(false, pkt)
        Sleep(250)
        pkt = {}
        pkt.type = 3
        pkt.x = GetLocal().pos.x
        pkt.y = GetLocal().pos.y
        pkt.px = xgemm2
        pkt.py = ygemm1
        pkt.value = 5640
        pkt.state = 16
        SendPacketRaw(false, pkt)
        Sleep(250)
        pkt = {}
        pkt.type = 3
        pkt.x = GetLocal().pos.x
        pkt.y = GetLocal().pos.y
        pkt.px = xgemm3
        pkt.py = ygemm1
        pkt.value = 5640
        pkt.state = 16
        SendPacketRaw(false, pkt)
        colecp4()
        Sleep(500)
        FindPath(bx, by)
        resetchand2 = false
    end

    if relog then
        SendPacket(3,"action|quit_to_exit")
        Sleep(100)
        SendPacket(3, "action|join_request\n|name|"..namew.."\n|invitedWorld|0")
    end
    relog = false
end
