"""Make sure only a natural spoken reply ever reaches the app."""
import re

_BLOCK = re.compile(r"<think>.*?</think>", re.S | re.I)
_CLOSE = re.compile(r"</think>", re.I)
_OPEN = re.compile(r"<think>", re.I)

# Plain-language "reasoning" that qwen-style models sometimes emit without tags.
_LEAK_START = re.compile(
    r"^\s*(?:okay|ok|alright|so|hmm+|wait|first)?[,.:!\s]*"
    r"(?:the user|user\b|let me|let's (?:see|think|figure|check)|i need to|i should|i must|"
    r"i'll (?:respond|reply|say|ask)|i will (?:respond|reply|say|ask)|my (?:reply|response|task)|"
    r"the (?:scenario|system|instructions?|prompt)|they (?:want|said|are asking|asked))",
    re.I,
)
_LEAK_ANYWHERE = re.compile(r"\bthe user\b|\bsystem prompt\b|\bas yusr\b|\bmy instructions\b", re.I)


def strip_think_tags(text: str) -> str:
    text = _BLOCK.sub("", text)
    m = _CLOSE.search(text)          # stray </think>: everything before it was reasoning
    if m:
        text = text[m.end():]
    m = _OPEN.search(text)           # unclosed <think>: everything after it is reasoning
    if m:
        text = text[:m.start()]
    return text.strip()


def looks_like_reasoning(text: str) -> bool:
    return bool(_LEAK_START.search(text) or _LEAK_ANYWHERE.search(text))


def clean_reply(raw: str) -> tuple[str, bool]:
    """Return (reply, ok). ok=False means the caller should retry or fall back."""
    reply = strip_think_tags(raw or "")
    if not reply or looks_like_reasoning(reply):
        return "", False
    return reply, True
