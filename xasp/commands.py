from pathlib import Path
from typing import Optional

from xasp.primitives import Model
from xasp.queries import create_explanation


def save_explanation_dag(dag: Model, answer_set: Model, atoms_to_explain: Model, target: Path,
                         distance: Optional[int] = None,
                         **kwargs):
    create_explanation().given_the_dag(
        dag,
        the_answer_set=answer_set,
        the_atoms_to_explain=atoms_to_explain,
    ).compute_igraph().save_igraph(target, distance, **kwargs)

