"""Static Android distribution contract, not gameplay acceptance."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class AndroidSourceTests(unittest.TestCase):
    def test_native_launch_is_present_and_bounded(self):
        p=ROOT/'offline/scripts/android_launch.gd'
        self.assertTrue(p.is_file(),'Android needs its own HTTPS ticket redemption; Linux memfd/Python cannot run on Android')
        text=p.read_text()
        for value in ('AndroidRuntime','getActivity','getIntent','getDataString','HTTPRequest','body_size_limit','max_redirects','[A-Za-z0-9_-]{43}'):
            self.assertIn(value,text)
        self.assertNotIn('client_unsafe',text)
    def test_packaged_android_assets_use_resource_loader(self):
        text=(ROOT/'offline/scripts/ui_theme.gd').read_text()
        self.assertIn('ResourceLoader.load',text,'Exported APK remaps imported font/SVG assets; raw FileAccess loses them')
        self.assertIn('OS.has_feature("android")',text)
    def test_touch_controls_present(self):
        p=ROOT/'offline/scripts/mobile_controls.gd'
        self.assertTrue(p.is_file(),'Android needs movement/camera/jump controls, not desktop-only keyboard input')
if __name__=='__main__':unittest.main()
