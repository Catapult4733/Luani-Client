"""Android exporter branding contract; final APK/OS inspection is still required."""
from pathlib import Path
import re,unittest,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
class AndroidBrandingTests(unittest.TestCase):
    def test_launcher_and_adaptive_variants_use_project_artwork(self):
        preset=(ROOT/'distribution/android/export_presets.cfg').read_text()
        for key in ('main_192x192','adaptive_foreground_432x432','adaptive_background_432x432','adaptive_monochrome_432x432'):
            match=re.search(r'^launcher_icons/'+key+r'="res://([^"]+)"$',preset,re.M)
            self.assertIsNotNone(match,'Missing explicit Android icon: '+key)
            assert match is not None
            path=ROOT/'offline'/match.group(1);self.assertTrue(path.is_file())
            self.assertEqual(ET.fromstring(path.read_text()).tag,'{http://www.w3.org/2000/svg}svg')
    def test_android_splash_disables_stock_engine_image(self):
        preset=(ROOT/'distribution/android/export_presets.cfg').read_text()
        self.assertIn('splash_screen/disable_godot_boot_splash=true',preset)
        self.assertRegex(preset,r'splash_screen/icon="res://assets/branding/luani-[^"]+"')
        self.assertNotIn('boot_splash/show_image=false',(ROOT/'offline/project.godot').read_text(),'Keep desktop startup unchanged')
if __name__=='__main__':unittest.main()
