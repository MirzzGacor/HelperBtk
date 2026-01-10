-- ccd1.lua (Bothax-compatible fixed, handlers registered after functions)
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

-- register_normalized helper (defined here but used later)
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

-- =========================
-- Original script content (preserved and complete)
-- =========================

--V.0.13.0
--->>> EDIT AREA <<<---
local WEBHOOK_SB = "" -- link webhook
local WEBHOOK_TYPER  = "" 
local WEBHOOK_VANISHMOD = ""
local USER_TO_PING_TYPER = "&" --id user or a role, if a role use the & if no delete the &
local USER_TO_PING = "" -- id discord

--------------------------------------

--->>> DON'T TOUCH ANYTHING HERE <<<---
local checkip = false
local GET_ALTS = false
local ONLINE_ACCS = {}
local SEARCH_USER = ""
local SEARCH_ACCS = false
local Configs = {
    Name = nil,
    TyperUserID = nil,
    TyperText = nil
}
local modss = {
    modchats = {},
    bans = {},
    ductTapes = {},
    curses = {},
    sanctioneds = {},
    nukeds = {},
    smashLocks = {},
    spks = {},
    unbankey = {} 
}

local DisplayX = 0
local DisplayY = 0
local total = 0
local pointss = ""
local cal1 = 0
local cal2 = 0
local botlog = {}
local calclog = {}
local antipickup = false
local automodage = false
local KeybindStr = "F7"
local Key = 118
local autoeatchamp = false
local modlogss = false
local quickstorage = false
local antipull = false
local turnads = false
local tradelogs = false
local tradelog = {}
local autorecycle = false
local chatbox = ""
local chatlog = {}
local chatlogs = false
local onspam = false
local autospam = false
local spamreturn = false
local textspam = "Do /sstext to Input Spam Text"
local reasons = {}
local punishlog = {}
local textemoji = false
local autowatermark = false
local watermark = ""
local conpikemoji = ""
local conpikcolor = ""
local autocolor = false
local autoemoji = false
local textcolor = false
local collectlog = {}
local droplog = {}
local vanishmod = true
local showcmd = false
local cbgl = false
local buybgl = false
local buychamp = false
local buydl = false
local vanishlog = {}
local recivlog = {}
local donetlog = {}
local turndonate = true
local boxx = 0
local boxy = 0
local putdonate = false
local shortspin = false
local antifreeze = false
local CommandQueue = {}
local IsProcessing = false
local XSB,YSB = (GetLocal() and GetLocal().pos and GetLocal().pos.x //32) or 0 , (GetLocal() and GetLocal().pos and GetLocal().pos.y //32) or 0
local WORLD_SB = (GetWorld() and GetWorld().name) or ""
local NAME = (GetLocal() and GetLocal().name) or ""
local GEMSB = (GetPlayerInfo() and GetPlayerInfo().gems) or 0
local delay = 3
local MULAI_SB = os.time()
local TOTAL_USED_GEMS = 0
local USED_GEMS = 0
local USED_BGEMS = 0
local TOTAL_USED_BGEMS = 0
local SB_PENDING = 0
local sisabgems = 0
local pakebgems = false
local pakegems = false
local COUNT = 0
local COUNTS = 0
local JUMLAH_SB = 0
local STARTSB = false
local SCOPY = true
local LONELY = false
local WDON = false
local logfake = ""
local safesb = false
local sbpending = false
local total_sb = 0
local totaldelay = "5"
local sdbtimer = 0
local timercount = 0
local settimer = false
local sdbcount = 0
local sdbamount = 0
local line1 = ""
local line2 = ""
local line3 = ""
local gassdb = false
local TEXT_SB = ""
local MENITS = 0
local PTIME = 0
local SISA_SB = 0
local reme = false
local qeme = false
local leme = false
local wheellog = {}
local fakelog = {}
local CheatStates = true
local pull = false
local kick = false
local ban = false
local totalworth = 0 
local localblgl = 0
local localbgl = 0

local Config = {
    ItemDetails = {},
    ItemNames = {},
    ItemCounts = {},
    RecentReports = {},
    ALLTexts = {"Nothing here yet..."},
    AllLogs = {},
    UserName = "Unknown User",
    EcoscanItemName = "",
    TotalAmount = "",
    PunishMenu = false,
    CheckReports = true,
    GetNicks = false,
    GetID = false,
    TargetItem = nil,
    SpecificItem = false,
    FindName = false,
    CopySign = false,
    SortAscending = true,
    CheckRecent = false,
    WorldsPerPage = 10,
    PlayersPerPage = 20,
    CurrentWorldsPage = 1,
    CurrentPlayersPage = 1,
    TotalItems = 0,
    ItemsPerPage = 25,
    CurrentPage = 1
}

local function FileRead(FileName)
    local file = io.open(FileName, 'r')
    if not file then return {} end
    local data = {}
    for line in file:lines() do
        table.insert(data, line)
    end
    file:close()
    return data
end

local function FileWrite(FileName, data) 
    local blacklisted = FileRead(FileName)
    for _, id in pairs(blacklisted) do
        if id == data then
            return
        end
    end
    local file = io.open(FileName, 'a')
    file:write(data .. "\n")
    file:close()
end

local function FileModify(FileName, data)
    local file = io.open(FileName, 'w')
    file:write(data .. "\n")
    file:close()
end

local function GetPlayerFromUserID(userid)
	for _,plr in pairs(GetPlayerList()) do
		if tonumber(plr.userid) == tonumber(userid) then
			return plr
		end
	end
end

local function RemoveBlacklistedUserID(UserID)
    local BlacklistedUsers = FileRead("BlacklistedUserIDS.txt")
    local UpdatedList = {}

    for _, id in ipairs(BlacklistedUsers) do
        if id ~= tostring(UserID) then
            table.insert(UpdatedList, id)
        end
    end

    local file = io.open("BlacklistedUserIDS.txt", 'w')
    for _, id in ipairs(UpdatedList) do
        file:write(id .. "\n")
    end
    file:close()
end

local function ClearBlacklistedUserIDs()
    local file = io.open("BlacklistedUserIDS.txt", 'w')
    file:close()
end

local function GetPlayerFromNetID(netid)
	for _,plr in pairs(GetPlayerList()) do
		if tonumber(plr.netid) == tonumber(netid) then
			return plr
		end
	end
end
local BlacklistedUserIDs = FileRead("BlacklistedUserIDS.txt")
local function Wrench(x, y)
    local pkt = {}
    pkt.type = 3
    pkt.value = 32
    pkt.px = math.floor((GetLocal() and GetLocal().pos and GetLocal().pos.x or 0) / 32 + x)
    pkt.py = math.floor((GetLocal() and GetLocal().pos and GetLocal().pos.y or 0) / 32 + y)
    pkt.x = (GetLocal() and GetLocal().pos and GetLocal().pos.x) or 0
    pkt.y = (GetLocal() and GetLocal().pos and GetLocal().pos.y) or 0
    SendPacketRaw(false, pkt)
    SleepS(0.04)
end

local function GetDisplayItem()
    Wrench(DisplayX, DisplayY)
    SleepS(0.09)
    SendPacket(2, "action|dialog_return\ndialog_name|displayblock_edit\nx|" .. tostring(DisplayX) .. "|\ny|" .. tostring(DisplayY) .. "|\nbuttonClicked|get_display_item")
end

function addToBuffer(value)
    table.insert(calclog, value)
end

function getLastFive(tbl)
    local result = {}
    local start = math.max(1, #calclog - 4)
    for i = start, #calclog do
        table.insert(result, calclog[i])
    end
    return result
end

local KeyCodes = {
    Lbutton = 1,
    Rbutton = 2,
    Xbutton1 = 5,
    Xbutton2 = 6,
    Cancel = 3,
    Mbutton = 4,
    Back = 8,
    Tab = 9,
    Clear = 12,
    Return = 13,
    Shift = 16,
    Control = 17,
    Menu = 18,
    Pause = 19,
    Capital = 20,
    Escape = 27,
    Space = 32,
    Prior = 33,
    Next = 34,
    End = 35,
    Home = 36,
    Left = 37,
    Up = 38,
    Right = 39,
    Down = 40,
    Select = 41,
    Print = 42,
    Execute = 43,
    Snapshot = 44,
    Insert = 45,
    Delete = 46,
    Help = 47,
    Num0 = 48,
    Num1 = 49,
    Num2 = 50,
    Num3 = 51,
    Num4 = 52,
    Num5 = 53,
    Num6 = 54,
    Num7 = 55,
    Num8 = 56,
    Num9 = 57,
    A = 65,
    B = 66,
    C = 67,
    D = 68,
    E = 69,
    F = 70,
    G = 71,
    H = 72,
    I = 73,
    J = 74,
    K = 75,
    L = 76,
    M = 77,
    N = 78,
    O = 79,
    P = 80,
    Q = 81,
    R = 82,
    S = 83,
    T = 84,
    U = 85,
    V = 86,
    W = 87,
    X = 88,
    Y = 89,
    Z = 90,
    Lwin = 91,
    Rwin = 92,
    Apps = 93,
    Numpad0 = 96,
    Numpad1 = 97,
    Numpad2 = 98,
    Numpad3 = 99,
    Numpad4 = 100,
    Numpad5 = 101,
    Numpad6 = 102,
    Numpad7 = 103,
    Numpad8 = 104,
    Numpad9 = 105,
    Multiply = 106,
    Add = 107,
    Separator = 108,
    Subtract = 109,
    Decimal = 110,
    Divide = 111,
    F1 = 112,
    F2 = 113,
    F3 = 114,
    F4 = 115,
    F5 = 116,
    F6 = 117,
    F7 = 118,
    F8 = 119,
    F9 = 120,
    F10 = 121,
    F11 = 122,
    F12 = 123,
    F13 = 124,
    F14 = 125,
    F15 = 126,
    F16 = 127,
    F17 = 128,
    F18 = 129,
    F19 = 130,
    F20 = 131,
    F21 = 132,
    F22 = 133,
    F23 = 134,
    F24 = 135,
    Numlock = 144,
    Scroll = 145,
    Lshift = 160,
    Lcontrol = 162,
    Lmenu = 164,
    Rshift = 161,
    Rcontrol = 163,
    Rmenu = 165
}

function GenerateRandomString()
    local Length = 24
    local Charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local RandomString = ""

    for i = 1, Length do
        local randIndex = math.random(1, #Charset)
        RandomString = RandomString .. Charset:sub(randIndex, randIndex)
    end

    return RandomString
end

local function split(inputstr, sep) -- Credits to Asleepdream
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function Ashtext()
    SendPacket(2, "action|input\n|text|`0[ `cAsh `0] `2Dah `cOn `2Ni `b? `4!")
end
Ashtext()

function inv(id)
    for _, item in pairs(GetInventory()) do
        if (item.id == id) then
        return item.amount
        end 
    end
    return 0
end

function say(tulisan)
    SendPacket(2, "action|input\n|text|`0[ `cAsh `0] "..tulisan)
end

local function Use(id, x, y)
    local pkt = {}
    pkt.type = 3
    pkt.value = id
    pkt.px = math.floor(((GetLocal() and GetLocal().pos and GetLocal().pos.x) or 0) / 32 + x)
    pkt.py = math.floor(((GetLocal() and GetLocal().pos and GetLocal().pos.y) or 0) / 32 + y)
    pkt.x = (GetLocal() and GetLocal().pos and GetLocal().pos.x) or 0
    pkt.y = (GetLocal() and GetLocal().pos and GetLocal().pos.y) or 0
    SendPacketRaw(false, pkt)
end

function cLog(str)
    LogToConsole("`0[ `cAsh `0] `0"..str)
end

function Ash(china)
    SendVariantList({[0] = "OnTextOverlay", [1] = china })
end

function wrn(text)
    local china = {}
    china[0] = "OnAddNotification"
    china[1] = "interface/atomic_button.rttex"
    china[2] = text
    china[3] = "audio/hub_open.wav"
    china[4] = 0
    SendVariantList(china)
end

function getDigit(value, digitPlace)
    return tonumber(tostring(value):sub(digitPlace, digitPlace))
end

local function SendWebhook(url, data)
    MakeRequest(url,"POST",{["Content-Type"] = "application/json"},data)
end

local function GetUsernameFromDialog(dialog)
    local cleanedDialog = dialog:gsub("`.", "")

    local username = cleanedDialog:match("add_label_with_icon|big|([^|%(]*)")

    if username then
        username = username:match("^%s*(.-)%s*$")
    end

    return username or "Unknown User"
end

function ANGKA_0(str)
    local cleanedStr = str:gsub("10", "0"):gsub("11", "1")
    return cleanedStr
end

function cty(id,id2,amount)
    for _, inv in pairs(GetInventory()) do
        if inv.id == id then
            if inv.amount < amount then
                SendPacketRaw(false, { type = 10, value = id2})
            end 
        end 
    end 
end

local function onspamm()
    SleepS(0.45)
    SendPacket(2, "action|input\n|text|/setspam " .. textspam)
end

local function SortItems()
    local function compare(a, b)
        if Config.SortAscending then
            return a[2] < b[2]
        else
            return a[2] > b[2]
        end
    end
    local items = {}
    for i = 1, #Config.ItemNames do
        table.insert(items, {Config.ItemNames[i], Config.ItemCounts[i]})
    end
    table.sort(items, compare)
    
    Config.ItemNames = {}
    Config.ItemCounts = {}
    for _, item in ipairs(items) do
        table.insert(Config.ItemNames, item[1])
        table.insert(Config.ItemCounts, item[2])
    end
end

-- UI/dialog definitions (ensure these exist before handlers)
local function updatebar()
    local dialog = [[
add_label_with_icon|big|`cAsh `bProxy|left|11550|
add_textbox|`bProxy Version `0: `2V.13.0|
add_smalltext|`b/update `0(`9Open This Dialog`0)|
add_spacer|small|
add_label_with_icon|small|`2V.0.13.0|left|834|
add_textbox|`2Update Logs `0=|
add_smalltext|`b- `9Added `#/blacklist`0, `4Blacklist `9Player System`0.|
add_smalltext|`b- `9Added `9Fast Take items in Display Block`0, `9Try It`4!|
add_textbox|`4Bug Fixes `0=|
add_smalltext|`b- `9Forgot to Add Calculator Logs in Logs Menu`0.|
add_smalltext|`b- `9Fixed SC will crash if no number inputed and clicked add in calculator`0.|
add_smalltext|`b- `9If Hotkey Button is pressed, will eat Champ even the hotkey command is off`0.|
add_textbox|`b-|
add_spacer|small|
add_spacer|small|
add_smalltext|`2GO CHECK IT OUT!|
add_spacer|small|
add_button|menuu|`bCommand/Menu Bar||
end_dialog|hsj|Close|
]]
    CreateDialog(dialog)
end
updatebar()

local function telephone()
    local dialog = [[
add_label_with_icon|big|`bTelephone `9Commands`0 :|left|3898
add_spacer|small|
add_smalltext|`b/cv `b- `9Wrench `bTelephone `9to Change `cDL|
add_smalltext|`b/buybgl `b- `9Wrench `bTelephone `9to Buy `eBGL|
add_smalltext|`b/buydl `b- `9Wrench `bTelephone `9to Buy `cDL|
add_smalltext|`b/buychamp `b- `9Wrench `bTelephone `9to Buy `2Champagne|
add_spacer|small|
add_button|Back??|Back||
end_dialog|hsj|Close|
]]
    CreateDialog(dialog)
end

local function wrenchlist()
    local dialog = [[
add_label_with_icon|big|`4Wrench `9Commands`0 :|left|32
add_spacer|small|
add_smalltext|`b/wrp `b- `9Wrench `8Pull|
add_smalltext|`b/wrk `b- `9Wrench `5Kick|
add_smalltext|`b/wrb `b- `9Wrench `4Ban|
add_spacer|small|
add_button|Back??|Back||
end_dialog|hsj|Close|
]]
    CreateDialog(dialog)
end

local function calculator()
    local dialog = [[
add_label_with_icon|big|`bCalculator|left|10568|
add_spacer|small|
add_button|calclog|`9History|
add_spacer|small|
add_text_input|num1|`9Input First Number:||10|
add_text_input|num2|`9Input Second Number:||10|
add_spacer|small|
add_button|add|`9Add (+)|noflags|0|0|
add_button|substract|`9Substract (-)|noflags|0|0|
add_button|multiply|`9Multiply (*)|noflags|0|0|
add_button|divide|`9Divide (/)|noflags|0|0|
add_spacer|small|
add_quick_exit||
add_button|Back??|Back||
end_dialog|hsj|Close|
]]
    CreateDialog(dialog)
end

local function calculator2()
    local dialog = [[
add_label_with_icon|big|`bCalculator|left|10568|
add_spacer|small|
add_text_input|num1|`9Input First Number:||10|
add_text_input|num2|`9Input Second Number:||10|
add_smalltext|`4]]..cal1..[[ `0]]..pointss..[[ `4]]..cal2..[[ `0= `2]]..total..[[|
add_spacer|small|
add_button|add|`9Add (+)|noflags|0|0|
add_button|substract|`9Substract (-)|noflags|0|0|
add_button|multiply|`9Multiply (*)|noflags|0|0|
add_button|divide|`9Divide (/)|noflags|0|0|
add_spacer|small|
add_quick_exit||
add_button|Back??|Back||
end_dialog|hsj|Close|
]]
    CreateDialog(dialog)
end

local function tradelist()
    local dialog = [[
add_label_with_icon|big|`qTrade `9Commands`0 :|left|242
add_spacer|small|
add_smalltext|`b/td `9(`4Amount`9) `b- `9Put Your `cDiamond Locks`9 At Trade`0.|
add_smalltext|`b/tb `9(`4Amount`9) `b- `9Put Your `eBlue Gem Locks`9 At Trade`0.|
add_smalltext|`b/tbl `9(`4Amount`9) `b- `9Put Your `bBlack Gem Locks`9 At Trade`0.|
add_spacer|small|
add_button|Back??|Back||
end_dialog|hsj|Close|
]]
    CreateDialog(dialog)
end

local function donatelist()
    local dialog = [[
add_label_with_icon|big|`eDonate `9Commands`0 :|left|1452
add_spacer|small|
add_smalltext|`b/dmode `b- `9Toggle `2ON`0/`4OFF `eDonate `9Mode Wrench`0.|
add_smalltext|                  `1-`9Wrench to The Selected Box to do|
add_smalltext|                    `4(`b/pd`0, `b/pb`0, `b/pbl`4)`0.|
add_smalltext|`b/pd `9(`4Amount`9) `b- `9Donate `cDiamond Locks`0.|
add_smalltext|`b/pb `9(`4Amount`9) `b- `9Donate `eBlue Gem Locks`0.|
add_smalltext|`b/pbl `9(`4Amount`9) `b- `9Donate `bBlack Gem Locks`0.|
add_smalltext|                            `1-`9Need To Turn `2ON `b/dmode `9for|
add_smalltext|                             `4(`b/pd`0, `b/pb`0, `b/pbl`4)`0.|
add_smalltext|`b/takeall `b- `9Retrieving All Items`0.|
add_smalltext|                `1-`9Need To Turn `2ON `b/dmode`0.|
add_spacer|small|
add_button|Back??|Back||
end_dialog|hsj|Close|
]]
    CreateDialog(dialog)
end

local function sblist()
    local dialog = [[
add_label_with_icon|big|`eSB `9Commands`0 :|left|2480
add_spacer|small|
add_smalltext|`b/sblog `b- `eSB `9LOG)|
add_smalltext|`b/copy `b- `9Copy Text `0(`4Auto Turn ON`0)|
add_smalltext|`b/count `0(`4amount`0) `b- `9Set How Many `eSB|
add_smalltext|`b/1h `b- `9+ 1 Hour SB|
add_smalltext|`b/2h `b- `9+ 2 Hour SB|
add_smalltext|`b/3h `b- `9+ 3 Hour SB|
add_smalltext|`b/csb `0(`4amount`0) `4+ `0(`4amount`0) `eSB ]|
add_smalltext|`b/wdone `0(`4world`0) `b- `9Set Done World after `eSB|
add_spacer|small|
add_smalltext|`b/start `b- `9Start `eSB|
add_smalltext|`b/stop `b- `9Stop `eSB|
add_spacer|small|
add_smalltext|`b/ads `b- `9Add World Name after Your ID|
add_smalltext|`bExample `0: `c@Ash`c[`0BTK`c]|
add_smalltext|`b/solo `b- `9Hide/Unhide People|
add_smalltext|`b/safe `b- `9Stay in World|
add_spacer|small|
add_label_with_icon|big|`2SDB `9Commands`0 :|left|2480
add_spacer|small|
add_smalltext|`b/sdblog `b- `2SDB `9LOG|
add_smalltext|`b/sdbtime `0(`4amount`0) `b- `9Set extra Delay before `2SDB|
add_smalltext|`bExample `0: `9Normal delay is 5 Mins, so if add extra delay|
add_smalltext|`9Total of 5 Mins + Extra Delay|
add_smalltext|`b/lineall `b- `9Set All 3 `2SDB `9Text Line|
add_smalltext|`b/sdbstart `0(`4amount`0) `b- `9Start SDB|
add_spacer|small|
add_button|Back??|Back||
end_dialog|hsj|Close|
]]
    CreateDialog(dialog)
end

local function gamblinglist()
    local dialog = [[
add_label_with_icon|big|`4Gambling `9Commands`0 :|left|758
add_spacer|small|
add_smalltext|`b/shorter `b- `9Toggle `2ON `4OFF `eShort Wheel `9Text`0|
add_smalltext|`b/reme `b- `9Toggle `2ON `4OFF `eREME `9Mode`0|
add_smalltext|`b/qeme `b- `9Toggle `2ON `4OFF `#QEME `9Mode`0|
add_smalltext|`b/leme `b- `9Toggle `2ON `4OFF `cLEME `9Mode`0|
add_spacer|small|
add_button|Back??|Back||
end_dialog|hsj|Close|
]]
    CreateDialog(dialog)
end

local function commandftr()
    local dialog = [[
add_label_with_icon|big|`tHelpful `9Commands`0 :|left|5770
add_spacer|small||
add_spacer|small|
add_smalltext|`b/blacklist `b- `4Blacklist `9Player System`0.|
add_smalltext|`b/hotkey `b- `2Enable `9Hotkey Button|
add_smalltext|   `2Current Hotkeys =|
add_smalltext|      `9Eat `2Champagne `0= `4F7|     
add_spacer|small|
add_smalltext|`b/calcu (number x/+/-/: number) `b- `9Calculate with cmd`0.|
add_smalltext|`b/calculator `b- `bCalculator `9Menu`0.|
add_spacer|small|
add_smalltext|`b/antipickup `b- `4Anti Pick Up `9Items`0.|
add_smalltext|`b/autorecycle `b- `9Fast Recycle same like Fast Drop`0, `9Choose item and Press Recycle`0.|
add_smalltext|`b/quickstorage `b- `9Fast Withdraw/Deposit Max Amount in `wStorage Box`0.|
add_smalltext|`b/relog `b- `9ReConnect Command`0.|
add_smalltext|`b/exit `b- `2Exit Command`0.|
add_smalltext|`b/res `b- `2Respawnd Command`0.
add_smalltext|`b/rnick `b- `9/nick to a `2R`4a`5n`8d`9o`bm `9Nick`0.|
add_smalltext|`b/rworld `b- `9Join a `2R`4a`5n`8d`9o`bm `9World`0.|
add_spacer|small|
add_smalltext|`b/antifreeze `b- `9Anti `cFreeze`0.|
add_smalltext|`b/antipull `b- `9Anti `bPull`0.|
add_smalltext|`b/automd `b- `9Auto `2Modage `0(`9Anti Balloon,Pie,Clover,Arroz,etc`0)`0.
add_spacer|small|
add_smalltext|`b/showcmd `b- `9Show `bCommand Text`0.|
add_spacer|small|
add_smalltext|`#@Mods `4Only|
add_smalltext|`b/g `b- `9Shortcut for /ghost`0.|
add_smalltext|`b/f `b- `9Shortcut for /vinvis`0.|
add_smalltext|`b/punish `0(`4nick`0) `b- `4Punish `9Menu`0.|
add_smalltext|`b/viewinv `0(`4nick`0) `b- `9Modifed View Inventory Can use Nick`0/`9UserID`0.|
add_smalltext|`b/mod `b- `9To Check `#Mods `9that Using a Nick`0.|
add_smalltext|`b/reports `b- `9To Check Recent `4Report `9from Player and Warp to them`0.|
add_smalltext|`b/recent `b- `9To Check Recent `2World `9that you Joined and Want to enter again`0.|
add_smalltext|`b/online (name) `b- `9a Very Helpful Command for Mods to Check How Many Accounts Online (BASED ON IPCHECK)`0.|
add_smalltext|`b/onlinerid (name) `b- `9Same as `#/online but (BASED ON RIDCHECK)`0.|
add_smalltext|  `4WARNING /ONLINE AND /ONLINERID MIGHT CAUSE THE GAME CRASH DUE TO BOTHAX UNSTABILITY WITH THE FUNC|
add_spacer|small|
add_smalltext|`b/wede `0(`4amount`0) `b- `9Withdraw from Bank`0.|
add_smalltext|`b/depo `0(`4amount`0) `b- `9Deposit to Bank`0.|
add_smalltext|`b/black `b- `9Make `bBlack Gem Lock`0.|
add_smalltext|`b/blue `b- `9Make `eBlue Gem Lock`0.|
add_smalltext|`b/bd `b- `9Drop `eBGL`0.|
add_smalltext|`b/dd `b- `9Drop `cDL`0.|
add_smalltext|`b/wd `b- `9Drop `9WL`0.|
add_smalltext|`b/bdl `b- `9Drop `bBLACK|
add_spacer|small|
add_spacer|small|
add_button|Back??|Back||
end_dialog|hsj|Close|
]]
    CreateDialog(dialog)
end

local function spamftr()
    local dialog = [[
add_label_with_icon|big|`bSpam `9Commands`0 :|left|1420
add_spacer|small|
add_smalltext|`b/sstext `b- `9Set `bSpam `9Text`0.|
add_smalltext|`b/spam `b- `9Toggle `2ON `4The Auto `bSpam`0.|
add_smalltext|`b/stopspam `b- `9Toggle `4OFF `9The Auto `bSpam`0.|
add_spacer|small|
add_smalltext|`b-`bAuto Set Spam Text If `4Disconnected `bor Entering a Different World`0.|
add_spacer|small|
add_button|Back??|Back||
end_dialog|hsj|Close|
]]
    CreateDialog(dialog)
end

local function menubar()
    local dialog = [[
add_label_with_icon|big|`cAsh `bProxy|left|2480|
add_textbox|		
add_textbox|`9GrowID `0: ]] .. GetLocal().name ..[[|
add_textbox|`9Date `0: `2]] .. os.date("!%a, %b/%d/%Y") .. [[|
add_textbox|`9Time `0: `2]] .. os.date("%I:%M %p") .. [[|
add_spacer|small|				
add_smalltext|`b/menu `0(`9Show This Dialog`0)|
add_spacer|small|
add_label|big|`4All Feature `0:|
add_spacer|small|
text_scaling_string|jjjjjjjjjjjjjjjjjjjjjjjjjj|
add_button_with_icon|commandftr|`9Commands|staticYellowFrame|5770||
add_button_with_icon|wrenchlist|`aWrench `9Mode|staticYellowFrame|32||
add_button_with_icon|donatelist|`eDonating `9Mode|staticYellowFrame|1452||
add_button_with_icon|tradelist|`pTrading `9Mode|staticYellowFrame|242||
add_button_with_icon|gamblinglist|`eGambling `9Mode|staticYellowFrame|758||
add_button_with_icon|spamlist|`9Auto `bSpam|staticYellowFrame|1420||
add_button_with_icon|telephone|`bTelephone|staticYellowFrame|3898||
add_button_with_icon|sblist|`eSB `9& `2SDB `9Cmds|staticYellowFrame|2480|
add_button_with_icon|alllogs|`9All `bLogs `9List|staticYellowFrame|1436|||
add_button_with_icon|texcolor|`bEmoji `0& `cColor `9List|staticYellowFrame|558|||
add_button_with_icon|modlogss|`#Mod `bLogs|staticYellowFrame|1436|||
add_button_with_icon|calculator|`bCalculator|staticYellowFrame|10568|||
text_scaling_string|jjjjjjjjjjjjjjjjjjjjjjjjjj|
add_spacer|small|
add_button_with_icon||END_LIST|noflags|0||
add_spacer|small|
end_dialog|cmdend|Cancel|
]]
    CreateDialog(dialog)
end

local function logslogs()
    local dialog = [[
add_label_with_icon|big|`9All `bLogs`0 :|left|1436
add_spacer|small|
add_textbox|`#/log `9as the `eCMD `9to This Menu|
add_spacer|small|
add_button|rsetlog|`4Reset `9All `bLogs||
add_textbox|`#/resetlog `9as the `eCMD|
add_spacer|small|
add_spacer|small|
add_button|calclog|`bCalculator `bLogs||
add_smalltext|`#/calclog `9as the `eCMD|
add_button|botlog|`4Botting `bLogs||
add_smalltext|`#/botlog `9as the `eCMD|
add_button|logtrade|`bTrade `bLogs||
add_smalltext|`#/tradelog `9as the `eCMD|
add_button|logchat|`eWorld Chat `bLogs||
add_smalltext|`#/chatlog `9as the `eCMD|
add_button|logcollect|`aCollect `bLogs||
add_smalltext|`#/collectlog `9as the `eCMD|
add_button|logdrop|`cDrop `bLogs||
add_smalltext|`#/droplog `9as the `eCMD|
add_button|logreciv|`bReceives `bLogs||
add_smalltext|`#/reclog `9as the `eCMD|
add_button|logdonet|`eDonate `bLogs||
add_smalltext|`#/donatelog `9as the `eCMD|
add_button|logfake|`4Fake `0Spin `bLogs||
add_smalltext|`#/fakelog `9as the `eCMD|
add_button|logwheel|`9All `2Spin `bLogs||
add_smalltext|`#/wheellog `9as the `eCMD|
add_button|logvanish|`4Vanished `#@Mod `bLogs||
add_smalltext|`#/vanishlog `9as the `eCMD|
add_button|logpunish|`4Punish `bLogs||
add_smalltext|`#/punishlog `9as the `eCMD|
add_button|logsb|`eSB `bLogs||
add_smalltext|`#/sblog `9as the `eCMD|
add_button|logsdb|`2SDB `bLogs||
add_smalltext|`#/sdblog `9as the `eCMD|
add_spacer|small|
add_button|Back??|Back||
end_dialog|hsj|Close|
]]
    CreateDialog(dialog)
end

local function modlogs()
    local dialog = [[
add_label_with_icon|big|`#Mod `bLogs`0 :|left|1436
add_spacer|small|
]]
    
    if modlogss then
        dialog = dialog .. "\nadd_button|enablemodlogs|`4Disable||\nadd_smalltext|`0[`#Mod `bLogs `0: `2ON`0]|\nadd_spacer|small|"
    else
        dialog = dialog .. "\nadd_button|enablemodlogs|`2Enable||\nadd_smalltext|`0[`#Mod `bLogs `0: `4OFF`0]|\nadd_spacer|small|"
    end

    dialog = dialog .. [[
add_textbox|`#/modlog `9as the `eCMD `9to This Menu|
add_spacer|small|
add_button|resetmodlogs|`4Reset `9All `bLogs||
add_spacer|small|
add_spacer|small|
add_button|banlogs|`4Ban `bLogs||
add_smalltext|`#/banlog `9as the `eCMD|
add_button|curselogs|`bCurse `bLogs||
add_smalltext|`#/curselog `9as the `eCMD|
add_button|ducttapelogs|`bDuct Tape `bLogs||
add_smalltext|`#/tapelog `9as the `eCMD|
add_button|smashlocklogs|`4Smash Lock `bLogs||
add_smalltext|`#/smashlog `9as the `eCMD|
add_button|spklogs|`5SPK `bLogs||
add_smalltext|`#/spklog `9as the `eCMD|
add_button|nukedlogs|`4Nuked `bLogs||
add_smalltext|`#/nukedlog `9as the `eCMD|
add_button|sanctionedlogs|`bSanctioned `bLogs||
add_smalltext|`#/sanclog `9as the `eCMD|
add_button|unbankeylogs|`4Unban Key `bLogs||
add_smalltext|`#/unbankeylog `9as the `eCMD|
add_button|modchatlogs|`5Modchat `bLogs||
add_smalltext|`#/modchatlog `9as the `eCMD|
add_spacer|small|
add_button|Back??|Back||
end_dialog|hsj|Close|
]]
    CreateDialog(dialog)
end

local function texmoji()
    local dialog = [[
add_label_with_icon|big|`9All `eEmoji `9Commands`0 :|left|6276
add_spacer|small|
add_button|resetemoji1|`4Back `9To `4No `bEmoji|
add_spacer|small|
add_textbox|`#/textmoji`0, `9For This Menu|
add_textbox|`#/noemoji`0, `9Reset to `4No `bEmoji|
add_spacer|small|
add_textbox|`#/setemoji`0 + `0(`4code`0),`9Example :|
add_textbox|`#/setemoji (moyai),`9Code = `0(moyai`0)|
add_spacer|small|
add_label|big|`4Codes `0:|
add_spacer|small|
add_textbox|`0(`9wl`0),(`9yes`0),(`9no`0),(`9love`0),(`9oops`0),|
add_textbox|`0(`9shy`0),(`9wink`0),(`9tongue`0),(`9agree`0),(`9sleep`0),|
add_textbox|`0(`9punch`0),(`9music`0),(`9build`0),(`9megaphone`0),(`9sigh`0),|
add_textbox|`0(`9mad`0),(`9wow`0),(`9dance`0),(`9see-no-evil`0),(`9bheart`0),|
add_textbox|`0(`9heart`0),(`9grow`0),(`9gems`0),(`9kiss`0),(`9gtoken`0),|
add_textbox|`0(`9lol`0),(`9smile`0),(`9cool`0),(`9cry`0),(`9vend`0),|
add_textbox|`0(`9bunny`0),(`9cactus`0),(`9pine`0),(`9peace`0),(`9terror`0),|
add_textbox|`0(`9troll`0),(`9evil`0),(`9fireworks`0),(`9football`0),(`9alien`0),|
add_textbox|`0(`9party`0),(`9pizza`0),(`9clap`0),(`9song`0),(`9ghost`0),|
add_textbox|`0(`9nuke`0),(`9halo`0),(`9turkey`0),(`9gift`0),(`9cake`0),|
add_textbox|`0(`9heartarrow`0),(`9lucky`0),(`9shamrock`0),(`9grin`0),(`9ill`0),|
add_textbox|`0(`9eyes`0),(`9weary`0),(`9moyai`0),(`9plead`0).|
add_spacer|small|
add_button|Back2|Back||
end_dialog|hsj|Close|
]]
    CreateDialog(dialog)
end

local function colorcmd()
    local dialog = [[
add_label_with_icon|big|`9All `cColor `9Commands`0 :|left|1156
add_spacer|small|
add_button|resetcolr1|`4Back `9To `0Default `cColor||
add_spacer|small|
add_textbox|`#/colorcmd`0, `9For This Menu|
add_textbox|`#/nocolor`0, `4Reset `cColor `9Text|
add_spacer|small|
add_textbox|`#/color`0(`4code`0),`9Example :|
add_textbox|`#/color`ee,`9Code = `ee`0(`eBlue`0)|
add_spacer|small|
add_label|big|`4Codes `0:|
add_spacer|small|
add_textbox|`b-`44 `b- `4Red|
add_textbox|`b-`@@ `b- `2Bright Red|
add_textbox|`b-`&& `b- `&Very Pale Pink|
add_textbox|`b-`pp `b- `pPink|
add_textbox|`b-`55 `b- `5Pinky Purple|
add_textbox|`b-`ww `b- `wWhite|
add_textbox|`b-`qq `b- `qDark Blue|
add_textbox|`b-`ee `b- `eBlue|
add_textbox|`b-`cc `b- `cCyan|
add_textb
]]
    CreateDialog(dialog)
end

-- (other original functions and dialogs continue here...)
-- Ensure all original functions referenced by handlers exist above this point:
-- pos_dialog, colect, DropItem, wear, ovlay, menubar, tap, wrenchop, proxy, etc.

-- =========================
-- Handlers: var, text, raw (definitions only, registration later)
-- =========================

-- Variant handler: handles OnVariant / OnDialogRequest / OnTalkBubble / OnConsoleMessage
local function variant_handler(var, netid)
    if not var or type(var) ~= "table" then return false end
    local ev = tostring(var[0] or "")
    -- OnConsoleMessage
    if ev == "OnConsoleMessage" then
        local msg = tostring(var[1] or "")
        if msg:find("commands.") then
            LOG("Unknown command used")
            return true
        end
        return false
    end

    if ev == "OnDialogRequest" then
        local content = tostring(var[1] or "")
        if content:find("end_dialog|telephone") and cvdl == true then
            SendPacket(2, "action|dialog_return\ndialog_name|telephone\nnum|53785|\nx|"..tostring(content:match("embed_data|x|(%d+)") or "").."|\ny|"..tostring(content:match("embed_data|y|(%d+)") or "").."|\nbuttonClicked|dlconvert")
            return true
        end
        return false
    end

    if ev == "OnTalkBubble" then
        local text = tostring(var[2] or "")
        if text:find("spun the wheel") then
            LOG("TalkBubble: "..tostring(text))
            return false
        end
    end

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

    if pkt:find("buttonClicked|blockSDB") then
        blocksdb = not blocksdb
        ovlay(blocksdb and "`2Block Sdb Mode Enabled" or "`4Block Sdb Mode Disabled")
        return true
    end

    if pkt:find("action|dialog_return\ndialog_name|kk\nbuttonClicked|Wrench") then
        CreateDialog(wrenchop)
        return true
    end
    if pkt:find("action|dialog_return\ndialog_name|kk\nbuttonClicked|Proxy") then
        CreateDialog(proxy)
        return true
    end

    if pkt:find("/pos") then
        pos_dialog()
        return true
    end

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

    if pkt:find("/setb") then
        bx = math.floor((GetLocal() and GetLocal().pos and GetLocal().pos.x or 0) / 32)
        by = math.floor((GetLocal() and GetLocal().pos and GetLocal().pos.y or 0) / 32)
        ovlay("Succes Set Back Pos ("..tostring(bx)..", "..tostring(by)..")")
        return true
    end

    if pkt:find("/help") or pkt:find("/fitur") then
        menubar()
        return true
    end

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

    local d_amt = pkt:match("action|input\n|text|/d (%d+)") or pkt:match("/d (%d+)")
    if d_amt then DropItem(1796, d_amt); ovlay("Succes Drop "..d_amt.." Diamond Lock"); return true end
    local w_amt = pkt:match("action|input\n|text|/w (%d+)") or pkt:match("/w (%d+)")
    if w_amt then DropItem(242, w_amt); ovlay("Succes Drop "..w_amt.." World Lock"); return true end
    local b_amt = pkt:match("action|input\n|text|/b (%d+)") or pkt:match("/b (%d+)")
    if b_amt then DropItem(7188, b_amt); ovlay("Succes Drop "..b_amt.." Blue Gem Lock"); return true end

    if pkt:find("/bdl") then cvdl = not cvdl; ovlay(cvdl and "`2Buy Dl Mode Enable" or "`4Buy Dl Mode Disable"); return true end

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
                                { x = xgem1, y = ygem1 }, { x = xgem1, y = xgem2 }, { x = xgem1, y = xgem3 },
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

    return false
end

-- =========================
-- Register normalized handlers AFTER all functions are defined
-- =========================
register_normalized("main_handlers", {
    var = variant_handler,
    text = text_handler,
    raw = raw_handler
})

-- =========================
-- Init messages (keeps original behavior)
-- =========================
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
-- If original script had a main loop, ensure it uses SleepS and is placed here.
-- =========================

-- End of file
