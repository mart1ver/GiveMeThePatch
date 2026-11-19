"""Assemble les plugins : la page index.html est intégrée dans chaque plugin.
À relancer après une modification de index.html ou d'un fichier *_src.lua :

    python3 build.py
"""
import os, zipfile

root = os.path.dirname(os.path.abspath(__file__))
html = open(os.path.join(root, 'index.html'), encoding='utf-8').read()
assert ']==]' not in html and '/*@@EMBEDDED_DATA@@*/' in html

XML = {
    'grandma2': '''<?xml version="1.0" encoding="utf-8"?>
<MA xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.malighting.de/grandma2/xml/MA" xsi:schemaLocation="http://schemas.malighting.de/grandma2/xml/MA http://schemas.malighting.de/grandma2/xml/3.9.60/MA.xsd" major_vers="3" minor_vers="9" stream_vers="60">
\t<Info datetime="2026-10-26T20:00:00" showfile="GiveMeThePatch" />
\t<Plugin index="0" execute_on_load="0" name="Give The Patch" luafile="GiveMeThePatch.lua" />
</MA>
''',
    'grandma3': '''<?xml version="1.0" encoding="UTF-8"?>
<GMA3 DataVersion="1.9.3.3">
\t<Plugin Name="Give The Patch" Author="Mart1ver" Version="1.0.0.0">
\t\t<ComponentLua Name="GiveMeThePatch" FileName="GiveMeThePatch.lua" />
\t</Plugin>
</GMA3>
''',
}

for d, xml in XML.items():
    src = open(os.path.join(root, d, 'GiveMeThePatch_src.lua'), encoding='utf-8').read()
    with open(os.path.join(root, d, 'GiveMeThePatch.lua'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(src.replace('@@TEMPLATE@@', html))
    with open(os.path.join(root, d, 'GiveMeThePatch.xml'), 'w', encoding='utf-8') as f:
        f.write(xml)
    # zip prêt à dézipper à la racine de la clé USB
    usb = {'grandma2': 'gma2/plugins', 'grandma3': 'gma3_library/datapools/plugins'}[d]
    name = 'GiveMeThePatch_' + d.replace('grandma', 'grandMA') + '.zip'
    with zipfile.ZipFile(os.path.join(root, d, name), 'w', zipfile.ZIP_DEFLATED) as z:
        for ext in ('lua', 'xml'):
            info = zipfile.ZipInfo(usb + '/GiveMeThePatch.' + ext, (2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, open(os.path.join(root, d, 'GiveMeThePatch.' + ext), 'rb').read())
    print(d + '/GiveMeThePatch.lua :', os.path.getsize(os.path.join(root, d, 'GiveMeThePatch.lua')), 'octets')
