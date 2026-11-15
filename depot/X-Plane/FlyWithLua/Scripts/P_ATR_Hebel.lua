-- P_ATR_Hebel.lua
-- Eigene Joystick-Kommandos für die DWSim ATR 72-600: beide Condition Lever eine Raste hoch bzw. runter.
--
-- Hintergrund: Die ATR bietet für die Condition Lever kein Kommando; sim/engines/prop_up/_down wirkt nicht.
-- Die Hebelstellung steht in DWSim/ATR_Series/datarefs/throttleQuadrant/fuelConditionLever/<left|right>/rotation
-- (Grad, beschreibbar); die Triebwerkslogik übernimmt den geschriebenen Wert (audio/eng/<n>/cla folgt,
-- audio/eng/<n>/cl_detent meldet die Raste).
-- Rasten (live gemessen 2026-10-28): FUEL S.O. 0 · FTR 25 · AUTO 42,5 (erkannt 41,5–43,5) · 100% OVRD 60
--
-- Belegen: X-Plane → Einstellungen → Joystick → Taste wählen → Kommando „P_Joystick/atr_cl_hoch“ bzw. „…_runter“.

if XPLMFindDataRef("DWSim/ATR_Series/datarefs/throttleQuadrant/fuelConditionLever/left/rotation") ~= nil then
    local links = dataref_table("DWSim/ATR_Series/datarefs/throttleQuadrant/fuelConditionLever/left/rotation")
    local rechts = dataref_table("DWSim/ATR_Series/datarefs/throttleQuadrant/fuelConditionLever/right/rotation")
    local RASTEN = {0, 25, 42.5, 60}
    local TOLERANZ = 1        -- so nah an einer Raste gilt der Hebel als in dieser Raste

    -- richtung +1: nächste Raste über der jetzigen Stellung, -1: nächste darunter; am Ende bleibt er stehen
    function p_atr_cl_raste(richtung)
        local ist = links[0]
        local ziel = nil
        if richtung > 0 then
            for i = 1, #RASTEN do
                if RASTEN[i] > ist + TOLERANZ then ziel = RASTEN[i]; break end
            end
        else
            for i = #RASTEN, 1, -1 do
                if RASTEN[i] < ist - TOLERANZ then ziel = RASTEN[i]; break end
            end
        end
        if ziel ~= nil then
            links[0] = ziel
            rechts[0] = ziel
        end
    end

    create_command("P_Joystick/atr_cl_hoch", "ATR: beide Condition Lever eine Raste hoch",
                   "p_atr_cl_raste(1)", "", "")
    create_command("P_Joystick/atr_cl_runter", "ATR: beide Condition Lever eine Raste runter",
                   "p_atr_cl_raste(-1)", "", "")

    -- Parkbremse: sim/flight_controls/park_brake_set/_release ändern nur X-Planes Wert, der ATR-Hebel bleibt stehen.
    -- Den Hebel bewegt nur DWSim/…/parkingBrake/lever/toggle, reihum durch drei Stellungen
    -- (throttleQuadrant/parkingBrake/movement: 1 PARK → 0 AUS → 0,5 → 1, jeweils kurz animiert).
    -- Die Kommandos schalten deshalb so oft um, bis die gewünschte Stellung erreicht ist.
    local bremse = dataref_table("DWSim/ATR_Series/datarefs/throttleQuadrant/parkingBrake/movement")
    local bremse_ziel = nil   -- 1 PARK, 0 AUS, nil = nichts zu tun
    local zeit = dataref_table("sim/time/total_running_time_sec")
    local WARTEN = 2          -- Sekunden nach jedem Umschalten (Animation; ein Umschalten mitten darin kehrt sie um)
    local naechster = 0       -- Laufzeit, ab der wieder nachgesehen wird
    local versuche = 0        -- Schutz: höchstens 3 Umschaltungen (einmal reihum)

    function p_atr_bremse(ziel)
        bremse_ziel = ziel
        naechster = 0
        versuche = 0
    end

    function p_atr_bremse_fahren()
        if bremse_ziel == nil then return end
        if zeit[0] < naechster then return end
        if math.abs(bremse[0] - bremse_ziel) < 0.01 or versuche >= 3 then
            bremse_ziel = nil
            return
        end
        command_once("DWSim/ATR_Series/commands/throttleQuadrant/parkingBrake/lever/toggle")
        versuche = versuche + 1
        naechster = zeit[0] + WARTEN
    end

    do_every_frame("p_atr_bremse_fahren()")

    create_command("P_Joystick/atr_parkbremse_an", "ATR: Parkbremse auf PARK", "p_atr_bremse(1)", "", "")
    create_command("P_Joystick/atr_parkbremse_aus", "ATR: Parkbremse lösen", "p_atr_bremse(0)", "", "")
end
