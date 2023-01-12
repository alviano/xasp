from pathlib import Path
from typing import Optional
from dumbo_asp.primitives import Model

from xasp.entities import Explain


def save_explanation_dag(dag: Model, answer_set: Model, atoms_to_explain: Model, target: Path,
                         distance: Optional[int] = None,
                         **kwargs):
    Explain.the_dag(
        dag,
        the_answer_set=answer_set,
        the_atoms_to_explain=atoms_to_explain,
    ).save_igraph(target, distance, **kwargs)

