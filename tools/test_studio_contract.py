"""Cheap source contracts. Engine/runtime/UI verification belongs on edward."""
import json
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

class StudioContracts(unittest.TestCase):
    def test_native_world_registry_and_data_only_runtime_exist(self):
        registry = ROOT / 'offline/studio/instances.json'
        self.assertTrue(registry.is_file(), 'Studio shared instance registry is missing')
        self.assertEqual(set(json.loads(registry.read_text())['classes']), {'Part','Model','Folder','SpawnPoint','Weld','PointLight','SpotLight','DirectionalLight'})
        data = (ROOT / 'offline/scripts/studio_data.gd').read_text()
        runtime = (ROOT / 'offline/scripts/studio_runtime.gd').read_text()
        self.assertIn('func validate', data)
        self.assertNotRegex(runtime, r'(?<!pre)load\(', 'Creator documents must not select arbitrary engine resources')
        self.assertIn('RigidBody3D.new()', runtime)
        self.assertIn('Weld', runtime)

    def test_studio_gets_its_own_managed_desktop_entry_without_a_second_uri_handler(self):
        installer = (ROOT / 'distribution/install.sh').read_text()
        self.assertIn('org.luani.Studio.desktop', installer)
        self.assertIn('Name=Luani Studio', installer)
        self.assertIn(' --studio', installer)

if __name__ == '__main__':
    unittest.main()
