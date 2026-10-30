import importlib.util
import unittest
from pathlib import Path
SPEC=importlib.util.spec_from_file_location('luani_protocol',Path(__file__).resolve().parents[1]/'distribution/protocol_launch.py')
protocol=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(protocol)

class StudioProtocolTests(unittest.TestCase):
    def test_strict_paired_studio_launch_and_unchanged_online_launch(self):
        ticket='a'*43
        studio='b'*43
        uri=f'luani://launch?ticket={ticket}&studio=play&studio_ticket={studio}'
        parse=getattr(protocol,'parse_launch',None)
        self.assertTrue(callable(parse),'Studio paired launch parser is missing')
        self.assertEqual(parse(uri),{'ticket':ticket,'studio':'play','studio_ticket':studio})
        self.assertEqual(parse('luani://launch?ticket='+ticket),ticket)
        for bad in [uri+'&owner=1',uri.replace('&studio_ticket='+studio,''),uri.replace('studio=play','studio=server'),uri+'&ticket='+ticket,uri.replace('&studio_ticket=','&studioTicket='),uri+'#x']:
            with self.subTest(uri=bad),self.assertRaises(ValueError):parse(bad)

if __name__=='__main__':unittest.main()
