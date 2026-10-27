from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class AndroidBuildContract(unittest.TestCase):
    def test_isolated_production_and_nonshipping_profile_builds_preserve_key(self):
        text=(ROOT/'distribution/android/build_on_linux.py').read_text()
        for value in ('--build-root','--render-profile','android-preview-3','renderqa','.gdignore'):
            self.assertTrue(value in text,'Missing isolated build/profile contract: '+value)
        self.assertNotIn("'-genkeypair'",text,'An update must never generate a replacement signing key')
if __name__=='__main__':unittest.main()
