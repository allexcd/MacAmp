from pathlib import Path
root=Path(__file__).resolve().parent.parent
out=root/'Licenses'; out.mkdir(exist_ok=True)
for package in (root/'.build/checkouts').iterdir():
    if package.is_dir():
        for f in package.iterdir():
            if f.is_file() and ('LICENSE' in f.name.upper() or 'COPYING' in f.name.upper()):
                (out/(package.name+'-'+f.name)).write_bytes(f.read_bytes())
