"""Installer association checks in temporary XDG homes; never run/install a game."""
import ast
import configparser
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / 'distribution/install.sh'
MIME = 'x-scheme-handler/luani'
DESKTOP = 'org.luani.Client.desktop'


def installer_functions():
    source = SOURCE.read_text().split("<<'PY'\n", 1)[1].rsplit('\nPY', 1)[0]
    tree = ast.parse(source, filename=str(SOURCE))
    tree.body = [node for node in tree.body if isinstance(node, (
        ast.Import, ast.ImportFrom, ast.FunctionDef, ast.ClassDef))]
    namespace = {}
    exec(compile(tree, str(SOURCE), 'exec'), namespace)
    return namespace


class CaseSensitiveConfig(configparser.ConfigParser):
    def optionxform(self, optionstr: str) -> str:
        return optionstr


def config(path):
    parser = CaseSensitiveConfig(interpolation=None, strict=False)
    parser.read(path)
    return parser


class AssociationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.home = self.root / 'home'
        self.cfg = self.home / '.config'
        self.apps = self.home / '.local/share/applications'
        self.system = self.root / 'system/share/applications'
        self.syscfg = self.root / 'system/config'
        for directory in (self.cfg, self.apps, self.system, self.syscfg):
            directory.mkdir(parents=True)
        self.environment = patch.dict(os.environ, {
            'HOME': str(self.home), 'XDG_CONFIG_HOME': str(self.cfg),
            'XDG_DATA_HOME': str(self.apps.parent),
            'XDG_CONFIG_DIRS': str(self.syscfg),
            'XDG_DATA_DIRS': str(self.system.parent),
            'XDG_CURRENT_DESKTOP': 'KDE:GNOME',
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.functions = installer_functions()

    def reset(self):
        self.assertIn('configure_luani_protocol', self.functions,
                      'Installer only sets a default; it does not remove competing Luani associations')
        return self.functions['configure_luani_protocol'](self.apps)

    def test_replaces_competing_handlers_without_touching_other_apps_or_protocols(self):
        user = self.cfg / 'mimeapps.list'
        original = ('# Keep this comment\n[Default Applications]\n'
                    + MIME + '=old.desktop;org.luani.Client.desktop;\n'
                    'x-scheme-handler/https=browser.desktop;\n'
                    '[Added Associations]\n' + MIME + '=old.desktop;\n'
                    '[Removed Associations]\n' + MIME + '=org.luani.Client.desktop;retired.desktop;\n')
        user.write_text(original)
        legacy = self.system / 'competing.desktop'
        legacy_text = ('[Desktop Entry]\nType=Application\nName=Other application\n'
                       'Exec=/bin/true %u\nMimeType=' + MIME + ';text/plain;\n')
        legacy.write_text(legacy_text)
        global_config = self.syscfg / 'mimeapps.list'
        global_text = '[Default Applications]\n' + MIME + '=global.desktop;\n'
        global_config.write_text(global_text)
        self.reset()
        actual = config(user)
        for section in ('Default Applications', 'Added Associations'):
            self.assertEqual(actual[section][MIME], DESKTOP + ';')
        self.assertEqual(set(actual['Removed Associations'][MIME].strip(';').split(';')),
                         {'old.desktop', 'retired.desktop', 'competing.desktop', 'global.desktop'})
        self.assertEqual(actual['Default Applications']['x-scheme-handler/https'], 'browser.desktop;')
        self.assertIn('# Keep this comment', user.read_text())
        self.assertEqual(legacy.read_text(), legacy_text)
        self.assertEqual(global_config.read_text(), global_text)
        backups = list(self.cfg.glob('.mimeapps.list.luani-backup-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), original)
    def test_resets_desktop_specific_and_legacy_overrides(self):
        paths = [self.cfg / 'kde-mimeapps.list', self.apps / 'gnome-mimeapps.list',
                 self.apps / 'defaults.list']
        for path in paths:
            path.write_text('[Default Applications]\n' + MIME + '=desktop-old.desktop;\n'
                            'x-scheme-handler/https=browser.desktop;\n')
        self.reset()
        for path in paths:
            actual = config(path)
            self.assertEqual(actual['Default Applications'][MIME], DESKTOP + ';', str(path))
            self.assertEqual(actual['Default Applications']['x-scheme-handler/https'], 'browser.desktop;')
            self.assertNotIn('Added Associations', actual)
        self.assertIn('desktop-old.desktop;', config(self.cfg / 'mimeapps.list')['Removed Associations'][MIME])

    def test_refresh_is_idempotent_and_claims_newly_added_competitors(self):
        self.reset()
        previous = {p: p.read_bytes() for folder in (self.cfg, self.apps)
                    for p in folder.iterdir() if p.is_file()}
        self.reset()
        self.assertEqual(previous, {p: p.read_bytes() for folder in (self.cfg, self.apps)
                                    for p in folder.iterdir() if p.is_file()})
        (self.apps / 'new.desktop').write_text('[Desktop Entry]\nMimeType=' + MIME + ';\n')
        self.reset()
        self.assertIn('new.desktop;', config(self.cfg / 'mimeapps.list')['Removed Associations'][MIME])
        self.assertEqual(config(self.cfg / 'mimeapps.list')['Default Applications'][MIME], DESKTOP + ';')

    def test_refuses_symlinked_user_config_without_altering_target(self):
        target = self.root / 'do-not-edit.list'
        target.write_text('[Default Applications]\n' + MIME + '=other.desktop;\n')
        (self.cfg / 'mimeapps.list').symlink_to(target)
        with self.assertRaisesRegex(RuntimeError, 'symlinked protocol configuration'):
            self.reset()
        self.assertIn('other.desktop;', target.read_text())
        self.assertFalse((self.apps / 'mimeapps.list').exists())

    def test_gio_default_and_choices_are_exclusively_luani(self):
        import ctypes.util
        import json
        import subprocess
        import sys
        if not ctypes.util.find_library('gio-2.0'):
            self.skipTest('GLib/GIO is not installed')
        for folder, identifier in ((self.apps, DESKTOP), (self.system, 'old.desktop')):
            (folder / identifier).write_text('[Desktop Entry]\nType=Application\nName=' + identifier
                                            + '\nExec=/bin/true %u\nMimeType=' + MIME + ';\n')
        (self.cfg / 'mimeapps.list').write_text('[Default Applications]\n' + MIME + '=old.desktop;\n'
                                              '[Added Associations]\n' + MIME + '=old.desktop;\n')
        probe = '''import ctypes as C, json
lib=C.CDLL('libgio-2.0.so.0')
class GList(C.Structure): pass
GList._fields_=[('data',C.c_void_p),('next',C.POINTER(GList)),('prev',C.POINTER(GList))]
lib.g_app_info_get_default_for_uri_scheme.argtypes=[C.c_char_p]
lib.g_app_info_get_default_for_uri_scheme.restype=C.c_void_p
lib.g_app_info_get_id.argtypes=[C.c_void_p]
lib.g_app_info_get_id.restype=C.c_char_p
lib.g_app_info_get_all_for_type.argtypes=[C.c_char_p]
lib.g_app_info_get_all_for_type.restype=C.POINTER(GList)
app=lib.g_app_info_get_default_for_uri_scheme(b'luani')
default=lib.g_app_info_get_id(app).decode() if app else None
choices=[]
node=lib.g_app_info_get_all_for_type(b'x-scheme-handler/luani')
while node:
 choices.append(lib.g_app_info_get_id(node.contents.data).decode())
 node=node.contents.next
print(json.dumps({'default':default,'choices':sorted(choices)}))
'''
        def query():
            return json.loads(subprocess.check_output([sys.executable, '-c', probe], text=True))
        self.assertEqual(query()['default'], 'old.desktop')
        self.reset()
        self.assertEqual(query(), {'default': DESKTOP, 'choices': [DESKTOP]})

    def test_install_and_reinstall_path_calls_the_reset(self):
        source = SOURCE.read_text().split("<<'PY'\n", 1)[1].rsplit('\nPY', 1)[0]
        tree = ast.parse(source)
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == 'main')
        calls = [node for node in main.body if isinstance(node, ast.Assign)
                 and isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name)
                 and node.value.func.id == 'configure_luani_protocol']
        self.assertTrue(calls, 'The installer must reset associations after both install and reusable-release refresh')


if __name__ == '__main__':
    unittest.main(verbosity=2)
