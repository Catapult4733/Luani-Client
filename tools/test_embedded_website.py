from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class EmbeddedWebsiteContract(unittest.TestCase):
    def test_native_browser_exists_without_a_javascript_secret_bridge(self):
        p=ROOT/'distribution/android/java/org/luani/client/LuaniWebsitePlugin.java'
        self.assertTrue(p.exists(),'Android needs a real WebView plugin, not an external browser shortcut')
        text=p.read_text()
        for token in ('new WebView','setDomStorageEnabled(true)','setAllowFileAccess(false)','setAllowContentAccess(false)','MIXED_CONTENT_NEVER_ALLOW','handler.cancel()','WebsitePolicy.canLaunchFrom'):
            self.assertIn(token,text)
        self.assertNotIn('addJavascriptInterface',text)
        self.assertNotIn('getCookie(',text)
    def test_practice_cancels_pending_web_launch(self):
        source=(ROOT/'offline/scripts/bootstrap.gd').read_text()
        practice=source.split('func _practice()',1)[1].split('func return_to_website()',1)[0]
        self.assertIn('_android.cancel_pending()',practice)
    def test_android_boot_opens_embedded_site(self):
        text=(ROOT/'offline/scripts/bootstrap.gd').read_text()
        for token in ('LuaniWebsite','showWebsite','return_to_website','MobileUI.configure'):
            self.assertIn(token,text)
if __name__=='__main__':unittest.main()
