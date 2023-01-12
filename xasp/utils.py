from pathlib import Path
from typing import Callable, Final, Any


PROJECT_ROOT: Final = Path(__file__).parent.parent


def call_with_difference_if_invalid_index(index: int, length: int, callback: Callable[[int], Any]):
    if index >= 0:
        if length <= index:
            callback(index - length + 1)
    else:
        if length < -index:
            callback(-index - length)
