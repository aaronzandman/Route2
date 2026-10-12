import json,re,subprocess
VER="2.9.1"; OUT="planners/"
src=open('source/route-planner-source.html').read()
stores=json.load(open('source/stores.json'))
i=src.index('// ===EDITION-START==='); j=src.index('// ===EDITION-END===')
MARK='/*@@EDITION@@*/'; template=src[:i]+MARK+src[j:]; va_block=src[i:j]
# Virginia edition keeps its own list (with route groups); add any Virginia store it doesn't have yet. Never remove.
def _va_add(block):
    have=set(re.findall(r'^(\d+)\t',block.split('const DEFAULT_STORES = `')[1].split('`')[0],re.M))
    new=[r for r in stores if r.get("State")=="VA" and str(r["Store #"]) not in have]
    if not new: return block
    c=lambda v:"" if v is None or str(v).strip().lower()=="not available" else str(v).replace("\t"," ").replace("`","'")
    srow="\n".join(f'{r["Store #"]}\t\t{c(r.get("Shopping Center"))}\t{c(r.get("Address"))}\t{c(r.get("City"))}\tVA\t{c(r.get("Zip"))}\t\t{c(r.get("Phone"))}' for r in new)
    crow="\n".join(f'{r["Store #"]}\t{c(r.get("Latitude"))}\t{c(r.get("Longitude"))}' for r in new if c(r.get("Latitude")))
    grow="\n".join(f'P{r["Store #"]}\tNEW' for r in new)
    def app(b,name,rows):
        k=b.index('const '+name+' = `'); e=b.index('`;',k); return b[:e]+("\n" if rows else "")+rows+b[e:]
    block=app(block,"DEFAULT_STORES",srow); block=app(block,"DEFAULT_GROUPS",grow)
    if crow: block=app(block,"DEFAULT_COORDS",crow)
    print("Virginia edition: added",", ".join(str(r["Store #"]) for r in new))
    return block
va_block=_va_add(va_block)
STATES={"AL":"Alabama","FL":"Florida","GA":"Georgia","KY":"Kentucky","NC":"North Carolina","SC":"South Carolina","TN":"Tennessee"}
cols=["Store #","Shopping Center","Address","City","State","Zip","Phone","Latitude","Longitude"]
clean=lambda v:"" if v is None or str(v).strip().lower()=="not available" else str(v).replace("\t"," ").replace("`","'").replace("\\","/").replace("${","$ {")
tsv=lambda rows:"\n".join(["\t".join(cols)]+["\t".join(clean(r.get(c)) for c in cols) for r in rows])
def block(id,name,key,reset,groupBy,rows):
    return ('// ===EDITION-START===\nconst EDITION = {id:%s, name:%s, key:%s, resetLabel:%s, groupBy:%s};\n'
            'const DEFAULT_GROUPS = ``;\nconst DEFAULT_STORES = `%s`;\nconst DEFAULT_COORDS = ``;\n')%(
            json.dumps(id),json.dumps(name),json.dumps(key),json.dumps(reset),json.dumps(groupBy),tsv(rows))
E=[dict(code="ALL",title="Company-wide",file=f"route-planner-v{VER}.html",stores=len(stores),note="All 1,443 stores in every state",
        block=block("company","Service Route Planner – Company Wide","rpc.","Restore company store list","state",stores))]
for code,name in sorted(list(STATES.items())+[("VA","Virginia")]):
    if code=="VA":
        n=len(set(re.findall(r'^(\d+)\t',va_block.split('const DEFAULT_STORES = `')[1].split('`')[0],re.M)))
        E.append(dict(code="VA",title="Virginia",file=f"route-planner-VA-v{VER}.html",stores=n,block=va_block,
            note="All Virginia stores plus Kill Devil Hills, NC (1615), with route groups A–F"))
    else:
        rows=[r for r in stores if r["State"]==code]
        E.append(dict(code=code,title=name,file=f"route-planner-{code}-v{VER}.html",stores=len(rows),note=f"{len(rows)} {name} stores, grouped by city",
            block=block("state-"+code,"Service Route Planner – "+name,"rp-"+code+".","Restore "+name+" store list","city",rows)))
for e in E:
    html=template.replace(MARK,e["block"]); e["size"]=len(html.encode())
    open('/tmp/t.js','w').write(html.split('<script>')[1].split('</script>')[0])
    r=subprocess.run(['node','-e',"new Function(require('fs').readFileSync('/tmp/t.js','utf8'))"],capture_output=True,text=True); assert r.returncode==0,(e["code"],r.stderr)
    open(OUT+e["file"],'w').write(html); print(e["file"],e["stores"])
    open(OUT+("ALL" if e["code"]=="ALL" else e["code"])+".html",'w').write(html)  # stable link, always newest
    c=("ALL" if e["code"]=="ALL" else e["code"])
    open(OUT+c+".webmanifest",'w').write(json.dumps({"id":"route-planner-"+c,"name":"Route Planner – "+e["title"],"short_name":"Route "+c,
        "start_url":c+".html","scope":"./"+c+".html","display":"standalone","background_color":"#E9EDF0","theme_color":"#1F6B4F",
        "icons":[{"src":"../icons/icon-192.png","sizes":"192x192","type":"image/png"},{"src":"../icons/icon-512.png","sizes":"512x512","type":"image/png"},
                 {"src":"../icons/icon-maskable-512.png","sizes":"512x512","type":"image/png","purpose":"maskable"}]},indent=1))
open("version.json","w").write(json.dumps({"version":VER,"editions":[("ALL" if e["code"]=="ALL" else e["code"]) for e in E]}))
B={"version":VER,"template":template,"editions":[{k:e[k] for k in("code","title","file","stores","note","block","size")} for e in E]}
payload=json.dumps(B,separators=(',',':')).replace('<','\\u003c')
tag='<script type="application/json" id="bundle">'
# Offline download page (repo index.html) gets the new bundle; a versioned copy goes to the outputs folder.
import os
for path in ["index.html"]:
    hh=open(path).read(); a=hh.index(tag)+len(tag); b=hh.index('</script>',a)
    open(path,'w').write(hh[:a]+payload+hh[b:]); print("updated",path)
EXTRA=os.environ.get("EXTRA_OUT")
if EXTRA:
    import shutil
    shutil.copy("index.html",EXTRA+f"/route-planner-downloads-local-v{VER}.html")
    for e in E: shutil.copy(OUT+e["file"],EXTRA+"/"+e["file"])
    pub=EXTRA+"/route-planner-downloads.html"
    if os.path.exists(pub):
        hh=open(pub).read(); a=hh.index(tag)+len(tag); b=hh.index('</script>',a)
        open(pub,'w').write(hh[:a]+payload+hh[b:]); print("updated published page")
