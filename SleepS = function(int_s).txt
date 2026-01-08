-- Script remade (final cleaned)
SleepS = function(int_s)
  sleep(int_s * 1000)
end

local proxy = {}
local command = {}
local PlayerList = {}
proxy.dev = "Mrzz"
proxy.name = "#Mirzz BTK Helper"
proxy.version = "BETA"
version = "BETA"
proxy.support = "undefined"
command.var = {}
command.var.taptp = false
data = {}
Tax = 0
local rfspin = true

loginp = [[
add_quick_exit|
]]

proxy = [[
set_border_color|112,86,191,255
set_bg_color|43,34,74,200
set_default_color|`9
add_label_with_icon|big|[`cMIrzz`2BTK Helper`9]        `2Features|left|9474|
add_smalltext|             `2BETA TEST|
add_spacer|small|
add_label_with_icon|small|Proxy remade by `c#MIirzz|left|12436|
add_spacer|small|
add_spacer|small|
add_label_with_icon|big|`2Fast Drop Commands `9:|left|13810|
add_textbox|`2/db `9<Amount> [Drop `eBlue Gem Lock`9]|
add_textbox|`2/dd `9<Amount> [Drop `1Diamond Lock`9]|
add_textbox|`2/dw `9<Amount> [Drop World Lock]|
add_textbox|`2/cd `9<Amount> [Custom Drop]|
add_spacer|small|
add_label_with_icon|big|`2Hosting Helper `9:|left|758|
add_textbox|`2/pos `9<1-2> [Set Take & Drop Bets Position]|
add_textbox|`2/tax `9<Amount> [Set Tax]|
add_textbox|`2/bet `9<Amount> [Set Bet]|
add_textbox|`2/take `9[Take Bets From Position 1 & 2]|
add_textbox|`2/win `9<1-2> [Drop Bets to Winner]|
add_spacer|small|
add_label_with_icon|big|`2Gamble Helper `9:|left|5774|
add_textbox|`2/g `9[For check gems manual]|
add_spacer|small|
add_spacer|small|
end_dialog|bye|Close|
add_quick_exit|
]]

function DropItem(id, count)
    sendPacket(2, "action|dialog_return\ndialog_name|drop\nitem_drop|"..id.."|\nitem_count|"..count.."\n")
end

function checkitm(id)
    for _, inv in pairs(getInventory()) do
        if inv.id == id then
            return inv.amount
        end
    end
    return 0
end

function wear(id)
    local pkt = {}
    pkt.type = 10
    pkt.value = id
    sendPacketRaw(false, pkt)
end

function ovlay(str)
    local var = {}
    var[0] = "OnTextOverlay"
    var[1] = "`9[`c#Mirzz`2BTK Helper`9] " .. str
    sendVariant(var)
end

function tol(txt)
    logToConsole("`9[`c#Mirzz`2BTK Helper`9] `o"..txt)
end

function Data()
    Amount = 0
    for _, list in pairs(data) do
        if list.id == 7188 then
            Amount = Amount + list.count * 10000
        elseif list.id == 1796 then
            Amount = Amount + list.count * 100
        elseif list.id == 242 then
            Amount = Amount + list.count
        end
    end
    data = {}
end

function collect()
    local tiles = {
        {PX1, PY1}, {PX2, PY2}
    }
    for _, obj in pairs(getWorldObject()) do
        for _, t in pairs(tiles) do
            if (obj.pos.x)//32 == t[1] and (obj.pos.y)//32 == t[2] then
                sendPacketRaw(false, {type=11, value=obj.oid, x=obj.pos.x, y=obj.pos.y})
                table.insert(data, {id=obj.id, count=obj.amount})
            end
        end
    end
    Data()
    data = {}
end

function GetName(id)
    for _, name in pairs(PlayerList) do
        if name.netid == id then
            return name.name
        end
    end
    return nil
end

-- hook untuk touch (menggunakan fungsi on_touchpacket jika ada)
AddHook("onTouch", "on_touch", on_touchpacket)

-- Hook untuk varlist console message (menampilkan semua console message)
AddHook("OnVarlist", "variants", function(var)
    local varcontent = var[1]
    if var[0] == "OnConsoleMessage" then
        tol(varcontent)
        return true
    end
    return false
end)

-- Hook OnVarlist untuk koleksi item dan dialog handling
AddHook("OnVarlist", "var", function(var)
    if var[0] == "OnConsoleMessage" then
        if var[1]:find("Collected") and var[1]:find("(%d+) Blue Gem Lock") then
            local bgl = var[1]:match("(%d+) Blue Gem Lock")
            tol("`9Collected `2"..bgl.." `eBlue Gem Lock`9.")
            ovlay("`9Collected `2"..bgl.." `eBlue Gem Lock")
            return true
        end

        if var[1]:find("Collected") and var[1]:find("(%d+) Diamond Lock") then
            local dl = var[1]:match("(%d+) Diamond Lock")
            tol("`9Collected `2"..dl.." `1Diamond Lock`9.")
            ovlay("`9Collected `2"..dl.." `1Diamond Lock")
            return true
        end

        if var[1]:find("Collected") and var[1]:find("(%d+) World Lock") then
            local wl = var[1]:match("(%d+) World Lock")
            tol("`9Collected `2"..wl.." `9World Lock.")
            ovlay("`9Collected `2"..wl.." `9World Lock")
            wear(242)
            return true
        end
    end

    if var[0] == "OnDialogRequest" then
        if var[1]:find("Drop Blue Gem Lock") or var[1]:find("Drop Diamond Lock") or var[1]:find("Drop World Lock") then
            return true
        end
    end

    return false
end)

-- Hook OnTextPacket untuk command and input handling (cleaned: removed reme/qeme/slog/spin UI)
AddHook("OnTextPacket", "packet", function(_, packet)
    -- rfspin flag (optional detector)
    if packet:find("realfakespin|1") then
        rfspin = true
        tol("`2REAL`o-`4FAKE `oSpin Detector `2Enabled`o.")
    elseif packet:find("realfakespin|0") then
        rfspin = false
        tol("`2REAL`o-`4FAKE `oSpin Detector `4Disabled`o.")
    end

    -- /proxy
    if packet:find("action|input\n|text|/proxy") then
        local v = {}
        v[0] = "OnDialogRequest"
        v[1] = proxy
        sendVariant(v)
        logToConsole("`6/proxy")
        return true
    end

    -- /news
    if packet:find("action|input\n|text|/news") then
        local v = {}
        v[0] = "OnDialogRequest"
        v[1] = loginp
        sendVariant(v)
        logToConsole("`6/news")
        return true
    end

    -- /db
    if packet:find("action|input\n|text|/db (%d+)") then
        local txt = packet:match("action|input\n|text|/db (%d+)")
        DropItem(7188, txt)
        logToConsole("`6/db "..txt.."")
        tol("`9Dropped `2"..txt.." `eBlue Gem Lock`9.")
        ovlay("`9Dropped `2"..txt.." `eBlue Gem Lock")
        return true
    end

    -- /dd
    if packet:find("action|input\n|text|/dd (%d+)") then
        local txt = packet:match("action|input\n|text|/dd (%d+)")
        DropItem(1796, txt)
        logToConsole("`6/dd "..txt.."")
        tol("`9Dropped `2"..txt.." `1Diamond Lock`9.")
        ovlay("`9Dropped `2"..txt.." `1Diamond Lock")
        return true
    end

    -- /dw
    if packet:find("action|input\n|text|/dw (%d+)") then
        local txt = packet:match("action|input\n|text|/dw (%d+)")
        DropItem(242, txt)
        logToConsole("`6/dw "..txt.."")
        tol("`9Dropped `2"..txt.." `9World Lock.")
        ovlay("`9Dropped `2"..txt.." `9World Lock")
        return true
    end

    -- /cd
    if packet:find("action|input\n|text|/cd (%d+)") then
        local total = tonumber(packet:match("action|input\n|text|/cd (%d+)"))
        local count = total
        local bgl = math.floor(total/10000)
        total = total - bgl*10000
        local dl = math.floor(total/100)
        local wl = total % 100
        if checkitm(242) < wl then wear(1796) end
        if checkitm(1796) < dl then wear(7188) end
        if bgl > 0 then DropItem(7188, bgl) end
        if dl > 0 then DropItem(1796, dl) end
        if wl > 0 then DropItem(242, wl) end
        local hasil = (bgl ~= 0 and bgl.." `eBlue Gem Lock`9." or "").." `2"..(dl ~= 0 and dl.." `1Diamond Lock`9." or "").." `2"..(wl ~= 0 and wl.." `9World Lock." or "")
        logToConsole("`6/cd "..count.."")
        tol("`9Dropped `2"..hasil.."")
        ovlay("`9Dropped `2"..hasil.."")
        return true
    end

    -- /pos 1
    if packet:find("action|input\n|text|/pos 1") then
        PX1 = getLocal().pos.x//32
        PY1 = getLocal().pos.y//32
        logToConsole("`6/pos 1")
        tol("`9Set Position 1 to (`2"..PX1.."`9, `2"..PY1.."`9).")
        ovlay("`9Set Position 1 to (`2"..PX1.."`9, `2"..PY1.."`9)")
        return true
    end

    -- /pos 2
    if packet:find("action|input\n|text|/pos 2") then
        PX2 = getLocal().pos.x//32
        PY2 = getLocal().pos.y//32
        logToConsole("`6/pos 2")
        tol("`9Set Position 2 to (`2"..PX2.."`9, `2"..PY2.."`9).")
        ovlay("`9Set Position 2 to (`2"..PX2.."`9, `2"..PY2.."`9)")
        return true
    end

    -- /tax
    if packet:find("action|input\n|text|/tax (%d+)") then
        local pler = packet:match("action|input\n|text|/tax (%d+)")
        Tax = ""..pler..""
        logToConsole("`6/tax "..Tax.."")
        tol("`9Set Tax to : `2"..Tax.."%%`9.")
        ovlay("`9Set Tax to : `2"..Tax.."%")
        return true
    end

    -- /take
    if packet:find("action|input\n|text|/take") then
        collect()
        local tax = math.floor(Amount * Tax / 100)
        local drop = Amount - tax
        logToConsole("`6/take")
        tol("`9Tax : `2"..Tax.."%%`9.")
        tol("`9Drop to Winner : `2"..drop.."`9.")
        tol("`9Successfully Took All Bets`9.")
        ovlay("`9Tax (`2"..Tax.."%`9) Drop to Winner (`2"..drop.."`9)")
        return true
    end

-- /win 1 (fixed)
if packet:find("action|input\n|text|/win 1") then
    -- pastikan Amount ada (0 jika nil)
    local totalAmount = tonumber(Amount) or 0
    local tax = math.floor(totalAmount * (tonumber(Tax) or 0) / 100)
    local drop = totalAmount - tax

    -- hitung pecahan item
    local bgl = math.floor(drop / 10000)
    local rem = drop - bgl * 10000
    local dl = math.floor(rem / 100)
    local wl = rem % 100

    -- pastikan posisi sudah diset
    local x = (PX1 or getLocal().pos.x//32) * 32
    local y = (PY1 or getLocal().pos.y//32) * 32

    sendPacketRaw(false, { type = 0, x = x, y = y, state = 48 })

    if checkitm(242) < wl then wear(1796) end
    if checkitm(1796) < dl then wear(7188) end

    if bgl > 0 then DropItem(7188, bgl) end
    if dl > 0 then DropItem(1796, dl) end
    if wl > 0 then DropItem(242, wl) end

    local hasil = (bgl ~= 0 and bgl.." `eBlue Gem Lock`9." or "").." `2"..(dl ~= 0 and dl.." `1Diamond Lock`9." or "").." `2"..(wl ~= 0 and wl.." `9World Lock." or "")
    logToConsole("`6/win 1")
    tol("`9Total Bet : `2"..totalAmount.."`9.")
    tol("`9Tax : `2"..tax.."`9.")
    tol("`9Drop to Winner : `2"..drop.."`9.")
    tol("`9Dropped `2"..hasil.."")
    ovlay("`9Dropped `2"..hasil.."")
    return true
end

-- /win 2 (fixed)
if packet:find("action|input\n|text|/win 2") then
    local totalAmount = tonumber(Amount) or 0
    local tax = math.floor(totalAmount * (tonumber(Tax) or 0) / 100)
    local drop = totalAmount - tax

    local bgl = math.floor(drop / 10000)
    local rem = drop - bgl * 10000
    local dl = math.floor(rem / 100)
    local wl = rem % 100

    local x = (PX2 or getLocal().pos.x//32) * 32
    local y = (PY2 or getLocal().pos.y//32) * 32

    sendPacketRaw(false, { type = 0, x = x, y = y, state = 32 })

    if checkitm(242) < wl then wear(1796) end
    if checkitm(1796) < dl then wear(7188) end

    if bgl > 0 then DropItem(7188, bgl) end
    if dl > 0 then DropItem(1796, dl) end
    if wl > 0 then DropItem(242, wl) end

    local hasil = (bgl ~= 0 and bgl.." `eBlue Gem Lock`9." or "").." `2"..(dl ~= 0 and dl.." `1Diamond Lock`9." or "").." `2"..(wl ~= 0 and wl.." `9World Lock." or "")
    logToConsole("`6/win 2")
    tol("`9Total Bet : `2"..totalAmount.."`9.")
    tol("`9Tax : `2"..tax.."`9.")
    tol("`9Drop to Winner : `2"..drop.."`9.")
    tol("`9Dropped `2"..hasil.."")
    ovlay("`9Dropped `2"..hasil.."")
    return true
end

    -- /balance
    if packet:find("action|input\n|text|/balance") then
        logToConsole("`6/balance")
        local gems = getLocal().gems
        tol("`9Your Gems Amount : `2"..gems.."`9.")
        tol("`9Your Locks Amount : `2"..checkitm(7188).." `eBGL`9, `2"..checkitm(1796).." `1DL`9, `2"..checkitm(242).." `9WL.")
        ovlay("`9Your Locks Amount : `2"..checkitm(7188).." `eBGL`9, `2"..checkitm(1796).." `1DL`9, `2"..checkitm(242).." `9WL.")
        return true
    end

    -- /time
    if packet:find("action|input\n|text|/time") then
        local date = os.date("%D")
        local time = os.date("%H:%M:%S")
        logToConsole("`6/time")
        tol("`9Your Region Date : `2"..date.."`9.")
        tol("`9Your Region Time : `2"..time.."`9.")
        ovlay("`9Your Region Time : `2"..time.."`9, `2"..date.."")
        return true
    end

    return false
end)

-- Simpan jumlah gems terakhir
local lastGems = 0

-- Function untuk menampilkan gems yang baru dikoleksi
function showCollectedGems()
    local player = getLocal()
    if player then
        local currentGems = player.gems
        local diff = currentGems - lastGems
        if diff > 0 then
            logToConsole("`9Collected Gems : `2+" .. diff .. "`9. Total : `2" .. currentGems)
            sendPacket(2, "action|input\n|text|`9Collected Gems `2" .. diff .. "(gems)")
            local var = {}
            var[0] = "OnTextOverlay"
            var[1] = "`9Collected `2+" .. diff .. " `9gems! Total: `2" .. currentGems
            sendVariant(var)
        else
            logToConsole("`9No new gems collected. Total : `2" .. currentGems)
        end
        lastGems = currentGems
    else
        logToConsole("`4Player data tidak ditemukan!")
    end
end

-- Hook untuk command input /gems
function hook(type, pkt)
    if pkt:find("action|input\n|text|/gems") then
        showCollectedGems()
        return true
    end
    return false
end

-- Pasang hook
AddHook("OnTextPacket", "showGemsHook", hook)

-- show login dialog on start
sendVariant({
    [0] = "OnDialogRequest",
    [1] = loginp,
}, -1, 3500)
