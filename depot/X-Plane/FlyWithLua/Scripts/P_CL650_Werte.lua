-- P_CL650_Werte.lua
-- Stellt in der Hot Start Challenger 650 die Livewerte für die Stream-Deck-Profile (P_CL650) als eigene Datarefs bereit.
--
-- Hintergrund: Die CL650 führt die am FCP/DCP gewählten Werte nur auf ihren ARINC-429-Bussen (abus/CL650/ARINC429/…,
-- SI-Einheiten). Diese Datarefs entstehen erst, wenn die Avionik Strom hat. X-KeyPad bricht das Laden der ganzen
-- Konfiguration ab, sobald ein Dataref fehlt – mit den abus-Datarefs direkt in der Konfiguration ginge cold & dark
-- keine einzige Taste. Dieses Skript legt deshalb beim Laden eigene Datarefs P_CL650/… an (immer vorhanden), füllt
-- sie in jedem Frame aus den abus-Datarefs, sobald es diese gibt (Suche jede Sekunde), rechnet in Cockpit-Einheiten um und lädt die
-- X-KeyPad-Konfiguration einmal neu, damit sie die eigenen Datarefs sicher findet.
--
-- Eigene Datarefs (Float; 0, solange die Quelle fehlt bzw. kein Wert gewählt ist):
--   P_CL650/fcp/spd   gewählte Geschwindigkeit kt   (FDCU-1 FCC IAS_SEL, m/s × 1,943844)
--   P_CL650/fcp/hdg   gewählter Steuerkurs °        (FDCU-1 FCC HDG_SEL)
--   P_CL650/fcp/alt   gewählte Höhe ft              (FDCU-1 FCC ALT_SEL, m ÷ 0,3048)
--   P_CL650/fcp/vs    gewählte Steigrate ft/min     (FDCU-1 FCC VS_TGT, m/s × 196,85; im Pitch-Modus 0)
--   P_CL650/dcp1/baro, P_CL650/dcp2/baro   eingestellter Luftdruck hPa (L-PFD-1 EFIS 0 / R-PFD-1 EFIS 1 QNH, Pa ÷ 100)
--   P_CL650/dcp1/range, P_CL650/dcp2/range Kartenbereich NM            (L-PFD-1 EFIS 0 / R-PFD-1 EFIS 1 MAP_RANGE, m ÷ 1852)
-- Einheiten live bestimmt am 2026-11-09 (IAS 119,6 m/s bei Mach 0,585 ↔ TAS 183,6 m/s, ALT_SEL 11887,2 m = 39000 ft,
-- QNH 101325 Pa, MAP_RANGE 370400 m = 200 NM).

if string.find(AIRCRAFT_PATH, "CL650", 1, true) and string.find(AIRCRAFT_FILENAME, "CL650", 1, true) then
    local A = "abus/CL650/ARINC429/"
    -- eigener Dataref → (Quelle, Umrechnungsfaktor)
    local WERTE = {
        {"P_CL650/fcp/spd", A .. "FDCU-1/words/FCC/0/IAS_SEL", 1.943844},
        {"P_CL650/fcp/hdg", A .. "FDCU-1/words/FCC/0/HDG_SEL", 1},
        {"P_CL650/fcp/alt", A .. "FDCU-1/words/FCC/0/ALT_SEL", 1 / 0.3048},
        {"P_CL650/fcp/vs", A .. "FDCU-1/words/FCC/0/VS_TGT", 196.8504},
        {"P_CL650/dcp1/baro", A .. "L-PFD-1/words/EFIS/0/QNH", 0.01},
        {"P_CL650/dcp2/baro", A .. "R-PFD-1/words/EFIS/1/QNH", 0.01},
        {"P_CL650/dcp1/range", A .. "L-PFD-1/words/EFIS/0/MAP_RANGE", 1 / 1852},
        {"P_CL650/dcp2/range", A .. "R-PFD-1/words/EFIS/1/MAP_RANGE", 1 / 1852},
    }
    for _, w in ipairs(WERTE) do
        define_shared_DataRef(w[1], "Float")
        w.ziel = dataref_table(w[1])
    end

    local nachgeladen = false
    local sekunden = 0

    -- jede Sekunde: fehlende Quellen suchen, einmal nachladen
    function p_cl650_suchen()
        for _, w in ipairs(WERTE) do
            if w.quelle == nil and XPLMFindDataRef(w[2]) ~= nil then
                w.quelle = dataref_table(w[2])          -- Bus-Wort ist da (Avionik hat Strom)
            end
        end
        -- einmal nach dem Anlegen nachladen, damit X-KeyPad die eigenen Datarefs findet
        sekunden = sekunden + 1
        if not nachgeladen and sekunden >= 3 then
            nachgeladen = true
            command_once("SRS/X-KeyPad/Reload_Configuration")
            logMsg("P_CL650_Werte: Datarefs angelegt, X-KeyPad-Konfiguration nachgeladen")
        end
    end

    -- jeder Frame: Werte umrechnen und kopieren (Anzeige folgt dem Drehen sofort)
    function p_cl650_werte()
        for _, w in ipairs(WERTE) do
            local v = 0
            if w.quelle ~= nil then
                v = w.quelle[0]
                if v ~= v then v = 0 end                -- NaN: kein Wert gewählt (z. B. VS im Pitch-Modus)
            end
            w.ziel[0] = v * w[3]
        end
    end

    do_often("p_cl650_suchen()")
    do_every_frame("p_cl650_werte()")
end
