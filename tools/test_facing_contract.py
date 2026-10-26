"""Protocol source guard; real math/packet checks run on the authorized build laptop."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class FacingContract(unittest.TestCase):
    def test_camera_lock_is_sent_separately(self):
        source=(ROOT/'offline/scripts/network_client.gd').read_text()
        self.assertIn('"look_locked":look_locked',source,'Camera yaw alone cannot describe body facing in free-camera mode')
    def test_snapshot_uses_body_facing_not_tool_aim(self):
        source=(ROOT/'offline/scripts/dedicated_server.gd').read_text()
        snapshot=source.split('func _broadcast_snapshots()',1)[1].split('func _broadcast(',1)[0]
        self.assertIn('member.facing',snapshot)
        self.assertNotIn('member.yaw,body.is_on_floor()',snapshot)
    def test_facing_math_is_shared(self):
        self.assertTrue((ROOT/'offline/scripts/facing.gd').is_file())
        for name in ('player.gd','dedicated_server.gd'):
            self.assertIn('Facing.target',(ROOT/'offline/scripts'/name).read_text())
if __name__=='__main__':unittest.main()
