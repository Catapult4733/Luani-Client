#!/usr/bin/env python3
"""Source-only regression for native Button property collisions; never starts Godot."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
# Godot 4.7.2 BaseButton.xml declares shortcut as a Shortcut resource, not text:
# https://github.com/godotengine/godot/blob/4.7.2-stable/doc/classes/BaseButton.xml
# These names cannot be redeclared by GDScript subclasses of Button.
NATIVE_BUTTON_PROPERTIES = {
    "action_mode", "button_group", "button_mask", "button_pressed", "disabled",
    "keep_pressed_outside", "shortcut", "shortcut_feedback", "shortcut_in_tooltip",
    "toggle_mode",
}


class HudNativeMembersTest(unittest.TestCase):
    def test_custom_button_fields_do_not_redeclare_native_properties(self):
        source = (ROOT / "offline/scripts/ui_controls.gd").read_text()
        classes = re.findall(
            r"^class (\w+) extends Button:\n(.*?)(?=^class |\Z)",
            source, re.MULTILINE | re.DOTALL,
        )
        self.assertTrue(classes, "No custom Button classes found; regression guard is inactive")
        for name, body in classes:
            fields = set(re.findall(r"^\tvar (\w+)\b", body, re.MULTILINE))
            with self.subTest(button_class=name):
                self.assertFalse(
                    fields & NATIVE_BUTTON_PROPERTIES,
                    f"{name} redeclares native BaseButton properties: "
                    f"{sorted(fields & NATIVE_BUTTON_PROPERTIES)}",
                )


if __name__ == "__main__":
    unittest.main()
