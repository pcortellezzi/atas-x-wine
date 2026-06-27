import sys

d = open(sys.argv[1],"rb").read()
for o,n in [("Serial number","ATAS-SN-2026X"),("deaddead-dead-dead-dead-deaddeaddead","6F88E200-A973-11EE-8C90-0800200C9A66"),("None","ATAS"),("WINEHDISK","DISK-ATAS"),("Base Board","ATAS-MB-X1"),("VideoController1","NVidiaGeForceRTX"),("VideoProcessor","GeForceRTX4050")]:
    ob=o.encode("utf-16-le"); nb=n.encode("utf-16-le")
    assert len(ob)==len(nb)
    c=d.count(ob)
    if c: d=d.replace(ob,nb); print(f"OK: {o!r} ({c}x)")
    else: print(f"SKIP: {o!r} not found")
open(sys.argv[1],"wb").write(d)
