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
--
-- 757/767 zusätzlich: ALT-Regler am Stream Deck Plus mit 100- oder 1000-ft-Schritten.
-- Das MCP kennt nur 1-sim/comm/AP/altUP und altDN (je 100 ft); der Wert 1-sim/AP/altSetting ist nicht beschreibbar.
-- Eigene Kommandos:
--   P_B6/alt_hoch, P_B6/alt_runter   eine Raste: 100 ft, im 1000er-Modus bis zum nächsten vollen Tausender
--   P_B6/alt_schritt                 schaltet zwischen 100 und 1000 ft um (Tippen aufs Regler-Display)
-- Eigener Dataref (Float): P_B6/alt/schritt   0 = 100 ft, 1 = 1000 ft
-- Die nötigen altUP/altDN werden gesammelt und einzeln je Frame gesendet (ein Kommando je Frame wertet das MCP sicher aus).

local KOMMANDOS, DATAREF, FF76 = nil, nil, false
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
    FF76 = true
end

if FF76 then
    define_shared_DataRef("P_B6/alt/schritt", "Float")
    local schritt = dataref_table("P_B6/alt/schritt")
    local alt_wert = nil                                  -- 1-sim/AP/altSetting, erst nach dem Anlegen durch FF da
    local offen = 0                                       -- noch zu sendende Rasten: + altUP, − altDN

    function p_b6_alt_drehen(richtung)
        if schritt[0] < 0.5 then
            offen = offen + richtung
            return
        end
        if alt_wert == nil and XPLMFindDataRef("1-sim/AP/altSetting") ~= nil then
            alt_wert = dataref_table("1-sim/AP/altSetting")
        end
        if alt_wert == nil then
            offen = offen + 10 * richtung
            return
        end
        local ziel = alt_wert[0] + 100 * offen            -- Wert nach den schon gesammelten Rasten
        local neu
        if richtung > 0 then
            neu = (math.floor(ziel / 1000 + 0.001) + 1) * 1000
        else
            neu = (math.ceil(ziel / 1000 - 0.001) - 1) * 1000
        end
        offen = offen + math.floor((neu - ziel) / 100 + 0.5)
    end

    function p_b6_alt_schritt()
        if schritt[0] < 0.5 then
            schritt[0] = 1
        else
            schritt[0] = 0
        end
    end

    function p_b6_alt_senden()
        if offen > 0 then
            command_once("1-sim/comm/AP/altUP")
            offen = offen - 1
        elseif offen < 0 then
            command_once("1-sim/comm/AP/altDN")
            offen = offen + 1
        end
    end

    create_command("P_B6/alt_hoch", "FF 757/767: MCP ALT eine Raste hoch (100/1000 ft)", "p_b6_alt_drehen(1)", "", "")
    create_command("P_B6/alt_runter", "FF 757/767: MCP ALT eine Raste runter (100/1000 ft)", "p_b6_alt_drehen(-1)", "", "")
    create_command("P_B6/alt_schritt", "FF 757/767: ALT-Schritt 100/1000 ft umschalten", "p_b6_alt_schritt()", "", "")
    do_every_frame("p_b6_alt_senden()")
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
