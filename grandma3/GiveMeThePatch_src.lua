--[[
  GiveMeThePatch — feuille de patch imprimable depuis la grandMA3
  ----------------------------------------------------------------------------
  Lit le patch du show (Fix ID, Ch ID, noms, types, layer ou class, patch,
  nombre de canaux), puis écrit sur la CLÉ USB, dans un dossier GiveMeThePatch
  à sa racine :
    • <show>_<date>_GiveMeThePatch.html  → à ouvrir dans un navigateur sur un ordi,
                                           puis Imprimer / Enregistrer en PDF
    • <show>_<date>_GiveMeThePatch.csv   → le patch au format CSV
    • GiveMeThePatch_diag.txt            → rapport de diagnostic (si CFG.diag = true)
  Sans clé, la feuille est écrite dans le dossier des shows de la MA.

  Auteur : Mart1ver — licence GNU GPL v3 ou ultérieure (voir LICENSE)

  Installation : copier GiveMeThePatch.xml + GiveMeThePatch.lua dans
  gma3_library/datapools/plugins de la clé USB, puis pool Plugins → Import.
--]]

local CFG = {
  titre   = 'Patch lumière',   -- titre par défaut de la feuille
  lieu    = '',                -- sous-titre par défaut
  dossier = 'GiveMeThePatch',  -- dossier créé à la racine de la clé USB
  diag    = false,             -- écrire aussi GiveMeThePatch_diag.txt (mise au point)
}

local TEMPLATE = [==[@@TEMPLATE@@]==]

