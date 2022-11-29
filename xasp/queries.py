from typing import Optional

import clingo

from xasp.primitives import Model


def compute_stable_model(asp_program: str) -> Optional[Model]:
    control = clingo.Control()
    control.add("base", [], asp_program)
    control.ground([("base", [])])
    return Model.of(control)
