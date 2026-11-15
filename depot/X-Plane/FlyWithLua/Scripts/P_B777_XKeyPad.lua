-- P_B777_XKeyPad.lua
-- Lädt in der FlightFactor 777, 767 und 757 die X-KeyPad-Konfiguration einmal nach, sobald das Flugzeug seine Kommandos
-- angelegt hat.
--
-- Hintergrund: X-KeyPad liest die Stream-Deck-Konfiguration beim Laden des Flugzeugs direkt nach
-- „[B777 INFO]: Initializing modules…“. Die 777 legt ihre Kommandos (1-sim/command/…) aber erst in den
-- folgenden Frames und Sekunden an; X-KeyPad bricht dann mit „Unable to find command“ ab.
-- LOAD_DELAY in X-KeyPad_777-*.ini reicht dafür nicht (10 getestet am 2026-10-25, Einheit sind Frames).
-- Die MFD-Taste CAM (nur 300ER und F) legt die 777 deutlich später an als die übrigen Kommandos.
-- Dieses Skript prüft jede Sekunde, ob alle Kommandos der Liste existieren, wartet dann noch PUFFER Sekunden
-- und löst einmal SRS/X-KeyPad/Reload_Configuration aus (= Menü Plugins › X-KeyPad › Reload configuration files).
-- Spätestens nach 90 s lädt es auf jeden Fall nach.
-- 767 (Ordner Boeing767-Full) und 757 (Boeing757-Full): gleiches Verfahren mit den MCP-Kommandos (Taster und Knopf).

local KOMMANDOS, DATAREF = nil, nil
if string.find(AIRCRAFT_PATH, "FlightFactor777", 1, true) then
    KOMMANDOS = {"1-sim/command/beaconLightSwitch_button"}
    if string.find(AIRCRAFT_FILENAME, "300ER", 1, true) or string.find(AIRCRAFT_FILENAME, "777-F", 1, true) then
        table.insert(KOMMANDOS, "1-sim/command/mfdPageCamButtom_button")
    end
    DATAREF = "1-sim/ckpt/beaconLightSwitch/anim"          -- falls XPLMFindCommand fehlt
elseif (string.find(AIRCRAFT_PATH, "Boeing767-Full", 1, true) and string.find(AIRCRAFT_FILENAME, "767", 1, true))
    or string.find(AIRCRAFT_PATH, "Boeing757-Full", 1, true) then
    KOMMANDOS = {"1-sim/command/AP/lnavButton_button", "1-sim/comm/AP/spdUP"}
    DATAREF = "1-sim/AP/lnavButton"
end

if KOMMANDOS then
    local PUFFER = 5
    local erledigt = false
    local sekunden = 0
    local gefunden = 0                                    -- Sekunden, seit alle Kommandos vorhanden sind

    local function vorhanden()
        if type(XPLMFindCommand) ~= "function" then
            return XPLMFindDataRef(DATAREF) ~= nil
        end
        for _, k in ipairs(KOMMANDOS) do
            if XPLMFindCommand(k) == nil then
                return false
            end
        end
        return true
    end

    function p_b777_xkeypad_nachladen()
        if erledigt then
            return
        end
        sekunden = sekunden + 1
        if vorhanden() then
            gefunden = gefunden + 1
        end
        if gefunden > PUFFER or sekunden >= 90 then
            erledigt = true
            command_once("SRS/X-KeyPad/Reload_Configuration")
            logMsg("P_B777_XKeyPad: X-KeyPad-Konfiguration nach " .. sekunden .. " s nachgeladen")
        end
    end

    do_often("p_b777_xkeypad_nachladen()")
end
