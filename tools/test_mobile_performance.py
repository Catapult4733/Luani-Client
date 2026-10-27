"""Android render-state wiring, not a promise of physical-phone FPS."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class MobilePerformanceTests(unittest.TestCase):
    def test_active_game_and_hidden_website_have_separate_budgets(self):
        p=ROOT/'offline/scripts/mobile_performance.gd'
        self.assertTrue(p.exists(),'Need Android-only frame-state policy, not a server FPS change')
        text=p.read_text()
        for value in ('OS.has_feature("android")','Engine.max_fps','low_processor_usage_mode','VSYNC_ENABLED','settings_for'):
            self.assertIn(value,text)
        boot=(ROOT/'offline/scripts/bootstrap.gd').read_text()
        self.assertIn('MobilePerformance.set_website_visible(true)',boot)
        self.assertIn('MobilePerformance.set_website_visible(false)',boot)
        java=(ROOT/'distribution/android/java/org/luani/client/LuaniWebsitePlugin.java').read_text()
        for value in ('browser.pauseTimers()','browser.resumeTimers()','prefer60Hz','getSupportedModes'):
            self.assertTrue(value in java,'Missing measured-scope background/pacing wiring: '+value)
    def test_android_world_reduces_shadow_and_mesh_overhead(self):
        world=(ROOT/'offline/scripts/world.gd').read_text()
        self.assertIn('SHADOW_CASTING_SETTING_OFF',world,'Baseplate grid lines should not cast shadows into directional cascades')
        self.assertIn('SHADOW_ORTHOGONAL',world,'Android should use single-pass orthogonal directional shadows')
        avatar=(ROOT/'offline/scripts/avatar.gd').read_text()
        self.assertIn('radial_segments',avatar,'Avatar eye spheres should bound segment count')
        self.assertIn('is_visible_in_tree()',avatar,'Hidden HUD avatar preview should skip per-frame animation')
        pickup=(ROOT/'offline/scripts/pickup.gd').read_text()
        self.assertIn('SHADOW_CASTING_SETTING_OFF',pickup,'Pickup floor rings/pads should not cast shadows')
if __name__=='__main__':unittest.main()
