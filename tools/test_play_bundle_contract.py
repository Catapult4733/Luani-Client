from pathlib import Path
import configparser,unittest
ROOT=Path(__file__).resolve().parents[1]
class PlayBundleContract(unittest.TestCase):
 def test_play_preset_preserves_existing_application_identity(self):
  path=ROOT/'distribution/android/export_play.cfg'
  self.assertTrue(path.is_file(),'A distinct Play bundle preset is required; do not mutate the sideload channel')
  c=configparser.ConfigParser();c.read(path);p=c['preset.0.options']
  self.assertEqual(p['package/unique_name'],'"com.luani.client"')
  self.assertEqual(p['gradle_build/export_format'],'1')
  self.assertEqual(p['gradle_build/target_sdk'],'"36"')
  self.assertEqual(p['version/code'],'50004')
  self.assertEqual(p['architectures/arm64-v8a'],'true')
  self.assertEqual(p['package/signed'],'false','Sign the AAB outside the source tree, with jarsigner and the existing upload key')
  self.assertNotIn('release_password',path.read_text())
 def test_play_builder_verifies_a_real_signed_bundle(self):
  path=ROOT/'distribution/android/build_play_bundle.py'
  self.assertTrue(path.is_file(),'Need a real AAB export/sign/validation path')
  text=path.read_text()
  for value in ('jarsigner','bundletool','--source-sha256','audit_native_bundle','--build-root','.aab'):
   self.assertIn(value,text)
  self.assertNotIn('-genkeypair',text)
if __name__=='__main__':unittest.main()
