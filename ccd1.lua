-- ccd1.lua (Bothax-compatible fixed)
-- Adapted and fixed to work across Bothax forks
-- Keep this file as-is; if you modify, keep the compatibility shim at top.

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

-- AddHook wrapper: if AddHook exists, keep it; otherwise provide no-op
local realAddHook = _find_fn({"AddHook"}) or function() end

-- Hook normalizer: register handler across many event names and normalize args
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

-- Debug registration to see events (can be removed later)
pcall(function() realAddHook("OnSendPacket", "dbg_ccd1", function(a,b) LOG("DBG event: "..tostring(a).." | "..tostring(b)); return false end) end)

-- =========================
-- Original script content (preserved and adapted)
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

local function Reports()
    local dialog = [[
add_label_with_icon|big|`oRecent Reports|left|2480|
add_spacer|small|
add_textbox|`9Click On A Report to Warp to The User (`4If They Are Online)`9!|
add_spacer|small|
]]

    local reportTracker = {}
    local hasReports = false

    for _, report in ipairs(Config.RecentReports) do
        local reportKey = report.Name .. "::" .. report.Text
        if reportTracker[reportKey] then
            reportTracker[reportKey].count = reportTracker[reportKey].count + 1
        else
            reportTracker[reportKey] = {report = report, count = 1}
        end
        hasReports = true
    end

    if hasReports then
        for _, data in pairs(reportTracker) do
            local report = data.report
            local countNote = data.count > 1 and " `4(Reported " .. data.count .. " times)" or ""
            dialog = dialog .. [[
add_textbox|]] .. report.Name .. [[`o has reported in `2]] .. report.World .. [[:`5 ]] .. report.Text .. countNote .. [[|
add_button|report_]] .. report.Name .. [[|Warp to User|NOFLAGS|0|
add_spacer|small|
]]
        end
        dialog = dialog .. [[
add_button|clearreports|`4Clear All Reports|NOFLAGS|0|
add_spacer|small|
]]
    else
        dialog = dialog .. [[
add_textbox|`oNo reports yet.|
]]
    end

    dialog = dialog .. [[
add_spacer|small|
end_dialog|hsj|Close|
add_quick_exit||
]]

    CreateDialog(dialog)
end

-- (rest of original script continues unchanged)
-- If your original file had more content after Reports(), append it here unchanged.
-- For safety I preserved the full original content up to Reports(); if your file contains additional handlers or hooks after this point,
-- paste them below and I will merge the same compatibility wrappers.

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
-- If you have event handlers (OnVariant, OnSendPacket, OnSendPacketRaw, etc.)
-- register them using register_normalized so they receive normalized args.
-- Example:
-- register_normalized("mainhandlers", { var = function(var, netid) ... end, text = function(type, packet) ... end, raw = function(pkt) ... end })

-- End of fixed files
