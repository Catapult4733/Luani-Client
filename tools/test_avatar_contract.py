"""Cheap source/package contracts only. Godot runtime checks belong on edward."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

class AvatarSourceContracts(unittest.TestCase):
    def test_shared_six_part_renderer_updates_cosmetics_without_rebuilding_pivots(self):
        spec = json.loads((ROOT / 'offline/assets/avatar/definition.json').read_text())
        self.assertEqual(len(spec['parts']), 6)
        self.assertTrue(all(item['price'] == 0 for item in spec['catalog']))
        data = ROOT / 'offline/scripts/avatar_data.gd'
        self.assertTrue(data.is_file(), 'Missing canonical data-only native avatar model')
        source = (ROOT / 'offline/scripts/avatar.gd').read_text()
        self.assertIn('func apply_appearance(', source)
        self.assertIn('AvatarData.definition()', source)
        self.assertIn('EULER_ORDER_XYZ', source)
        update = source.split('func apply_appearance(', 1)[1].split('\nfunc ', 1)[0]
        self.assertNotIn('_part(', update, 'Appearance refresh must retain tool/animation pivots')
        self.assertIn('_rebuild_accessories()', update)

    def test_live_refresh_is_host_admission_bound_and_does_not_reset_controls(self):
        sync = ROOT / 'offline/scripts/avatar_sync.gd'
        self.assertTrue(sync.is_file(), 'Missing bounded host-to-roster refresh')
        source = sync.read_text()
        self.assertIn('member.get("admission_id")', source)
        self.assertIn('profile.get("public_id"', source)
        self.assertIn('AvatarData.revision(', source)
        server = (ROOT / 'offline/scripts/dedicated_server.gd').read_text()
        self.assertIn('"avatar_updates":true', server)
        self.assertIn('AvatarSync.apply_updates(_peers,', server)
        client = (ROOT / 'offline/scripts/network_client.gd').read_text()
        self.assertIn('SessionState.apply_server_avatar(', client)
        remote = (ROOT / 'offline/scripts/remote_player.gd').read_text()
        self.assertIn('func apply_profile(', remote)
        self.assertIn('rig.apply_appearance(', remote)
        session = (ROOT / 'offline/scripts/session_state.gd').read_text().split('func apply_server_avatar(', 1)[1].split('\nfunc ', 1)[0]
        self.assertNotIn('preferences_changed.emit()', session)

    def test_android_exports_include_the_raw_shared_json_asset(self):
        for relative in ['distribution/android/export_presets.cfg', 'distribution/android/export_play.cfg']:
            content = (ROOT / relative).read_text()
            include = next(line for line in content.splitlines() if line.startswith('include_filter='))
            self.assertIn('*.json', include, f'{relative} would omit the canonical rig/catalog from its PCK')

if __name__ == '__main__':
    unittest.main()
