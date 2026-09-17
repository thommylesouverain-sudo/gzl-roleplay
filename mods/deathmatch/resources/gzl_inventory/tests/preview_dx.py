"""Approximate offline layout preview from real DX Lua draw calls; not an MTA capture."""
import check_dx as test
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
lua,g,ROOT=test.lua,test.g,test.ROOT
canvas=Image.new('RGB',(1920,1080),(47,44,36))
def surface(_,x,y,w,h,options,post=True):
    if w<=0 or h<=0:return True
    layer=Image.new('RGBA',canvas.size); d=ImageDraw.Draw(layer)
    c=options['color']; color=tuple(int(c[i] or 255) for i in range(1,5))
    edge=options['borderColor']; border=tuple(int(edge[i] or 255) for i in range(1,5)) if edge else None
    d.rounded_rectangle((x,y,x+w,y+h),radius=max(0,options['radius'] or 0),fill=color,outline=border)
    canvas.paste(layer,(0,0),layer); return True
def rect(x,y,w,h,c,*args):return surface(None,x,y,w,h,lua.table_from({'color':c,'radius':0}))
def text(value,x,y,x2,y2,c,scale,font,align,*args):
    f=g.fonts[font]; size=max(7,int(f[2]*1.33)) if f else 12
    path=ROOT.parent/'aura_ui/assets'/('Manrope-Bold.ttf' if f and 'Bold' in f[1] else 'Manrope-Medium.ttf')
    ft=ImageFont.truetype(str(path),size)
    value=str(value)
    while value and ft.getlength(value)>x2-x:value=value[:-1]
    px=x if align=='left' else x2-ft.getlength(value) if align=='right' else (x+x2-ft.getlength(value))/2
    d=ImageDraw.Draw(canvas); d.text((px,(y+y2-size)/2),value,font=ft,fill=tuple(int(c[i]) for i in (1,2,3)))
textures={}
def texture(path,*args):
    el=g.createElement('texture'); textures[el]=ROOT/path;return el
def image(x,y,w,h,el,*args):
    path=textures.get(el)
    if path and path.is_file():
        im=Image.open(path).convert('RGBA');im=im.resize((max(1,int(w)),max(1,int(h))),Image.Resampling.LANCZOS)
        canvas.paste(im,(int(x),int(y)),im)
g.exports.aura_ui.uiDrawSurface=surface;g.dxDrawRectangle=rect;g.dxDrawText=text;g.dxCreateTexture=texture;g.dxDrawImage=image
g.InventorySurface.draw=lambda x,y,w,h,c,r,edge:surface(None,x,y,w,h,lua.table_from({'color':c,'radius':r,'borderColor':edge}))
lua.execute('''
sw=1920; sh=1080; cursorVisible=false
InventoryDX.left.items[4]={slot=4,name="water",count=3,weight=350,label="Su"}
InventoryDX.right.label="Dünya"
InventoryDX.setData(InventoryDX.left,InventoryDX.right)
InventoryDX.setVisible(true); frame()
''')
out=ROOT/'tests/preview-dx.png';canvas.save(out);print(out)
