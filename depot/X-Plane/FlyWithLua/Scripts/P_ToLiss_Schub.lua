-- P_ToLiss_Schub.lua
-- Eigene Joystick-Kommandos für die ToLiss-Airbusse (A319 … A346): Schubhebel auf eine Raste fahren.
--
-- Hintergrund: Der ToLiss überschreibt AirbusFBW/throttle_input in jedem Frame mit seiner eigenen
-- Hebelstellung; direktes Setzen wirkt nicht, ebenso wenig sim/engines/throttle_idle/_full.
-- Zuverlässig reagiert er auf sim/engines/throttle_up/_down (so arbeitet auch das Scrollrad).
-- Diese Kommandos fahren den Hebel deshalb schrittweise mit throttle_up/_down zur Raste und lesen
-- die Stellung aus AirbusFBW/throttle_input zurück.
-- Raste-Werte (gemessen am A346): IDLE 0 · TAXI 0,15 · CL 0,695 · FLX/MCT 0,875 · TOGA 1
-- Ein throttle_up/_down bewegt den Hebel um 0,04; ToLiss fängt ihn in der Raste selbst
-- (von unten bei CL 0,70, von oben bei 0,695; FLX/MCT 0,875). Fern vom Ziel fährt das Skript 4 Schritte
-- je Frame, nah am Ziel einen Schritt jedes zweite Frame (der Wert kommt erst ein Frame später zurück)
-- und hält an, sobald das Ziel erreicht oder überschritten ist – sonst pendelt der Hebel um die Raste.
--
-- Belegen: X-Plane → Einstellungen → Joystick → Taste wählen → Kommando „P_Joystick/toliss_throttle_…“.

if XPLMFindDataRef("AirbusFBW/throttle_input") ~= nil then
    local schub = dataref_table("AirbusFBW/throttle_input")
    local ziel = nil          -- angestrebte Hebelstellung, nil = nichts zu tun
    local richtung = 0        -- +1 hoch, -1 runter; Wechsel heißt: Ziel überschritten
    local bilder = 0          -- Schutz: nach 300 Frames (ca. 5 s) aufgeben
    local SCHRITTE_FERN = 4   -- Schritte je Frame, solange das Ziel weiter als NAH entfernt ist
    local NAH = 0.2
    local TOLERANZ = 0.004    -- kleiner als ein Schritt, damit der letzte Schritt in die Raste noch kommt

    function p_toliss_schub_ziel(wert)
        ziel = wert
        bilder = 0
        richtung = (schub[0] < wert) and 1 or -1
    end

    function p_toliss_schub_fahren()
        if ziel == nil then return end
        bilder = bilder + 1
        local ist = schub[0]
        local jetzt = (ist < ziel) and 1 or -1
        if math.abs(ist - ziel) <= TOLERANZ or jetzt ~= richtung or bilder > 300 then
            ziel = nil
            return
        end
        local kommando = (jetzt > 0) and "sim/engines/throttle_up" or "sim/engines/throttle_down"
        if math.abs(ist - ziel) > NAH then
            for _ = 1, SCHRITTE_FERN do
                command_once(kommando)
            end
        elseif bilder % 2 == 0 then
            command_once(kommando)
        end
    end

    do_every_frame("p_toliss_schub_fahren()")

    local rasten = {
        {"idle", "IDLE", 0},
        {"taxi", "TAXI (Rollschub)", 0.15},
        {"cl",   "CL (Climb)", 0.695},
        {"flex", "FLX/MCT", 0.875},
        {"toga", "TOGA", 1},
    }
    for _, r in ipairs(rasten) do
        create_command("P_Joystick/toliss_throttle_" .. r[1],
                       "ToLiss: Schubhebel auf " .. r[2],
                       "p_toliss_schub_ziel(" .. r[3] .. ")", "", "")
    end
end
