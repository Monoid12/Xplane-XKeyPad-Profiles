-- P_A333L_Baro.lua
-- Laminar Airbus A330-300: ein BARO-Regler am Stream Deck Plus stellt Kapitän und Kopilot gemeinsam ein (P_A333L).
--
-- Hintergrund: Ein Plus-Regler kann je Raste nur ein Kommando senden. Der A330 führt aber je Seite eigene Kommandos
-- (sim/instruments/barometer_up … für den Kapitän, barometer_copilot_up … für den Kopiloten, laminar/A333/push|pull/
-- baro/capt_std|fo_std für QNH/STD, laminar/A333/knob/baro/capt_hPa|capt_inHg|fo_… für die Einheit). Dieses Skript
-- legt eigene Kommandos an, die beide Seiten gleich schalten, und einen Anzeige-Dataref für den Regler.
-- Verhalten der A330-Kommandos (xlua A333.switches.lua): push = QNH (holt den gemerkten Wert zurück), pull = STD
-- (merkt den Wert); Drehen ändert bei STD nur die Vorwahl laminar/A333/barometer/…_knob_pos, bei QNH auch den Wert.
--
-- Eigene Kommandos:
--   P_A333L/baro_hoch, P_A333L/baro_runter   beide Seiten eine Raste; bei QNH danach Kopilot = Kapitän
--   P_A333L/baro_std                         Kapitän auf STD → beide QNH, sonst beide STD
--   P_A333L/baro_einheit                     Kapitän in inHg → beide hPa, sonst beide inHg
-- Eigener Dataref (Float): P_A333L/baro/modus   0 = QNH in inHg, 1 = QNH in hPa, 2 = STD (Kapitänsseite)
-- X-KeyPad wird nach dem Anlegen einmal neu geladen, damit die Konfiguration den eigenen Dataref sicher findet.

if string.find(AIRCRAFT_PATH, "Airbus A330-300", 1, true) and AIRCRAFT_FILENAME == "A330.acf" then
    local G = "sim/cockpit2/gauges/actuators/"
    local L = "laminar/A333/"

    local capt_wert = dataref_table(G .. "barometer_setting_in_hg_pilot")
    local fo_wert = dataref_table(G .. "barometer_setting_in_hg_copilot")
    local capt_std = dataref_table(G .. "barometer_setting_is_std_pilot")
    local fo_std = dataref_table(G .. "barometer_setting_is_std_copilot")
    local capt_hpa = dataref_table(L .. "barometer/capt_inHg_hPa_pos")
    local capt_knopf = dataref_table(L .. "barometer/capt_knob_pos")
    local fo_knopf = dataref_table(L .. "barometer/fo_knob_pos")

    define_shared_DataRef("P_A333L/baro/modus", "Float")
    local modus = dataref_table("P_A333L/baro/modus")

    -- Kopilot auf den Wert des Kapitäns setzen (nur wenn beide auf QNH stehen; Vorwahlknopf immer)
    local function angleichen()
        fo_knopf[0] = capt_knopf[0]
        if capt_std[0] == 0 and fo_std[0] == 0 then
            fo_wert[0] = capt_wert[0]
        end
    end

    function p_a333l_baro_drehen(richtung)
        command_once("sim/instruments/barometer_" .. richtung)
        command_once("sim/instruments/barometer_copilot_" .. richtung)
        angleichen()
    end

    function p_a333l_baro_std()
        if capt_std[0] == 1 then                        -- STD → QNH (gemerkter Wert)
            command_once(L .. "push/baro/capt_std")
            command_once(L .. "push/baro/fo_std")
        else                                            -- QNH → STD
            command_once(L .. "pull/baro/capt_std")
            command_once(L .. "pull/baro/fo_std")
        end
        angleichen()
    end

    function p_a333l_baro_einheit()
        if capt_hpa[0] == 0 then
            command_once(L .. "knob/baro/capt_hPa")
            command_once(L .. "knob/baro/fo_hPa")
        else
            command_once(L .. "knob/baro/capt_inHg")
            command_once(L .. "knob/baro/fo_inHg")
        end
    end

    create_command("P_A333L/baro_hoch", "A330: BARO beide Seiten eine Raste hoch", "p_a333l_baro_drehen('up')", "", "")
    create_command("P_A333L/baro_runter", "A330: BARO beide Seiten eine Raste runter", "p_a333l_baro_drehen('down')", "", "")
    create_command("P_A333L/baro_std", "A330: BARO beide Seiten STD/QNH umschalten", "p_a333l_baro_std()", "", "")
    create_command("P_A333L/baro_einheit", "A330: BARO beide Seiten hPa/inHg umschalten", "p_a333l_baro_einheit()", "", "")

    -- jeder Frame: Anzeige-Modus der Kapitänsseite
    function p_a333l_baro_modus()
        if capt_std[0] == 1 then
            modus[0] = 2
        elseif capt_hpa[0] == 1 then
            modus[0] = 1
        else
            modus[0] = 0
        end
    end
    do_every_frame("p_a333l_baro_modus()")

    -- einmal nach dem Anlegen X-KeyPad nachladen
    local sekunden = 0
    function p_a333l_baro_nachladen()
        sekunden = sekunden + 1
        if sekunden == 3 then
            command_once("SRS/X-KeyPad/Reload_Configuration")
            logMsg("P_A333L_Baro: Dataref angelegt, X-KeyPad-Konfiguration nachgeladen")
        end
    end
    do_often("p_a333l_baro_nachladen()")
end
