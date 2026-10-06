#!/usr/bin/env python3
"""
flag_utils.py - shared flag-generation helper for Stages 1-5.

Produces flags that mix letters and numbers THROUGHOUT the flag, not
just as a trailing numeric suffix:
  - each thematic word gets light leetspeak substitution (a->4, e->3,
    i->1, o->0, s->5, t->7), applied per-character with a probability
    so it's not fully predictable or fully unreadable
  - a short random alphanumeric token is inserted at a RANDOM position
    among the words (start, middle, or end) rather than always last

Example outputs for phrase ["digital", "footprint"]:
    NOVA{d1g1t4l_x9k_f00tpr1nt}
    NOVA{jq2_d1g174l_footpr1nt}
    NOVA{d1git4l_footpr1nt_7mv}
"""
import random
import string

LEET_MAP = {"a": "4", "e": "3", "i": "1", "o": "0", "s": "5", "t": "7"}


def leetify(word: str, intensity: float = 0.45) -> str:
    chars = list(word)
    for idx, ch in enumerate(chars):
        low = ch.lower()
        if low in LEET_MAP and random.random() < intensity:
            chars[idx] = LEET_MAP[low]
    return "".join(chars)


def random_token(n=None) -> str:
    if n is None:
        n = random.choice([3, 4])
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=n))


def build_mixed_flag(prefix: str, phrase_words: list) -> tuple:
    """
    prefix: e.g. "NOVA"
    phrase_words: list of thematic words, e.g. ["digital", "footprint"]

    Returns (flag_string, ordered_word_list) where ordered_word_list is
    the exact list of parts between the braces, in order - useful for
    stages that need to hide fragments in a specific sequence.
    """
    mixed = [leetify(w) for w in phrase_words]
    token = random_token()
    insert_pos = random.randint(0, len(mixed))
    mixed.insert(insert_pos, token)
    flag = f"{prefix}{{{'_'.join(mixed)}}}"
    return flag, mixed
