import logging
import re
from typing import Callable

import valid8
from rich.console import Console
from rich.logging import RichHandler
from rich.prompt import Prompt, Confirm
from typeguard import typechecked

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
