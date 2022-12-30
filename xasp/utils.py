import logging
import re
import zlib
from pathlib import Path
from typing import Callable, Final, Any
import urllib.parse

import valid8
from rich.console import Console
from rich.logging import RichHandler
from rich.prompt import Prompt, Confirm
from typeguard import typechecked

PROJECT_ROOT: Final = Path(__file__).parent.parent

console = Console()
prompt = Prompt(console=console)
confirm = Confirm(console=console)

validate = valid8.validate
ValidationError = valid8.ValidationError

logging.basicConfig(
    format="%(message)s",
    datefmt="[%X]",
    handlers=[RichHandler(console=console, markup=True, rich_tracebacks=True)],
)
log = logging.getLogger("rich")


@typechecked
def pattern(regex: str) -> Callable[[str], bool]:
    r = re.compile(regex)

    def res(value):
        return bool(r.fullmatch(value))

    res.__name__ = f'pattern({regex})'
    return res


def pako_deflate_raw(data):
    compress = zlib.compressobj(zlib.Z_DEFAULT_COMPRESSION, zlib.DEFLATED, -15, 8, zlib.Z_DEFAULT_STRATEGY)
    compressed_data = compress.compress(urllib.parse.quote(data).encode())
    compressed_data += compress.flush()
    return compressed_data


def call_with_difference_if_invalid_index(index: int, length: int, callback: Callable[[int], Any]):
    if index >= 0:
        if length <= index:
            callback(index - length + 1)
    else:
        if length < -index:
            callback(-index - length)
