--[[
  GiveMeThePatch — feuille de patch imprimable depuis la grandMA2
  ----------------------------------------------------------------------------
  Lit le patch du show (layers, Fix ID, Ch ID, noms, types, univers.adresse),
  vérifie les adresses de départ en double et les projecteurs non patchés,
  puis écrit sur la CLÉ USB, dans un dossier GiveMeThePatch à sa racine.
  La MA ne donne pas aux plugins le disque sélectionné (SelectDrive) : le
  plugin trouve la clé lui-même, sans commande système —
    • onPC (Windows) : lecteurs D: à Z:, de préférence celui qui contient gma2 ;
    • console (Linux) : supports montés listés dans /proc/mounts.
  Sans clé, la feuille est écrite dans l'installation MA (dossier GiveMeThePatch).
  La première fenêtre indique où la feuille sera écrite.
    • <show>_<date>_GiveMeThePatch.html  → à ouvrir dans un navigateur sur un ordi,
                                       puis Imprimer / Enregistrer en PDF
    • <show>_<date>_GiveMeThePatch.csv   → le patch au format CSV (Layer;Fix ID;…)
    • GiveMeThePatch_diag.txt            → rapport de diagnostic (si CFG.diag = true)

  Auteur : Mart1ver — licence GNU GPL v3 ou ultérieure (voir LICENSE)

  Installation : copier GiveMeThePatch.xml + GiveMeThePatch.lua dans gma2/plugins
  de la clé USB (ou du dossier plugins de l'onPC), puis dans le pool Plugins :
  Import → GiveMeThePatch. Lancer le plugin.
--]]

local CFG = {
  titre    = 'Patch lumière',   -- titre par défaut de la feuille
  lieu     = '',                -- sous-titre par défaut ('' pour aucun)
  demander = true,              -- demander titre et lieu au lancement
  maxScan  = 20000,             -- plus grand Fix ID / Ch ID balayé si nécessaire
  dossier  = 'GiveMeThePatch',      -- dossier créé à la racine de la clé USB
  diag     = false,             -- écrire aussi GiveMeThePatch_diag.txt (mise au point)
}

local TEMPLATE = [==[@@TEMPLATE@@]==]

-------------------------------------------------------------------------------
local G = gma
local O = G.show.getobj
local P = G.show.property

local function log(s) s = 'GiveMeThePatch: ' .. tostring(s); pcall(G.echo, s); pcall(G.feedback, s) end
local function safe(f, ...) local ok, r = pcall(f, ...); if ok then return r end; return nil end
local function str(v) if v == nil then return '' end; return (tostring(v):gsub('^%s+', ''):gsub('%s+$', '')) end
local function norm(s) return (str(s):lower():gsub('[^%w]', '')) end

local DIAG = {}
local function diag(s) DIAG[#DIAG + 1] = s end

-- toutes les propriétés d'un objet : { nomNormalisé = valeur }, plus la liste brute
local function props(h)
  local t, raw = {}, {}
  local n = safe(P.amount, h) or 0
  for i = 0, n do
    local name = safe(P.name, h, i)
    if name and name ~= '' and t[norm(name)] == nil then
      local v = safe(P.get, h, i)
      t[norm(name)] = str(v)
      raw[#raw + 1] = name .. ' = ' .. str(v)
    end
  end
  return t, raw
end

local ALIASES = {
  fid   = { 'fixid', 'fixtureid', 'fid', 'fix' },
  chid  = { 'chaid', 'chid', 'channelid', 'channel', 'ch' },
  name  = { 'name', 'label' },
  ftype = { 'fixturetype', 'type', 'ftype' },
  patch = { 'patch', 'dmx', 'address', 'dmxaddress' },
  layer = { 'layer' },
}
local function pick(t, key)
  for _, a in ipairs(ALIASES[key]) do
    -- la MA affiche « - » pour un ID vide et « (-) » pour un patch vide
    if t[a] and t[a] ~= '' and t[a] ~= '-' and t[a] ~= '(-)' then return t[a] end
  end
  return ''
end

-- Le show peut contenir plusieurs copies des layers (ex. copie d'édition du
-- Setup + patch actif). On ne garde qu'un objet que la MA désigne elle-même
-- par son numéro : Fixture <Fix ID>, sinon Channel <Ch ID>. Les objets sans
-- numéro (« [Preset] … » du layer Auto-Created) sont écartés.
local function isLive(h)
  local t = props(h)
  local fid = pick(t, 'fid'):match('^(%d+)')
  if fid and safe(O.handle, 'Fixture ' .. fid) == h then return true end
  local chid = pick(t, 'chid'):match('^(%d+)')
  if chid and safe(O.handle, 'Channel ' .. chid) == h then return true end
  return false
end

local function describe(h)
  if not h then return 'nil' end
  return string.format('class=%s name=%s number=%s children=%s',
    str(safe(O.class, h)), str(safe(O.name, h)), str(safe(O.number, h)), str(safe(O.amount, h)))
end

-- nombre de canaux DMX d'un projecteur (sert à détecter les chevauchements de plages).
-- Lu sur le projecteur, sinon sur son fixture type ; vide si la MA ne le donne pas.
local NCH_KEYS = { 'dmxfootprint', 'footprint', 'channels', 'dmxchannels', 'nochannels',
                   'numberofchannels', 'channelcount', 'nbchannels', 'chans' }
local function nchOf(t)
  for _, k in ipairs(NCH_KEYS) do
    local n = tonumber(str(t[k]):match('^(%d+)'))
    if n and n > 0 and n <= 512 then return tostring(n) end
  end
  for k, v in pairs(t) do
    if k:find('footprint', 1, true) then
      local n = tonumber(str(v):match('(%d+)'))
      if n and n > 0 and n <= 512 then return tostring(n) end
    end
  end
  return nil
end
local typeNch, typeDiag = {}, false
local function typeChannels(ftype)
  local n = str(ftype):match('^(%d+)')
  if not n then return '' end
  if typeNch[n] == nil then
    local v, h = '', nil
    for _, a in ipairs({ 'FixtureType ' .. n, 'Fixturetype ' .. n }) do h = h or safe(O.handle, a) end
    if h then
      local t, raw = props(h)
      v = nchOf(t) or ''
      if not typeDiag then
        typeDiag = true
        diag('fixture type ' .. n .. ' : ' .. describe(h))
        for _, r in ipairs(raw) do diag('   ' .. r) end
      end
    elseif not typeDiag then
      typeDiag = true
      diag('fixture type ' .. n .. ' : introuvable avec O.handle("FixtureType ' .. n .. '")')
    end
    typeNch[n] = v
  end
  return typeNch[n]
end

-------------------------------------------------------------------------------
-- lecture du patch
local fixtures, seen = {}, {}

local function addFixture(h, layerName, fallbackFid, fallbackChid)
  if not h or seen[h] then return end
  seen[h] = true
  local t = props(h)
  local layer = pick(t, 'layer')
  if layer == '' then layer = layerName or '' end
  local rec = {
    layer = layer,
    fid   = pick(t, 'fid'),
    chid  = pick(t, 'chid'),
    name  = pick(t, 'name'),
    ftype = pick(t, 'ftype'),
    patch = pick(t, 'patch'),
  }
  if rec.fid == '' and rec.chid == '' then
    rec.fid, rec.chid = fallbackFid or '', fallbackChid or ''
  end
  if rec.name == '' then rec.name = str(safe(O.label, h) or safe(O.name, h)) end
  -- type au même format que l'export de la MA : « 26 Robin Esprite Mode 1 (26) »
  local tn = rec.ftype:match('^(%d+)%s+.+$')
  if tn and not rec.ftype:match('%(%d+%)%s*$') then rec.ftype = rec.ftype .. ' (' .. tn .. ')' end

  -- appareil multi-instances (plusieurs sous-fixtures) : comme l'export de la MA,
  -- une seule ligne « <Fix ID>.1 », avec l'adresse de départ du projecteur
  local nsub = safe(O.amount, h) or 0
  if nsub > 0 then
    for i = 0, nsub - 1 do
      local c = safe(O.child, h, i)
      if c then
        seen[c] = true
        if rec.patch == '' then rec.patch = pick(props(c), 'patch') end
      end
    end
  end
  if nsub > 1 and rec.fid ~= '' and not rec.fid:find('.', 1, true) then rec.fid = rec.fid .. '.1' end
  rec.nch = nchOf(t) or typeChannels(rec.ftype)
  fixtures[#fixtures + 1] = rec
end

-- barre de progression unique (0..100) ----------------------------------------
local PB, PBV = nil, -1
local function pbStart(title)
  PB = safe(G.gui.progress.start, title); PBV = -1
  if PB then safe(G.gui.progress.setrange, PB, 0, 100) end
end
local function pbSet(v, text)
  if not PB then return end
  v = math.floor(v)
  if v == PBV and not text then return end
  PBV = v
  safe(G.gui.progress.set, PB, v)
  if text and G.gui.progress.settext then safe(G.gui.progress.settext, PB, text) end
end
local function pbStop() if PB then safe(G.gui.progress.stop, PB); PB = nil end end

local function findFirst(maxN)
  pbSet(2, 'Recherche des projecteurs…')
  for i = 1, maxN do
    local h = safe(O.handle, 'Fixture ' .. i)
    if h then return h, 'Fixture ' .. i end
  end
  for i = 1, maxN do
    local h = safe(O.handle, 'Channel ' .. i)
    if h then return h, 'Channel ' .. i end
  end
  return nil
end

-- méthode 1 : remonter d'un projecteur à son layer puis à la liste des layers
local function readByLayers(first)
  local layer = safe(O.parent, first)
  local container = layer and safe(O.parent, layer)
  diag('parent      : ' .. describe(layer))
  diag('grand-parent: ' .. describe(container))
  if not container then return false end
  local cls = safe(O.class, first)
  local nl = safe(O.amount, container) or 0
  if nl < 1 then return false end
  local total, done = 0, 0
  for li = 0, nl - 1 do total = total + (safe(O.amount, safe(O.child, container, li)) or 0) end
  if total < 1 then total = 1 end
  local found, skipped = 0, 0
  for li = 0, nl - 1 do
    local L = safe(O.child, container, li)
    local lname = str(safe(O.label, L)); if lname == '' then lname = str(safe(O.name, L)) end
    pbSet(5 + 75 * done / total, 'Lecture du layer ' .. lname .. '…')
    local nf = safe(O.amount, L) or 0
    for fi = 0, nf - 1 do
      local F = safe(O.child, L, fi)
      if F and safe(O.class, F) == cls then
        if isLive(F) then addFixture(F, lname); found = found + 1
        else skipped = skipped + 1 end
      end
      done = done + 1
      pbSet(5 + 75 * done / total)
    end
  end
  diag(string.format("layers : %d projecteurs gardés, %d copies ou objets sans numéro écartés", found, skipped))
  return found > 0 and seen[first] == true
end

-- méthode 2 : balayage Fixture 1..max puis Channel 1..max
local function readByScan(maxN)
  for k, kw in ipairs({ 'Fixture', 'Channel' }) do
    pbSet(5 + 37.5 * (k - 1), 'Balayage des ' .. kw .. ' 1 à ' .. maxN .. '…')
    for i = 1, maxN do
      local h = safe(O.handle, kw .. ' ' .. i)
      if h and not seen[h] then
        local L = safe(O.parent, h)
        local lname = L and str(safe(O.label, L)) or ''
        if lname == '' and L then lname = str(safe(O.name, L)) end
        addFixture(h, lname, kw == 'Fixture' and tostring(i) or '', kw == 'Channel' and tostring(i) or '')
      end
      if i % 200 == 0 then pbSet(5 + 37.5 * (k - 1) + 37.5 * i / maxN) end
    end
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
  -- colonne Channels seulement si la MA a donné le nombre de canaux d'au moins un projecteur
  local withN = false
  for _, f in ipairs(fixtures) do if (f.nch or '') ~= '' then withN = true; break end end
  local lines = { 'Layer;Fix ID;Ch ID;Name;FixtureType;Patch' .. (withN and ';Channels' or '') }
  for _, f in ipairs(fixtures) do
    lines[#lines + 1] = table.concat({ csvField(f.layer), csvField(f.fid), csvField(f.chid),
      csvField(f.name), csvField(f.ftype), csvField(f.patch) }, ';') .. (withN and (';' .. csvField(f.nch or '')) or '')
  end
  return table.concat(lines, '\n') .. '\n'
end

local function check()
  local addr, dups, unp = {}, {}, {}
  for _, f in ipairs(fixtures) do
    local id = f.fid ~= '' and f.fid or ('Ch ' .. f.chid)
    local u, a = f.patch:match('(%d+)%s*%.%s*(%d+)')
    if not u then
      local n = tonumber(f.patch:match('^%s*(%d+)%s*$') or '')
      if n and n > 0 then u, a = math.floor((n - 1) / 512) + 1, (n - 1) % 512 + 1 end
    end
    if not u then unp[#unp + 1] = id
    else
      local k = tonumber(u) .. '.' .. string.format('%03d', tonumber(a))
      if addr[k] then dups[#dups + 1] = k .. ' (' .. addr[k] .. ' / ' .. id .. ')' else addr[k] = id end
    end
  end
  return dups, unp
end

-- Destination ---------------------------------------------------------------
-- La MA ne change pas de disque quand un plugin lance SelectDrive : le plugin
-- écrit donc sur le disque déjà sélectionné dans la MA ($PATH au lancement),
-- ou sur un chemin tapé à la main (onPC : lettre de la clé, ex. E:).
local function getPath() return (str(safe(G.show.getvar, 'PATH')):gsub('\\', '/')) end
local function writable(dir)
  local f = dir .. '/.givemethepatch_probe'
  local fh = io.open(f, 'wb')
  if fh then fh:close(); pcall(os.remove, f); return true end
  return false
end
-- Clé USB : la MA n'expose pas le disque sélectionné ($PATH reste sur
-- l'installation). On cherche donc la clé directement, en lisant les fichiers.
local function findUSB(base)
  local isWin = str(safe(G.show.getvar, 'OS')):upper():find('WIN') ~= nil or base:match('^%a:') ~= nil
  local withG, other = {}, {}
  if isWin then
    local sys = (base:match('^(%a):') or 'C'):upper()
    for c = string.byte('D'), string.byte('Z') do
      local L = string.char(c)
      if L ~= sys then
        local d = L .. ':'
        if writable(d .. '/gma2') then withG[#withG + 1] = d
        elseif writable(d) then other[#other + 1] = d end
      end
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
          if removable and fsOk and mp ~= '/' and base:sub(1, #mp + 1) ~= mp .. '/' then
            if writable(mp .. '/gma2') then withG[#withG + 1] = mp
            elseif writable(mp) then other[#other + 1] = mp end
          end
        end
      end
      fh:close()
    end
  end
  diag('clés trouvées (avec gma2) : ' .. table.concat(withG, ', ') .. ' | autres : ' .. table.concat(other, ', '))
  return withG[1] or other[1]
end

-- racine du disque : on enlève un « /gma2 » final ( E:/gma2 → E: )
local function driveRoot(p)
  p = (p:gsub('/+$', ''))
  local r = (p:gsub('/[gG][mM][aA]2$', ''))
  if r == '' then r = '/' end
  return r
end

local function ensureDir(dir)
  local probe = io.open(dir .. '/.givemethepatch', 'wb')
  if probe then probe:close(); pcall(os.remove, dir .. '/.givemethepatch'); return true end
  local win = dir:find('^%a:') ~= nil
  local cmd = win and ('mkdir "' .. dir:gsub('/', '\\') .. '"') or ('mkdir -p "' .. dir .. '"')
  pcall(os.execute, cmd)
  probe = io.open(dir .. '/.givemethepatch', 'wb')
  if probe then probe:close(); pcall(os.remove, dir .. '/.givemethepatch'); return true end
  return false
end

local function prettyPath(p)
  if p:find('^%a:') then return (p:gsub('/', '\\')) end
  return p
end

local function writeFile(dirs, name, content)
  for _, d in ipairs(dirs) do
    local path = d .. '/' .. name
    local fh = io.open(path, 'wb')
    if fh then fh:write(content); fh:close(); return path end
  end
  return nil
end

-- texte → nom de fichier sûr : accents retirés, espaces et signes → « - »
local ACCENTS = {
  ['à']='a', ['â']='a', ['ä']='a', ['á']='a', ['ã']='a', ['å']='a', ['ç']='c',
  ['é']='e', ['è']='e', ['ê']='e', ['ë']='e', ['î']='i', ['ï']='i', ['í']='i', ['ì']='i',
  ['ô']='o', ['ö']='o', ['ó']='o', ['ò']='o', ['õ']='o', ['ù']='u', ['û']='u', ['ü']='u', ['ú']='u',
  ['ÿ']='y', ['ñ']='n', ['œ']='oe', ['æ']='ae',
  ['À']='A', ['Â']='A', ['Ä']='A', ['Á']='A', ['Ç']='C', ['É']='E', ['È']='E', ['Ê']='E', ['Ë']='E',
  ['Î']='I', ['Ï']='I', ['Ô']='O', ['Ö']='O', ['Ù']='U', ['Û']='U', ['Ü']='U', ['Ñ']='N', ['Œ']='OE', ['Æ']='AE',
}
local function slug(t)
  t = str(t)
  for k, v in pairs(ACCENTS) do t = t:gsub(k, v) end
  t = t:gsub('[^%w%-]+', '-'):gsub('%-+', '-'):gsub('^%-', ''):gsub('%-$', '')
  if t == '' then t = 'patch' end
  return t:sub(1, 60)
end

-------------------------------------------------------------------------------
local function main()
  -- titre et lieu : derniers saisis (mémorisés dans le show), sinon valeurs de CFG
  local function remember(k, v)
    if G.show.setvar then safe(G.show.setvar, k, v)
    else safe(G.cmd, 'SetVar $' .. k .. ' = "' .. v:gsub('"', '') .. '"') end
  end
  local titre = str(safe(G.show.getvar, 'GIVEMETHEPATCH_TITRE')); if titre == '' then titre = CFG.titre end
  local lieu = safe(G.show.getvar, 'GIVEMETHEPATCH_LIEU'); lieu = (lieu == nil) and CFG.lieu or str(lieu)
  local lignes = {}
  for i = 1, 4 do lignes[i] = str(safe(G.show.getvar, 'GIVEMETHEPATCH_L' .. i)) end
  -- fenêtre d'explication : confirm (OK / Annuler) si disponible, sinon simple message
  local function notice(title, text)
    if G.gui.confirm then
      local ok = safe(G.gui.confirm, title, text)
      return ok ~= false
    end
    safe(G.gui.msgbox, title, text)
    return true
  end
  -- valeurs actuelles, pour les rappeler dans les consignes
  local function shown(v) return v ~= '' and v or '(vide)' end

  local base0 = getPath()
  local usbRoot = findUSB(base0)
  local selRoot = usbRoot or base0
  log('destination : ' .. selRoot .. ' (' .. (usbRoot and 'clé USB' or 'aucune clé, installation MA') .. ')')
  local destText = usbRoot
    and ('La feuille sera écrite sur la clé USB :\n' .. prettyPath(selRoot .. '/' .. CFG.dossier))
    or ('Aucune clé USB détectée : la feuille sera écrite dans\n' ..
        prettyPath(selRoot .. '/' .. CFG.dossier) .. '\n\n' ..
        'Pour l\'écrire sur une clé : Annuler, brancher la clé,\npuis relancer le plugin.')

  if CFG.demander then
    if not notice('GiveMeThePatch',
      'GiveMeThePatch — feuille de patch imprimable\n' ..
      'Plugin écrit par Mart1ver\n\n' ..
      'Vous allez saisir, dans l\'ordre :\n' ..
      '1. le titre de la feuille\n' ..
      '2. le lieu, affiché sous le titre\n' ..
      '3. les 4 lignes du cartouche, en texte libre\n' ..
      '(régie, version, date du spectacle…)\n\n' ..
      'Chaque fenêtre reprend la valeur précédente.\n' ..
      'Valider pour la garder, effacer pour laisser vide.\n\n' ..
      destText) then
      return
    end
    local t = safe(G.textinput, 'Titre', titre); if t == nil then return end
    titre = str(t) ~= '' and str(t) or titre
    local l = safe(G.textinput, 'Lieu', lieu); if l ~= nil then lieu = str(l) end
    for i = 1, 4 do
      local v = safe(G.textinput, 'Cartouche ' .. i .. '/4', lignes[i])
      if v ~= nil then lignes[i] = str(v) end
    end
    remember('GIVEMETHEPATCH_TITRE', titre)
    remember('GIVEMETHEPATCH_LIEU', lieu)
    for i = 1, 4 do remember('GIVEMETHEPATCH_L' .. i, lignes[i]) end
  end

  local base = str(safe(G.show.getvar, 'PATH'))
  local show = str(safe(G.show.getvar, 'SHOWFILE')); if show == '' then show = 'show' end
  diag('GiveMeThePatch diag — ' .. str(safe(os.date, '%Y-%m-%d %H:%M:%S')))
  diag('VERSION : ' .. str(safe(G.show.getvar, 'VERSION')) .. ' — PATH : ' .. base .. ' — SHOWFILE : ' .. show)

  pbStart('GiveMeThePatch')
  local first, how = findFirst(CFG.maxScan)
  if not first then
    log('aucun Fixture ni Channel trouvé (1..' .. CFG.maxScan .. ')')
    diag('Aucun objet trouvé avec O.handle("Fixture N") / ("Channel N").')
  else
    local _, raw = props(first)
    diag('premier objet : ' .. how .. ' — ' .. describe(first))
    for _, r in ipairs(raw) do diag('   ' .. r) end
    local c0 = safe(O.child, first, 0)
    if c0 then
      local _, rc = props(c0)
      diag('   premier enfant : ' .. describe(c0))
      for _, r in ipairs(rc) do diag('      ' .. r) end
    end
    local ok = safe(readByLayers, first)
    diag('méthode layers : ' .. (ok and ('OK, ' .. #fixtures .. ' projecteurs') or 'échec'))
    if not ok then
      fixtures, seen = {}, {}
      readByScan(CFG.maxScan)
      diag('méthode balayage : ' .. #fixtures .. ' projecteurs')
    end
  end

  -- destination : dossier GiveMeThePatch sur le disque choisi
  pbSet(82, 'Accès au disque…')
  local dirs, destErr = {}, nil
  local root = selRoot
  local target = root .. '/' .. CFG.dossier
  if ensureDir(target) then dirs[#dirs + 1] = target end
  for _, d in ipairs({ root, base .. '/reports', base .. '/importexport', base }) do dirs[#dirs + 1] = d end
  diag('destination : ' .. target)

  -- nom des fichiers : <show>_<date>_GiveMeThePatch (nom du show lu sur la console, sans accents ni espaces)
  local stamp = str(safe(os.date, '%Y-%m-%d_%Hh%M')); if stamp == '' then stamp = 'export' end
  local stem = slug(show) .. '_' .. stamp .. '_GiveMeThePatch'

  if CFG.diag then
    diag(''); diag('5 premiers projecteurs lus :')
    for i = 1, math.min(5, #fixtures) do
      local f = fixtures[i]
      diag(string.format('   layer=%s fid=%s chid=%s name=%s type=%s patch=%s', f.layer, f.fid, f.chid, f.name, f.ftype, f.patch))
    end
    local p = writeFile(dirs, 'GiveMeThePatch_diag.txt', table.concat(DIAG, '\n') .. '\n')
    if p then log('diagnostic : ' .. p) end
  end

  if #fixtures == 0 then
    pbStop()
    safe(G.gui.msgbox, 'GiveMeThePatch', 'Aucun projecteur lu.\nPasser CFG.diag à true en tête du fichier GiveMeThePatch.lua\npour obtenir un rapport GiveMeThePatch_diag.txt.')
    return
  end

  pbSet(88, 'Préparation de la feuille…')
  local csv = buildCSV()
  local meta = '{"titre":' .. jsString(titre) .. ',"lieu":' .. jsString(lieu) ..
               ',"lignes":[' .. jsString(lignes[1]) .. ',' .. jsString(lignes[2]) .. ',' .. jsString(lignes[3]) .. ',' .. jsString(lignes[4]) .. '],"exporte":' .. jsString(str(safe(os.date, '%Y-%m-%dT%H:%M:%S'))) .. ',"source":' .. jsString(show .. ' (grandMA2)') .. ',"label":"Patch lu sur la console"}'
  local data = 'window.EMBEDDED_CSV=' .. jsString(csv) .. ';window.EMBEDDED_META=' .. meta .. ';'
  local mark = '/*@@EMBEDDED_DATA@@*/'
  local s, e = TEMPLATE:find(mark, 1, true)
  local html = s and (TEMPLATE:sub(1, s - 1) .. data .. TEMPLATE:sub(e + 1)) or TEMPLATE

  pbSet(92, 'Écriture des fichiers…')
  local pHtml = writeFile(dirs, stem .. '.html', html)
  pbSet(97)
  local pCsv  = writeFile(dirs, stem .. '.csv', csv)

  pbSet(99, 'Vérification du patch…')
  local dups, unp = check()
  pbSet(100, 'Terminé')
  pbStop()
  local msg = #fixtures .. ' projecteurs lus.\n'
  if #dups > 0 then msg = msg .. '\n' .. #dups .. ' adresse(s) de départ en double :\n' .. table.concat(dups, '\n', 1, math.min(#dups, 8)) .. (#dups > 8 and '\n…' or '') .. '\n' end
  if #unp > 0 then msg = msg .. '\n' .. #unp .. ' sans patch : ' .. table.concat(unp, ', ', 1, math.min(#unp, 15)) .. (#unp > 15 and '…' or '') .. '\n' end
  if #dups == 0 and #unp == 0 then msg = msg .. 'Aucune adresse en double, tout est patché.\n' end
  if pHtml then
    local dir = prettyPath(pHtml:match('^(.*)/[^/]+$') or pHtml)
    local file = pHtml:match('([^/]+)$')
    msg = msg .. (destErr and ('\n⚠ ' .. destErr .. '\n') or '') ..
          '\nFichiers écrits dans :\n  ' .. dir .. '\n  ' .. file ..
          '\n\nOuvrir ce fichier dans un navigateur sur un ordinateur,\npuis Imprimer / PDF.'
  else msg = msg .. '\nImpossible d\'écrire le fichier HTML (clé protégée en écriture ?).' end
  log(msg:gsub('\n', ' | '))
  if pCsv then log('CSV : ' .. pCsv) end
  safe(G.gui.msgbox, 'GiveMeThePatch', msg)
end

-- point d'entrée : la barre de progression est toujours refermée, même en cas d'erreur
return function()
  local ok, err = pcall(main)
  pbStop()
  if not ok then
    log('erreur : ' .. tostring(err))
    safe(G.gui.msgbox, 'GiveMeThePatch', 'Erreur pendant la génération :\n' .. tostring(err))
  end
end
