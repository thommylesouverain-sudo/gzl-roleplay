"""Read-only audit: CEF/business files unchanged, Lua syntax, exports and dependencies."""
from pathlib import Path
import hashlib,json,re,subprocess
import xml.etree.ElementTree as ET
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[2]
audit=json.loads(Path(__file__).with_name("migration_manifest.json").read_text(encoding="utf-8"))
# Inventory alone was subsequently authorized for CEF -> DX migration.
# Its server, definitions and web assets remain covered by the original hashes.
inventory_dx={"gzl_inventory/client/main.lua","gzl_inventory/meta.xml"}
for name,expected in audit["protected"].items():
    if name in inventory_dx: continue
    assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==expected, f"Protected file changed: {name}"
lua=LuaRuntime(unpack_returned_tuples=True)
compile_lua=lua.eval('function(code,name) local f,e=loadstring(code,name); return f~=nil,e end')
exports={e.get("function") for e in ET.parse(ROOT/"aura_ui/meta.xml").getroot().findall("export")}
count=0
for resource in audit["resources"]+["gzl_ui","aura_ui","gzl_inventory"]:
    meta=ET.parse(ROOT/resource/"meta.xml").getroot()
    if resource!="aura_ui": assert any(e.get("resource")=="aura_ui" for e in meta.findall("include")),resource
    for script in meta.findall("script"):
        if script.get("type")!="client": continue
        path=ROOT/resource/script.get("src")
        source=path.read_text(encoding="utf-8-sig")
        ok,error=compile_lua(source,str(path))
        assert ok,(str(path),error)
        for function in re.findall(r'exports\.aura_ui:(\w+)\(',source): assert function in exports,(str(path),function)
        count+=1
repo=Path(subprocess.check_output(["git","rev-parse","--show-toplevel"],cwd=ROOT,text=True).strip())
for name in audit["files"]:
    path=ROOT/name
    before=subprocess.check_output(["git","show","HEAD:"+path.relative_to(repo).as_posix()],cwd=ROOT).decode("utf-8-sig").replace("\r\n","\n")
    after=path.read_text(encoding="utf-8-sig")
    # Gameplay/network actions and handler registrations were not rewritten.
    pattern=r'\b(?:triggerServerEvent|addEventHandler|addEvent|bindKey|addCommandHandler)\([^\n]+'
    assert re.findall(pattern,before)==re.findall(pattern,after),f"Event contract changed: {name}"
print(f"PASS: {len(audit['protected'])-len(inventory_dx)} protected CEF/server/shared/assets unchanged; {count} client scripts parse as Lua 5.1; exports/dependencies valid; original DX migration event contracts retained.")
