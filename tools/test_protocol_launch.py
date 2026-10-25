import importlib.util
from pathlib import Path
import unittest

PATH=Path(__file__).resolve().parents[1]/'distribution/protocol_launch.py'
spec=importlib.util.spec_from_file_location('protocol_launch',PATH)
assert spec is not None and spec.loader is not None
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ProtocolTests(unittest.TestCase):
    def test_ticket_only_fixed_origin_uri(self):
        ticket='A'*43
        self.assertEqual(module.parse_uri('luani://launch?ticket='+ticket),ticket)
    def test_rejects_flags_urls_reusable_tokens_and_ambiguous_uris(self):
        bad=['--server','https://new.luani.fyi','luani://launch?ticket=a.b.c',
             'luani://launch?ticket='+'A'*43+'&server=attacker.invalid',
             'luani://launch?ticket='+'A'*43+'&ticket='+'B'*43,
             'luani://user@launch?ticket='+'A'*43,
             'luani://launch:443?ticket='+'A'*43,
             'luani://launch/path?ticket='+'A'*43,
             'luani://launch?ticket='+'A'*43+'#fragment',
             'luani://launch?ticket='+'A'*43+'\n']
        for uri in bad:
            with self.subTest(uri=uri),self.assertRaises(ValueError): module.parse_uri(uri)

if __name__=='__main__': unittest.main()
