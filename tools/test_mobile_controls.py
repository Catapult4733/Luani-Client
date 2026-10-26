from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class MobileControlContract(unittest.TestCase):
    def test_mode_saved_and_validated(self):
        text=(ROOT/'offline/scripts/session_state.gd').read_text()
        self.assertIn('mobile_joystick_mode',text)
        self.assertIn('set_mobile_joystick_mode',text)
        self.assertIn('"fixed", "floating"',text)
    def test_floating_stick_math_is_separate_and_bounded(self):
        self.assertTrue((ROOT/'offline/scripts/touch_geometry.gd').exists())
        text=(ROOT/'offline/scripts/mobile_controls.gd').read_text()
        for token in ('Geometry.stick_offset','Geometry.movement','_floating_origin','touch_hits_ui'):
            self.assertIn(token,text)
    def test_android_does_not_show_desktop_shortcut_tooltips(self):
        text=(ROOT/'offline/scripts/hud.gd').read_text()
        self.assertTrue('b.tooltip_text = "" if OS.has_feature("android") else title' in text, 'Mobile must not show desktop shortcut tooltips')
    def test_empty_custom_tooltip_stays_empty(self):
        text=(ROOT/'offline/scripts/ui_controls.gd').read_text()
        self.assertIn('if _for_text.is_empty(): return null',text)
    def test_scale_is_android_only(self):
        p=ROOT/'offline/scripts/mobile_ui.gd';self.assertTrue(p.exists())
        self.assertIn('OS.has_feature("android")',p.read_text())
if __name__=='__main__':unittest.main()
