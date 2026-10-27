"""Narrow Android-only UI contract; actual APK screenshots remain required."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class AndroidChromeTests(unittest.TestCase):
    def test_website_has_no_native_toolbar_or_practice_handoff(self):
        java=(ROOT/'distribution/android/java/org/luani/client/LuaniWebsitePlugin.java').read_text()
        boot=(ROOT/'offline/scripts/bootstrap.gd').read_text()
        for removed in ('LinearLayout toolbar', 'button("Back"', 'button("Refresh"', 'button("Practice"', '"practice_requested"'):
            self.assertFalse(removed in java, 'Native Android website chrome remains: '+removed)
        self.assertNotIn('connect("practice_requested"',boot)
    def test_android_launcher_is_connecting_with_bounded_recovery(self):
        screen=ROOT/'offline/scripts/connecting_screen.gd'
        self.assertTrue(screen.is_file(), 'Android needs a connecting screen, not the desktop launcher')
        text=screen.read_text()
        self.assertIn('"connecting"',text)
        self.assertIn('func show_error',text)
        self.assertIn('retry_requested',text)
        for removed in ('Open Luani website','Offline practice'):
            self.assertNotIn(removed,text)
        boot=(ROOT/'offline/scripts/bootstrap.gd').read_text()
        launcher=boot.split('func _build_launcher()',1)[1].split('func _entered()',1)[0]
        early=launcher.split('_screen=CanvasLayer.new()',1)[0]
        self.assertIn('OS.has_feature("android")',early)
        self.assertIn('Connecting.new()',early)
        self.assertIn('return',early)
    def test_native_website_has_connecting_and_error_only_retry(self):
        text=(ROOT/'distribution/android/java/org/luani/client/LuaniWebsitePlugin.java').read_text()
        for required in ('new FrameLayout', '"connecting"', '"Retry"', 'onPageFinished', 'onReceivedHttpError', 'pageLoadGeneration'):
            self.assertTrue(required in text, 'Missing WebView connection/error state: '+required)
if __name__=='__main__':unittest.main()
