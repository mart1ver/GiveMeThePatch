# Give Me The Patch

Feuilles de patch et étiquettes imprimables à partir d'une grandMA2, d'une grandMA3, de WYSIWYG ou de Capture — *printable patch sheets and fixture labels.*

Par **Mart1ver**.

```
index.html                 la page web : tout se passe ici
grandma2/                  plugin grandMA2 (GiveMeThePatch.lua + .xml)
grandma3/                  plugin grandMA3 (GiveMeThePatch.lua + .xml)
build.py                   intègre index.html dans les deux plugins
LICENSE                    GPL v3
```

## Page web

Ouvrir `index.html` dans un navigateur, ou la page publiée sur GitHub Pages, puis déposer un export CSV. Le fichier est lu dans le navigateur : rien n'est envoyé à un serveur.

- **Feuille de patch** (A3 ou A4 paysage) :
  - récapitulatifs par layer, par univers et par type ;
  - patch par layer et patch par univers ;
  - plan d'occupation : une barre de 512 canaux par univers, avec les plages libres ;
  - alertes : adresses en double, plages qui se chevauchent, projecteurs non patchés.
- **Étiquettes** à coller sur les projecteurs :
  - planches A3 à découper (4 × 3, 3 × 4 ou 5 × 2 cm), ou planches adhésives A4 du commerce (Avery, ou dimensions au choix) ;
  - une couleur par layer, et choix des informations imprimées, ou « Fix ID seul » pour le lire de loin ;
  - une annotation par étiquette.
- **Changements** : on charge l'ancien patch, la page liste les projecteurs modifiés, ajoutés et supprimés. Ce récap peut être ajouté en tête de la feuille.
- **Enregistrer la feuille** : un seul fichier `.html` avec le patch, les annotations, les masquages et les réglages, à envoyer tel quel.

Interface et documents imprimés en français, anglais, espagnol, allemand, japonais, russe et arabe. La langue de l'interface et celle des documents se choisissent séparément.

Pour imprimer : marges *Aucune*, « Graphiques d'arrière-plan » coché. Pour les planches adhésives, imprimer à 100 % (*Taille réelle*).

**Fichiers acceptés :** CSV grandMA2 / grandMA3 (`Layer;Fix ID;Ch ID;Name;FixtureType;Patch`), rapport *Spots* de WYSIWYG, export de Capture, ou une feuille `.html` du plugin. Si les colonnes ne sont pas reconnues, la page demande lesquelles utiliser et retient ce choix.

## Plugins grandMA2 et grandMA3

Le plugin lit le patch dans le show et écrit la feuille (`.html`, données intégrées) et le CSV sur la clé USB, dans un dossier `GiveMeThePatch`. Il trouve la clé tout seul. Dans le pool Plugins, il s'appelle **Give The Patch**.

Le plus simple : dans la page web, boutons **grandMA2** / **grandMA3** du panneau de gauche. Le zip se dézippe à la racine de la clé USB et met les fichiers au bon endroit.

| | Copier `GiveMeThePatch.lua` + `.xml` dans | Puis |
|---|---|---|
| grandMA2 | `gma2/plugins` de la clé (onPC : dossier `plugins` de l'installation) | Pool Plugins → Import |
| grandMA3 | `gma3_library/datapools/plugins` de la clé | Pool Plugins → Import |

La première fenêtre indique où la feuille sera écrite et demande le titre, le lieu et les 4 lignes du cartouche.

Si le plugin ne lit aucun projecteur : mettre `diag = true` en tête du fichier `.lua` et relancer. Il écrit alors un rapport `GiveMeThePatch_diag.txt` à côté de la feuille (le plugin grandMA3 l'écrit de lui-même).

Après une modification de `index.html` ou d'un `GiveMeThePatch_src.lua` : `python3 build.py`, puis réimporter le plugin.

## Licence

GiveMeThePatch est un logiciel libre, sous licence **GNU GPL v3 ou ultérieure** (fichier `LICENSE`). On peut l'utiliser, le modifier et le redistribuer ; les versions modifiées doivent rester sous GPL, avec leur code source.

---

**English.** Open `index.html` and drop a CSV export from grandMA2/3, WYSIWYG or Capture. You get a patch sheet, colour-coded fixture labels (A3 to cut out, or A4 adhesive sheets), a list of changes against an older patch, and a *Save* button that writes everything into a single shareable `.html` file. Available in French, English, Spanish, German, Japanese, Russian and Arabic. The `grandma2/` and `grandma3/` plugins read the patch on the console and write the sheet to a USB stick. License: GNU GPL v3 or later.
