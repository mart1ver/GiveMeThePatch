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

local TEMPLATE = [==[<!doctype html>
<!-- Give Me The Patch — Mart1ver — GNU GPL v3 ou ultérieure — https://www.gnu.org/licenses/gpl-3.0.html -->
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Give Me The Patch</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600;700&family=IBM+Plex+Sans+Condensed:wght@400;500;600;700&display=swap" rel="stylesheet">
<script src="https://cdnjs.cloudflare.com/ajax/libs/PapaParse/5.4.1/papaparse.min.js"></script>
<style>
/* ───────────── interface ───────────── */
:root {
  --bg: #e9e9e6; --panel: #fbfbf9; --ink: #16161a; --muted: #6b6b70; --line: #d8d8d3;
  --accent: #e8a317; --accent-ink: #1a1405; --warn-bg: #fff3c4; --ok: #2f7d4a; --err: #b3261e;
  --drop: #f3f3ef;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #1b1b1e; --panel: #232327; --ink: #ececec; --muted: #9a9aa0; --line: #38383e;
    --accent: #f0b432; --accent-ink: #1a1405; --warn-bg: #4a3d12; --ok: #6cc28a; --err: #ff8a80;
    --drop: #2a2a2f;
  }
}
:root[data-theme="dark"] {
  --bg: #1b1b1e; --panel: #232327; --ink: #ececec; --muted: #9a9aa0; --line: #38383e;
  --accent: #f0b432; --accent-ink: #1a1405; --warn-bg: #4a3d12; --ok: #6cc28a; --err: #ff8a80;
  --drop: #2a2a2f;
}
* { box-sizing: border-box; }
html, body { margin: 0; height: 100%; }
body { background: var(--bg); color: var(--ink); font: 14px/1.45 "IBM Plex Sans", system-ui, sans-serif; }
.app { display: grid; grid-template-columns: 340px 1fr; height: 100vh; }
aside { background: var(--panel); border-right: 1px solid var(--line); overflow-y: auto; padding: 22px 22px 28px; display: flex; flex-direction: column; gap: 20px; }
.brand { display: flex; align-items: center; gap: 12px; }
.brand .dot { width: 12px; height: 12px; border-radius: 50%; background: var(--accent); flex: none; margin-top: 5px; align-self: flex-start; }
.brand h1 { font-size: 15px; font-weight: 600; margin: 0; letter-spacing: 0; }
.brandlink { display: flex; align-items: center; gap: 12px; flex: 1; min-width: 0; color: inherit; text-decoration: none; }
.brandlink:hover h1 { text-decoration: underline; }
.dl { display: flex; gap: 8px; }
.dl a { flex: 1; text-align: center; text-decoration: none; }
.brand p { margin: 0; font-size: 12px; color: var(--muted); }
select.lang { margin-inline-start: auto; flex: none; align-self: flex-start; font: inherit; font-size: 12px; color: var(--ink); background: var(--bg); border: 1px solid var(--line); border-radius: 8px; padding: 4px 6px; max-width: 8.5em; }
.drop { border: 1.5px dashed var(--line); border-radius: 12px; background: var(--drop); padding: 22px 16px; text-align: center; cursor: pointer; transition: border-color .15s, background .15s; }
.drop:hover, .drop.over { border-color: var(--accent); }
.drop b { display: block; font-size: 14px; margin-bottom: 4px; }
.drop span { font-size: 12px; color: var(--muted); }
.drop.loaded { border-style: solid; text-align: left; padding: 14px 16px; }
.drop .fname { font-weight: 600; word-break: break-all; }
fieldset { border: 0; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 12px; }
legend { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: var(--muted); font-weight: 600; margin-bottom: 10px; padding: 0; }
label.f, div.f { display: flex; flex-direction: column; gap: 5px; font-size: 12.5px; color: var(--muted); }
input[type=text], textarea { font: inherit; color: var(--ink); background: var(--bg); border: 1px solid var(--line); border-radius: 8px; padding: 8px 10px; }
textarea { resize: vertical; min-height: 64px; line-height: 1.4; }
select.lbsel, .lbcust input { font: inherit; color: var(--ink); background: var(--bg); border: 1px solid var(--line); border-radius: 8px; padding: 7px 8px; width: 100%; min-width: 0; }
.lbcust { display: grid; grid-template-columns: 1fr 1fr; gap: 6px 8px; }
.lbcust label { display: flex; flex-direction: column; gap: 2px; font-size: 11.5px; color: var(--muted); }
.lbcust input { padding: 5px 7px; }
input[type=text]:focus, textarea:focus { outline: 2px solid var(--accent); outline-offset: -1px; }
.seg { display: grid; grid-template-columns: 1fr 1fr; background: var(--bg); border: 1px solid var(--line); border-radius: 9px; padding: 3px; gap: 3px; }
.seg button { font: inherit; font-size: 13px; border: 0; border-radius: 6px; padding: 7px; background: transparent; color: var(--ink); cursor: pointer; }
.seg button.on { background: var(--panel); box-shadow: 0 1px 3px rgba(0,0,0,.15); font-weight: 600; }
.chk { display: flex; align-items: center; gap: 9px; font-size: 13.5px; cursor: pointer; }
.chk input { accent-color: var(--accent); width: 16px; height: 16px; }
.hideAdd { display: flex; gap: 6px; }
.hideAdd input { flex: 1; min-width: 0; }
.hideAdd button, .chipx, .linkbtn { font: inherit; cursor: pointer; }
.hideAdd button { border: 1px solid var(--line); background: var(--bg); color: var(--ink); border-radius: 8px; padding: 0 12px; font-size: 13px; }
.chips { display: flex; flex-wrap: wrap; gap: 6px; }
.chip { display: inline-flex; align-items: center; gap: 6px; background: var(--bg); border: 1px solid var(--line); border-radius: 999px; padding: 3px 4px 3px 10px; font-size: 12px; max-width: 100%; }
.chip span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.chipx { border: 0; background: transparent; color: var(--muted); font-size: 14px; line-height: 1; padding: 2px 5px; border-radius: 999px; }
.chipx:hover { background: var(--line); color: var(--ink); }
.linkbtn { border: 0; background: none; color: var(--muted); text-decoration: underline; padding: 0; font-size: 12px; align-self: flex-start; }
.hint2 { font-size: 11.5px; color: var(--muted); margin: 0; }
@media screen {
  #pages .sheet tbody tr[data-k] { cursor: pointer; }
  #pages .sheet tbody tr[data-k]:hover td { background: #ffe9a8 !important; text-decoration: line-through; }
}
.stats { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.stat { background: var(--bg); border-radius: 9px; padding: 9px 11px; }
.stat b { display: block; font-size: 20px; line-height: 1.1; font-variant-numeric: tabular-nums; }
.stat span { font-size: 11px; color: var(--muted); text-transform: uppercase; letter-spacing: .6px; }
.alerts { display: flex; flex-direction: column; gap: 8px; font-size: 12.5px; }
.alert { border-radius: 9px; padding: 9px 11px; background: var(--warn-bg); }
.alert.ok { background: transparent; border: 1px solid var(--line); color: var(--ok); }
.alert.err { background: transparent; border: 1px solid var(--err); color: var(--err); }
.btn { font: inherit; font-weight: 600; font-size: 14.5px; border: 0; border-radius: 10px; padding: 12px 14px; background: var(--accent); color: var(--accent-ink); cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 8px; }
.btn:disabled { opacity: .4; cursor: not-allowed; }
.btn.ghost { background: transparent; border: 1px solid var(--line); color: var(--ink); font-weight: 500; font-size: 13px; padding: 9px 12px; }
.hint { font-size: 11.5px; color: var(--muted); margin: -8px 0 0; }
.spacer { flex: 1; }
.foot { font-size: 11px; color: var(--muted); }
main { overflow: auto; position: relative; }
.tabs { display: inline-grid; grid-auto-flow: column; background: var(--panel); border: 1px solid var(--line); border-radius: 9px; padding: 3px; gap: 3px; }
.tabs button { font: inherit; font-size: 13px; border: 0; border-radius: 6px; padding: 6px 12px; background: transparent; color: var(--ink); cursor: pointer; }
.tabs button.on { background: var(--accent); color: var(--accent-ink); font-weight: 600; }
.tb-left { display: flex; align-items: center; gap: 14px; min-width: 0; }
.tb-left #pageInfo { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
body[data-tab="patch"] aside [data-tab]:not([data-tab~="patch"]),
body[data-tab="labels"] aside [data-tab]:not([data-tab~="labels"]),
body[data-tab="diff"] aside [data-tab]:not([data-tab~="diff"]) { display: none !important; }
.tabs button { white-space: nowrap; }
/* plan d'occupation des univers : une barre de 512 canaux par univers */
.umap { height: 17mm; display: flex; flex-direction: column; }
.umap .uh { display: flex; gap: 3mm; align-items: baseline; height: 5mm; font-size: 7.6pt; white-space: nowrap; }
.umap .uh b { font-size: 9pt; }
.umap .uh .free { color: #555; overflow: hidden; text-overflow: ellipsis; flex: 1; min-width: 0; }
.umap .bar { position: relative; height: 8mm; background: #f1f1f1; border: .4pt solid #999; direction: ltr; }
.umap .useg { position: absolute; top: 0; bottom: 0; background: var(--c); color: var(--ct); box-shadow: inset -.35pt 0 #fff;
  font: 700 6.2pt/8mm "IBM Plex Sans Condensed", "IBM Plex Sans", Arial, sans-serif; overflow: hidden; white-space: nowrap; padding-left: .5mm; }
.umap .useg.est { background-image: repeating-linear-gradient(135deg, rgba(255,255,255,.4) 0 .45mm, transparent .45mm 1.8mm); }
.umap .ovl { position: absolute; bottom: -1.6mm; height: 1.2mm; background: #d11; }
.umap .scale { position: relative; height: 3.2mm; font-size: 5.6pt; color: #777; direction: ltr; margin-top: .5mm; }
.umap .scale span { position: absolute; top: .4mm; transform: translateX(-50%); }
.umap .scale span::before { content: ''; position: absolute; left: 50%; top: -.9mm; height: .8mm; border-left: .3pt solid #999; }
.maplegend { font-size: 7.4pt; color: #555; margin: -2mm 0 3mm; }
/* arabe (droite à gauche) : adresses, numéros et plages restent écrits de gauche à droite */
[dir=rtl] .sheet td.num, [dir=rtl] .sheet td.ad, [dir=rtl] .sheet td.fid, [dir=rtl] .sheet td.dfrom, [dir=rtl] .sheet td.dto,
[dir=rtl] .lbl .big { direction: ltr; unicode-bidi: isolate; }
[dir=rtl] .sheet td.num, [dir=rtl] .sheet td.fid { text-align: right; }
dialog#mapDlg { border: 1px solid var(--line); border-radius: 12px; padding: 18px 20px; max-width: 520px; width: calc(100% - 32px); background: var(--panel, #fff); color: var(--ink); }
dialog#mapDlg::backdrop { background: rgba(0,0,0,.45); }
dialog#mapDlg h2 { margin: 0 0 6px; font-size: 17px; }
.maprow { display: grid; grid-template-columns: 11em 1fr; gap: 8px; align-items: center; margin: 6px 0; font-size: 13px; }
.maprow select { font: inherit; padding: 4px 6px; min-width: 0; }
.mapbtns { display: flex; gap: 8px; justify-content: flex-end; margin-top: 14px; flex-wrap: wrap; }
.mapbtns .btn { padding: 8px 14px; font-size: 13.5px; }
.mapbtns .linkbtn { margin-right: auto; align-self: center; }
.reffile { font-size: 12.5px; word-break: break-all; }
.sheet .dch { width: 22mm; } .sheet td.dch { color:#555; }
.sheet td.dfrom { color:#888; text-decoration: line-through; }
.sheet td.dto { font-weight: 700; }
.sheet .kpi.mod b { color: #b45309; } .sheet .kpi.add b { color: #15803d; } .sheet .kpi.del b { color: #b91c1c; }
.lcolors { display: flex; flex-direction: column; gap: 6px; }
.lcolor { display: flex; align-items: center; gap: 8px; font-size: 13px; }
.lcolor input[type=color] { width: 30px; height: 22px; border: 1px solid var(--line); border-radius: 5px; padding: 0; background: none; cursor: pointer; flex: none; }
.lcolor span { cursor: pointer; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; flex: 1; }
.lcolor input[type=checkbox] { accent-color: var(--accent); margin: 0; flex: none; }
.lcolor.off span { color: var(--muted); text-decoration: line-through; }
.lcolor.off input[type=color] { opacity: .35; }
.lcolor small { color: var(--muted); font-variant-numeric: tabular-nums; flex: none; }
.toolbar { position: sticky; top: 0; z-index: 2; display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 10px 22px; background: color-mix(in srgb, var(--bg) 88%, transparent); backdrop-filter: blur(6px); border-bottom: 1px solid var(--line); font-size: 12.5px; color: var(--muted); }
.zoom { display: flex; align-items: center; gap: 8px; }
.zoom input { accent-color: var(--accent); width: 120px; }
#pages { padding: 26px 22px 60px; display: flex; flex-direction: column; align-items: center; gap: 22px; }
.empty { height: calc(100vh - 60px); display: grid; place-items: center; text-align: center; color: var(--muted); }
.empty .big { font-size: 46px; opacity: .35; margin-bottom: 6px; }

@media (max-width: 820px) {
  .app { grid-template-columns: 1fr; height: auto; }
  aside { border-right: 0; border-bottom: 1px solid var(--line); }
  main { overflow: visible; }
}

/* ───────────── feuille (identique écran / impression) ───────────── */
.sheet {
  --row: 4.6mm; --head: 7mm; --thead: 5mm; --gap: 4mm;
  position: relative; background: #fff; color: #111; padding: 14mm;
  font-family: "IBM Plex Sans", Arial, sans-serif; font-size: 9pt;
  box-shadow: 0 2px 18px rgba(0,0,0,.18); flex: none; overflow: hidden;
  -webkit-print-color-adjust: exact; print-color-adjust: exact;
}
.sheet.A3 { width: 420mm; height: 297mm; }
.sheet.A4 { width: 297mm; height: 210mm; }
/* planches d'étiquettes (A3 portrait) */
.sheet.A3P { width: 297mm; height: 420mm; padding: 10mm; }
.sheet.LSH { padding: 0; }
.lbl.adh { position: absolute; border: 0; margin: 0; }
@media screen { .lbl.adh { outline: .3pt dashed #bbb; } }
.lgrid { display: grid; grid-template-columns: repeat(var(--cols), var(--w)); grid-auto-rows: var(--h); justify-content: center; }
.lbl { border: .3pt dashed #9a9a9a; margin: 0 -.15pt -.15pt 0; overflow: hidden; display: flex; flex-direction: column; background: #fff; color: #111; }
.lbl .band { background: var(--c); color: var(--ct); font-size: 6.3pt; font-weight: 700; height: 3.4mm; line-height: 3.4mm; padding: 0 1.5mm; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; letter-spacing: .3pt; text-transform: uppercase; flex: none; }
.lbl .band.thin { height: 1.6mm; }
.lbl .body { flex: 1; min-height: 0; display: flex; flex-direction: column; padding: .5mm 1.2mm .6mm 2mm; border-left: 1.4mm solid var(--c); gap: .2mm; }
.lbl .big { min-height: 0; display: flex; align-items: center; overflow: hidden; white-space: nowrap; line-height: 1; font-weight: 700; font-family: "IBM Plex Sans Condensed", "IBM Plex Sans", Arial, sans-serif; font-variant-numeric: tabular-nums; letter-spacing: -.01em; }
.lbl .bigs { flex: 1 1 0; min-height: 0; display: flex; flex-direction: column; }
.lbl .lfid { flex: 1.8 1 0; font-size: 30pt; }
.lbl .lpt { flex: 1 1 0; font-size: 18pt; }
.lbl.wide .bigs { flex-direction: row; gap: 1.5mm; align-items: stretch; }
.lbl.wide .lpt { justify-content: flex-end; }
.lbl.wide .lfid { flex: 1 1 0; } .lbl.wide .lpt { flex: 1.15 1 0; }
.lbl.wide .ann { min-height: 2.8mm; font-size: 6pt; }
.lbl .lnm { font-size: 7.4pt; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; line-height: 1.2; }
.lbl .ty, .lbl .ch { font-size: 5.9pt; color: #444; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; line-height: 1.2; font-family: "IBM Plex Sans Condensed", "IBM Plex Sans", Arial, sans-serif; }
.lbl .ann { margin-top: auto; font-size: 7pt; font-style: italic; line-height: 1.25; min-height: 3.4mm; white-space: nowrap; overflow: hidden; border-top: .3pt solid #c8c8c8; padding-top: .3mm; outline: none; }
.lbl .ann:empty { border-top-color: transparent; }
.sheet.A3P .lfoot { position: absolute; left: 10mm; right: 10mm; bottom: 4mm; display: flex; justify-content: space-between; font-size: 7pt; color: #888; }
@media screen {
  .lbl .ann { cursor: text; }
  .lbl .ann:empty { border-top: .3pt dashed #ddd; }
  .lbl .ann:empty::before { content: attr(data-ph); color: #bbb; }
  .lbl .ann:focus { background: #fff4c7; }
}
.sheet .pfoot { position: absolute; left: 14mm; right: 14mm; bottom: 7mm; display: flex; justify-content: space-between; font-size: 7.5pt; color: #777; }
.sheet header.top { display:flex; justify-content:space-between; align-items:flex-end; border-bottom: 2.4pt solid #111; padding-bottom: 3mm; margin-bottom: 5mm; }
.sheet header.top h1 { font-size: 21pt; margin: 0; letter-spacing: 0; line-height:1.05; font-weight: 600; }
.sheet header.top .sub { font-size: 11pt; margin-top: 1.5mm; }
.sheet header.top .meta { text-align:right; font-size: 8.5pt; color:#444; line-height:1.5; flex: none; }
.sheet header.top > div:first-child { flex: none; }
.sheet header.top .note { flex: 1; min-width: 0; align-self: stretch; margin: 0 10mm; padding: 0 0 0 4mm; border-left: .8pt solid #111;
  font-size: 9pt; line-height: 1.35; color: #222; overflow: hidden; display: flex; flex-direction: column; justify-content: flex-start; }
.sheet header.top .note .ln { min-height: 1.35em; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sheet h2 { font-size: 11.5pt; text-transform: uppercase; letter-spacing: 1pt; margin: 0 0 4mm; height: 7mm; line-height: 6mm; border-bottom: .8pt solid #111; font-weight: 700; }
.sheet .kpis { display:flex; gap: 5mm; margin-bottom: 6mm; }
.sheet .kpi { flex:1; border: .8pt solid #111; padding: 2.5mm 4mm; display:flex; align-items:baseline; gap:3mm; }
.sheet .kpi b { font-size: 20pt; line-height:1; }
.sheet .kpi span { font-size: 8pt; text-transform: uppercase; letter-spacing:.7pt; color:#444; }
.sheet .sumcols { display:flex; gap: 8mm; margin-bottom: 6mm; }
.sheet .sumcols > div { flex: 1; min-width: 0; } .sheet .sumcols > div.wide { flex: 1.35; }
.sheet table { width:100%; border-collapse: collapse; table-layout: fixed; }
.sheet th { text-align:left; font-size: 6.8pt; text-transform: uppercase; letter-spacing:.5pt; color:#fff; background:#222; height: var(--thead); padding: 0 1.6mm; font-weight: 600; }
.sheet td { padding: 0 1.6mm; border-bottom: .35pt solid #c4c4c4; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; height: var(--row); line-height: calc(var(--row) - .3mm); }
.sheet tbody tr:nth-child(even) td { background: #efefef; }
.sheet .summary td { white-space: normal; height: auto; line-height: 1.35; padding: .9mm 1.6mm; }
.sheet .num { text-align:center; }
.sheet td.ty { color:#333; font-size: 8pt; font-family: "IBM Plex Sans Condensed", "IBM Plex Sans", Arial, sans-serif; }
.sheet .fid { width: 16mm; } .sheet td.fid { font-weight:700; }
.sheet .nm { width: 35mm; } .sheet td.nm { font-weight:600; }
.sheet .lay { width: 23mm; } .sheet td.lay { color:#555; font-size: 7.2pt; font-family: "IBM Plex Sans Condensed", "IBM Plex Sans", Arial, sans-serif; }
.sheet .un { width: 11mm; text-align:center; }
.sheet .ad { width: 11mm; text-align:center; } .sheet td.ad { font-weight:700; }
.sheet td, .sheet th, .sheet .kpi b { font-variant-numeric: tabular-nums; }
.sheet .cols { display:flex; gap: 8mm; align-items:flex-start; }
.sheet .col { flex: 1; min-width: 0; }
.sheet .grp { margin-bottom: var(--gap); }
.sheet .grp h3 { display:flex; justify-content:space-between; align-items:center; margin:0; height: var(--head); padding: 0 2mm; border: .8pt solid #111; border-bottom:none; font-size: 10pt; letter-spacing:.5pt; font-weight: 700; }
.sheet .grp h3 em { font-weight:400; font-size: 8pt; }
.sheet .grp h3 small { font-weight: 400; font-size: 7.8pt; color:#444; letter-spacing:0; }
.sheet .grp table { outline: .8pt solid #111; outline-offset: -.4pt; }
.sheet .warn { border:.8pt solid #111; background:#fff3c4; padding: 2mm 3mm; font-size: 8.5pt; margin: 0 0 5mm; }

#measure { position: absolute; left: -10000px; top: 0; visibility: hidden; }

@media print {
  html, body { background: #fff; height: auto; }
  aside, .toolbar, .empty, #measure { display: none !important; }
  .app { display: block; height: auto; }
  main { overflow: visible; }
  #pages { padding: 0; gap: 0; display: block; }
  .sheet { box-shadow: none; zoom: 1 !important; break-after: page; margin: 0; }
  .sheet:last-child { break-after: auto; }
}
</style>
<style id="pagesize">@page { size: A3 landscape; margin: 0; }</style>
</head>
<body>
<div class="app">
  <aside>
    <div class="brand">
      <a class="brandlink" href="https://github.com/mart1ver/GiveMeThePatch" target="_blank" rel="noopener" data-i18n-title="repoLink" title="Le projet sur GitHub">
        <div class="dot" aria-hidden="true"></div>
        <div><h1 data-i18n="brandTitle">Give Me The Patch</h1><p data-i18n="brandSub">Patch → feuille et étiquettes imprimables</p></div>
      </a>
      <select class="lang" id="lang" aria-label="Langue / Language">
        <option value="fr">FR · Français</option>
        <option value="en">EN · English</option>
        <option value="es">ES · Español</option>
        <option value="de">DE · Deutsch</option>
        <option value="ja">JA · 日本語</option>
        <option value="ru">RU · Русский</option>
        <option value="ar">AR · العربية</option>
      </select>
    </div>

    <label class="drop" id="drop" tabindex="0">
      <input type="file" id="file" accept=".csv,.txt,.html,.htm,text/csv,text/html" hidden>
      <div id="dropText"><b data-i18n="dropTitle">Déposer le patch ici</b><span data-i18n="dropSub">CSV ou .html — ou cliquer pour choisir un fichier</span></div>
    </label>

    <fieldset data-tab="patch">
      <legend data-i18n="legHeader">En-tête</legend>
      <label class="f"><span data-i18n="lblTitle">Titre</span><input type="text" id="titre" value="Patch lumière"></label>
      <label class="f"><span data-i18n="lblPlace">Lieu / sous-titre</span><input type="text" id="lieu" value="Gaîté Lyrique"></label>
      <div class="f"><span data-i18n="lblNotes">Cartouche (texte libre)</span>
        <input type="text" id="note1" data-i18n-ph="line1" placeholder="Ligne 1" aria-label="Ligne 1">
        <input type="text" id="note2" data-i18n-ph="line2" placeholder="Ligne 2" aria-label="Ligne 2">
        <input type="text" id="note3" data-i18n-ph="line3" placeholder="Ligne 3" aria-label="Ligne 3">
        <input type="text" id="note4" data-i18n-ph="line4" placeholder="Ligne 4" aria-label="Ligne 4">
      </div>
    </fieldset>

    <fieldset data-tab="patch diff">
      <legend data-i18n="legFormat">Format papier (paysage)</legend>
      <div class="seg" id="fmt">
        <button type="button" data-v="A3" class="on" data-i18n="fmtA3">A3 · 3 colonnes</button>
        <button type="button" data-v="A4" data-i18n="fmtA4">A4 · 2 colonnes</button>
      </div>
    </fieldset>

    <fieldset data-tab="patch">
      <legend data-i18n="legContent">Contenu</legend>
      <label class="chk"><input type="checkbox" id="optSumLayer" checked> <span data-i18n="optSumLayer">Récap. par layer</span></label>
      <label class="chk"><input type="checkbox" id="optSumUniv" checked> <span data-i18n="optSumUniv">Récap. par univers</span></label>
      <label class="chk"><input type="checkbox" id="optSumType" checked> <span data-i18n="optSumType">Récap. par type de projecteur</span></label>
      <label class="chk"><input type="checkbox" id="optLayer" checked> <span data-i18n="optLayer">Patch par layer</span></label>
      <label class="chk"><input type="checkbox" id="optUniv" checked> <span data-i18n="optUniv">Patch par univers</span></label>
      <label class="chk"><input type="checkbox" id="optMap" checked> <span data-i18n="optMap">Plan d'occupation des univers</span></label>
      <label class="chk"><input type="checkbox" id="optHideUnp"> <span data-i18n="optHide">Masquer les non patchés</span></label>
      <label class="chk"><input type="checkbox" id="optExport" checked> <span data-i18n="optExport">Afficher la date d'export</span></label>
    </fieldset>

    <fieldset data-tab="labels">
      <legend data-i18n="legLabels">Étiquettes</legend>
      <select id="lbSize" class="lbsel" aria-label="Format">
        <optgroup label="A3 à découper (scotch)" data-i18n-label="lbCutGrp">
          <option value="40x30">4 × 3 cm — 78</option>
          <option value="30x40">3 × 4 cm — 81</option>
          <option value="50x20">5 × 2 cm — 95</option>
        </optgroup>
        <optgroup label="Planches adhésives A4" data-i18n-label="lbAdhGrp">
          <option value="L7651">Avery L7651 · 38,1 × 21,2 mm — 65</option>
          <option value="L7654">Avery L7654 · 45,7 × 25,4 mm — 40</option>
          <option value="L7159">Avery L7159 · 63,5 × 33,9 mm — 24</option>
          <option value="L7160">Avery L7160 · 63,5 × 38,1 mm — 21</option>
          <option value="3474">Avery 3474 · 70 × 37 mm — 24</option>
          <option value="custom" data-i18n="lbCustom">Autre planche (dimensions à saisir)…</option>
        </optgroup>
      </select>
      <div class="lbcust" id="lbCust" hidden>
        <label><span data-i18n="cuPage">Papier</span><select id="cu_page" class="lbsel"><option>A4</option><option>A3</option></select></label>
        <label><span data-i18n="cuCols">Colonnes × lignes</span><span style="display:flex;gap:4px"><input type="number" id="cu_cols" min="1" max="20"><input type="number" id="cu_rows" min="1" max="40"></span></label>
        <label><span data-i18n="cuW">Largeur étiquette (mm)</span><input type="number" id="cu_w" step="0.1" min="5"></label>
        <label><span data-i18n="cuH">Hauteur étiquette (mm)</span><input type="number" id="cu_h" step="0.1" min="5"></label>
        <label><span data-i18n="cuLeft">Marge gauche (mm)</span><input type="number" id="cu_left" step="0.05" min="0"></label>
        <label><span data-i18n="cuTop">Marge haut (mm)</span><input type="number" id="cu_top" step="0.05" min="0"></label>
        <label><span data-i18n="cuPx">Pas horizontal (mm)</span><input type="number" id="cu_px" step="0.05" min="5"></label>
        <label><span data-i18n="cuPy">Pas vertical (mm)</span><input type="number" id="cu_py" step="0.05" min="5"></label>
      </div>
      <p class="hint2" id="lbAdhHint" data-i18n="lbAdhHint" hidden>Planche adhésive : imprimer à 100 % (« Taille réelle »), marges Aucune. Faire d'abord un essai sur papier ordinaire, par transparence.</p>
      <label class="chk"><input type="checkbox" id="lbOnly"> <span data-i18n="lbOnly">Fix ID seul (lisible de loin)</span></label>
      <label class="chk"><input type="checkbox" id="lbFid" checked> <span data-i18n="lbFid">Fix ID</span></label>
      <label class="chk"><input type="checkbox" id="lbPatch" checked> <span data-i18n="lbPatch">Adresse DMX (univ.adr)</span></label>
      <label class="chk"><input type="checkbox" id="lbName" checked> <span data-i18n="lbName">Nom</span></label>
      <label class="chk"><input type="checkbox" id="lbType"> <span data-i18n="lbType">Type de projecteur</span></label>
      <label class="chk"><input type="checkbox" id="lbChid"> <span data-i18n="lbChid">Ch ID</span></label>
      <label class="chk"><input type="checkbox" id="lbLayer" checked> <span data-i18n="lbLayer">Nom du layer (bandeau)</span></label>
      <label class="chk"><input type="checkbox" id="lbAnn" checked> <span data-i18n="lbAnn">Zone d'annotation</span></label>
      <label class="chk"><input type="checkbox" id="lbHideUnp"> <span data-i18n="optHide">Masquer les non patchés</span></label>
      <p class="hint2" data-i18n="lbHint">Annotation : cliquer en bas d'une étiquette dans l'aperçu et écrire.</p>
    </fieldset>

    <fieldset data-tab="labels" id="lcolorBox" hidden>
      <legend data-i18n="legColors">Layers à imprimer</legend>
      <p class="hint2" data-i18n="lcHint">Décocher un layer pour ne pas imprimer ses étiquettes. Cliquer sur la pastille pour changer sa couleur.</p>
      <div class="lcolors" id="lcolors"></div>
      <button type="button" class="linkbtn" id="lcolorReset" data-i18n="colorsReset">Couleurs par défaut</button>
    </fieldset>

    <fieldset data-tab="diff">
      <legend data-i18n="legDiff">Comparer avec un ancien patch</legend>
      <button type="button" class="btn ghost" id="refBtn" data-i18n="refBtn">Charger l'ancien patch…</button>
      <input type="file" id="refFile" accept=".csv,.txt,.html,.htm,text/csv,text/html" hidden>
      <div class="reffile" id="refName" hidden></div>
      <p class="hint2" data-i18n="refHint">CSV, ou feuille .html (plugin ou enregistrée). Les projecteurs sont reconnus par leur Fix ID.</p>
      <label class="chk"><input type="checkbox" id="diffInSheet"> <span data-i18n="diffInSheet">Ajouter les changements en tête de la feuille de patch</span></label>
    </fieldset>

    <fieldset id="hideBox" hidden>
      <legend data-i18n="legHidden">Projecteurs masqués</legend>
      <div class="hideAdd">
        <input type="text" id="hideInput" list="fxList" data-i18n-ph="hidePh" placeholder="Fix ID ou nom…" autocomplete="off">
        <button type="button" id="hideBtn" data-i18n="hideBtn">Masquer</button>
      </div>
      <datalist id="fxList"></datalist>
      <p class="hint2" data-i18n="hideHint">Ou cliquer sur une ligne de l'aperçu pour la masquer.</p>
      <div class="chips" id="hiddenChips"></div>
      <button type="button" class="linkbtn" id="unhideAll" hidden data-i18n="unhideAll">Tout réafficher</button>
    </fieldset>

    <div id="info" hidden>
      <fieldset>
        <legend data-i18n="legFile">Fichier</legend>
        <div class="stats" id="stats"></div>
        <div class="alerts" id="alerts"></div>
        <button type="button" class="linkbtn" id="mapBtn" data-i18n="mapBtn">Colonnes du fichier…</button>
      </fieldset>
    </div>

    <button class="btn" id="print" disabled>
      <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9V3h12v6"/><rect x="3" y="9" width="18" height="8" rx="2"/><path d="M6 14h12v7H6z"/></svg>
      <span data-i18n="print">Imprimer / PDF</span>
    </button>
    <button class="btn ghost" id="save" disabled>
      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3v12"/><path d="m7 10 5 5 5-5"/><path d="M5 21h14"/></svg>
      <span data-i18n="save">Enregistrer la feuille (.html)</span>
    </button>
    <p class="hint" data-i18n="saveHint">Un seul fichier avec le patch, les annotations, les masquages et les réglages. Il s'ouvre dans n'importe quel navigateur.</p>
    <p class="hint" id="printHint" data-i18n-html="printHint">Dans la boîte d'impression : destination « Enregistrer en PDF » ou l'imprimante, marges <b>Aucune</b>, « Graphiques d'arrière-plan » coché.</p>

    <div class="spacer"></div>
    <fieldset>
      <legend data-i18n="legPlugins">Plugins pour la console</legend>
      <div class="dl">
        <a class="btn ghost" href="https://github.com/mart1ver/GiveMeThePatch/raw/main/grandma2/GiveMeThePatch_grandMA2.zip" download>grandMA2</a>
        <a class="btn ghost" href="https://github.com/mart1ver/GiveMeThePatch/raw/main/grandma3/GiveMeThePatch_grandMA3.zip" download>grandMA3</a>
      </div>
      <p class="hint2" data-i18n="pluginsHint">Dézipper à la racine de la clé USB, puis dans le pool Plugins de la console : Import → GiveMeThePatch.</p>
    </fieldset>
    <div class="foot" data-i18n="foot">Le fichier est lu dans le navigateur : rien n'est envoyé au serveur. Give Me The Patch, par Mart1ver.</div>
  </aside>

  <main>
    <div class="toolbar">
      <div class="tb-left">
        <div class="tabs" id="tabs" role="tablist">
          <button type="button" data-v="patch" class="on" data-i18n="tabPatch">Feuille de patch</button>
          <button type="button" data-v="labels" data-i18n="tabLabels">Étiquettes</button>
          <button type="button" data-v="diff" data-i18n="tabDiff">Changements</button>
        </div>
        <span id="pageInfo">Aucun fichier chargé</span>
      </div>
      <div class="zoom"><span data-i18n="zoom">Zoom</span><input type="range" id="zoom" min="20" max="100" value="45"><span id="zoomVal">45 %</span></div>
    </div>
    <div id="pages">
      <div class="empty"><div><div class="big">◎</div><span data-i18n="emptyMsg">Charge un patch pour commencer : export grandMA2 ou grandMA3, WYSIWYG, Capture, ou feuille .html du plugin.</span></div></div>
    </div>
    <div id="measure"></div>
  </main>
</div>

<dialog id="mapDlg">
  <form method="dialog" id="mapForm">
    <h2 data-i18n="mapTitle">Colonnes du fichier</h2>
    <p class="hint2" data-i18n="mapHint">Indique quelle colonne contient quoi. Il faut au moins le patch, ou l'univers et l'adresse. Le choix est mémorisé pour les fichiers qui ont le même en-tête.</p>
    <div id="mapRows"></div>
    <label class="chk"><input type="checkbox" id="mapAuto"> <span data-i18n="mapAuto">Numéroter les projecteurs sans numéro (dans l'ordre des adresses)</span></label>
    <p class="hint2" id="mapErr" style="color:#b91c1c" hidden></p>
    <div class="mapbtns">
      <button type="button" class="linkbtn" id="mapReset" data-i18n="mapReset">Détection automatique</button>
      <button type="button" class="btn ghost" id="mapCancel" data-i18n="mapCancel">Annuler</button>
      <button type="submit" class="btn" id="mapOk" data-i18n="mapApply">Appliquer</button>
    </div>
  </form>
</dialog>

<script id="gmtp-data">/*@@EMBEDDED_DATA@@*/</script>
<script>
'use strict';
// copie de la page telle que chargée, avant toute modification : sert de modèle à « Enregistrer »
const PRISTINE = document.documentElement.cloneNode(true);
// ───────────── utilitaires ─────────────
const $ = s => document.querySelector(s);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const store = {
  get(k, d) { try { const v = localStorage.getItem('givemethepatch.' + k); return v === null ? d : JSON.parse(v); } catch { return d; } },
  set(k, v) { try { localStorage.setItem('givemethepatch.' + k, JSON.stringify(v)); } catch {} }
};
const FORMATS = { A3: { W: 420, H: 297, ncol: 3 }, A4: { W: 297, H: 210, ncol: 2 } };
const MARGIN = 14, ROW = 4.6, HEAD = 7, THEAD = 5, GAP = 4, H2 = 11;

const I18N = {
  fr: {
    brandTitle: 'Give Me The Patch', brandSub: 'Patch → feuille et étiquettes imprimables',
    dropTitle: 'Déposer le patch ici', dropSub: 'CSV ou .html — ou cliquer pour choisir un fichier',
    legHeader: 'En-tête', lblTitle: 'Titre', lblPlace: 'Lieu / sous-titre', lblNotes: 'Cartouche (texte libre)',
    line1: 'Ligne 1', line2: 'Ligne 2', line3: 'Ligne 3', line4: 'Ligne 4',
    legFormat: 'Format papier (paysage)', fmtA3: 'A3 · 3 colonnes', fmtA4: 'A4 · 2 colonnes',
    legContent: 'Contenu', optSumLayer: 'Récap. par layer', optSumUniv: 'Récap. par univers', optSumType: 'Récap. par type de projecteur', sumType: 'Récapitulatif par type', thFxType: 'Type de projecteur', optLayer: 'Patch par layer', optUniv: 'Patch par univers', optMap: "Plan d'occupation des univers", secMap: "Plan d'occupation des univers", mapUsed: n => `${n}/512 canaux utilisés`, mapFree: 'Libre :', mapFull: 'Plus aucun canal libre', mapEst: "Hachuré : nombre de canaux inconnu, plage estimée jusqu'au projecteur suivant.", mapOvl: 'Rouge : canaux en conflit.', optHide: 'Masquer les non patchés', legHidden: 'Projecteurs masqués', tabPatch: 'Feuille de patch', tabLabels: 'Étiquettes', legLabels: 'Étiquettes', lbFid: 'Fix ID', lbPatch: 'Adresse DMX (univ.adr)', lbName: 'Nom', lbType: 'Type de projecteur', lbChid: 'Ch ID', lbLayer: 'Nom du layer (bandeau)', lbAnn: "Zone d'annotation", lbHint: "Annotation : cliquer en bas d'une étiquette dans l'aperçu et écrire.", legColors: 'Layers à imprimer', lcHint: 'Décocher un layer pour ne pas imprimer ses étiquettes. Cliquer sur la pastille pour changer sa couleur.', lcPrint: 'Imprimer les étiquettes de ce layer', colorsReset: 'Couleurs par défaut', annPh: 'annotation…', lbInfo: (f, n, p) => `${f} — ${n} étiquette${n > 1 ? 's' : ''}, ${p} planche${p > 1 ? 's' : ''} A3`, lbFoot: (p, n) => `Étiquettes · planche ${p}/${n}`, noLabels: 'Aucun projecteur à étiqueter.',
    lbCutGrp: 'A3 à découper (scotch)', lbAdhGrp: 'Planches adhésives A4', lbCustom: 'Autre planche (dimensions à saisir)…', lbOnly: 'Fix ID seul (lisible de loin)',
    cuPage: 'Papier', cuCols: 'Colonnes × lignes', cuW: 'Largeur étiquette (mm)', cuH: 'Hauteur étiquette (mm)', cuLeft: 'Marge gauche (mm)', cuTop: 'Marge haut (mm)', cuPx: 'Pas horizontal (mm)', cuPy: 'Pas vertical (mm)',
    lbAdhHint: "Planche adhésive : imprimer à 100 % (« Taille réelle »), marges Aucune. Faire d'abord un essai sur papier ordinaire, par transparence.",
    lbInfoAdh: (f, n, p, nm) => `${f} — ${n} étiquette${n > 1 ? 's' : ''}, ${p} planche${p > 1 ? 's' : ''} ${nm}`,
    tabDiff: 'Changements', legDiff: 'Comparer avec un ancien patch', refBtn: "Charger l'ancien patch…", refHint: 'CSV, ou feuille .html (plugin ou enregistrée). Les projecteurs sont reconnus par leur Fix ID.', diffInSheet: 'Ajouter les changements en tête de la feuille de patch',
    refOld: 'Ancien :', diffNoRef: "Charge l'ancien patch dans le panneau de gauche pour voir ce qui a changé.", diffTitle: 'Changements de patch', diffNone: 'Aucun changement entre les deux patchs.',
    kMod: 'modifiés', kAdd: 'ajoutés', kDel: 'supprimés', kSame: 'inchangés', gMod: 'Modifiés', gAdd: 'Ajoutés', gDel: 'Supprimés',
    thChange: 'Changement', thFrom: 'Avant', thTo: 'Après', thPatch: 'Patch', dAddr: 'Adresse', dType: 'Type', dLayer: 'Layer', dName: 'Nom', dNch: 'Canaux',
    diffInfo: (o, n, p) => `${o} → ${n} — ${p} page${p > 1 ? 's' : ''}`, diffFoot: 'Changements de patch', refErr: "Ancien patch illisible :", refNoCols: "Colonnes non reconnues dans l'ancien fichier. Ouvre-le d'abord comme patch principal pour choisir ses colonnes.",
    mapBtn: 'Colonnes du fichier…', mapTitle: 'Colonnes du fichier', mapHint: "Indique quelle colonne contient quoi. Il faut au moins le patch, ou l'univers et l'adresse. Le choix est mémorisé pour les fichiers qui ont le même en-tête.",
    mapAuto: "Numéroter les projecteurs sans numéro (dans l'ordre des adresses)", mapReset: 'Détection automatique', mapCancel: 'Annuler', mapApply: 'Appliquer', mapNeed: 'Choisis au moins la colonne Patch, ou Univers + Adresse.', mapNone: '— aucune —',
    mFid: 'Fix ID', mChid: 'Ch ID', mLayer: 'Layer / groupe', mName: 'Nom', mType: 'Type de projecteur', mPatch: 'Patch (univ.adresse)', mUniv: 'Univers (colonne à part)', mAddr: 'Adresse (colonne à part)', mNch: 'Nombre de canaux',
    unknownCols: "Colonnes non reconnues : choisis-les dans la fenêtre qui vient de s'ouvrir.", noIds: 'Aucun numéro de projecteur dans le fichier.', autoNum: 'Numéroter automatiquement',
    legPlugins: 'Plugins pour la console', pluginsHint: 'Dézipper à la racine de la clé USB, puis dans le pool Plugins de la console : Import → GiveMeThePatch.', repoLink: 'Le projet sur GitHub',
    save: 'Enregistrer la feuille (.html)', saveHint: "Un seul fichier avec le patch, les annotations, les masquages et les réglages. Il s'ouvre dans n'importe quel navigateur.", fromSaved: 'Feuille enregistrée', hidePh: 'Fix ID ou nom…', hideBtn: 'Masquer', hideHint: "Ou cliquer sur une ligne de l'aperçu pour la masquer.", unhideAll: 'Tout réafficher', unhide: 'Réafficher', hideRow: 'Cliquer pour masquer ce projecteur', notFound: 'Aucun projecteur ne correspond.', stHidden: n => `${n} masqué${n > 1 ? 's' : ''} à la main`,
    legFile: 'Fichier', print: 'Imprimer / PDF',
    printHint: "Dans la boîte d'impression : destination « Enregistrer en PDF » ou l'imprimante, marges <b>Aucune</b>, « Graphiques d'arrière-plan » coché.",
    foot: "Le fichier est lu dans le navigateur : rien n'est envoyé au serveur. Give Me The Patch, par Mart1ver.",
    zoom: 'Zoom', noFile: 'Aucun fichier chargé', emptyMsg: 'Charge un patch pour commencer : export grandMA2 ou grandMA3, WYSIWYG, Capture, ou feuille .html du plugin.',
    loaded: 'Fichier chargé', fromConsole: 'Patch lu sur la console', changeFile: 'Cliquer ou déposer un autre fichier pour en changer',
    readErr: 'Lecture impossible', emptyFile: 'Fichier vide.', noFixtures: 'Aucun projecteur trouvé dans le fichier.',
    noCols: h => `Colonnes introuvables. Il faut au minimum une colonne « Patch » (ou « DMX Universe » + « DMX Channel »). En-tête lu : ${h}`,
    noPatched: 'Aucun projecteur patché à afficher.',
    fixtures: n => `${n} projecteur${n > 1 ? 's' : ''}`, cont: '(suite)',
    thFid: 'Fix ID', thName: 'Nom', thType: 'Type', thUniv: 'Univ.', thAddr: 'Adr.', thLayer: 'Layer',
    univ: 'Univers', unpatched: 'Non patchés', secLayer: 'Patch par layer', secUniv: 'Patch par univers',
    warnDup: 'Adresses de départ en double :', warnOvl: 'Plages DMX qui se chevauchent :', warnUnp: n => `${n} projecteur(s) sans patch :`,
    printed: d => `Imprimé le ${d}`, exported: (d, h) => `Exporté le ${d} à ${h}`, optExport: "Afficher la date d'export",
    kpiFix: 'Projecteurs', kpiLayers: 'Layers', kpiUniv: 'Univers DMX', kpiTypes: "Types d'appareils",
    sumLayer: 'Récapitulatif par layer', sumUniv: 'Récapitulatif par univers',
    thQty: 'Qté', thTypes: 'Types', thUnivFull: 'Univers', thStart: 'Adresses de départ', thLayers: 'Layers',
    pageInfo: (f, n, fmt) => `${f} — ${n} page${n > 1 ? 's' : ''} ${fmt} paysage`,
    stFix: 'Projecteurs', stLayers: 'Layers', stUniv: 'Univers', stTypes: 'Types',
    alDup: n => `${n} adresse(s) en double`, alOvl: n => `${n} chevauchement(s) de plage`, alUnp: n => `${n} sans patch`, alHidden: ' — masqués sur la feuille',
    alOk: '✓ Aucune adresse de départ en double, tout est patché.',
    defTitle: 'Patch lumière', docTitle: 'Give Me The Patch', locale: 'fr-FR',
  },
  en: {
    brandTitle: 'Give Me The Patch', brandSub: 'Patch → printable sheet and labels',
    dropTitle: 'Drop the patch here', dropSub: 'CSV or .html — or click to choose a file',
    legHeader: 'Header', lblTitle: 'Title', lblPlace: 'Venue / subtitle', lblNotes: 'Title block (free text)',
    line1: 'Line 1', line2: 'Line 2', line3: 'Line 3', line4: 'Line 4',
    legFormat: 'Paper size (landscape)', fmtA3: 'A3 · 3 columns', fmtA4: 'A4 · 2 columns',
    legContent: 'Content', optSumLayer: 'Summary by layer', optSumUniv: 'Summary by universe', optSumType: 'Summary by fixture type', sumType: 'Summary by fixture type', thFxType: 'Fixture type', optLayer: 'Patch by layer', optUniv: 'Patch by universe', optMap: 'Universe occupancy map', secMap: 'Universe occupancy map', mapUsed: n => `${n}/512 channels used`, mapFree: 'Free:', mapFull: 'No free channel left', mapEst: 'Hatched: channel count unknown, range estimated up to the next fixture.', mapOvl: 'Red: conflicting channels.', optHide: 'Hide unpatched fixtures', legHidden: 'Hidden fixtures', tabPatch: 'Patch sheet', tabLabels: 'Labels', legLabels: 'Labels', lbFid: 'Fix ID', lbPatch: 'DMX address (univ.addr)', lbName: 'Name', lbType: 'Fixture type', lbChid: 'Ch ID', lbLayer: 'Layer name (band)', lbAnn: 'Annotation area', lbHint: 'Annotation: click at the bottom of a label in the preview and type.', legColors: 'Layers to print', lcHint: 'Untick a layer to skip its labels. Click the swatch to change its colour.', lcPrint: 'Print labels for this layer', colorsReset: 'Default colours', annPh: 'note…', lbInfo: (f, n, p) => `${f} — ${n} label${n > 1 ? 's' : ''}, ${p} A3 sheet${p > 1 ? 's' : ''}`, lbFoot: (p, n) => `Labels · sheet ${p}/${n}`, noLabels: 'No fixture to label.',
    lbCutGrp: 'A3 to cut out (tape)', lbAdhGrp: 'A4 adhesive label sheets', lbCustom: 'Other sheet (enter its dimensions)…', lbOnly: 'Fix ID only (readable from afar)',
    cuPage: 'Paper', cuCols: 'Columns × rows', cuW: 'Label width (mm)', cuH: 'Label height (mm)', cuLeft: 'Left margin (mm)', cuTop: 'Top margin (mm)', cuPx: 'Horizontal pitch (mm)', cuPy: 'Vertical pitch (mm)',
    lbAdhHint: 'Adhesive sheet: print at 100 % (“Actual size”), margins None. Do a test on plain paper first and hold it against the sheet.',
    lbInfoAdh: (f, n, p, nm) => `${f} — ${n} label${n > 1 ? 's' : ''}, ${p} sheet${p > 1 ? 's' : ''} ${nm}`,
    tabDiff: 'Changes', legDiff: 'Compare with an older patch', refBtn: 'Load the older patch…', refHint: 'CSV, or .html sheet (plugin or saved). Fixtures are matched by Fix ID.', diffInSheet: 'Add the changes at the start of the patch sheet',
    refOld: 'Older:', diffNoRef: 'Load the older patch in the left panel to see what changed.', diffTitle: 'Patch changes', diffNone: 'No change between the two patches.',
    kMod: 'changed', kAdd: 'added', kDel: 'removed', kSame: 'unchanged', gMod: 'Changed', gAdd: 'Added', gDel: 'Removed',
    thChange: 'Change', thFrom: 'Before', thTo: 'After', thPatch: 'Patch', dAddr: 'Address', dType: 'Type', dLayer: 'Layer', dName: 'Name', dNch: 'Channels',
    diffInfo: (o, n, p) => `${o} → ${n} — ${p} page${p > 1 ? 's' : ''}`, diffFoot: 'Patch changes', refErr: 'Cannot read the older patch:', refNoCols: 'Columns not recognised in the older file. Open it first as the main patch to choose its columns.',
    mapBtn: 'File columns…', mapTitle: 'File columns', mapHint: 'Tell which column holds what. At least the patch, or the universe and the address, are needed. The choice is remembered for files with the same header.',
    mapAuto: 'Number fixtures that have no number (in address order)', mapReset: 'Automatic detection', mapCancel: 'Cancel', mapApply: 'Apply', mapNeed: 'Choose at least the Patch column, or Universe + Address.', mapNone: '— none —',
    mFid: 'Fix ID', mChid: 'Ch ID', mLayer: 'Layer / group', mName: 'Name', mType: 'Fixture type', mPatch: 'Patch (univ.address)', mUniv: 'Universe (own column)', mAddr: 'Address (own column)', mNch: 'Channel count',
    unknownCols: 'Columns not recognised: choose them in the window that just opened.', noIds: 'No fixture number in the file.', autoNum: 'Number them automatically',
    legPlugins: 'Console plugins', pluginsHint: 'Unzip at the root of the USB stick, then in the console Plugins pool: Import → GiveMeThePatch.', repoLink: 'The project on GitHub',
    save: 'Save the sheet (.html)', saveHint: 'One file with the patch, notes, hidden fixtures and settings. It opens in any browser.', fromSaved: 'Saved sheet', hidePh: 'Fix ID or name…', hideBtn: 'Hide', hideHint: 'Or click a row in the preview to hide it.', unhideAll: 'Show all again', unhide: 'Show again', hideRow: 'Click to hide this fixture', notFound: 'No matching fixture.', stHidden: n => `${n} hidden manually`,
    legFile: 'File', print: 'Print / PDF',
    printHint: 'In the print dialog: destination “Save as PDF” or your printer, margins <b>None</b>, “Background graphics” checked.',
    foot: 'The file is read in your browser: nothing is sent to the server. Give Me The Patch, by Mart1ver.',
    zoom: 'Zoom', noFile: 'No file loaded', emptyMsg: 'Load a patch to start: grandMA2 or grandMA3 export, WYSIWYG, Capture, or a plugin .html sheet.',
    loaded: 'File loaded', fromConsole: 'Patch read from the console', changeFile: 'Click or drop another file to change it',
    readErr: 'Cannot read file', emptyFile: 'Empty file.', noFixtures: 'No fixtures found in the file.',
    noCols: h => `Columns not found. At least a “Patch” column (or “DMX Universe” + “DMX Channel”) is required. Header read: ${h}`,
    noPatched: 'No patched fixtures to display.',
    fixtures: n => `${n} fixture${n > 1 ? 's' : ''}`, cont: '(cont.)',
    thFid: 'Fix ID', thName: 'Name', thType: 'Type', thUniv: 'Univ.', thAddr: 'Addr.', thLayer: 'Layer',
    univ: 'Universe', unpatched: 'Unpatched', secLayer: 'Patch by layer', secUniv: 'Patch by universe',
    warnDup: 'Duplicate start addresses:', warnOvl: 'Overlapping DMX ranges:', warnUnp: n => `${n} unpatched fixture(s):`,
    printed: d => `Printed ${d}`, exported: (d, h) => `Exported ${d} at ${h}`, optExport: 'Show export date',
    kpiFix: 'Fixtures', kpiLayers: 'Layers', kpiUniv: 'DMX universes', kpiTypes: 'Fixture types',
    sumLayer: 'Summary by layer', sumUniv: 'Summary by universe',
    thQty: 'Qty', thTypes: 'Types', thUnivFull: 'Universe', thStart: 'Start addresses', thLayers: 'Layers',
    pageInfo: (f, n, fmt) => `${f} — ${n} page${n > 1 ? 's' : ''} ${fmt} landscape`,
    stFix: 'Fixtures', stLayers: 'Layers', stUniv: 'Universes', stTypes: 'Types',
    alDup: n => `${n} duplicate address(es)`, alOvl: n => `${n} overlapping range(s)`, alUnp: n => `${n} unpatched`, alHidden: ' — hidden on the sheet',
    alOk: '✓ No duplicate start address, everything is patched.',
    defTitle: 'Lighting patch', docTitle: 'Give Me The Patch', locale: 'en-GB',
  },
  es: {
    brandTitle: 'Give Me The Patch', brandSub: 'Patch → hoja y etiquetas para imprimir',
    dropTitle: 'Suelta el patch aquí', dropSub: 'CSV o .html — o haz clic para elegir un archivo',
    legHeader: 'Encabezado', lblTitle: 'Título', lblPlace: 'Lugar / subtítulo', lblNotes: 'Cajetín (texto libre)',
    line1: 'Línea 1', line2: 'Línea 2', line3: 'Línea 3', line4: 'Línea 4',
    legFormat: 'Tamaño de papel (horizontal)', fmtA3: 'A3 · 3 columnas', fmtA4: 'A4 · 2 columnas',
    legContent: 'Contenido', optSumLayer: 'Resumen por layer', optSumUniv: 'Resumen por universo', optSumType: 'Resumen por tipo de aparato', sumType: 'Resumen por tipo', thFxType: 'Tipo de aparato', optLayer: 'Patch por layer', optUniv: 'Patch por universo', optMap: 'Mapa de ocupación de universos', secMap: 'Mapa de ocupación de universos', mapUsed: n => `${n}/512 canales usados`, mapFree: 'Libre:', mapFull: 'Ningún canal libre', mapEst: 'Rayado: número de canales desconocido, rango estimado hasta el siguiente aparato.', mapOvl: 'Rojo: canales en conflicto.', optHide: 'Ocultar los aparatos sin patch', legHidden: 'Aparatos ocultos', tabPatch: 'Hoja de patch', tabLabels: 'Etiquetas', legLabels: 'Etiquetas', lbFid: 'Fix ID', lbPatch: 'Dirección DMX (univ.dir)', lbName: 'Nombre', lbType: 'Tipo de aparato', lbChid: 'Ch ID', lbLayer: 'Nombre del layer (banda)', lbAnn: 'Zona de anotación', lbHint: 'Anotación: haz clic abajo de una etiqueta en la vista previa y escribe.', legColors: 'Layers a imprimir', lcHint: 'Desmarca un layer para no imprimir sus etiquetas. Haz clic en la muestra para cambiar su color.', lcPrint: 'Imprimir las etiquetas de este layer', colorsReset: 'Colores por defecto', annPh: 'nota…', lbInfo: (f, n, p) => `${f} — ${n} etiqueta${n > 1 ? 's' : ''}, ${p} hoja${p > 1 ? 's' : ''} A3`, lbFoot: (p, n) => `Etiquetas · hoja ${p}/${n}`, noLabels: 'Ningún aparato que etiquetar.',
    lbCutGrp: 'A3 para recortar (cinta)', lbAdhGrp: 'Hojas adhesivas A4', lbCustom: 'Otra hoja (introducir sus medidas)…', lbOnly: 'Solo el Fix ID (legible de lejos)',
    cuPage: 'Papel', cuCols: 'Columnas × filas', cuW: 'Ancho de etiqueta (mm)', cuH: 'Alto de etiqueta (mm)', cuLeft: 'Margen izquierdo (mm)', cuTop: 'Margen superior (mm)', cuPx: 'Paso horizontal (mm)', cuPy: 'Paso vertical (mm)',
    lbAdhHint: 'Hoja adhesiva: imprimir al 100 % («Tamaño real»), márgenes Ninguno. Haz antes una prueba en papel normal y compárala a contraluz.',
    lbInfoAdh: (f, n, p, nm) => `${f} — ${n} etiqueta${n > 1 ? 's' : ''}, ${p} hoja${p > 1 ? 's' : ''} ${nm}`,
    tabDiff: 'Cambios', legDiff: 'Comparar con un patch anterior', refBtn: 'Cargar el patch anterior…', refHint: 'CSV, o hoja .html (del plugin o guardada). Los aparatos se reconocen por su Fix ID.', diffInSheet: 'Añadir los cambios al principio de la hoja de patch',
    refOld: 'Anterior:', diffNoRef: 'Carga el patch anterior en el panel izquierdo para ver qué ha cambiado.', diffTitle: 'Cambios de patch', diffNone: 'Ningún cambio entre los dos patches.',
    kMod: 'modificados', kAdd: 'añadidos', kDel: 'eliminados', kSame: 'sin cambios', gMod: 'Modificados', gAdd: 'Añadidos', gDel: 'Eliminados',
    thChange: 'Cambio', thFrom: 'Antes', thTo: 'Después', thPatch: 'Patch', dAddr: 'Dirección', dType: 'Tipo', dLayer: 'Layer', dName: 'Nombre', dNch: 'Canales',
    diffInfo: (o, n, p) => `${o} → ${n} — ${p} página${p > 1 ? 's' : ''}`, diffFoot: 'Cambios de patch', refErr: 'No se puede leer el patch anterior:', refNoCols: 'Columnas no reconocidas en el archivo anterior. Ábrelo primero como patch principal para elegir sus columnas.',
    mapBtn: 'Columnas del archivo…', mapTitle: 'Columnas del archivo', mapHint: 'Indica qué columna contiene qué. Hace falta al menos el patch, o el universo y la dirección. La elección se recuerda para los archivos con el mismo encabezado.',
    mapAuto: 'Numerar los aparatos sin número (en el orden de las direcciones)', mapReset: 'Detección automática', mapCancel: 'Cancelar', mapApply: 'Aplicar', mapNeed: 'Elige al menos la columna Patch, o Universo + Dirección.', mapNone: '— ninguna —',
    mFid: 'Fix ID', mChid: 'Ch ID', mLayer: 'Layer / grupo', mName: 'Nombre', mType: 'Tipo de aparato', mPatch: 'Patch (univ.dirección)', mUniv: 'Universo (columna aparte)', mAddr: 'Dirección (columna aparte)', mNch: 'Número de canales',
    unknownCols: 'Columnas no reconocidas: elígelas en la ventana que se acaba de abrir.', noIds: 'Ningún número de aparato en el archivo.', autoNum: 'Numerar automáticamente',
    legPlugins: 'Plugins para la consola', pluginsHint: 'Descomprimir en la raíz de la memoria USB y, en el pool Plugins de la consola: Import → GiveMeThePatch.', repoLink: 'El proyecto en GitHub',
    save: 'Guardar la hoja (.html)', saveHint: 'Un solo archivo con el patch, las notas, los aparatos ocultos y los ajustes. Se abre en cualquier navegador.', fromSaved: 'Hoja guardada', hidePh: 'Fix ID o nombre…', hideBtn: 'Ocultar', hideHint: 'O haz clic en una fila de la vista previa para ocultarla.', unhideAll: 'Mostrar todo', unhide: 'Mostrar', hideRow: 'Haz clic para ocultar este aparato', notFound: 'Ningún aparato coincide.', stHidden: n => `${n} oculto${n > 1 ? 's' : ''} a mano`,
    legFile: 'Archivo', print: 'Imprimir / PDF',
    printHint: 'En el cuadro de impresión: destino «Guardar como PDF» o la impresora, márgenes <b>Ninguno</b>, «Gráficos de fondo» marcado.',
    foot: 'El archivo se lee en el navegador: no se envía nada al servidor. Give Me The Patch, por Mart1ver.',
    zoom: 'Zoom', noFile: 'Ningún archivo cargado', emptyMsg: 'Carga un patch para empezar: exportación grandMA2 o grandMA3, WYSIWYG, Capture, u hoja .html del plugin.',
    loaded: 'Archivo cargado', fromConsole: 'Patch leído en la consola', changeFile: 'Haz clic o suelta otro archivo para cambiarlo',
    readErr: 'No se puede leer el archivo', emptyFile: 'Archivo vacío.', noFixtures: 'No hay aparatos en el archivo.',
    noCols: h => `Columnas no encontradas. Hace falta al menos una columna «Patch» (o «DMX Universe» + «DMX Channel»). Encabezado leído: ${h}`,
    noPatched: 'Ningún aparato con patch que mostrar.',
    fixtures: n => `${n} aparato${n > 1 ? 's' : ''}`, cont: '(cont.)',
    thFid: 'Fix ID', thName: 'Nombre', thType: 'Tipo', thUniv: 'Univ.', thAddr: 'Dir.', thLayer: 'Layer',
    univ: 'Universo', unpatched: 'Sin patch', secLayer: 'Patch por layer', secUniv: 'Patch por universo',
    warnDup: 'Direcciones de inicio duplicadas:', warnOvl: 'Rangos DMX que se solapan:', warnUnp: n => `${n} aparato(s) sin patch:`,
    printed: d => `Impreso el ${d}`, exported: (d, h) => `Exportado el ${d} a las ${h}`, optExport: 'Mostrar la fecha de exportación',
    kpiFix: 'Aparatos', kpiLayers: 'Layers', kpiUniv: 'Universos DMX', kpiTypes: 'Tipos de aparato',
    sumLayer: 'Resumen por layer', sumUniv: 'Resumen por universo',
    thQty: 'Cant.', thTypes: 'Tipos', thUnivFull: 'Universo', thStart: 'Direcciones de inicio', thLayers: 'Layers',
    pageInfo: (f, n, fmt) => `${f} — ${n} página${n > 1 ? 's' : ''} ${fmt} horizontal`,
    stFix: 'Aparatos', stLayers: 'Layers', stUniv: 'Universos', stTypes: 'Tipos',
    alDup: n => `${n} dirección(es) duplicada(s)`, alOvl: n => `${n} rango(s) solapado(s)`, alUnp: n => `${n} sin patch`, alHidden: ' — ocultos en la hoja',
    alOk: '✓ Ninguna dirección de inicio duplicada, todo tiene patch.',
    defTitle: 'Patch de iluminación', docTitle: 'Give Me The Patch', locale: 'es-ES',
  },
  de: {
    brandTitle: 'Give Me The Patch', brandSub: 'Patch → druckbare Liste und Etiketten',
    dropTitle: 'Patch hier ablegen', dropSub: 'CSV oder .html — oder klicken, um eine Datei zu wählen',
    legHeader: 'Kopfzeile', lblTitle: 'Titel', lblPlace: 'Ort / Untertitel', lblNotes: 'Schriftfeld (freier Text)',
    line1: 'Zeile 1', line2: 'Zeile 2', line3: 'Zeile 3', line4: 'Zeile 4',
    legFormat: 'Papierformat (quer)', fmtA3: 'A3 · 3 Spalten', fmtA4: 'A4 · 2 Spalten',
    legContent: 'Inhalt', optSumLayer: 'Übersicht nach Layer', optSumUniv: 'Übersicht nach Universe', optSumType: 'Übersicht nach Gerätetyp', sumType: 'Übersicht nach Typ', thFxType: 'Gerätetyp', optLayer: 'Patch nach Layer', optUniv: 'Patch nach Universe', optMap: 'Belegungsplan der Universes', secMap: 'Belegungsplan der Universes', mapUsed: n => `${n}/512 Kanäle belegt`, mapFree: 'Frei:', mapFull: 'Kein freier Kanal mehr', mapEst: 'Schraffiert: Kanalanzahl unbekannt, Bereich bis zum nächsten Gerät geschätzt.', mapOvl: 'Rot: Kanäle im Konflikt.', optHide: 'Ungepatchte Geräte ausblenden', legHidden: 'Ausgeblendete Geräte', tabPatch: 'Patchliste', tabLabels: 'Etiketten', legLabels: 'Etiketten', lbFid: 'Fix ID', lbPatch: 'DMX-Adresse (Univ.Adr)', lbName: 'Name', lbType: 'Gerätetyp', lbChid: 'Ch ID', lbLayer: 'Layer-Name (Band)', lbAnn: 'Notizfeld', lbHint: 'Notiz: in der Vorschau unten auf ein Etikett klicken und schreiben.', legColors: 'Zu druckende Layer', lcHint: 'Layer abwählen, um seine Etiketten nicht zu drucken. Auf das Farbfeld klicken, um die Farbe zu ändern.', lcPrint: 'Etiketten dieses Layers drucken', colorsReset: 'Standardfarben', annPh: 'Notiz…', lbInfo: (f, n, p) => `${f} — ${n} Etikett${n > 1 ? 'en' : ''}, ${p} A3-Bogen`, lbFoot: (p, n) => `Etiketten · Bogen ${p}/${n}`, noLabels: 'Keine Geräte zu etikettieren.',
    lbCutGrp: 'A3 zum Ausschneiden (Klebeband)', lbAdhGrp: 'Klebeetiketten-Bögen A4', lbCustom: 'Anderer Bogen (Maße eingeben)…', lbOnly: 'Nur Fix ID (aus der Ferne lesbar)',
    cuPage: 'Papier', cuCols: 'Spalten × Zeilen', cuW: 'Etikettenbreite (mm)', cuH: 'Etikettenhöhe (mm)', cuLeft: 'Rand links (mm)', cuTop: 'Rand oben (mm)', cuPx: 'Abstand horizontal (mm)', cuPy: 'Abstand vertikal (mm)',
    lbAdhHint: 'Klebebogen: mit 100 % drucken („Tatsächliche Größe“), Ränder Keine. Zuerst auf Normalpapier testen und gegen das Licht vergleichen.',
    lbInfoAdh: (f, n, p, nm) => `${f} — ${n} Etikett${n > 1 ? 'en' : ''}, ${p} Bogen ${nm}`,
    tabDiff: 'Änderungen', legDiff: 'Mit einem älteren Patch vergleichen', refBtn: 'Älteren Patch laden…', refHint: 'CSV oder .html-Liste (Plugin oder gespeichert). Geräte werden über ihre Fix ID zugeordnet.', diffInSheet: 'Änderungen an den Anfang der Patchliste setzen',
    refOld: 'Älter:', diffNoRef: 'Älteren Patch im linken Bereich laden, um die Änderungen zu sehen.', diffTitle: 'Patch-Änderungen', diffNone: 'Keine Änderung zwischen den beiden Patches.',
    kMod: 'geändert', kAdd: 'hinzugefügt', kDel: 'entfernt', kSame: 'unverändert', gMod: 'Geändert', gAdd: 'Hinzugefügt', gDel: 'Entfernt',
    thChange: 'Änderung', thFrom: 'Vorher', thTo: 'Nachher', thPatch: 'Patch', dAddr: 'Adresse', dType: 'Typ', dLayer: 'Layer', dName: 'Name', dNch: 'Kanäle',
    diffInfo: (o, n, p) => `${o} → ${n} — ${p} Seite${p > 1 ? 'n' : ''}`, diffFoot: 'Patch-Änderungen', refErr: 'Älterer Patch nicht lesbar:', refNoCols: 'Spalten in der älteren Datei nicht erkannt. Sie zuerst als Haupt-Patch öffnen, um die Spalten zu wählen.',
    mapBtn: 'Spalten der Datei…', mapTitle: 'Spalten der Datei', mapHint: 'Angeben, welche Spalte was enthält. Mindestens der Patch oder Universe und Adresse sind nötig. Die Wahl wird für Dateien mit gleicher Kopfzeile gespeichert.',
    mapAuto: 'Geräte ohne Nummer nummerieren (in Adressreihenfolge)', mapReset: 'Automatische Erkennung', mapCancel: 'Abbrechen', mapApply: 'Übernehmen', mapNeed: 'Mindestens die Spalte Patch oder Universe + Adresse wählen.', mapNone: '— keine —',
    mFid: 'Fix ID', mChid: 'Ch ID', mLayer: 'Layer / Gruppe', mName: 'Name', mType: 'Gerätetyp', mPatch: 'Patch (Univ.Adresse)', mUniv: 'Universe (eigene Spalte)', mAddr: 'Adresse (eigene Spalte)', mNch: 'Kanalanzahl',
    unknownCols: 'Spalten nicht erkannt: im soeben geöffneten Fenster wählen.', noIds: 'Keine Gerätenummer in der Datei.', autoNum: 'Automatisch nummerieren',
    legPlugins: 'Plugins für das Pult', pluginsHint: 'Im Stammverzeichnis des USB-Sticks entpacken, dann im Plugin-Pool des Pults: Import → GiveMeThePatch.', repoLink: 'Das Projekt auf GitHub',
    save: 'Liste speichern (.html)', saveHint: 'Eine einzige Datei mit Patch, Notizen, ausgeblendeten Geräten und Einstellungen. Öffnet sich in jedem Browser.', fromSaved: 'Gespeicherte Liste', hidePh: 'Fix ID oder Name…', hideBtn: 'Ausblenden', hideHint: 'Oder in der Vorschau auf eine Zeile klicken, um sie auszublenden.', unhideAll: 'Alle wieder einblenden', unhide: 'Einblenden', hideRow: 'Klicken, um dieses Gerät auszublenden', notFound: 'Kein passendes Gerät.', stHidden: n => `${n} manuell ausgeblendet`,
    legFile: 'Datei', print: 'Drucken / PDF',
    printHint: 'Im Druckdialog: Ziel „Als PDF speichern“ oder den Drucker, Ränder <b>Keine</b>, „Hintergrundgrafiken“ aktiviert.',
    foot: 'Die Datei wird im Browser gelesen: Es wird nichts an den Server gesendet. Give Me The Patch, von Mart1ver.',
    zoom: 'Zoom', noFile: 'Keine Datei geladen', emptyMsg: 'Patch laden, um zu beginnen: Export aus grandMA2 oder grandMA3, WYSIWYG, Capture oder eine .html-Liste des Plugins.',
    loaded: 'Datei geladen', fromConsole: 'Patch vom Pult gelesen', changeFile: 'Klicken oder andere Datei ablegen, um sie zu wechseln',
    readErr: 'Datei nicht lesbar', emptyFile: 'Leere Datei.', noFixtures: 'Keine Geräte in der Datei gefunden.',
    noCols: h => `Spalten nicht gefunden. Mindestens eine Spalte „Patch“ (oder „DMX Universe“ + „DMX Channel“) ist nötig. Gelesene Kopfzeile: ${h}`,
    noPatched: 'Keine gepatchten Geräte anzuzeigen.',
    fixtures: n => `${n} Gerät${n > 1 ? 'e' : ''}`, cont: '(Forts.)',
    thFid: 'Fix ID', thName: 'Name', thType: 'Typ', thUniv: 'Univ.', thAddr: 'Adr.', thLayer: 'Layer',
    univ: 'Universe', unpatched: 'Ungepatcht', secLayer: 'Patch nach Layer', secUniv: 'Patch nach Universe',
    warnDup: 'Doppelte Startadressen:', warnOvl: 'Überlappende DMX-Bereiche:', warnUnp: n => `${n} ungepatchte(s) Gerät(e):`,
    printed: d => `Gedruckt am ${d}`, exported: (d, h) => `Exportiert am ${d} um ${h}`, optExport: 'Exportdatum anzeigen',
    kpiFix: 'Geräte', kpiLayers: 'Layer', kpiUniv: 'DMX-Universes', kpiTypes: 'Gerätetypen',
    sumLayer: 'Übersicht nach Layer', sumUniv: 'Übersicht nach Universe',
    thQty: 'Anz.', thTypes: 'Typen', thUnivFull: 'Universe', thStart: 'Startadressen', thLayers: 'Layer',
    pageInfo: (f, n, fmt) => `${f} — ${n} Seite${n > 1 ? 'n' : ''} ${fmt} quer`,
    stFix: 'Geräte', stLayers: 'Layer', stUniv: 'Universes', stTypes: 'Typen',
    alDup: n => `${n} doppelte Adresse(n)`, alOvl: n => `${n} überlappende(r) Bereich(e)`, alUnp: n => `${n} ungepatcht`, alHidden: ' — auf der Liste ausgeblendet',
    alOk: '✓ Keine doppelte Startadresse, alles ist gepatcht.',
    defTitle: 'Lichtpatch', docTitle: 'Give Me The Patch', locale: 'de-DE',
  },
  ja: {
    brandTitle: 'Give Me The Patch', brandSub: 'パッチ → 印刷用シートとラベル',
    dropTitle: 'ここにパッチをドロップ', dropSub: 'CSV または .html — クリックしてファイルを選択',
    legHeader: 'ヘッダー', lblTitle: 'タイトル', lblPlace: '会場 / サブタイトル', lblNotes: '表題欄（自由記入）',
    line1: '1行目', line2: '2行目', line3: '3行目', line4: '4行目',
    legFormat: '用紙サイズ（横向き）', fmtA3: 'A3 · 3列', fmtA4: 'A4 · 2列',
    legContent: '内容', optSumLayer: 'レイヤー別集計', optSumUniv: 'ユニバース別集計', optSumType: '機種別集計', sumType: '機種別集計', thFxType: '機種', optLayer: 'レイヤー別パッチ', optUniv: 'ユニバース別パッチ', optMap: 'ユニバース使用状況マップ', secMap: 'ユニバース使用状況マップ', mapUsed: n => `使用 ${n}/512 ch`, mapFree: '空き：', mapFull: '空きチャンネルなし', mapEst: '斜線：チャンネル数不明、次の機材までと推定。', mapOvl: '赤：競合しているチャンネル。', optHide: '未パッチの機材を隠す', legHidden: '非表示の機材', tabPatch: 'パッチシート', tabLabels: 'ラベル', legLabels: 'ラベル', lbFid: 'Fix ID', lbPatch: 'DMXアドレス（univ.addr）', lbName: '名前', lbType: '機種', lbChid: 'Ch ID', lbLayer: 'レイヤー名（帯）', lbAnn: 'メモ欄', lbHint: 'メモ：プレビューでラベルの下部をクリックして入力。', legColors: '印刷するレイヤー', lcHint: 'チェックを外すとそのレイヤーのラベルは印刷されません。色見本をクリックすると色を変更できます。', lcPrint: 'このレイヤーのラベルを印刷', colorsReset: '既定の色', annPh: 'メモ…', lbInfo: (f, n, p) => `${f} — ラベル ${n} 枚、A3 ${p} 枚`, lbFoot: (p, n) => `ラベル · ${p}/${n} 枚目`, noLabels: 'ラベルを作る機材がありません。',
    lbCutGrp: 'A3 切り取り用（テープ貼り）', lbAdhGrp: 'A4 ラベルシール用紙', lbCustom: 'その他の用紙（寸法を入力）…', lbOnly: 'Fix ID のみ（遠くから読める）',
    cuPage: '用紙', cuCols: '列 × 行', cuW: 'ラベル幅 (mm)', cuH: 'ラベル高さ (mm)', cuLeft: '左余白 (mm)', cuTop: '上余白 (mm)', cuPx: '横ピッチ (mm)', cuPy: '縦ピッチ (mm)',
    lbAdhHint: 'ラベル用紙：100 %（実際のサイズ）、余白なしで印刷。まず普通紙で試し、用紙に重ねて透かして確認してください。',
    lbInfoAdh: (f, n, p, nm) => `${f} — ラベル ${n} 枚、${nm} ${p} 枚`,
    tabDiff: '変更点', legDiff: '以前のパッチと比較', refBtn: '以前のパッチを読み込む…', refHint: 'CSV、または .html シート（プラグイン出力または保存版）。機材は Fix ID で照合します。', diffInSheet: '変更点をパッチシートの先頭に追加',
    refOld: '以前：', diffNoRef: '左のパネルで以前のパッチを読み込むと、変更点が表示されます。', diffTitle: 'パッチの変更点', diffNone: '2つのパッチに違いはありません。',
    kMod: '変更', kAdd: '追加', kDel: '削除', kSame: '変更なし', gMod: '変更', gAdd: '追加', gDel: '削除',
    thChange: '変更', thFrom: '変更前', thTo: '変更後', thPatch: 'パッチ', dAddr: 'アドレス', dType: '機種', dLayer: 'レイヤー', dName: '名前', dNch: 'チャンネル数',
    diffInfo: (o, n, p) => `${o} → ${n} — ${p} ページ`, diffFoot: 'パッチの変更点', refErr: '以前のパッチを読み込めません：', refNoCols: '以前のファイルの列を認識できません。先にメインのパッチとして開き、列を選択してください。',
    mapBtn: 'ファイルの列…', mapTitle: 'ファイルの列', mapHint: 'どの列に何が入っているか指定してください。少なくともパッチ、またはユニバースとアドレスが必要です。同じヘッダーのファイルでは選択が記憶されます。',
    mapAuto: '番号のない機材に番号を振る（アドレス順）', mapReset: '自動検出', mapCancel: 'キャンセル', mapApply: '適用', mapNeed: '少なくとも Patch 列、またはユニバース + アドレスを選んでください。', mapNone: '— なし —',
    mFid: 'Fix ID', mChid: 'Ch ID', mLayer: 'レイヤー / グループ', mName: '名前', mType: '機種', mPatch: 'パッチ（univ.アドレス）', mUniv: 'ユニバース（別の列）', mAddr: 'アドレス（別の列）', mNch: 'チャンネル数',
    unknownCols: '列を認識できません：開いたウィンドウで選択してください。', noIds: 'ファイルに機材番号がありません。', autoNum: '自動で番号を振る',
    legPlugins: '卓用プラグイン', pluginsHint: 'USBメモリのルートに解凍し、卓の Plugins プールで Import → GiveMeThePatch。', repoLink: 'GitHub のプロジェクト',
    save: 'シートを保存 (.html)', saveHint: 'パッチ、メモ、非表示の機材、設定をまとめた1つのファイル。どのブラウザでも開けます。', fromSaved: '保存されたシート', hidePh: 'Fix ID または名前…', hideBtn: '隠す', hideHint: 'またはプレビューの行をクリックして隠す。', unhideAll: 'すべて再表示', unhide: '再表示', hideRow: 'クリックでこの機材を隠す', notFound: '一致する機材がありません。', stHidden: n => `手動で ${n} 台を非表示`,
    legFile: 'ファイル', print: '印刷 / PDF',
    printHint: '印刷ダイアログで：送信先「PDFに保存」またはプリンター、余白<b>なし</b>、「背景のグラフィック」にチェック。',
    foot: 'ファイルはブラウザ内で読み込まれ、サーバーには何も送信されません。Give Me The Patch — Mart1ver 作。',
    zoom: 'ズーム', noFile: 'ファイル未読み込み', emptyMsg: 'パッチを読み込んで始めます：grandMA2 / grandMA3 のエクスポート、WYSIWYG、Capture、またはプラグインの .html シート。',
    loaded: '読み込み済み', fromConsole: '卓から読み取ったパッチ', changeFile: 'クリックまたは別のファイルをドロップして変更',
    readErr: 'ファイルを読み込めません', emptyFile: 'ファイルが空です。', noFixtures: 'ファイルに機材がありません。',
    noCols: h => `列が見つかりません。少なくとも「Patch」列（または「DMX Universe」+「DMX Channel」）が必要です。読み取ったヘッダー：${h}`,
    noPatched: '表示するパッチ済みの機材がありません。',
    fixtures: n => `${n} 台`, cont: '（続き）',
    thFid: 'Fix ID', thName: '名前', thType: '機種', thUniv: 'Univ.', thAddr: 'Addr.', thLayer: 'レイヤー',
    univ: 'ユニバース', unpatched: '未パッチ', secLayer: 'レイヤー別パッチ', secUniv: 'ユニバース別パッチ',
    warnDup: '開始アドレスの重複：', warnOvl: '重なっているDMX範囲：', warnUnp: n => `未パッチの機材 ${n} 台：`,
    printed: d => `印刷日 ${d}`, exported: (d, h) => `エクスポート ${d} ${h}`, optExport: 'エクスポート日時を表示',
    kpiFix: '機材', kpiLayers: 'レイヤー', kpiUniv: 'DMXユニバース', kpiTypes: '機種',
    sumLayer: 'レイヤー別集計', sumUniv: 'ユニバース別集計',
    thQty: '数', thTypes: '機種', thUnivFull: 'ユニバース', thStart: '開始アドレス', thLayers: 'レイヤー',
    pageInfo: (f, n, fmt) => `${f} — ${fmt} 横 ${n} ページ`,
    stFix: '機材', stLayers: 'レイヤー', stUniv: 'ユニバース', stTypes: '機種',
    alDup: n => `重複アドレス ${n} 件`, alOvl: n => `範囲の重なり ${n} 件`, alUnp: n => `未パッチ ${n} 台`, alHidden: ' — シートでは非表示',
    alOk: '✓ 開始アドレスの重複なし、すべてパッチ済み。',
    defTitle: '照明パッチ', docTitle: 'Give Me The Patch', locale: 'ja-JP',
  },
  ru: {
    brandTitle: 'Give Me The Patch', brandSub: 'Патч → таблица и этикетки для печати',
    dropTitle: 'Перетащите патч сюда', dropSub: 'CSV или .html — или нажмите, чтобы выбрать файл',
    legHeader: 'Заголовок', lblTitle: 'Название', lblPlace: 'Площадка / подзаголовок', lblNotes: 'Штамп (свободный текст)',
    line1: 'Строка 1', line2: 'Строка 2', line3: 'Строка 3', line4: 'Строка 4',
    legFormat: 'Формат бумаги (альбомный)', fmtA3: 'A3 · 3 колонки', fmtA4: 'A4 · 2 колонки',
    legContent: 'Содержание', optSumLayer: 'Сводка по слоям', optSumUniv: 'Сводка по юниверсам', optSumType: 'Сводка по типам приборов', sumType: 'Сводка по типам', thFxType: 'Тип прибора', optLayer: 'Патч по слоям', optUniv: 'Патч по юниверсам', optMap: 'Карта занятости юниверсов', secMap: 'Карта занятости юниверсов', mapUsed: n => `занято каналов: ${n}/512`, mapFree: 'Свободно:', mapFull: 'Свободных каналов нет', mapEst: 'Штриховка: число каналов неизвестно, диапазон оценён до следующего прибора.', mapOvl: 'Красный: каналы в конфликте.', optHide: 'Скрыть незапатченные приборы', legHidden: 'Скрытые приборы', tabPatch: 'Патч-лист', tabLabels: 'Этикетки', legLabels: 'Этикетки', lbFid: 'Fix ID', lbPatch: 'DMX-адрес (univ.addr)', lbName: 'Имя', lbType: 'Тип прибора', lbChid: 'Ch ID', lbLayer: 'Имя слоя (полоса)', lbAnn: 'Поле для заметки', lbHint: 'Заметка: нажмите внизу этикетки в предпросмотре и пишите.', legColors: 'Слои для печати', lcHint: 'Снимите отметку со слоя, чтобы не печатать его этикетки. Нажмите на образец цвета, чтобы изменить цвет.', lcPrint: 'Печатать этикетки этого слоя', colorsReset: 'Цвета по умолчанию', annPh: 'заметка…', lbInfo: (f, n, p) => `${f} — этикеток: ${n}, листов A3: ${p}`, lbFoot: (p, n) => `Этикетки · лист ${p}/${n}`, noLabels: 'Нет приборов для этикеток.',
    lbCutGrp: 'A3 для вырезания (скотч)', lbAdhGrp: 'Листы самоклеящихся этикеток A4', lbCustom: 'Другой лист (ввести размеры)…', lbOnly: 'Только Fix ID (читается издалека)',
    cuPage: 'Бумага', cuCols: 'Колонки × ряды', cuW: 'Ширина этикетки (мм)', cuH: 'Высота этикетки (мм)', cuLeft: 'Отступ слева (мм)', cuTop: 'Отступ сверху (мм)', cuPx: 'Шаг по горизонтали (мм)', cuPy: 'Шаг по вертикали (мм)',
    lbAdhHint: 'Самоклеящийся лист: печатать в масштабе 100 % («Фактический размер»), поля «Нет». Сначала сделайте пробу на обычной бумаге и сравните на просвет.',
    lbInfoAdh: (f, n, p, nm) => `${f} — этикеток: ${n}, листов ${nm}: ${p}`,
    tabDiff: 'Изменения', legDiff: 'Сравнить с прежним патчем', refBtn: 'Загрузить прежний патч…', refHint: 'CSV или лист .html (плагин или сохранённый). Приборы сопоставляются по Fix ID.', diffInSheet: 'Добавить изменения в начало патч-листа',
    refOld: 'Прежний:', diffNoRef: 'Загрузите прежний патч на левой панели, чтобы увидеть изменения.', diffTitle: 'Изменения патча', diffNone: 'Между двумя патчами нет изменений.',
    kMod: 'изменено', kAdd: 'добавлено', kDel: 'удалено', kSame: 'без изменений', gMod: 'Изменено', gAdd: 'Добавлено', gDel: 'Удалено',
    thChange: 'Изменение', thFrom: 'Было', thTo: 'Стало', thPatch: 'Патч', dAddr: 'Адрес', dType: 'Тип', dLayer: 'Слой', dName: 'Имя', dNch: 'Каналы',
    diffInfo: (o, n, p) => `${o} → ${n} — страниц: ${p}`, diffFoot: 'Изменения патча', refErr: 'Не удаётся прочитать прежний патч:', refNoCols: 'Колонки в прежнем файле не распознаны. Сначала откройте его как основной патч и выберите колонки.',
    mapBtn: 'Колонки файла…', mapTitle: 'Колонки файла', mapHint: 'Укажите, что содержит каждая колонка. Нужен как минимум патч или юниверс и адрес. Выбор запоминается для файлов с тем же заголовком.',
    mapAuto: 'Пронумеровать приборы без номера (по порядку адресов)', mapReset: 'Автоопределение', mapCancel: 'Отмена', mapApply: 'Применить', mapNeed: 'Выберите хотя бы колонку Patch или Юниверс + Адрес.', mapNone: '— нет —',
    mFid: 'Fix ID', mChid: 'Ch ID', mLayer: 'Слой / группа', mName: 'Имя', mType: 'Тип прибора', mPatch: 'Патч (univ.адрес)', mUniv: 'Юниверс (отдельная колонка)', mAddr: 'Адрес (отдельная колонка)', mNch: 'Число каналов',
    unknownCols: 'Колонки не распознаны: выберите их в открывшемся окне.', noIds: 'В файле нет номеров приборов.', autoNum: 'Пронумеровать автоматически',
    legPlugins: 'Плагины для пульта', pluginsHint: 'Распакуйте в корень USB-накопителя, затем в пуле Plugins пульта: Import → GiveMeThePatch.', repoLink: 'Проект на GitHub',
    save: 'Сохранить лист (.html)', saveHint: 'Один файл с патчем, заметками, скрытыми приборами и настройками. Открывается в любом браузере.', fromSaved: 'Сохранённый лист', hidePh: 'Fix ID или имя…', hideBtn: 'Скрыть', hideHint: 'Или нажмите на строку в предпросмотре, чтобы скрыть её.', unhideAll: 'Показать все', unhide: 'Показать', hideRow: 'Нажмите, чтобы скрыть этот прибор', notFound: 'Подходящий прибор не найден.', stHidden: n => `Скрыто вручную: ${n}`,
    legFile: 'Файл', print: 'Печать / PDF',
    printHint: 'В окне печати: назначение «Сохранить как PDF» или принтер, поля <b>Нет</b>, отметить «Фоновая графика».',
    foot: 'Файл читается в браузере: на сервер ничего не отправляется. Give Me The Patch, автор Mart1ver.',
    zoom: 'Масштаб', noFile: 'Файл не загружен', emptyMsg: 'Загрузите патч, чтобы начать: экспорт grandMA2 или grandMA3, WYSIWYG, Capture или лист .html плагина.',
    loaded: 'Файл загружен', fromConsole: 'Патч прочитан с пульта', changeFile: 'Нажмите или перетащите другой файл, чтобы заменить',
    readErr: 'Не удаётся прочитать файл', emptyFile: 'Пустой файл.', noFixtures: 'В файле нет приборов.',
    noCols: h => `Колонки не найдены. Нужна как минимум колонка «Patch» (или «DMX Universe» + «DMX Channel»). Прочитанный заголовок: ${h}`,
    noPatched: 'Нет запатченных приборов для показа.',
    fixtures: n => { const a = n % 10, b = n % 100; return `${n} ${a === 1 && b !== 11 ? 'прибор' : a >= 2 && a <= 4 && (b < 12 || b > 14) ? 'прибора' : 'приборов'}`; }, cont: '(продолж.)',
    thFid: 'Fix ID', thName: 'Имя', thType: 'Тип', thUniv: 'Univ.', thAddr: 'Адр.', thLayer: 'Слой',
    univ: 'Юниверс', unpatched: 'Без патча', secLayer: 'Патч по слоям', secUniv: 'Патч по юниверсам',
    warnDup: 'Повторяющиеся стартовые адреса:', warnOvl: 'Перекрывающиеся DMX-диапазоны:', warnUnp: n => `Приборов без патча: ${n}:`,
    printed: d => `Напечатано ${d}`, exported: (d, h) => `Экспорт ${d} в ${h}`, optExport: 'Показывать дату экспорта',
    kpiFix: 'Приборы', kpiLayers: 'Слои', kpiUniv: 'DMX-юниверсы', kpiTypes: 'Типы приборов',
    sumLayer: 'Сводка по слоям', sumUniv: 'Сводка по юниверсам',
    thQty: 'Кол.', thTypes: 'Типы', thUnivFull: 'Юниверс', thStart: 'Стартовые адреса', thLayers: 'Слои',
    pageInfo: (f, n, fmt) => `${f} — страниц ${fmt} (альбомная): ${n}`,
    stFix: 'Приборы', stLayers: 'Слои', stUniv: 'Юниверсы', stTypes: 'Типы',
    alDup: n => `Повторяющихся адресов: ${n}`, alOvl: n => `Перекрытий диапазонов: ${n}`, alUnp: n => `Без патча: ${n}`, alHidden: ' — скрыты в листе',
    alOk: '✓ Нет повторяющихся стартовых адресов, всё запатчено.',
    defTitle: 'Световой патч', docTitle: 'Give Me The Patch', locale: 'ru-RU',
  },
  ar: {
    brandTitle: 'Give Me The Patch', brandSub: 'الباتش ← جدول وملصقات للطباعة',
    dropTitle: 'أفلت ملف الباتش هنا', dropSub: 'CSV أو ‎.html — أو انقر لاختيار ملف',
    legHeader: 'الترويسة', lblTitle: 'العنوان', lblPlace: 'المكان / عنوان فرعي', lblNotes: 'خانة البيانات (نص حر)',
    line1: 'السطر 1', line2: 'السطر 2', line3: 'السطر 3', line4: 'السطر 4',
    legFormat: 'حجم الورق (أفقي)', fmtA3: 'A3 · ‏3 أعمدة', fmtA4: 'A4 · ‏عمودان',
    legContent: 'المحتوى', optSumLayer: 'ملخص حسب الطبقة', optSumUniv: 'ملخص حسب اليونيفرس', optSumType: 'ملخص حسب نوع الجهاز', sumType: 'ملخص حسب النوع', thFxType: 'نوع الجهاز', optLayer: 'الباتش حسب الطبقة', optUniv: 'الباتش حسب اليونيفرس', optMap: 'خريطة إشغال اليونيفرسات', secMap: 'خريطة إشغال اليونيفرسات', mapUsed: n => `القنوات المستخدمة: ${n}/512`, mapFree: 'متاح:', mapFull: 'لا توجد قنوات متاحة', mapEst: 'مخطط: عدد القنوات غير معروف، والنطاق تقديري حتى الجهاز التالي.', mapOvl: 'أحمر: قنوات متعارضة.', optHide: 'إخفاء الأجهزة غير الموصولة', legHidden: 'الأجهزة المخفية', tabPatch: 'جدول الباتش', tabLabels: 'الملصقات', legLabels: 'الملصقات', lbFid: 'Fix ID', lbPatch: 'عنوان DMX ‏(univ.addr)', lbName: 'الاسم', lbType: 'نوع الجهاز', lbChid: 'Ch ID', lbLayer: 'اسم الطبقة (الشريط)', lbAnn: 'مساحة للملاحظة', lbHint: 'ملاحظة: انقر أسفل الملصق في المعاينة واكتب.', legColors: 'الطبقات المراد طباعتها', lcHint: 'ألغِ تحديد طبقة لعدم طباعة ملصقاتها. انقر على عيّنة اللون لتغييره.', lcPrint: 'طباعة ملصقات هذه الطبقة', colorsReset: 'الألوان الافتراضية', annPh: 'ملاحظة…', lbInfo: (f, n, p) => `${f} — الملصقات: ${n}، أوراق A3: ${p}`, lbFoot: (p, n) => `الملصقات · الورقة ${p}/${n}`, noLabels: 'لا توجد أجهزة لوضع ملصقات عليها.',
    lbCutGrp: 'A3 للقص (بشريط لاصق)', lbAdhGrp: 'أوراق ملصقات لاصقة A4', lbCustom: 'ورقة أخرى (أدخل أبعادها)…', lbOnly: 'Fix ID فقط (يُقرأ من بعيد)',
    cuPage: 'الورق', cuCols: 'أعمدة × صفوف', cuW: 'عرض الملصق (مم)', cuH: 'ارتفاع الملصق (مم)', cuLeft: 'الهامش الأيسر (مم)', cuTop: 'الهامش العلوي (مم)', cuPx: 'الخطوة الأفقية (مم)', cuPy: 'الخطوة العمودية (مم)',
    lbAdhHint: 'ورقة لاصقة: اطبع بنسبة 100 % («الحجم الفعلي») وبدون هوامش. جرّب أولاً على ورق عادي وقارنه بالورقة في الضوء.',
    lbInfoAdh: (f, n, p, nm) => `${f} — الملصقات: ${n}، أوراق ${nm}: ${p}`,
    tabDiff: 'التغييرات', legDiff: 'المقارنة مع باتش سابق', refBtn: 'تحميل الباتش السابق…', refHint: 'ملف CSV أو جدول ‎.html (من الإضافة أو محفوظ). تتم مطابقة الأجهزة حسب Fix ID.', diffInSheet: 'إضافة التغييرات في بداية جدول الباتش',
    refOld: 'السابق:', diffNoRef: 'حمّل الباتش السابق من اللوحة الجانبية لرؤية ما تغيّر.', diffTitle: 'تغييرات الباتش', diffNone: 'لا توجد تغييرات بين الباتشين.',
    kMod: 'معدّلة', kAdd: 'مضافة', kDel: 'محذوفة', kSame: 'دون تغيير', gMod: 'معدّلة', gAdd: 'مضافة', gDel: 'محذوفة',
    thChange: 'التغيير', thFrom: 'قبل', thTo: 'بعد', thPatch: 'الباتش', dAddr: 'العنوان', dType: 'النوع', dLayer: 'الطبقة', dName: 'الاسم', dNch: 'القنوات',
    diffInfo: (o, n, p) => `${o} ← ${n} — الصفحات: ${p}`, diffFoot: 'تغييرات الباتش', refErr: 'تعذّرت قراءة الباتش السابق:', refNoCols: 'لم يتم التعرف على أعمدة الملف السابق. افتحه أولاً كباتش رئيسي لاختيار أعمدته.',
    mapBtn: 'أعمدة الملف…', mapTitle: 'أعمدة الملف', mapHint: 'حدّد محتوى كل عمود. يلزم على الأقل الباتش، أو اليونيفرس والعنوان. يُحفظ الاختيار للملفات ذات الترويسة نفسها.',
    mapAuto: 'ترقيم الأجهزة التي ليس لها رقم (بترتيب العناوين)', mapReset: 'الكشف التلقائي', mapCancel: 'إلغاء', mapApply: 'تطبيق', mapNeed: 'اختر على الأقل عمود Patch، أو اليونيفرس + العنوان.', mapNone: '— لا شيء —',
    mFid: 'Fix ID', mChid: 'Ch ID', mLayer: 'الطبقة / المجموعة', mName: 'الاسم', mType: 'نوع الجهاز', mPatch: 'الباتش (univ.العنوان)', mUniv: 'اليونيفرس (عمود منفصل)', mAddr: 'العنوان (عمود منفصل)', mNch: 'عدد القنوات',
    unknownCols: 'لم يتم التعرف على الأعمدة: اخترها في النافذة التي فُتحت للتو.', noIds: 'لا توجد أرقام أجهزة في الملف.', autoNum: 'ترقيم تلقائي',
    legPlugins: 'إضافات لوحة التحكم', pluginsHint: 'فك الضغط في جذر ذاكرة USB، ثم في مجمع Plugins في لوحة التحكم: Import ← GiveMeThePatch.', repoLink: 'المشروع على GitHub',
    save: 'حفظ الجدول (‎.html)', saveHint: 'ملف واحد يضم الباتش والملاحظات والأجهزة المخفية والإعدادات. يُفتح في أي متصفح.', fromSaved: 'جدول محفوظ', hidePh: 'Fix ID أو الاسم…', hideBtn: 'إخفاء', hideHint: 'أو انقر على سطر في المعاينة لإخفائه.', unhideAll: 'إظهار الكل', unhide: 'إظهار', hideRow: 'انقر لإخفاء هذا الجهاز', notFound: 'لا يوجد جهاز مطابق.', stHidden: n => `مخفية يدوياً: ${n}`,
    legFile: 'الملف', print: 'طباعة / PDF',
    printHint: 'في نافذة الطباعة: الوجهة «حفظ بتنسيق PDF» أو الطابعة، الهوامش <b>بلا</b>، مع تحديد «رسومات الخلفية».',
    foot: 'يُقرأ الملف داخل المتصفح: لا يُرسل أي شيء إلى الخادم. Give Me The Patch، من تطوير Mart1ver.',
    zoom: 'تكبير', noFile: 'لم يتم تحميل ملف', emptyMsg: 'حمّل باتش للبدء: تصدير grandMA2 أو grandMA3، أو WYSIWYG، أو Capture، أو جدول ‎.html من الإضافة.',
    loaded: 'تم تحميل الملف', fromConsole: 'باتش مقروء من لوحة التحكم', changeFile: 'انقر أو أفلت ملفاً آخر لتغييره',
    readErr: 'تعذّرت قراءة الملف', emptyFile: 'الملف فارغ.', noFixtures: 'لا توجد أجهزة في الملف.',
    noCols: h => `لم يتم العثور على الأعمدة. يلزم على الأقل عمود «Patch» (أو «DMX Universe» + «DMX Channel»). الترويسة المقروءة: ${h}`,
    noPatched: 'لا توجد أجهزة موصولة لعرضها.',
    fixtures: n => `الأجهزة: ${n}`, cont: '(تابع)',
    thFid: 'Fix ID', thName: 'الاسم', thType: 'النوع', thUniv: 'Univ.', thAddr: 'Addr.', thLayer: 'الطبقة',
    univ: 'يونيفرس', unpatched: 'غير موصولة', secLayer: 'الباتش حسب الطبقة', secUniv: 'الباتش حسب اليونيفرس',
    warnDup: 'عناوين بداية مكررة:', warnOvl: 'نطاقات DMX متداخلة:', warnUnp: n => `أجهزة غير موصولة (${n}):`,
    printed: d => `طُبع في ${d}`, exported: (d, h) => `صُدّر في ${d} الساعة ${h}`, optExport: 'إظهار تاريخ التصدير',
    kpiFix: 'الأجهزة', kpiLayers: 'الطبقات', kpiUniv: 'يونيفرسات DMX', kpiTypes: 'أنواع الأجهزة',
    sumLayer: 'ملخص حسب الطبقة', sumUniv: 'ملخص حسب اليونيفرس',
    thQty: 'العدد', thTypes: 'الأنواع', thUnivFull: 'يونيفرس', thStart: 'عناوين البداية', thLayers: 'الطبقات',
    pageInfo: (f, n, fmt) => `${f} — الصفحات: ${n} (${fmt} أفقي)`,
    stFix: 'الأجهزة', stLayers: 'الطبقات', stUniv: 'اليونيفرسات', stTypes: 'الأنواع',
    alDup: n => `عناوين مكررة: ${n}`, alOvl: n => `نطاقات متداخلة: ${n}`, alUnp: n => `غير موصولة: ${n}`, alHidden: ' — مخفية في الجدول',
    alOk: '✓ لا توجد عناوين بداية مكررة، وكل الأجهزة موصولة.',
    defTitle: 'باتش الإضاءة', docTitle: 'Give Me The Patch', locale: 'ar-u-nu-latn',
  },
};
let LANG = store.get('lang', (navigator.language || 'fr').slice(0, 2).toLowerCase());
if (!I18N[LANG]) LANG = 'en';
const t = (k, ...a) => { const v = I18N[LANG][k] ?? I18N.fr[k]; return typeof v === 'function' ? v(...a) : v; };
function applyI18n() {
  document.documentElement.lang = LANG;
  document.querySelectorAll('[data-i18n]').forEach(el => { el.textContent = t(el.dataset.i18n); });
  document.querySelectorAll('[data-i18n-html]').forEach(el => { el.innerHTML = t(el.dataset.i18nHtml); });
  document.querySelectorAll('[data-i18n-ph]').forEach(el => { el.placeholder = t(el.dataset.i18nPh); el.setAttribute('aria-label', t(el.dataset.i18nPh)); });
  document.querySelectorAll('[data-i18n-title]').forEach(el => { el.title = t(el.dataset.i18nTitle); });
  document.querySelectorAll('[data-i18n-label]').forEach(el => { el.label = t(el.dataset.i18nLabel); });
  document.documentElement.dir = LANG === 'ar' ? 'rtl' : 'ltr';
  $('#lang').value = LANG;
}

const state = { fx: null, fileName: '', fmt: store.get('fmt', 'A3'), label: null, exported: null, hidden: new Set() };
// identifiant stable d'un projecteur (pour le masquage à la main)
const fxKey = f => f.id ? 'id:' + f.id : 'np:' + f.name + '@' + (f.univ ?? '') + '.' + (f.addr ?? '');
const fxLabel = f => `${f.id || '—'} · ${f.name || '?'} (${f.layer})`;
const hiddenStoreKey = () => 'hidden:' + state.fileName;
state.tab = store.get('tab', 'patch');
state.lbSize = store.get('lbSize', '40x30');
state.notes = {};
state.colors = store.get('lcolors', {});
const notesStoreKey = () => 'notes:' + state.fileName;
const lbOffKey = () => 'lboff:' + state.fileName;
state.lbOff = new Set();
state.ref = null;      // ancien patch pour la comparaison
state.src = null;      // fichier courant : { text, rows, name, labelKey, exported }
state.map = null;
// palette lisible à l'impression, une couleur par layer
const PALETTE = ['#e6194b', '#3cb44b', '#4363d8', '#f58231', '#911eb4', '#42d4f4', '#f032e6', '#9a6324', '#469990', '#ffe119',
                 '#800000', '#000075', '#bfef45', '#808000', '#fabed4', '#dcbeff', '#aaffc3', '#ffd8b1', '#a9a9a9', '#000000'];
const textOn = hex => { const n = parseInt(hex.slice(1), 16), r = n >> 16, g = (n >> 8) & 255, b = n & 255;
  return (0.299 * r + 0.587 * g + 0.114 * b) > 150 ? '#111' : '#fff'; };

// ───────────── lecture CSV ─────────────
const ALIASES = {
  layer: ['layer', 'calque', 'groupe', 'position'],          // position : WYSIWYG (perche, pont…)
  fid:   ['fixid', 'fixtureid', 'fix', 'fid', 'spot'],       // spot : n° de projecteur WYSIWYG
  chid:  ['chid', 'channelid', 'channel', 'ch'],
  name:  ['name', 'nom', 'label', 'location'],               // location : Capture (perche, pont…)
  type:  ['fixturetype', 'type', 'fixture'],
  patch: ['patch', 'address', 'adresse', 'dmx', 'dmxaddress'],
  univ:  ['dmxuniverse', 'universe', 'univers'],               // Capture : univers et adresse séparés
  addr:  ['dmxchannel', 'startaddress', 'adressedmx'],
  nch:   ['ofdatachannels', 'datachannels', 'dmxchannels', 'channels', 'footprint', 'nbcanaux', 'canaux'], // WYSIWYG : « # of Data Channels »
};
const norm = h => String(h || '').trim().toLowerCase().replace(/[^a-z0-9]/g, '');

function decode(buf) {
  const b = new Uint8Array(buf);
  if (b[0] === 0xFF && b[1] === 0xFE) return new TextDecoder('utf-16le').decode(buf);
  if (b[0] === 0xFE && b[1] === 0xFF) return new TextDecoder('utf-16be').decode(buf);
  try { return new TextDecoder('utf-8', { fatal: true }).decode(buf).replace(/^﻿/, ''); }
  catch { return new TextDecoder('windows-1252').decode(buf); }
}

// analyseur de secours si PapaParse n'a pas pu être chargé (champs entre guillemets gérés)
function miniCSV(text, d) {
  const rows = []; let row = [], f = '', q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) {
      if (c === '"') { if (text[i + 1] === '"') { f += '"'; i++; } else q = false; }
      else f += c;
    } else if (c === '"') q = true;
    else if (c === d) { row.push(f); f = ''; }
    else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(f); f = '';
      if (row.some(x => x.trim())) rows.push(row);
      row = [];
    } else f += c;
  }
  row.push(f); if (row.some(x => x.trim())) rows.push(row);
  return rows;
}

function readRows(text) {
  const first = text.split(/\r?\n/)[0] || '';
  const delim = [';', ',', '\t'].reduce((a, d) => (first.split(d).length > first.split(a).length ? d : a), ';');
  const rows = window.Papa
    ? Papa.parse(text, { delimiter: delim, skipEmptyLines: 'greedy' }).data
    : miniCSV(text, delim);
  if (!rows.length) throw new Error(t('emptyFile'));
  return rows;
}
// correspondance des colonnes : { idx: { champ: n° de colonne }, autonum }
const headSig = head => 'map:' + head.map(norm).join('|');
function autoMap(head) {
  const h = head.map(norm), idx = {};
  for (const [k, names] of Object.entries(ALIASES)) {
    for (const n of names) { const i = h.indexOf(n); if (i >= 0) { idx[k] = i; break; } }
  }
  return { idx, autonum: false };
}
const mapUsable = m => !!(m && m.idx && ('patch' in m.idx || ('univ' in m.idx && 'addr' in m.idx)));
const mapFor = head => { const m = store.get(headSig(head), null); return mapUsable(m) ? m : autoMap(head); };
function records(rows, idx) {
  const split = !('patch' in idx);
  return rows.slice(1).filter(r => r.some(c => String(c).trim())).map(r => {
    const o = {};
    for (const k of Object.keys(ALIASES)) o[k] = k in idx ? String(r[idx[k]] ?? '').trim() : '';
    if (split && o.univ && o.addr) o.patch = o.univ + '.' + o.addr;
    return o;
  });
}
// feuille .html (plugin ou enregistrée) → { csv, meta } ; un CSV est renvoyé tel quel
function unwrap(text) {
  if (!/^\s*<(!doctype|html)/i.test(text)) return { csv: text, meta: null };
  const grab = name => {
    const i = text.indexOf('window.' + name + '=');
    if (i < 0) return null;
    const j = i + name.length + 8, end = text.indexOf(';window.', j), end2 = text.indexOf(';<' + '/script>', j);
    const stop = [end, end2].filter(x => x > 0).sort((a, b) => a - b)[0];
    try { return JSON.parse(text.slice(j, stop)); } catch { return null; }
  };
  const csv = grab('EMBEDDED_CSV');
  if (typeof csv !== 'string') throw new Error(t('noFixtures'));
  return { csv, meta: grab('EMBEDDED_META'), st: grab('EMBEDDED_STATE') };
}

// ───────────── normalisation ─────────────
const splitType = t => { const m = /^\s*(\d+)\s+(.*?)\s*\(\d+\)\s*$/.exec(t); return m ? m[2] : t.trim(); };
const shortType = t => t.replace(/\s*-\s*Standard\s+16\s*bit/i, ' Std 16 bit').replace(/\s+(\d+)\s+channels?$/i, ' $1 ch').replace(/\s+00$/, '');
function parsePatch(p) {
  p = (p || '').trim();
  let m = /(\d+)\s*\.\s*(\d+)/.exec(p);
  if (m) return [+m[1], +m[2]];
  m = /^(\d+)$/.exec(p);
  if (m && +m[1] > 0) { const n = +m[1]; return [Math.floor((n - 1) / 512) + 1, (n - 1) % 512 + 1]; }
  return [null, null];
}
const numKey = s => { const n = parseFloat(s); return isNaN(n) || !/^\s*-?\d/.test(s) ? [1, 0, s || ''] : [0, n, '']; };
const cmpKey = (a, b) => a[0] - b[0] || a[1] - b[1] || String(a[2]).localeCompare(String(b[2]));

function prepare(rows, autonum = false) {
  const fx = rows.map(r => {
    const [u, a] = parsePatch(r.patch);
    const tname = splitType(r.type);
    return {
      id: r.fid || (r.chid ? 'Ch ' + r.chid : ''),
      key: (r.fid || r.chid) ? numKey(r.fid || r.chid) : [2, u === null ? 1e9 : u * 1000 + a, ''], // sans n° : tri par adresse
      layer: (r.layer || '(sans layer)').toUpperCase(),
      name: r.name || tname, tname, tshort: shortType(tname), univ: u, addr: a,
      nch: parseInt(r.nch, 10) || 0,
    };
  });
  if (autonum) {
    // numéros à la suite du plus grand numéro existant, dans l'ordre des adresses
    let n = Math.floor(Math.max(0, ...fx.filter(f => f.id).map(f => parseFloat(f.id) || 0)));
    fx.filter(f => !f.id).sort((a, b) => cmpKey(a.key, b.key)).forEach(f => { f.id = String(++n); f.key = numKey(f.id); });
  }
  return fx;
}

// ───────────── analyse ─────────────
function analyse(fx) {
  const layerMin = new Map();
  for (const f of fx) { const k = layerMin.get(f.layer); if (!k || cmpKey(f.key, k) < 0) layerMin.set(f.layer, f.key); }
  const layers = [...layerMin.keys()].sort((a, b) => cmpKey(layerMin.get(a), layerMin.get(b)));
  const patched = fx.filter(f => f.univ !== null), unpatched = fx.filter(f => f.univ === null);
  const univs = [...new Set(patched.map(f => f.univ))].sort((a, b) => a - b);
  const seen = new Map(), dups = [];
  for (const f of patched) { const k = f.univ + '.' + f.addr; if (seen.has(k)) dups.push([f.univ, f.addr, seen.get(k), f.id]); else seen.set(k, f.id); }
  // chevauchements de plages (seulement si le fichier donne le nombre de canaux, ex. WYSIWYG)
  const overlaps = [];
  const byU = [...patched].filter(f => f.nch > 0).sort((a, b) => a.univ - b.univ || a.addr - b.addr);
  for (let i = 0; i < byU.length; i++) {
    const f = byU[i], end = f.addr + f.nch - 1;
    for (let j = i + 1; j < byU.length && byU[j].univ === f.univ && byU[j].addr <= end; j++)
      if (byU[j].addr !== f.addr) overlaps.push([f.univ, byU[j].addr, f.id, byU[j].id]);
    if (end > 512) overlaps.push([f.univ, f.addr, f.id, '> 512']);
  }
  const types = new Set(fx.map(f => f.tname));
  return { layers, patched, unpatched, univs, dups, overlaps, ntypes: types.size };
}

// ───────────── mise en page ─────────────
const pad3 = a => a === null ? '—' : String(a).padStart(3, '0');
const plural = n => t('fixtures', n);
const TH_L = () => `<thead><tr><th class="fid">${t('thFid')}</th><th class="nm">${t('thName')}</th><th>${t('thType')}</th><th class="un">${t('thUniv')}</th><th class="ad">${t('thAddr')}</th></tr></thead>`;
const TH_U = () => `<thead><tr><th class="fid">${t('thFid')}</th><th class="lay">${t('thLayer')}</th><th class="nm">${t('thName')}</th><th>${t('thType')}</th><th class="ad">${t('thAddr')}</th></tr></thead>`;
const rowL = f => `<tr data-k="${esc(fxKey(f))}" title="${esc(t('hideRow'))}"><td class="fid">${esc(f.id)}</td><td class="nm">${esc(f.name)}</td><td class="ty">${esc(f.tshort)}</td><td class="un">${f.univ ?? '—'}</td><td class="ad">${pad3(f.addr)}</td></tr>`;
const rowU = f => `<tr data-k="${esc(fxKey(f))}" title="${esc(t('hideRow'))}"><td class="fid">${esc(f.id)}</td><td class="lay">${esc(f.layer)}</td><td class="nm">${esc(f.name)}</td><td class="ty">${esc(f.tshort)}</td><td class="ad">${pad3(f.addr)}</td></tr>`;

function pack(groups, firstCap, pageH, ncol) {
  const pages = []; let cols = [], cur = [], used = 0, cap = firstCap;
  const newCol = () => {
    cols.push(cur.join('')); cur = []; used = 0;
    if (cols.length === ncol) { pages.push(cols); cols = []; cap = pageH; }
  };
  for (const [title, sub, rows, thead] of groups) {
    let i = 0, cont = false;
    while (i < rows.length) {
      const rem = rows.length - i;
      const need = HEAD + THEAD + ROW * ((!cont && rem <= 16) ? rem : Math.min(4, rem));
      if (used + need > cap && used > 0) newCol();
      const n = Math.max(1, Math.floor((cap - used - HEAD - THEAD) / ROW));
      const chunk = rows.slice(i, i + n);
      cur.push(`<section class="grp"><h3><span>${esc(title)}${cont ? ` <em>${t('cont')}</em>` : ''}</span><small>${esc(sub)}</small></h3><table>${thead}<tbody>${chunk.join('')}</tbody></table></section>`);
      used += HEAD + THEAD + ROW * chunk.length + GAP;
      i += chunk.length; cont = true;
      if (i < rows.length) newCol();
    }
  }
  if (cur.length || cols.length) { cols.push(cur.join('')); while (cols.length < ncol) cols.push(''); pages.push(cols); }
  return pages;
}
const colsHTML = cols => `<div class="cols">${cols.map(c => `<div class="col">${c}</div>`).join('')}</div>`;

// cartouche : une ligne = une place fixe, de haut en bas (ligne 1 en haut, même si les autres sont vides)
const noteHTML = note => note ? `<div class="note">${note.split('\n').map(l => `<div class="ln">${l ? esc(l) : '&nbsp;'}</div>`).join('')}</div>` : '';
// « Imprimé le » + « Exporté le » (date fournie par le plugin ou date du fichier CSV, non modifiable)
function metaHTML(today) {
  let h = t('printed', today);
  const d = state.exported;
  if ($('#optExport').checked && d instanceof Date && !isNaN(d)) {
    h += '<br>' + t('exported', d.toLocaleDateString(t('locale')),
                    d.toLocaleTimeString(t('locale'), { hour: '2-digit', minute: '2-digit' }));
  }
  return `<div class="meta">${h}</div>`;
}
function summaryHTML(fx, A, titre, lieu, note, show = { layer: true, univ: true, type: true }) {
  const today = new Date().toLocaleDateString(t('locale'));
  let warns = '';
  if (A.dups.length) warns += `<p class="warn"><b>${t('warnDup')}</b> ${A.dups.map(([u, a, x, y]) => `${u}.${pad3(a)} (${esc(x)} / ${esc(y)})`).join(', ')}</p>`;
  if (A.overlaps.length) warns += `<p class="warn"><b>${t('warnOvl')}</b> ${A.overlaps.map(([u, a, x, y]) => `${u}.${pad3(a)} (${esc(x)} / ${esc(y)})`).join(', ')}</p>`;
  if (A.unpatched.length) warns += `<p class="warn"><b>${t('warnUnp', A.unpatched.length)}</b> ${A.unpatched.map(f => esc(f.id)).join(', ')}</p>`;
  const layRows = A.layers.map(l => {
    const g = fx.filter(f => f.layer === l).sort((a, b) => cmpKey(a.key, b.key));
    const types = [...new Set(g.map(f => f.tname))].join(', ');
    const us = [...new Set(g.filter(f => f.univ !== null).map(f => f.univ))].sort((a, b) => a - b).join(', ') || '—';
    return `<tr><td class="nm">${esc(l)}</td><td class="num">${g.length}</td><td class="ty">${esc(types)}</td><td class="num">${esc(us)}</td></tr>`;
  }).join('');
  const uniRows = A.univs.map(u => {
    const g = A.patched.filter(f => f.univ === u).sort((a, b) => a.addr - b.addr);
    const ls = [...new Set(g.map(f => f.layer))].join(', ');
    return `<tr><td class="num"><b>${u}</b></td><td class="num">${g.length}</td><td class="num">${pad3(g[0].addr)} → ${pad3(g[g.length - 1].addr)}</td><td class="ty">${esc(ls)}</td></tr>`;
  }).join('');
  const types = [...new Set(fx.map(f => f.tname))].map(tn => {
    const g = fx.filter(f => f.tname === tn);
    return { tn, n: g.length, ls: [...new Set(g.map(f => f.layer))], us: [...new Set(g.filter(f => f.univ !== null).map(f => f.univ))].sort((a, b) => a - b) };
  }).sort((a, b) => b.n - a.n || a.tn.localeCompare(b.tn));
  const typRows = types.map(x => `<tr><td class="nm">${esc(x.tn)}</td><td class="num">${x.n}</td><td class="ty">${esc(x.ls.join(', '))}</td><td class="num">${esc(x.us.join(', ') || '—')}</td></tr>`).join('');
  const blocks = [];
  if (show.layer) blocks.push(`<div class="wide"><h2>${t('sumLayer')}</h2>
<table class="summary"><thead><tr><th style="width:32mm">${t('thLayer')}</th><th class="num" style="width:12mm">${t('thQty')}</th><th>${t('thTypes')}</th><th class="num" style="width:22mm">${t('thUnivFull')}</th></tr></thead><tbody>${layRows}</tbody></table></div>`);
  if (show.univ) blocks.push(`<div><h2>${t('sumUniv')}</h2>
<table class="summary"><thead><tr><th class="num" style="width:14mm">${t('thUniv')}</th><th class="num" style="width:12mm">${t('thQty')}</th><th class="num" style="width:36mm">${t('thStart')}</th><th>${t('thLayers')}</th></tr></thead><tbody>${uniRows}</tbody></table></div>`);
  if (show.type) blocks.push(`<div><h2>${t('sumType')}</h2>
<table class="summary"><thead><tr><th>${t('thFxType')}</th><th class="num" style="width:12mm">${t('thQty')}</th><th>${t('thLayers')}</th><th class="num" style="width:20mm">${t('thUnivFull')}</th></tr></thead><tbody>${typRows}</tbody></table></div>`);
  const head = `<header class="top"><div><h1>${esc(titre)}</h1>${lieu ? `<div class="sub">${esc(lieu)}</div>` : ''}</div>${noteHTML(note)}
${metaHTML(today)}</header>
<div class="kpis">
<div class="kpi"><b>${fx.length}</b><span>${t('kpiFix')}</span></div>
<div class="kpi"><b>${A.layers.length}</b><span>${t('kpiLayers')}</span></div>
<div class="kpi"><b>${A.univs.length}</b><span>${t('kpiUniv')}</span></div>
<div class="kpi"><b>${A.ntypes}</b><span>${t('kpiTypes')}</span></div>
</div>${warns}`;
  return { head, blocks };
}

function measureMM(html, fmt) {
  const m = $('#measure');
  m.innerHTML = `<div class="sheet ${fmt}"><div id="summary" style="display:flow-root">${html}</div></div>`;
  const h = m.querySelector('#summary').getBoundingClientRect().height;
  m.innerHTML = '';
  return h * 25.4 / 96 + 2;
}

function layerColors(layers) {
  const m = {};
  layers.forEach((l, i) => { m[l] = state.colors[l] || PALETTE[i % PALETTE.length]; });
  return m;
}

// formats d'étiquettes : A3 à découper, ou planches adhésives (position exacte de chaque étiquette)
const PAGES = { A4: [210, 297], A3: [297, 420] };
const LB_SHEETS = {
  L7651: { page: 'A4', w: 38.1, h: 21.2, cols: 5, rows: 13, left: 4.75, top: 10.7, px: 40.6, py: 21.2 },
  L7654: { page: 'A4', w: 45.7, h: 25.4, cols: 4, rows: 10, left: 9.7, top: 21.5, px: 48.3, py: 25.4 },
  L7159: { page: 'A4', w: 63.5, h: 33.9, cols: 3, rows: 8, left: 7.25, top: 12.9, px: 66, py: 33.9 },
  L7160: { page: 'A4', w: 63.5, h: 38.1, cols: 3, rows: 7, left: 7.25, top: 15.15, px: 66, py: 38.1 },
  3474:  { page: 'A4', w: 70, h: 37, cols: 3, rows: 8, left: 0, top: 0.5, px: 70, py: 37 },
};
const CU_DEF = { page: 'A4', w: 48.5, h: 25.4, cols: 4, rows: 11, left: 8, top: 8.7, px: 48.5, py: 25.4 };
const CU_KEYS = ['page', 'cols', 'rows', 'w', 'h', 'left', 'top', 'px', 'py'];
function lbGeom() {
  const v = state.lbSize;
  const cut = { '40x30': [40, 30], '30x40': [30, 40], '50x20': [50, 20] }[v];
  if (cut) return { cut: true, w: cut[0], h: cut[1] };
  const g = v === 'custom' ? { ...CU_DEF, ...store.get('lbCustom', {}) } : LB_SHEETS[v];
  if (!g) return { cut: true, w: 40, h: 30 };
  const opt = [...$('#lbSize').options].find(o => o.value === v);
  return { ...g, cut: false, name: v === 'custom' ? `${g.w} × ${g.h} mm` : (opt ? opt.text.split(' — ')[0] : v) };
}
function renderLabels() {
  const pagesEl = $('#pages');
  const base = state.fx.filter(f => !state.hidden.has(fxKey(f)) && !($('#lbHideUnp').checked && f.univ === null));
  const A = analyse(state.fx);
  const colors = layerColors(A.layers);
  const counts = {}; base.forEach(f => { counts[f.layer] = (counts[f.layer] || 0) + 1; });
  refreshColorUI(A.layers, colors, counts);
  const fx = base.filter(f => !state.lbOff.has(f.layer));
  if (!fx.length) { pagesEl.innerHTML = `<div class="empty"><div>${t('noLabels')}</div></div>`; $('#pageInfo').textContent = state.fileName; return; }
  const order = new Map(A.layers.map((l, i) => [l, i]));
  const list = [...fx].sort((a, b) => order.get(a.layer) - order.get(b.layer) || cmpKey(a.key, b.key));
  const G = lbGeom(), w = G.w, h = G.h;
  const wide = w / h >= 2;
  const cols = G.cut ? Math.floor(277 / w) : G.cols, rows = G.cut ? Math.floor((400 - 6) / h) : G.rows, per = cols * rows;
  // « Fix ID seul » : rien d'autre que le numéro (l'adresse s'il n'y a pas de numéro) et la couleur du layer
  const only = $('#lbOnly').checked;
  const show0 = id => !only && $('#' + id).checked;
  // format large : Fix ID et adresse côte à côte s'il reste du texte dessous, sinon empilés (plus gros)
  const rowLayout = wide && ['lbName', 'lbType', 'lbChid', 'lbAnn'].some(show0);
  const one = (f, j) => {
    const show = id => only ? (id === 'lbFid' || (id === 'lbPatch' && !f.id)) : $('#' + id).checked;
    const c = colors[f.layer], k = fxKey(f);
    const patch = f.univ !== null ? `${f.univ}.${pad3(f.addr)}` : '—';
    const r1 = ((show('lbFid') && f.id) || show('lbPatch')) ? `<div class="bigs">` +
      (show('lbFid') && f.id ? `<div class="big lfid">${esc(f.id || '—')}</div>` : '') +
      (show('lbPatch') ? `<div class="big lpt">${patch}</div>` : '') + `</div>` : '';
    const pos = G.cut ? '' : `;left:${(G.left + (j % cols) * G.px).toFixed(2)}mm;top:${(G.top + Math.floor(j / cols) * G.py).toFixed(2)}mm;width:${w}mm;height:${h}mm`;
    return `<div class="lbl${rowLayout ? ' wide' : ''}${G.cut ? '' : ' adh'}" style="--c:${c};--ct:${textOn(c)}${pos}">` +
      `<div class="band${show('lbLayer') ? '' : ' thin'}">${show('lbLayer') ? esc(f.layer) : ''}</div>` +
      `<div class="body">${r1}` +
      (show('lbName') ? `<div class="lnm">${esc(f.name)}</div>` : '') +
      (show('lbType') ? `<div class="ty">${esc(f.tshort)}</div>` : '') +
      (show('lbChid') && f.chid ? `<div class="ch">Ch ${esc(f.chid)}</div>` : '') +
      (show('lbAnn') ? `<div class="ann" contenteditable="plaintext-only" spellcheck="false" data-k="${esc(k)}" data-ph="${esc(t('annPh'))}">${esc(state.notes[k] || '')}</div>` : '') +
      `</div></div>`;
  };
  const sheets = [];
  for (let i = 0; i < list.length; i += per) sheets.push(list.slice(i, i + per));
  const n = sheets.length;
  $('#lbCust').hidden = state.lbSize !== 'custom';
  $('#lbAdhHint').hidden = G.cut;
  if (G.cut) {
    pagesEl.innerHTML = sheets.map((g, i) =>
      `<div class="sheet A3P"><div class="lgrid" style="--cols:${cols};--w:${w}mm;--h:${h}mm">${g.map(one).join('')}</div>` +
      `<div class="lfoot"><span>${esc(state.fileName)}</span><span>${esc(t('lbFoot', i + 1, n))}</span></div></div>`).join('');
    $('#pagesize').textContent = '@page { size: A3 portrait; margin: 0; }';
  } else {
    // planche adhésive : pas de pied de page (il tomberait sur les étiquettes)
    const [PW, PH] = PAGES[G.page] || PAGES.A4;
    pagesEl.innerHTML = sheets.map(g =>
      `<div class="sheet LSH" style="width:${PW}mm;height:${PH}mm">${g.map(one).join('')}</div>`).join('');
    $('#pagesize').textContent = `@page { size: ${G.page || 'A4'} portrait; margin: 0; }`;
  }
  applyZoom();
  fitLabels(w, h);
  if (document.fonts && document.fonts.status !== 'loaded') document.fonts.ready.then(() => { if (state.tab === 'labels') fitLabels(w, h); });
  $('#pageInfo').textContent = G.cut ? t('lbInfo', state.fileName, list.length, n) : t('lbInfoAdh', state.fileName, list.length, n, G.name);
}

// Fix ID et adresse : taille calculée pour remplir leur zone (lisibilité à distance).
// Les tailles sont posées en mm, mesurées en proportion de l'étiquette (indépendant du zoom).
let fitCtx = null;
function fitLabels(wmm, hmm) {
  fitCtx = fitCtx || document.createElement('canvas').getContext('2d');
  for (const cls of ['lfid', 'lpt']) {
    const ref = document.querySelector('#pages .big.' + cls); if (!ref) continue;
    const first = ref.closest('.lbl'), W = first.clientWidth, H = first.clientHeight;
    const cs = getComputedStyle(ref);
    const boxW = ref.clientWidth / W * wmm, boxH = ref.clientHeight / H * hmm;
    fitCtx.font = `700 100px ${cs.fontFamily}`;
    const maxH = boxH * 0.98;                    // line-height 1 → la hauteur du corps ≈ la zone
    // une seule taille pour toute la planche (la plus grande qui tient pour chaque étiquette)
    const els = [...document.querySelectorAll('#pages .big.' + cls)];
    let size = maxH;
    for (const el of els) {
      const tw = fitCtx.measureText(el.textContent).width / 100; // largeur pour 1 mm de corps
      if (tw) size = Math.min(size, boxW * 0.97 / tw);
    }
    const v = Math.max(2, size).toFixed(2) + 'mm';
    els.forEach(el => { el.style.fontSize = v; });
  }
}

function refreshColorUI(layers, colors, counts) {
  $('#lcolorBox').hidden = false;
  const box = $('#lcolors');
  const sig = layers.join('|');
  if (box.dataset.sig === sig) {
    // mêmes layers : on met juste les valeurs à jour (le sélecteur ouvert reste ouvert)
    box.querySelectorAll('input[type=color]').forEach(i => { if (document.activeElement !== i) i.value = colors[i.dataset.layer]; });
    box.querySelectorAll('.lcolor').forEach(r => { const l = r.dataset.layer; r.classList.toggle('off', state.lbOff.has(l)); r.querySelector('input[type=checkbox]').checked = !state.lbOff.has(l); r.querySelector('small').textContent = counts[l] || 0; });
    return;
  }
  box.dataset.sig = sig;
  box.innerHTML = layers.map(l => `<div class="lcolor${state.lbOff.has(l) ? ' off' : ''}" data-layer="${esc(l)}"><input type="checkbox" data-layer="${esc(l)}"${state.lbOff.has(l) ? '' : ' checked'} title="${esc(t('lcPrint'))}"><input type="color" value="${colors[l]}" data-layer="${esc(l)}"><span>${esc(l)}</span><small>${counts[l] || 0}</small></div>`).join('');
}

function render() {
  const pagesEl = $('#pages');
  if (!state.fx) return;
  document.body.dataset.tab = state.tab;
  if (state.tab === 'labels') return renderLabels();
  if (state.tab === 'diff') return renderDiff();
  const fx = state.fx.filter(f => !state.hidden.has(fxKey(f)) && !($('#optHideUnp').checked && f.univ === null));
  if (!fx.length) { pagesEl.innerHTML = `<div class="empty"><div>${t('noPatched')}</div></div>`; $('#pageInfo').textContent = state.fileName; return; }
  const A = analyse(fx), fmt = state.fmt;
  const { H, ncol } = FORMATS[fmt];
  const pageH = H - 2 * MARGIN - 7;
  const titre = $('#titre').value.trim() || t('defTitle');
  const lieu = $('#lieu').value.trim();
  const note = [1, 2, 3, 4].map(i => $('#note' + i).value.trim()).join('\n').replace(/\n+$/, '');
  const wantL = $('#optLayer').checked, wantU = $('#optUniv').checked;
  const sumShow = { layer: $('#optSumLayer').checked, univ: $('#optSumUniv').checked, type: $('#optSumType').checked };

  // en-tête + récapitulatifs, rangés par lignes (3 par ligne en A3, 2 en A4) ;
  // une ligne qui ne tient plus passe à la page suivante
  const S = summaryHTML(fx, A, titre, lieu, note, sumShow);
  const pre = [];
  let cur = S.head, used = measureMM(S.head, fmt);
  for (let i = 0; i < S.blocks.length; i += ncol) {
    const row = `<div class="sumcols">${S.blocks.slice(i, i + ncol).join('')}</div>`;
    const rh = measureMM(row, fmt);
    if (used + rh > pageH) { pre.push(cur); cur = row; used = rh; }
    else { cur += row; used += rh; }
  }

  const gL = A.layers.map(l => {
    const g = fx.filter(f => f.layer === l).sort((a, b) => cmpKey(a.key, b.key));
    return [l, plural(g.length), g.map(rowL), TH_L()];
  });
  const gU = A.univs.map(u => {
    const g = A.patched.filter(f => f.univ === u).sort((a, b) => a.addr - b.addr);
    return [t('univ') + ' ' + u, plural(g.length), g.map(rowU), TH_U()];
  });
  if (A.unpatched.length) gU.push([t('unpatched'), plural(A.unpatched.length), [...A.unpatched].sort((a, b) => cmpKey(a.key, b.key)).map(rowU), TH_U()]);

  // assemblage des pages
  const sheets = [...pre];
  let page1 = cur, page1Room = pageH - used;
  const sections = [];
  if (wantL) sections.push([t('secLayer'), gL]);
  if (wantU) sections.push([t('secUniv'), gU]);

  sections.forEach(([title, groups], si) => {
    // chaque section (patch par layer, patch par univers) commence en haut d'une page
    const cap = pageH - H2, onFirst = false;
    const pages = pack(groups, cap, pageH, ncol);
    pages.forEach((cols, i) => {
      const body = (i === 0 ? `<h2>${esc(title)}</h2>` : '') + colsHTML(cols);
      if (i === 0 && onFirst) { page1 += body; }
      else {
        if (page1 !== null) { sheets.push(page1); page1 = null; }
        sheets.push(body);
      }
    });
  });
  if (page1 !== null) sheets.splice(pre.length, 0, page1);
  // plan d'occupation : juste après la page des récapitulatifs
  if ($('#optMap').checked && A.univs.length) sheets.splice(pre.length + 1, 0, ...univMapPages(A, fmt));

  const foot = lieu ? `${titre} — ${lieu}` : titre;
  const dsh = ($('#diffInSheet').checked && state.ref) ? diffSheets(fmt).sheets : [];
  const all = [...dsh, ...sheets], n = all.length;
  pagesEl.innerHTML = all.map((s, i) =>
    `<div class="sheet ${fmt}">${s}<div class="pfoot"><span>${esc(state.fileName)}</span><span>${esc(i < dsh.length ? t('diffFoot') : foot)} · p. ${i + 1}/${n}</span></div></div>`).join('');
  $('#pagesize').textContent = `@page { size: ${fmt} landscape; margin: 0; }`;
  applyZoom();
  $('#pageInfo').textContent = t('pageInfo', state.fileName, n, fmt);
  document.title = `${titre} — ${t('docTitle')}`;
}

// ───────────── plan d'occupation des univers ─────────────
// Chaque univers = une barre de 512 canaux. Plage exacte si le fichier donne le nombre de canaux
// (WYSIWYG, Capture, plugin) ; sinon plage estimée jusqu'au projecteur suivant, hachurée.
function univMapPages(A, fmt) {
  const { H } = FORMATS[fmt], pageH = H - 2 * MARGIN - 7, BLK = 17;
  const colors = layerColors(A.layers);
  const pc = x => (x / 512 * 100).toFixed(3) + '%';
  let anyEst = false, anyOvl = false;
  const blocks = A.univs.map(u => {
    const g = A.patched.filter(f => f.univ === u).sort((a, b) => a.addr - b.addr);
    const occ = new Uint8Array(514);
    let known = true;
    const segs = g.map((f, i) => {
      let n = f.nch, est = false;
      if (!n) {
        est = true; known = false; anyEst = true;
        const nx = g.slice(i + 1).find(x => x.addr > f.addr);
        n = Math.max(1, (nx ? nx.addr : f.addr + 1) - f.addr);
      }
      const end = Math.min(512, f.addr + n - 1);
      if (!est) for (let c = f.addr; c <= end; c++) occ[c]++;
      const c = colors[f.layer];
      const tip = `${fxLabel(f)} · ${f.univ}.${pad3(f.addr)}${est ? '' : '–' + pad3(end)}`;
      return `<div class="useg${est ? ' est' : ''}" style="left:${pc(f.addr - 1)};width:${pc(end - f.addr + 1)};--c:${c};--ct:${textOn(c)}" title="${esc(tip)}">${esc(f.id)}</div>`;
    }).join('');
    // conflits (plages connues qui se recouvrent) et plages libres
    let ovl = '', free = [], used = 0, a0 = 0;
    for (let c = 1; c <= 513; c++) {
      if (c <= 512 && occ[c] > 1) { if (!a0) a0 = c; } else if (a0) { ovl += `<div class="ovl" style="left:${pc(a0 - 1)};width:${pc(c - a0)}"></div>`; a0 = 0; anyOvl = true; }
    }
    let f0 = 0;
    for (let c = 1; c <= 513; c++) {
      if (c <= 512 && occ[c]) used++;
      if (c <= 512 && !occ[c]) { if (!f0) f0 = c; } else if (f0) { free.push([f0, c - 1]); f0 = 0; }
    }
    const info = known
      ? `<span>${esc(t('mapUsed', used))}</span><span class="free">${esc(free.length ? t('mapFree') + ' ' + [...free].sort((x, y) => (y[1] - y[0]) - (x[1] - x[0]) || x[0] - y[0]).slice(0, 5)
        .map(([a, b]) => `${pad3(a)}–${pad3(b)} (${b - a + 1})`).join(' · ') + (free.length > 5 ? ' · …' : '') : t('mapFull'))}</span>`
      : `<span>${esc(plural(g.length))}</span>`;
    const ticks = [1, 65, 129, 193, 257, 321, 385, 449, 512].map(x => `<span style="left:${pc(x - .5)}">${x}</span>`).join('');
    return `<div class="umap"><div class="uh"><b>${esc(t('univ'))} ${u}</b>${info}</div><div class="bar">${segs}${ovl}</div><div class="scale">${ticks}</div></div>`;
  });
  const legend = [anyEst ? t('mapEst') : '', anyOvl ? t('mapOvl') : ''].filter(Boolean).join(' ');
  const head = `<h2>${esc(t('secMap'))}</h2>` + (legend ? `<p class="maplegend">${esc(legend)}</p>` : '');
  const pages = [];
  let cur = head, room = pageH - H2 - (legend ? 5 : 0);
  for (const b of blocks) {
    if (room < BLK) { pages.push(cur); cur = ''; room = pageH; }
    cur += b; room -= BLK;
  }
  if (cur) pages.push(cur);
  return pages;
}

// ───────────── comparaison avec un ancien patch ─────────────
const ptxt = f => f.univ === null ? '—' : f.univ + '.' + pad3(f.addr);
function diffPatch(oldFx, newFx) {
  // un projecteur = son Fix ID (ou Ch ID) ; sans numéro : layer + nom + type (+ rang)
  const keyed = fx => {
    const m = new Map(), cnt = {};
    for (const f of fx) {
      let k = f.id ? 'id:' + f.id : 'x:' + f.layer + '|' + f.name + '|' + f.tname;
      if (!f.id) { cnt[k] = (cnt[k] || 0) + 1; k += '#' + cnt[k]; }
      if (!m.has(k)) m.set(k, f);
    }
    return m;
  };
  const O = keyed(oldFx), N = keyed(newFx), mod = [], add = [], del = [];
  let same = 0;
  for (const [k, f] of N) {
    const o = O.get(k);
    if (!o) { add.push(f); continue; }
    const ch = [];
    if (ptxt(o) !== ptxt(f)) ch.push([t('dAddr'), ptxt(o), ptxt(f)]);
    if (o.tname !== f.tname) ch.push([t('dType'), o.tshort, f.tshort]);
    if (o.layer !== f.layer) ch.push([t('dLayer'), o.layer, f.layer]);
    if (o.name !== f.name) ch.push([t('dName'), o.name, f.name]);
    if (o.nch && f.nch && o.nch !== f.nch) ch.push([t('dNch'), o.nch, f.nch]);
    if (ch.length) mod.push([f, ch]); else same++;
  }
  for (const [k, o] of O) if (!N.has(k)) del.push(o);
  const by = (a, b) => cmpKey(a.key, b.key);
  mod.sort((a, b) => by(a[0], b[0])); add.sort(by); del.sort(by);
  return { mod, add, del, same };
}
const fmtDT = d => (d instanceof Date && !isNaN(d))
  ? d.toLocaleDateString(t('locale')) + ' ' + d.toLocaleTimeString(t('locale'), { hour: '2-digit', minute: '2-digit' }) : '';
function diffSheets(fmt) {
  const R = state.ref;
  const D = diffPatch(R.fx, state.fx);
  const { H, ncol } = FORMATS[fmt], pageH = H - 2 * MARGIN - 7;
  const side = (name, d) => esc(name) + (fmtDT(d) ? ` <small>(${esc(fmtDT(d))})</small>` : '');
  const head = `<header class="top"><div><h1>${esc(t('diffTitle'))}</h1><div class="sub">${side(R.name, R.exported)} → ${side(state.fileName, state.exported)}</div></div>
<div class="meta">${t('printed', new Date().toLocaleDateString(t('locale')))}</div></header>
<div class="kpis">
<div class="kpi mod"><b>${D.mod.length}</b><span>${t('kMod')}</span></div>
<div class="kpi add"><b>${D.add.length}</b><span>${t('kAdd')}</span></div>
<div class="kpi del"><b>${D.del.length}</b><span>${t('kDel')}</span></div>
<div class="kpi"><b>${D.same}</b><span>${t('kSame')}</span></div>
</div>`;
  const TH_D = `<thead><tr><th class="fid">${t('thFid')}</th><th class="nm">${t('thName')}</th><th class="dch">${t('thChange')}</th><th>${t('thFrom')}</th><th>${t('thTo')}</th></tr></thead>`;
  const TH_X = `<thead><tr><th class="fid">${t('thFid')}</th><th class="lay">${t('thLayer')}</th><th class="nm">${t('thName')}</th><th>${t('thType')}</th><th class="ad" style="width:15mm">${t('thPatch')}</th></tr></thead>`;
  const rowX = f => `<tr><td class="fid">${esc(f.id)}</td><td class="lay">${esc(f.layer)}</td><td class="nm">${esc(f.name)}</td><td class="ty">${esc(f.tshort)}</td><td class="ad">${ptxt(f)}</td></tr>`;
  const modRows = D.mod.flatMap(([f, ch]) => ch.map((c, i) =>
    `<tr><td class="fid">${i ? '' : esc(f.id)}</td><td class="nm">${i ? '' : esc(f.name)}</td><td class="dch">${esc(c[0])}</td><td class="dfrom">${esc(c[1])}</td><td class="dto">${esc(c[2])}</td></tr>`));
  const groups = [];
  if (D.mod.length) groups.push([t('gMod'), plural(D.mod.length), modRows, TH_D]);
  if (D.add.length) groups.push([t('gAdd'), plural(D.add.length), D.add.map(rowX), TH_X]);
  if (D.del.length) groups.push([t('gDel'), plural(D.del.length), D.del.map(rowX), TH_X]);
  if (!groups.length) return { D, sheets: [head + `<p class="warn">${esc(t('diffNone'))}</p>`] };
  const pages = pack(groups, pageH - measureMM(head, fmt), pageH, ncol);
  return { D, sheets: pages.map((cols, i) => (i ? '' : head) + colsHTML(cols)) };
}
function renderDiff() {
  const pagesEl = $('#pages'), fmt = state.fmt;
  if (!state.ref) { pagesEl.innerHTML = `<div class="empty"><div>${esc(t('diffNoRef'))}</div></div>`; $('#pageInfo').textContent = state.fileName; return; }
  const { sheets } = diffSheets(fmt), n = sheets.length;
  pagesEl.innerHTML = sheets.map((s, i) =>
    `<div class="sheet ${fmt}">${s}<div class="pfoot"><span>${esc(state.fileName)}</span><span>${esc(t('diffFoot'))} · p. ${i + 1}/${n}</span></div></div>`).join('');
  $('#pagesize').textContent = `@page { size: ${fmt} landscape; margin: 0; }`;
  applyZoom();
  $('#pageInfo').textContent = t('diffInfo', state.ref.name, state.fileName, n);
}
function refFrom(csv, name, exported, map) {
  const rows = readRows(csv);
  if (!mapUsable(map)) map = mapFor(rows[0]);
  if (!mapUsable(map)) throw new Error(t('refNoCols'));
  const fx = prepare(records(rows, map.idx), map.autonum);
  if (!fx.length) throw new Error(t('noFixtures'));
  return { fx, name, exported, csv, map };
}
function refreshRefUI() {
  const R = state.ref, el = $('#refName');
  el.hidden = !R;
  if (R) el.innerHTML = `<b>${esc(t('refOld'))}</b> ${esc(R.name)}${fmtDT(R.exported) ? ' · ' + esc(fmtDT(R.exported)) : ''} · ${esc(plural(R.fx.length))}`;
}
async function loadRefFile(file) {
  try {
    const u = unwrap(decode(await file.arrayBuffer()));
    const ex = u.meta && u.meta.exporte ? new Date(u.meta.exporte) : (file.lastModified ? new Date(file.lastModified) : null);
    state.ref = refFrom(u.csv, (u.meta && u.meta.source) || file.name, ex, u.st && u.st.map);
    refreshRefUI(); render();
  } catch (err) {
    $('#refName').hidden = false;
    $('#refName').innerHTML = `<span style="color:#b91c1c">${esc(t('refErr'))} ${esc(err.message)}</span>`;
  }
}

// ───────────── colonnes du fichier (choix manuel) ─────────────
const MAP_FIELDS = [['fid', 'mFid'], ['chid', 'mChid'], ['layer', 'mLayer'], ['name', 'mName'], ['type', 'mType'],
                    ['patch', 'mPatch'], ['univ', 'mUniv'], ['addr', 'mAddr'], ['nch', 'mNch']];
function openMap(map) {
  if (!state.src) return;
  const head = state.src.rows[0], ex = state.src.rows[1] || [];
  const opts = sel => `<option value="">${esc(t('mapNone'))}</option>` + head.map((h, i) =>
    `<option value="${i}"${sel === i ? ' selected' : ''}>${esc(h || '#' + (i + 1))}${ex[i] ? ' — ' + esc(String(ex[i]).slice(0, 22)) : ''}</option>`).join('');
  $('#mapRows').innerHTML = MAP_FIELDS.map(([k, l]) =>
    `<label class="maprow"><span>${esc(t(l))}</span><select data-k="${k}">${opts(map.idx[k])}</select></label>`).join('');
  $('#mapAuto').checked = !!map.autonum;
  $('#mapErr').hidden = true;
  if (!$('#mapDlg').open) $('#mapDlg').showModal();
}
$('#mapForm').addEventListener('submit', async e => {
  e.preventDefault();
  const idx = {};
  document.querySelectorAll('#mapRows select').forEach(sel => { if (sel.value !== '') idx[sel.dataset.k] = +sel.value; });
  const m = { idx, autonum: $('#mapAuto').checked };
  if (!mapUsable(m)) { $('#mapErr').textContent = t('mapNeed'); $('#mapErr').hidden = false; return; }
  store.set(headSig(state.src.rows[0]), m);
  $('#mapDlg').close();
  try { await applyMap(m); } catch (err) { showError(err); }
});
$('#mapCancel').addEventListener('click', () => $('#mapDlg').close());
$('#mapReset').addEventListener('click', () => { store.set(headSig(state.src.rows[0]), null); openMap(autoMap(state.src.rows[0])); });
$('#mapBtn').addEventListener('click', () => state.src && openMap(state.map || mapFor(state.src.rows[0])));
$('#alerts').addEventListener('click', async e => {
  if (e.target.id !== 'autoNumBtn' || !state.map) return;
  const m = { ...state.map, autonum: true };
  store.set(headSig(state.src.rows[0]), m);
  try { await applyMap(m); } catch (err) { showError(err); }
});

// ───────────── enregistrer : une feuille .html autonome ─────────────
const CHECKS = ['optSumLayer', 'optSumUniv', 'optSumType', 'optLayer', 'optUniv', 'optMap', 'optHideUnp', 'optExport',
                'lbOnly', 'lbFid', 'lbPatch', 'lbName', 'lbType', 'lbChid', 'lbLayer', 'lbAnn', 'lbHideUnp', 'diffInSheet'];
function saveSheet() {
  if (!state.fx) return;
  const J = v => JSON.stringify(v).replace(/</g, '\\u003c');
  const iso = d => (d instanceof Date && !isNaN(d)) ? d.toISOString() : '';
  const meta = {
    titre: $('#titre').value, lieu: $('#lieu').value, lignes: [1, 2, 3, 4].map(i => $('#note' + i).value),
    exporte: iso(state.exported), source: state.fileName, kind: 'saved', saved: new Date().toISOString(),
  };
  const chk = {}; CHECKS.forEach(id => { chk[id] = $('#' + id).checked; });
  const st = {
    map: state.map, notes: state.notes, hidden: [...state.hidden], lbOff: [...state.lbOff], colors: state.colors,
    opts: { chk, fmt: state.fmt, lbSize: state.lbSize, lbCustom: store.get('lbCustom', null), tab: state.tab },
    ref: state.ref ? { csv: state.ref.csv, name: state.ref.name, exported: iso(state.ref.exported), map: state.ref.map } : null,
  };
  const doc = PRISTINE.cloneNode(true);
  doc.querySelector('#gmtp-data').textContent =
    'window.EMBEDDED_CSV=' + J(state.src.text) + ';window.EMBEDDED_META=' + J(meta) + ';window.EMBEDDED_STATE=' + J(st) + ';';
  const stem = state.fileName.replace(/\.(csv|txt|html?)$/i, '').replace(/\s*\(grandMA[23]\)$/, '').replace(/_GiveMeThePatch/g, '');
  const slug = stem.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^\w.-]+/g, '_').replace(/^_+|_+$/g, '') || 'patch';
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob(['<!DOCTYPE html>\n' + doc.outerHTML], { type: 'text/html' }));
  a.download = slug + '_GiveMeThePatch.html';
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 5000);
}
// feuille enregistrée : ses réglages s'appliquent la première fois qu'on l'ouvre dans ce navigateur
// (ensuite, ce sont les modifications faites ici qui comptent, jusqu'au prochain enregistrement)
function applySaved(st, name, savedAt, csv) {
  if (st.ref) { try { state.ref = refFrom(st.ref.csv, st.ref.name, st.ref.exported ? new Date(st.ref.exported) : null, st.ref.map); } catch {} }
  const seen = 'seen:' + name;
  if (savedAt && store.get(seen, null) === savedAt) return;
  store.set(seen, savedAt);
  store.set('notes:' + name, st.notes || {});
  store.set('hidden:' + name, st.hidden || []);
  store.set('lboff:' + name, st.lbOff || []);
  if (st.colors) { state.colors = st.colors; store.set('lcolors', st.colors); }
  if (st.map) { try { store.set(headSig(readRows(csv)[0]), st.map); } catch {} }
  const o = st.opts || {};
  for (const [id, v] of Object.entries(o.chk || {})) { const el = $('#' + id); if (el) { el.checked = !!v; store.set(id, !!v); } }
  if (o.fmt) setFmt(o.fmt);
  if (o.lbCustom) { store.set('lbCustom', o.lbCustom); fillCustom(); }
  if (o.lbSize) setLbSize(o.lbSize);
  if (o.tab) setTab(o.tab);
}
async function loadEmbedded(csv, p, st) {
  p = p || {};
  // le titre et le lieu intégrés (console ou feuille enregistrée) priment sur ceux mémorisés dans le navigateur
  if (p.titre) $('#titre').value = Object.values(I18N).some(d => d.defTitle === p.titre) ? t('defTitle') : p.titre;
  if (p.lieu !== undefined) $('#lieu').value = p.lieu;
  if (Array.isArray(p.lignes)) [1, 2, 3, 4].forEach(i => { $('#note' + i).value = p.lignes[i - 1] || ''; });
  const name = p.source || 'grandMA2';
  if (st) applySaved(st, name, p.saved, csv);
  refreshRefUI();
  await loadText(csv, name, p.kind === 'saved' ? 'fromSaved' : 'fromConsole', p.exporte ? new Date(p.exporte) : null);
}

// ───────────── masquage de projecteurs ─────────────
function saveHidden() { store.set(hiddenStoreKey(), [...state.hidden]); }
function refreshHideUI() {
  if (!state.fx) return;
  $('#hideBox').hidden = false;
  const byKey = new Map(state.fx.map(f => [fxKey(f), f]));
  $('#fxList').innerHTML = state.fx.filter(f => !state.hidden.has(fxKey(f)))
    .sort((a, b) => cmpKey(a.key, b.key)).map(f => `<option value="${esc(fxLabel(f))}"></option>`).join('');
  const chips = [...state.hidden].filter(k => byKey.has(k)).map(k => {
    const f = byKey.get(k);
    return `<span class="chip" title="${esc(fxLabel(f))}"><span>${esc(fxLabel(f))}</span><button type="button" class="chipx" data-k="${esc(k)}" aria-label="${esc(t('unhide'))}" title="${esc(t('unhide'))}">×</button></span>`;
  });
  $('#hiddenChips').innerHTML = chips.join('');
  $('#unhideAll').hidden = chips.length < 2;
}
function setHidden(k, on) {
  if (on) state.hidden.add(k); else state.hidden.delete(k);
  saveHidden(); refreshHideUI(); showInfo(); render();
}
function hideFromInput() {
  const v = $('#hideInput').value.trim();
  if (!v || !state.fx) return;
  const lv = v.toLowerCase();
  const pool = state.fx.filter(f => !state.hidden.has(fxKey(f)));
  // 1) libellé exact de la liste ; 2) Fix ID exact ; 3) tous ceux dont le nom correspond exactement
  let hits = pool.filter(f => fxLabel(f) === v);
  if (!hits.length) hits = pool.filter(f => f.id && f.id.toLowerCase() === lv);
  if (!hits.length) hits = pool.filter(f => (f.name || '').toLowerCase() === lv);
  if (!hits.length) { $('#hideInput').setCustomValidity(t('notFound')); $('#hideInput').reportValidity(); return; }
  $('#hideInput').setCustomValidity('');
  hits.forEach(f => state.hidden.add(fxKey(f)));
  $('#hideInput').value = '';
  saveHidden(); refreshHideUI(); showInfo(); render();
}

function showInfo() {
  const fx = state.fx, A = analyse(fx);
  $('#info').hidden = false;
  $('#stats').innerHTML = [
    [fx.length, t('stFix')], [A.layers.length, t('stLayers')], [A.univs.length, t('stUniv')], [A.ntypes, t('stTypes')],
  ].map(([v, l]) => `<div class="stat"><b>${v}</b><span>${l}</span></div>`).join('');
  let al = '';
  if (A.dups.length) al += `<div class="alert"><b>${t('alDup', A.dups.length)}</b><br>${A.dups.map(([u, a, x, y]) => `${u}.${pad3(a)} : ${esc(x)} / ${esc(y)}`).join('<br>')}</div>`;
  if (A.overlaps.length) al += `<div class="alert"><b>${t('alOvl', A.overlaps.length)}</b><br>${A.overlaps.map(([u, a, x, y]) => `${u}.${pad3(a)} : ${esc(x)} / ${esc(y)}`).join('<br>')}</div>`;
  if (A.unpatched.length) al += `<div class="alert"><b>${t('alUnp', A.unpatched.length)}</b>${$('#optHideUnp').checked ? t('alHidden') : ''}<br>${A.unpatched.map(f => esc(f.id)).join(', ')}</div>`;
  if (!al) al = `<div class="alert ok">${t('alOk')}</div>`;
  if (fx.every(f => !f.id)) al += `<div class="alert">${esc(t('noIds'))}<br><button type="button" class="linkbtn" id="autoNumBtn">${esc(t('autoNum'))}</button></div>`;
  const nh = state.fx.filter(f => state.hidden.has(fxKey(f))).length;
  if (nh) al += `<div class="alert">${esc(t('stHidden', nh))}</div>`;
  $('#alerts').innerHTML = al;
}

function applyZoom() {
  const z = +$('#zoom').value;
  $('#zoomVal').textContent = z + ' %';
  document.querySelectorAll('#pages .sheet').forEach(s => s.style.zoom = z / 100);
  store.set('zoom', z);
}

function fitZoom() {
  const W = FORMATS[state.fmt].W * 96 / 25.4;
  const avail = $('main').clientWidth - 44;
  const z = Math.max(20, Math.min(100, Math.floor(avail / W * 100)));
  $('#zoom').value = z;
}

// ───────────── chargement ─────────────
function setDropText() {
  if (!state.fx) return;
  $('#dropText').innerHTML = `<span>${esc(t(state.label || 'loaded'))}</span><div class="fname">${esc(state.fileName)}</div><span>${esc(t('changeFile'))}</span>`;
}
async function loadFile(file) {
  try {
    const text = decode(await file.arrayBuffer());
    const u = unwrap(text);
    if (u.csv !== text) return await loadEmbedded(u.csv, { source: file.name, ...(u.meta || {}) }, u.st);
    await loadText(text, file.name, 'loaded', file.lastModified ? new Date(file.lastModified) : null);
  } catch (err) { showError(err); }
}
function showError(err) {
  $('#info').hidden = false;
  $('#stats').innerHTML = '';
  $('#alerts').innerHTML = `<div class="alert err"><b>${t('readErr')}</b><br>${esc(err.message)}</div>`;
}
async function loadText(text, name, labelKey = 'loaded', exported = null) {
  try {
    const rows = readRows(text);
    state.src = { text, rows, name, labelKey, exported };
    const map = mapFor(rows[0]);
    if (!mapUsable(map)) { openMap(map); throw new Error(t('unknownCols')); }
    await applyMap(map);
  } catch (err) { showError(err); }
}
async function applyMap(map) {
  const drop = $('#drop');
  const { rows, name, labelKey, exported } = state.src;
  {
    const fx = prepare(records(rows, map.idx), map.autonum);
    if (!fx.length) throw new Error(t('noFixtures'));
    state.fx = fx; state.map = map; state.fileName = name; state.label = labelKey; state.exported = exported;
    state.hidden = new Set(store.get(hiddenStoreKey(), []));
    state.notes = store.get(notesStoreKey(), {});
    state.lbOff = new Set(store.get(lbOffKey(), []));
    refreshHideUI();
    drop.classList.add('loaded');
    setDropText();
    $('#print').disabled = false;
    $('#save').disabled = false;
    showInfo();
    await document.fonts.ready;
    if (!store.get('zoom', null)) fitZoom();
    render();
  }
}

// ───────────── événements ─────────────
const drop = $('#drop');
$('#file').addEventListener('change', e => e.target.files[0] && loadFile(e.target.files[0]));
['dragenter', 'dragover'].forEach(ev => drop.addEventListener(ev, e => { e.preventDefault(); drop.classList.add('over'); }));
['dragleave', 'drop'].forEach(ev => drop.addEventListener(ev, e => { e.preventDefault(); drop.classList.remove('over'); }));
drop.addEventListener('drop', e => e.dataTransfer.files[0] && loadFile(e.dataTransfer.files[0]));
document.addEventListener('dragover', e => e.preventDefault());
document.addEventListener('drop', e => {
  e.preventDefault();
  const f = e.dataTransfer.files[0]; if (!f) return;
  if (state.tab === 'diff' && state.fx) loadRefFile(f); else loadFile(f);   // onglet Changements : fichier déposé = ancien patch
});
$('#refBtn').addEventListener('click', () => $('#refFile').click());
$('#refFile').addEventListener('change', e => { if (e.target.files[0]) loadRefFile(e.target.files[0]); e.target.value = ''; });
$('#save').addEventListener('click', saveSheet);
drop.addEventListener('keydown', e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); $('#file').click(); } });

for (const id of ['titre', 'lieu', 'note1', 'note2', 'note3', 'note4']) {
  const el = $('#' + id);
  el.value = store.get(id, el.value);
  el.addEventListener('input', () => { store.set(id, el.value); render(); });
}
for (const id of ['optSumLayer', 'optSumUniv', 'optSumType', 'optLayer', 'optUniv', 'optMap', 'optHideUnp', 'optExport', 'diffInSheet']) {
  const el = $('#' + id);
  el.checked = store.get(id, el.checked);
  el.addEventListener('change', () => { store.set(id, el.checked); if (state.fx) showInfo(); render(); });
}
function setFmt(v) {
  state.fmt = v; store.set('fmt', v);
  document.querySelectorAll('#fmt button').forEach(x => x.classList.toggle('on', x.dataset.v === v));
  render();
}
document.querySelectorAll('#fmt button').forEach(b => {
  b.classList.toggle('on', b.dataset.v === state.fmt);
  b.addEventListener('click', () => setFmt(b.dataset.v));
});
$('#zoom').value = store.get('zoom', 45);
$('#zoom').addEventListener('input', applyZoom);
$('#zoomVal').textContent = $('#zoom').value + ' %';
$('#print').addEventListener('click', () => window.print());

// masquage : bouton, Entrée, puces, « tout réafficher », clic sur une ligne de l'aperçu
$('#hideBtn').addEventListener('click', hideFromInput);
$('#hideInput').addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); hideFromInput(); } });
$('#hideInput').addEventListener('input', () => $('#hideInput').setCustomValidity(''));
$('#hiddenChips').addEventListener('click', e => { const b = e.target.closest('.chipx'); if (b) setHidden(b.dataset.k, false); });
$('#unhideAll').addEventListener('click', () => { state.hidden.clear(); saveHidden(); refreshHideUI(); showInfo(); render(); });
$('#pages').addEventListener('click', e => { const tr = e.target.closest('tr[data-k]'); if (tr) setHidden(tr.dataset.k, true); });

// onglets
function setTab(v) {
  state.tab = v; store.set('tab', v); document.body.dataset.tab = v;
  document.querySelectorAll('#tabs button').forEach(b => b.classList.toggle('on', b.dataset.v === v));
  if (state.fx) render();
}
document.querySelectorAll('#tabs button').forEach(b => b.addEventListener('click', () => setTab(b.dataset.v)));
// étiquettes : format, contenu, couleurs, annotations
function setLbSize(v) {
  if (![...$('#lbSize').options].some(o => o.value === v)) v = '40x30';
  state.lbSize = v; store.set('lbSize', v);
  $('#lbSize').value = v;
  render();
}
$('#lbSize').value = [...$('#lbSize').options].some(o => o.value === state.lbSize) ? state.lbSize : '40x30';
$('#lbSize').addEventListener('change', e => setLbSize(e.target.value));
function fillCustom() {
  const g = { ...CU_DEF, ...store.get('lbCustom', {}) };
  CU_KEYS.forEach(k => { $('#cu_' + k).value = g[k]; });
}
fillCustom();
CU_KEYS.forEach(k => $('#cu_' + k).addEventListener('input', () => {
  const g = {};
  CU_KEYS.forEach(x => { const v = $('#cu_' + x).value; g[x] = x === 'page' ? v : parseFloat(v); });
  if (CU_KEYS.every(x => x === 'page' || g[x] >= 0) && g.cols >= 1 && g.rows >= 1 && g.w > 0 && g.h > 0) { store.set('lbCustom', g); render(); }
}));
for (const id of ['lbOnly', 'lbFid', 'lbPatch', 'lbName', 'lbType', 'lbChid', 'lbLayer', 'lbAnn', 'lbHideUnp']) {
  const el = $('#' + id);
  el.checked = store.get(id, el.checked);
  el.addEventListener('change', () => { store.set(id, el.checked); render(); });
}
$('#lcolors').addEventListener('input', e => {
  const i = e.target.closest('input[type=color]'); if (!i) return;
  state.colors[i.dataset.layer] = i.value; store.set('lcolors', state.colors);
  render();
});
$('#lcolors').addEventListener('change', e => {
  const c = e.target.closest('input[type=checkbox]'); if (!c) return;
  if (c.checked) state.lbOff.delete(c.dataset.layer); else state.lbOff.add(c.dataset.layer);
  store.set(lbOffKey(), [...state.lbOff]);
  render();
});
$('#lcolors').addEventListener('click', e => {
  const n = e.target.closest('.lcolor span, .lcolor small'); if (!n) return;
  n.parentElement.querySelector('input[type=checkbox]').click();
});
$('#lcolorReset').addEventListener('click', () => { state.colors = {}; store.set('lcolors', {}); $('#lcolors').dataset.sig = ''; render(); });
let notesTimer = null;
$('#pages').addEventListener('input', e => {
  const a = e.target.closest('.ann[data-k]'); if (!a) return;
  const v = a.textContent.replace(/\s+/g, ' ').trim();
  if (v) state.notes[a.dataset.k] = v; else delete state.notes[a.dataset.k];
  clearTimeout(notesTimer); notesTimer = setTimeout(() => store.set(notesStoreKey(), state.notes), 300);
});
$('#pages').addEventListener('keydown', e => { if (e.target.closest('.ann') && e.key === 'Enter') { e.preventDefault(); e.target.blur(); } });
document.body.dataset.tab = state.tab;
document.querySelectorAll('#tabs button').forEach(b => b.classList.toggle('on', b.dataset.v === state.tab));

// langue
function setLang(l) {
  const ti = $('#titre');
  if (Object.values(I18N).some(d => d.defTitle === ti.value.trim())) { ti.value = I18N[l].defTitle; store.set('titre', ti.value); }
  LANG = l; store.set('lang', l);
  applyI18n(); setDropText();
  refreshRefUI();
  if (state.fx) { refreshHideUI(); showInfo(); render(); } else { $('#pageInfo').textContent = t('noFile'); }
}
$('#lang').addEventListener('change', e => setLang(e.target.value));
applyI18n();
if (!state.fx) $('#pageInfo').textContent = t('noFile');


// données intégrées : feuille du plugin grandMA2, ou feuille enregistrée avec « Enregistrer »
if (window.EMBEDDED_CSV) loadEmbedded(window.EMBEDDED_CSV, window.EMBEDDED_META, window.EMBEDDED_STATE);
</script>
</body>
</html>
]==]

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
