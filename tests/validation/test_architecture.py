import json
import subprocess
import unittest

class TestHealthcareArchitecture(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        result = subprocess.run(
            ["terraform", "-chdir=validation", "plan", "-json", "-input=false"],
            capture_output=True,
            text=True,
            check=True
        )
        cls.plan = [
            json.loads(line)
            for line in result.stdout.splitlines()
            if line.strip()
        ]

    def test_terraform_plan_succeeds(self):
        self.assertTrue(self.plan)

    def test_no_real_resources_created(self):
        self.assertFalse(any(
            event.get("type") == "planned_change"
            for event in self.plan
        ))

if __name__ == "__main__":
    unittest.main()
