"""Synthetic accessibility-matching regression tests. No device/account required."""
import unittest
import xml.etree.ElementTree as ET

from android_ui_acceptance import label, select_node, safe_ui_state, safe_flutter_error_flags


class AndroidAccessibilityMatchingTest(unittest.TestCase):
    def make_nodes(self, xml):
        return list(ET.fromstring(xml).iter("node"))

    def test_duplicate_text_and_content_description_still_match_exact(self):
        result = self.make_nodes(
            '<hierarchy><node text="Sign in" content-desc="Sign in" '
            'bounds="[20,40][300,80]"/></hierarchy>'
        )
        self.assertIsNotNone(select_node(result, "Sign in", exact=True))
        self.assertEqual(label(result[0]), "Sign in")

    def test_button_and_text_with_separate_accessibility_fields(self):
        result = self.make_nodes(
            '<hierarchy>'
            '<node text="" content-desc="English" bounds="[5,5][150,50]"/>'
            '<node text="Access your account" content-desc="" '
            'bounds="[10,70][300,140]"/>'
            '</hierarchy>'
        )
        self.assertIsNotNone(select_node(result, "English", exact=True))
        self.assertIsNotNone(select_node(result, "Access your account", exact=True))

    def test_unknown_personal_strings_never_enter_allowlisted_diagnostics(self):
        result = self.make_nodes(
            '<hierarchy>'
            '<node text="Private Example Name" content-desc="" '
            'bounds="[5,5][300,50]"/>'
            '<node text="Sign in" content-desc="Sign in" '
            'bounds="[5,55][300,90]"/>'
            '</hierarchy>'
        )
        self.assertNotIn("Private Example Name", repr(safe_ui_state(result)))
        self.assertTrue(safe_ui_state(result)["Sign in"])

    def test_false_match_prefix_is_rejected_for_exact_buttons(self):
        result = self.make_nodes(
            '<hierarchy><node text="Login successful" content-desc="" '
            'bounds="[5,5][150,45]"/></hierarchy>'
        )
        self.assertIsNone(select_node(result, "Login", exact=True))

    def test_diagnostics_allowlist_contains_no_private_fields(self):
        items = self.make_nodes(
            '<hierarchy>'
            '<node text="Private Phone 01712345678" content-desc="" '
            'bounds="[1,1][300,80]"/>'
            '<node text="English" content-desc="English" '
            'bounds="[1,80][300,140]"/>'
            '</hierarchy>'
        )
        report = safe_ui_state(items)
        self.assertTrue(report["English"])
        self.assertFalse(any("01712345678" in k for k in report))
        self.assertTrue(all(type(v) is bool for v in report.values()))


if __name__ == "__main__":
    unittest.main()
