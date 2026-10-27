from pathlib import Path
import importlib.util,struct,unittest
ROOT=Path(__file__).resolve().parents[1]
def elf64(alignment=16384,shared_relro=False):
 ident=b'\x7fELF'+bytes((2,1,1))+bytes(9)
 count=2 if shared_relro else 1
 header=struct.pack('<HHIQQQIHHHHHH',3,183,1,0,64,0,0,64,56,count,0,0,0)
 load=struct.pack('<IIQQQQQQ',1,6,0,0,0,256,32768,alignment)
 relro=struct.pack('<IIQQQQQQ',0x6474e552,4,0,0,0,4096,4096,1) if shared_relro else b''
 return (ident+header+load+relro).ljust(256,b'\0')
class ElfAlignmentTests(unittest.TestCase):
 def setUp(self):
  p=ROOT/'distribution/android/play_bundle_audit.py';self.assertTrue(p.is_file(),'Need real ELF-header verification, not a renamed ZIP or FPS assumption')
  spec=importlib.util.spec_from_file_location('play_bundle_audit',p);assert spec is not None and spec.loader is not None;m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);self.audit=m.audit_elf
 def test_accepts_16kb_load_segments(self):self.assertTrue(self.audit(elf64(),'arm64-v8a')['compatible_16kb'])
 def test_rejects_4kb_load_segments(self):self.assertFalse(self.audit(elf64(4096),'arm64-v8a')['compatible_16kb'])
 def test_rejects_shared_misaligned_relro(self):self.assertFalse(self.audit(elf64(shared_relro=True),'arm64-v8a')['compatible_16kb'])
 def test_rejects_non_elf_input(self):
  with self.assertRaises(ValueError):self.audit(b'not-an-elf','arm64-v8a')
if __name__=='__main__':unittest.main()
