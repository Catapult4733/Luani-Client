"""Read ELF/ZIP metadata only; no engine or uploaded code execution."""
import struct,zipfile
PAGE=16384

def audit_elf(data: bytes,abi: str) -> dict:
    if len(data)<64 or data[:4]!=b'\x7fELF' or data[4] not in (1,2) or data[5] not in (1,2):
        raise ValueError('Invalid ELF header')
    endian='<' if data[5]==1 else '>'
    wide=data[4]==2
    header=struct.unpack_from(endian+('HHIQQQIHHHHHH' if wide else 'HHIIIIIHHHHHH'),data,16)
    offset,stride,count=header[4],header[8],header[9]
    fmt=endian+('IIQQQQQQ' if wide else 'IIIIIIII');minimum=struct.calcsize(fmt)
    if stride<minimum or count<1 or offset+stride*count>len(data):raise ValueError('Invalid program-header bounds')
    segments=[]
    for n in range(count):
        p=struct.unpack_from(fmt,data,offset+n*stride)
        if wide:kind,flags,file_offset,address,_,file_size,memory_size,alignment=p
        else:kind,file_offset,address,_,file_size,memory_size,flags,alignment=p
        segments.append({'type':kind,'flags':flags,'offset':file_offset,'vaddr':address,'filesz':file_size,'memsz':memory_size,'alignment':alignment})
    loads=[p for p in segments if p['type']==1]
    if not loads:raise ValueError('ELF has no LOAD segments')
    required=abi in ('arm64-v8a','x86_64')
    errors=[]
    if required:
        for p in loads:
            if p['alignment']<PAGE or p['offset']%PAGE!=p['vaddr']%PAGE:errors.append('LOAD alignment below/inconsistent with16KB')
        for relro in (p for p in segments if p['type']==0x6474e552):
            end=relro['vaddr']+relro['memsz'];protected_end=((end+PAGE-1)//PAGE)*PAGE
            # Non-aligned RELRO is allowed when isolated from subsequent writable data.
            if end!=protected_end and any(p['flags']%4>=2 and p['vaddr']<protected_end and p['vaddr']+p['memsz']>end for p in loads):
                errors.append('RELRO protection overlaps a writable16KB sub-page')
    return {'abi':abi,'elf_bits':64 if wide else 32,'required_16kb':required,'load_alignments':[p['alignment'] for p in loads],'compatible_16kb':not errors,'errors':errors}

def audit_native_bundle(path) -> list[dict]:
    results=[]
    with zipfile.ZipFile(path) as z:
        names=z.namelist()
        if any(n.endswith(('.p12','.keystore','.jks','.password')) or 'export_credentials' in n for n in names):raise ValueError('Private signing material in bundle')
        if any('qa_render_profile' in n for n in names):raise ValueError('Nonshipping QA fixture in bundle')
        for name in names:
            parts=name.split('/')
            if len(parts)==4 and parts[:2]==['base','lib'] and name.endswith('.so'):
                result=audit_elf(z.read(name),parts[2]);result['entry']=name;results.append(result)
    if not results:raise ValueError('Bundle has no native libraries')
    return results