-------------------------------------------------------------------------------
local function safe(f, ...) if type(f) ~= 'function' then return nil end; local ok, r = pcall(f, ...); if ok then return r end; return nil end
local function str(v) if v == nil then return '' end; return (tostring(v):gsub('^%s+', ''):gsub('%s+$', '')) end
local function log(s) safe(Printf, 'GiveMeThePatch: ' .. tostring(s)) end
local DIAG = {}
local function diag(s) DIAG[#DIAG + 1] = s end

-- lecture d'une propriété : texte affiché par la MA (« 1.001 », nom du fixture type…)
local function prop(h, name)
  local v
  if Enums and Enums.Roles then v = safe(function() return h:Get(name, Enums.Roles.Display) end) end
  if v == nil then v = safe(function() return h:Get(name) end) end
  if v == nil then v = safe(function() return h[name] end) end
  if type(v) == 'userdata' or type(v) == 'table' then v = safe(function() return v.name or v.Name end) end
  v = str(v)
  if v == '-' or v == '(-)' or v == 'None' then v = '' end
  return v
end
local function children(h)
  local list = safe(function() return h:Children() end)
  if type(list) == 'table' then return list end
  list = {}
  local n = safe(function() return h:Count() end) or 0
  for i = 1, n do local c = safe(function() return h:Ptr(i) end); if c then list[#list + 1] = c end end
  return list
end
local function describe(h)
  return 'class=' .. str(safe(function() return h:GetClass() end)) .. ' name=' .. prop(h, 'Name') .. ' children=' .. #children(h)
end

-------------------------------------------------------------------------------
-- lecture du patch
local fixtures = {}

-- nombre de canaux DMX, via le mode DMX du projecteur (vide si la MA ne le donne pas)
local function footprint(h)
  local mode = safe(function() return h.ModeDirect end) or safe(function() return h.Mode end)
  for _, k in ipairs({ 'DMXFootprint', 'Footprint', 'Channels', 'DMXChannels' }) do
    local n = tonumber(prop(h, k):match('^(%d+)') or '')
    if not n and (type(mode) == 'userdata' or type(mode) == 'table') then n = tonumber(prop(mode, k):match('^(%d+)') or '') end
    if n and n > 0 and n <= 512 then return tostring(n) end
  end
  return ''
end

local function walk(h, parentName, depth)
  if depth > 6 then return end
  for _, f in ipairs(children(h)) do
    local fid, cid = prop(f, 'FID'), prop(f, 'CID')
    local subs = children(f)
    local hasFixtureKids = false
    for _, c in ipairs(subs) do if prop(c, 'FID') ~= '' or prop(c, 'CID') ~= '' then hasFixtureKids = true; break end end
    local patch = prop(f, 'Patch')
    if fid ~= '' or cid ~= '' then
      if not (hasFixtureKids and patch == '') then      -- un projecteur « groupe » sans patch n'est qu'un conteneur
        local rec = {
          layer = prop(f, 'Layer'), fid = fid, chid = cid, name = prop(f, 'Name'),
          ftype = prop(f, 'FixtureType'), patch = patch, nch = footprint(f),
        }
        if rec.layer == '' then rec.layer = prop(f, 'Class') end
        if rec.layer == '' then rec.layer = parentName or '' end
        -- appareil multi-instances : une ligne « <Fix ID>.1 », adresse de départ du premier élément
        local nsub = 0
        for _, c in ipairs(subs) do
          if prop(c, 'FID') == '' and prop(c, 'CID') == '' then
            nsub = nsub + 1
            if rec.patch == '' then rec.patch = prop(c, 'Patch') end
          end
        end
        if nsub > 1 and rec.fid ~= '' and not rec.fid:find('.', 1, true) then rec.fid = rec.fid .. '.1' end
        fixtures[#fixtures + 1] = rec
      end
    end
    if hasFixtureKids then walk(f, prop(f, 'Name'), depth + 1) end
  end
end

local function readPatch()
  local P = safe(Patch)
  if not P then diag('Patch() indisponible'); return end
  local stages = safe(function() return P.Stages end)
  diag('Patch : ' .. describe(P) .. ' — Stages : ' .. (stages and describe(stages) or 'nil'))
  for _, st in ipairs(stages and children(stages) or {}) do
    local fx = safe(function() return st.Fixtures end)
    diag('stage ' .. prop(st, 'Name') .. ' : ' .. (fx and describe(fx) or 'pas de Fixtures'))
    if fx then walk(fx, '', 0) end
  end
end

-------------------------------------------------------------------------------
-- sortie
local function csvField(s) return '"' .. str(s):gsub('"', '""') .. '"' end
local function jsString(s)
  s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\r', ''):gsub('\n', '\\n'):gsub('</', '<\\/')
  return '"' .. s .. '"'
end
local function buildCSV()
  local withN = false
  for _, f in ipairs(fixtures) do if f.nch ~= '' then withN = true; break end end
  local lines = { 'Layer;Fix ID;Ch ID;Name;FixtureType;Patch' .. (withN and ';Channels' or '') }
  for _, f in ipairs(fixtures) do
    lines[#lines + 1] = table.concat({ csvField(f.layer), csvField(f.fid), csvField(f.chid), csvField(f.name),
      csvField(f.ftype), csvField(f.patch) }, ';') .. (withN and (';' .. csvField(f.nch)) or '')
  end
  return table.concat(lines, '\n') .. '\n'
end
local function check()
  local addr, dups, unp = {}, {}, {}
  for _, f in ipairs(fixtures) do
    local id = f.fid ~= '' and f.fid or ('Ch ' .. f.chid)
    local u, a = f.patch:match('(%d+)%s*%.%s*(%d+)')
    if not u then unp[#unp + 1] = id
    else
      local k = tonumber(u) .. '.' .. string.format('%03d', tonumber(a))
      if addr[k] then dups[#dups + 1] = k .. ' (' .. addr[k] .. ' / ' .. id .. ')' else addr[k] = id end
    end
  end
  return dups, unp
end

-- destination : clé USB trouvée en testant l'écriture (Windows : D: à Z: ; console : /proc/mounts)
local function writable(dir)
  local f = dir .. '/.givemethepatch_probe'
  local fh = io.open(f, 'wb')
  if fh then fh:close(); pcall(os.remove, f); return true end
  return false
end
local function findUSB()
  local found = {}
  local isWin = str(safe(HostOS)):lower():find('win') ~= nil
  if isWin then
    for c = string.byte('D'), string.byte('Z') do
      local d = string.char(c) .. ':'
      if writable(d .. '/gma3_library') then table.insert(found, 1, d) elseif writable(d) then found[#found + 1] = d end
    end
  else
    local fh = io.open('/proc/mounts', 'r')
    if fh then
      for line in fh:lines() do
        local dev, mp, fs = line:match('^(%S+)%s+(%S+)%s+(%S+)')
        if mp then
          mp = mp:gsub('\\040', ' ')
          local removable = dev:match('^/dev/sd') or mp:match('^/media') or mp:match('^/mnt') or mp:lower():find('usb')
          local fsOk = fs:match('fat') or fs:match('ntfs') or fs == 'fuseblk' or fs == 'exfat'
          if removable and fsOk and mp ~= '/' then
            if writable(mp .. '/gma3_library') then table.insert(found, 1, mp) elseif writable(mp) then found[#found + 1] = mp end
          end
        end
      end
      fh:close()
    end
  end
  diag('clés trouvées : ' .. table.concat(found, ', '))
  return found[1]
end
local function ensureDir(dir)
  if writable(dir) then return true end
  safe(CreateDirectoryRecursive, dir)
  if writable(dir) then return true end
  local win = dir:find('^%a:') ~= nil
  pcall(os.execute, win and ('mkdir "' .. dir:gsub('/', '\\') .. '"') or ('mkdir -p "' .. dir .. '"'))
  return writable(dir)
end
local function writeFile(dir, name, content)
  local path = dir .. '/' .. name
  local fh = io.open(path, 'wb')
  if not fh then return nil end
  fh:write(content); fh:close()
  return path
end
local function pretty(p) return p:find('^%a:') and (p:gsub('/', '\\')) or p end

local ACCENTS = {
  ['à']='a', ['â']='a', ['ä']='a', ['á']='a', ['ç']='c', ['é']='e', ['è']='e', ['ê']='e', ['ë']='e',
  ['î']='i', ['ï']='i', ['ô']='o', ['ö']='o', ['ù']='u', ['û']='u', ['ü']='u', ['ñ']='n', ['œ']='oe', ['æ']='ae',
  ['À']='A', ['Â']='A', ['Ç']='C', ['É']='E', ['È']='E', ['Ê']='E', ['Î']='I', ['Ô']='O', ['Ù']='U', ['Û']='U',
}
local function slug(t)
  t = str(t)
  for k, v in pairs(ACCENTS) do t = t:gsub(k, v) end
  t = t:gsub('[^%w%-]+', '-'):gsub('%-+', '-'):gsub('^%-', ''):gsub('%-$', '')
  return t ~= '' and t:sub(1, 60) or 'patch'
end

-- mémoire des réglages (dans le show)
local function getv(k) local v = safe(GetVar, safe(GlobalVars), k); return v ~= nil and str(v) or nil end
local function setv(k, v) safe(SetVar, safe(GlobalVars), k, v) end

-- barre de progression
local PB
local function pbStart(t) PB = safe(StartProgress, t); if PB then safe(SetProgressRange, PB, 0, 100) end end
local function pbSet(v, t) if PB then safe(SetProgress, PB, math.floor(v)); if t then safe(SetProgressText, PB, t) end end end
local function pbStop() if PB then safe(StopProgress, PB); PB = nil end end

local function box(title, message, inputs, withCancel)
  local cmds = { { value = 1, name = 'OK' } }
  if withCancel then cmds[2] = { value = 0, name = 'Annuler' } end
  local r = safe(MessageBox, { title = title, message = message, commands = cmds, inputs = inputs, autoCloseOnInput = false })
  if type(r) ~= 'table' then return nil end
  return r
end

-------------------------------------------------------------------------------
local function main()
  local show = str(safe(function() return Root().manetsocket.showfile end))
  if show == '' then show = 'show' end
  local usb = findUSB()
  local base = usb and (usb .. '/' .. CFG.dossier)
  local fallback = str(safe(GetPath, Enums and Enums.PathType and Enums.PathType.Showfiles)) .. '/' .. CFG.dossier
  local dest = base or fallback
  local destText = usb and ('Clé USB détectée : la feuille sera écrite dans\n' .. pretty(base))
                       or ('Aucune clé USB détectée : la feuille sera écrite dans\n' .. pretty(fallback) ..
                           '\n(Annuler, brancher la clé, relancer le plugin.)')

  local titre = getv('GIVEMETHEPATCH_TITRE') or CFG.titre
  local lieu = getv('GIVEMETHEPATCH_LIEU') or CFG.lieu
  local lignes = {}
  for i = 1, 4 do lignes[i] = getv('GIVEMETHEPATCH_L' .. i) or '' end

  local r = box('Give The Patch',
    'Feuille de patch imprimable — plugin écrit par Mart1ver\n\n' .. destText ..
    '\n\nTitre, lieu et cartouche (4 lignes) figurent en tête de la feuille.\nIls restent modifiables ensuite dans la page web.',
    { { name = '1 Titre', value = titre }, { name = '2 Lieu', value = lieu },
      { name = '3 Cartouche 1/4', value = lignes[1] }, { name = '4 Cartouche 2/4', value = lignes[2] },
      { name = '5 Cartouche 3/4', value = lignes[3] }, { name = '6 Cartouche 4/4', value = lignes[4] } }, true)
  if r then
    if r.result ~= 1 then return end
    local I = r.inputs or {}
    titre = str(I['1 Titre'] or titre); lieu = str(I['2 Lieu'] or lieu)
    for i = 1, 4 do lignes[i] = str(I[(i + 2) .. ' Cartouche ' .. i .. '/4'] or lignes[i]) end
  else
    -- versions sans MessageBox à champs : questions une par une
    titre = str(safe(TextInput, 'Titre de la feuille', titre) or titre)
    lieu = str(safe(TextInput, 'Lieu / sous-titre', lieu) or lieu)
    for i = 1, 4 do lignes[i] = str(safe(TextInput, 'Cartouche ' .. i .. '/4', lignes[i]) or lignes[i]) end
  end
  setv('GIVEMETHEPATCH_TITRE', titre); setv('GIVEMETHEPATCH_LIEU', lieu)
  for i = 1, 4 do setv('GIVEMETHEPATCH_L' .. i, lignes[i]) end

  pbStart('Give The Patch')
  pbSet(5, 'Lecture du patch…')
  readPatch()
  pbSet(80, 'Préparation de la feuille…')
  if #fixtures == 0 then
    pbStop()
    CFG.diag = true
    if ensureDir(dest) then writeFile(dest, 'GiveMeThePatch_diag.txt', table.concat(DIAG, '\n') .. '\n') end
    box('Give The Patch', 'Aucun projecteur lu.\nUn rapport GiveMeThePatch_diag.txt a été écrit dans\n' .. pretty(dest) .. '\nEnvoie-le à l\'auteur du plugin.')
    return
  end

  local csv = buildCSV()
  local meta = '{"titre":' .. jsString(titre) .. ',"lieu":' .. jsString(lieu) .. ',"lignes":[' ..
    jsString(lignes[1]) .. ',' .. jsString(lignes[2]) .. ',' .. jsString(lignes[3]) .. ',' .. jsString(lignes[4]) ..
    '],"exporte":' .. jsString(os.date('%Y-%m-%dT%H:%M:%S')) .. ',"source":' .. jsString(show .. ' (grandMA3)') .. '}'
  local data = 'window.EMBEDDED_CSV=' .. jsString(csv) .. ';window.EMBEDDED_META=' .. meta .. ';'
  local mark = '/*@@EMBEDDED_DATA@@*/'
  local s, e = TEMPLATE:find(mark, 1, true)
  local html = s and (TEMPLATE:sub(1, s - 1) .. data .. TEMPLATE:sub(e + 1)) or TEMPLATE

  pbSet(90, 'Écriture des fichiers…')
  if not ensureDir(dest) and dest ~= fallback then dest = fallback; ensureDir(dest) end
  local stem = slug(show) .. '_' .. os.date('%Y-%m-%d_%Hh%M') .. '_GiveMeThePatch'
  local pHtml = writeFile(dest, stem .. '.html', html)
  writeFile(dest, stem .. '.csv', csv)
  if CFG.diag then writeFile(dest, 'GiveMeThePatch_diag.txt', table.concat(DIAG, '\n') .. '\n') end
  local dups, unp = check()
  pbSet(100, 'Terminé'); pbStop()

  local msg = #fixtures .. ' projecteurs lus.\n'
  if #dups > 0 then msg = msg .. '\n' .. #dups .. ' adresse(s) de départ en double :\n' .. table.concat(dups, '\n', 1, math.min(#dups, 8)) .. '\n' end
  if #unp > 0 then msg = msg .. '\n' .. #unp .. ' sans patch : ' .. table.concat(unp, ', ', 1, math.min(#unp, 15)) .. '\n' end
  if #dups == 0 and #unp == 0 then msg = msg .. 'Aucune adresse en double, tout est patché.\n' end
  if pHtml then
    msg = msg .. '\nFichiers écrits dans :\n  ' .. pretty(dest) .. '\n  ' .. stem .. '.html\n\nOuvrir ce fichier dans un navigateur sur un ordinateur,\npuis Imprimer / PDF.'
  else
    msg = msg .. '\nÉcriture impossible dans ' .. pretty(dest) .. '.'
  end
  log(msg:gsub('\n', ' | '))
  box('Give The Patch', msg)
end

return function(...)
  local ok, err = pcall(main, ...)
  if not ok then
    pcall(Printf, 'GiveMeThePatch : erreur — ' .. tostring(err))
    pcall(MessageBox, { title = 'Give The Patch', message = 'Erreur :\n' .. tostring(err), commands = { { value = 1, name = 'OK' } } })
  end
end
