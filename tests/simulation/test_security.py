import json
import subprocess
import unittest


class TestSecurityPolicies(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        result = subprocess.run(
            ["terraform", "-chdir=simulation", "plan", "-out=/tmp/healthcare-simulation.tfplan"],
            capture_output=True,
            text=True,
            check=True,
        )
        result = subprocess.run(
            ["terraform", "show", "-json", "/tmp/healthcare-simulation.tfplan"],
            capture_output=True,
            text=True,
            check=True,
        )
        cls.plan = json.loads(result.stdout)
        cls.platform = cls.plan["planned_values"]["outputs"]["platform_summary"]["value"]

    def test_five_accounts(self):
        self.assertEqual(self.platform["accounts"], 5)

    def test_private_eks(self):
        eks = self.platform["eks"]
        self.assertTrue(eks["private_endpoint"])
        self.assertFalse(eks["public_endpoint"])

    def test_encryption(self):
        self.assertEqual(self.platform["eks"]["secrets_encryption"], "AWS KMS")
        self.assertTrue(self.platform["logging"]["kms_encryption"])

    def test_audit_logging(self):
        self.assertTrue(self.platform["logging"]["cloudtrail"])
        self.assertTrue(self.platform["eks"]["control_plane_audit_logs"])

    def test_security_monitoring(self):
        self.assertTrue(self.platform["security"]["guardduty"])
        self.assertTrue(self.platform["security"]["prowler_scanning"])


if __name__ == "__main__":
    unittest.main()
