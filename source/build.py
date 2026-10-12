import json,re,subprocess
VER="2.2"; OUT="planners/"
src=open('source/route-planner-source.html').read()
stores=json.load(open('source/stores.json'))
i=src.index('// ===EDITION-START==='); j=src.index('// ===EDITION-END===')
MARK='/*@@EDITION@@*/'; template=src[:i]+MARK+src[j:]; va_block=src[i:j]
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
        n=len(set(re.findall(r'^(\d+)\t',va_block,re.M)))
        E.append(dict(code="VA",title="Virginia",file=f"route-planner-VA-v{VER}.html",stores=25,block=va_block,
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
B={"version":VER,"template":template,"editions":[{k:e[k] for k in("code","title","file","stores","note","block","size")} for e in E]}
payload=json.dumps(B,separators=(',',':')).replace('<','\\u003c')
tag='<script type="application/json" id="bundle">'
for old,new in [("route-planner-downloads.html","route-planner-downloads.html"),("route-planner-downloads-local-v2.1.html",f"route-planner-downloads-local-v{VER}.html")]:
    h=open(OUT+old).read(); a=h.index(tag)+len(tag); b=h.index('</script>',a)
    open(OUT+new,'w').write(h[:a]+payload+h[b:]); print(new)
