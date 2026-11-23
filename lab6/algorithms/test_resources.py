import unittest
from resources import BANK, DEADLOCK, TASK2, detect, safety, request


class ResourceTests(unittest.TestCase):
    def test_detection_example(self):
        step = detect(*DEADLOCK)
        self.assertEqual(step.order, (1, 2))
        self.assertEqual(step.blocked, (0, 3))
        self.assertEqual(step.work, ((0, 1, 0, 2, 1), (0, 2, 0, 3, 1), (0, 2, 0, 3, 2)))

    def test_no_resources_held_is_not_deadlocked(self):
        self.assertEqual(detect(((0,), (1,)), ((99,), (0,)), (0,)).blocked, ())

    def test_printed_task_2_is_not_safe_even_with_large_x(self):
        for x in (0, 1, 2, 1000):
            result = safety(TASK2[0], TASK2[1], (0, 0, x, 1, 1))
            self.assertIn(0, result.blocked)

    def test_banker_safety(self):
        s = safety(*BANK)
        self.assertFalse(s.blocked)
        self.assertEqual(s.order, (1, 3, 4, 0, 2))
        self.assertEqual(s.work[-1], (10, 5, 7))

    def test_request_commits_only_safe_state(self):
        ok = request(*BANK, 1, (1, 0, 2))
        self.assertEqual(ok.status, 'granted')
        self.assertEqual(ok.available, (2, 3, 0))
        self.assertEqual(ok.allocation[1], (3, 0, 2))
        for pid, vec, status in ((4, (3, 3, 0), 'unsafe'), (1, (3, 0, 0), 'exceeds-need'), (0, (0, 0, 3), 'unavailable')):
            with self.subTest(status=status):
                r = request(*BANK, pid, vec)
                self.assertEqual((r.status, r.allocation, r.available), (status, BANK[0], BANK[2]))

    def test_rejects_invalid_input(self):
        for pid, vec in ((-1, (0, 0, 0)), (1, (0, 0)), (1, (0, -1, 0))):
            with self.assertRaises(ValueError):
                request(*BANK, pid, vec)
        with self.assertRaises(ValueError):
            safety(((2,),), ((1,),), (0,))


if __name__ == '__main__':
    unittest.main()
