import unittest

from context_verifier import combine_incident_decision


class CombineIncidentDecisionTests(unittest.TestCase):
    def test_agreement_allows_likely_emergency(self):
        local = [
            {
                "detected_disaster_category": "Fire",
                "is_valid_report_photo": True,
            }
        ]
        context = {
            "available": True,
            "incident_status": "active_emergency",
            "category": "Fire",
            "evidence_strength": "strong",
            "summary": "Uncontrolled flames are threatening a structure.",
        }
        result = combine_incident_decision(local, context)
        self.assertEqual(result["decision"], "likely_emergency")
        self.assertEqual(result["suggested_category"], "Fire")
        self.assertTrue(result["auto_select_allowed"])

    def test_lookalike_never_auto_selects(self):
        local = [
            {
                "detected_disaster_category": "Flooding",
                "is_valid_report_photo": True,
            }
        ]
        context = {
            "available": True,
            "incident_status": "harmless_lookalike",
            "category": "Flooding",
            "evidence_strength": "strong",
            "summary": "Water is contained within a normal riverbank.",
            "lookalike_reason": "No normally dry land is visibly inundated.",
        }
        result = combine_incident_decision(local, context)
        self.assertEqual(result["decision"], "likely_non_emergency")
        self.assertIsNone(result["suggested_category"])
        self.assertFalse(result["auto_select_allowed"])

    def test_provider_failure_is_safe(self):
        result = combine_incident_decision([], {"available": False})
        self.assertEqual(result["decision"], "ml_only")
        self.assertTrue(result["requires_human_review"])


if __name__ == "__main__":
    unittest.main()
