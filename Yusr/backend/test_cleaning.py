import unittest
from cleaning import clean_reply, strip_think_tags

class CleaningTests(unittest.TestCase):
    def test_plain_reply_passes(self):
        self.assertEqual(clean_reply("Of course! Hot or iced?"), ("Of course! Hot or iced?", True))
    def test_okay_as_normal_speech_is_kept(self):
        self.assertTrue(clean_reply("Okay, great choice! Anything to drink?")[1])
    def test_closed_think_block_removed(self):
        self.assertEqual(clean_reply("<think>plan stuff</think>Sure thing!"), ("Sure thing!", True))
    def test_multiline_think_block_removed(self):
        self.assertEqual(clean_reply("<think>\nline1\nline2\n</think>\n\nWelcome!")[0], "Welcome!")
    def test_stray_closing_tag(self):
        self.assertEqual(strip_think_tags("I should greet them.</think>Hello there!"), "Hello there!")
    def test_unclosed_think_is_not_ok(self):
        self.assertFalse(clean_reply("<think>The user wants coffee, so I")[1])
    def test_untagged_reasoning_rejected(self):
        for leak in [
            "Okay, the user wants a coffee. I need to respond as a barista.",
            "Let me think about how a waiter would answer.",
            "The user said they'd like pasta, so I should ask about drinks.",
            "I need to keep this short and ask one question.",
            "Hmm, the scenario is a restaurant.",
        ]:
            self.assertFalse(clean_reply(leak)[1], leak)
    def test_empty_rejected(self):
        self.assertFalse(clean_reply("   ")[1])
        self.assertFalse(clean_reply("<think></think>")[1])

if __name__ == "__main__":
    unittest.main()
