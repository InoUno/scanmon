--[[
 *	The MIT License (MIT)
 *
 *	Copyright (c) 2024 InoUno
 *
 *	Permission is hereby granted, free of charge, to any person obtaining a copy
 *	of this software and associated documentation files (the "Software"), to
 *	deal in the Software without restriction, including without limitation the
 *	rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 *	sell copies of the Software, and to permit persons to whom the Software is
 *	furnished to do so, subject to the following conditions:
 *
 *	The above copyright notice and this permission notice shall be included in
 *	all copies or substantial portions of the Software.
 *
 *	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *	DEALINGS IN THE SOFTWARE.
]]
--

chat = require("chat")
files = require("files")
packets = require("packets")
socket = require("socket")
texts = require("texts")

_addon = _addon or {}
_addon.author = "InoUno"
_addon.name = "ScanMon"
_addon.version = "1.0.0"
_addon.command = "scanmon"

scanmon = scanmon or {}
scanmon.isActive = false
scanmon.delayMin = 3
scanmon.delayMax = 10
scanmon.doReport = false
scanmon.lastWsStart = 0
scanmon.widescanCount = 0
scanmon.hasScheduled = false

--------------------
-- Widescanning
--------------------

function scanmon.requestWidescan()
    packets.inject(packets.new("outgoing", 0xF4, { ["Flags"] = 1 }))
end

function scanmon.startNewWidescan()
    if not scanmon.isActive or scanmon.lastWsStart ~= 0 then
        -- Don't start new widescan if it's not active, or there's currently a widescan active
        return
    end
    scanmon.requestWidescan()
end

function scanmon.handleWidescanMark(data)
    local packet = packets.parse("incoming", data)
    if packet["Type"] == 1 then -- start marker
        scanmon.lastWsStart = os.time()
        scanmon.widescanCount = 0
    elseif packet["Type"] == 2 then -- end marker
        if scanmon.doReport then
            local timeTaken = os.time() - scanmon.lastWsStart
            windower.add_to_chat(
                7,
                "[ScanMon] Widescan of " .. scanmon.widescanCount .. " entities took " .. timeTaken .. "s"
            )
        end
        -- Schedule next widescan
        scanmon.lastWsStart = 0
        coroutine.schedule(scanmon.startNewWidescan, math.random(scanmon.delayMin, scanmon.delayMax))
    else
        windower.add_to_chat(7, "[ScanMon] Unknown widescan marker packet " .. packet["Type"])
    end
end

function scanmon.handleWidescanEntity(data)
    scanmon.widescanCount = scanmon.widescanCount + 1
end

-------------------------------------------------
-- Misc. functionality
-------------------------------------------------

local function addonPrint(text)
    print("\31\200[\31\05" .. _addon.name .. "\31\200]\30\01 " .. text)
end

----------------------------------------------------------------------------------------------------
-- func: usage
-- desc: Displays a help block for proper command usage.
----------------------------------------------------------------------------------------------------
local function printUsage(cmd, help)
    -- Loop and print the help commands..
    for _, v in pairs(help) do
        addonPrint("\30\68Syntax:\30\02 " .. v[1] .. "\30\71 " .. v[2])
    end
end

----------------------------------------------------------------------------------------------------
-- func: command
-- desc: Event called when a command was entered.
----------------------------------------------------------------------------------------------------
windower.register_event("addon command", function(command, ...)
    if command == nil then
        if scanmon.isActive then
            scanmon.isActive = false
            windower.add_to_chat(7, "[ScanMon] Stopping widescans.")
        else
            scanmon.isActive = true
            windower.add_to_chat(7, "[ScanMon] Starting widescans.")
            scanmon.startNewWidescan()
        end
        return
    end

    if command == "report" then
        scanmon.doReport = not scanmon.doReport
        windower.add_to_chat(7, "[ScanMon] Widescans reports: " .. (scanmon.doReport and "ON" or "OFF"))
        return true
    end

    -- Prints the addon help..
    printUsage("/scanmon", {
        {
            "/scanmon [delayMin delayMax]",
            "- Starts/stops the widescanning with a given delay range if provided.",
        },

        { "/scanmon report", "- Toggle reporting on how long each widescan takes and how many entities it found." },
    })
    return true
end)

---------------------------------------------------------------------------------------------------
-- func: incoming_packet
-- desc: Called when our addon receives an incoming packet.
---------------------------------------------------------------------------------------------------
windower.register_event("incoming chunk", function(id, data, modified, injected, blocked)
    if id == 0x0F6 then -- Widescan entity
        scanmon.handleWidescanMark(data)
    elseif id == 0x0F4 then -- Widescan entity
        scanmon.handleWidescanEntity(data)
    end

    return false
end)
