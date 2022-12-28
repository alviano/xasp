from typing import Optional, Any

import clingo
import clingo.ast

from xasp.entities import Explanation
from xasp.primitives import Model


def create_explanation() -> Explanation:
    return Explanation(compute_stable_model=compute_stable_model)


def compute_stable_model(asp_program: str, context: Optional[Any] = None) -> Optional[Model]:
    control = clingo.Control()
    control.add("base", [], asp_program)
    control.ground([("base", [])], context=context)
    return Model.of(control)


def compute_serialization(asp_program: str, answer_set: Model, base: Model,
                          atoms_to_explain: Model = Model.empty()) -> Model:
    return create_explanation().given(
        the_asp_program=asp_program,
        the_answer_set=answer_set,
        the_atoms_to_explain=atoms_to_explain,
        the_additional_atoms_in_the_base=base,
    ).serialization


def process_aggregates(to_be_explained_serialization: Model) -> Model:
    return create_explanation().given_the_serialization(
        to_be_explained_serialization
    ).process_aggregates().serialization


def compute_atoms_explained_by_initial_well_founded(serialization: Model) -> Model:
    return create_explanation().given_the_serialization(
        serialization
    ).compute_atoms_explained_by_initial_well_founded().atoms_explained_by_initial_well_founded


def compute_minimal_assumption_set(to_be_explained_serialization: Model) -> Model:
    return compute_minimal_assumption_sets(to_be_explained_serialization, up_to=1)[-1]


def compute_minimal_assumption_sets(to_be_explained_serialization: Model, up_to: Optional[int] = None) -> tuple[Model]:
    return create_explanation().given_the_serialization(
        to_be_explained_serialization
    ).compute_minimal_assumption_sets(up_to=up_to).minimal_assumption_sets


def compute_explanation(to_be_explained_serialization: Model) -> Model:
    return compute_explanations(to_be_explained_serialization, up_to=1)[-1]


def compute_explanations(to_be_explained_serialization: Model, up_to: Optional[int] = None) -> tuple[Model]:
    return create_explanation().given_the_serialization(
        to_be_explained_serialization
    ).compute_explanation_sequences(up_to=up_to).explanation_sequences


def compute_explanation_dag(to_be_explained_serialization: Model) -> Model:
    return compute_explanation_dags(to_be_explained_serialization, up_to=1)[-1]


def compute_explanation_dags(to_be_explained_serialization: Model, up_to: Optional[int] = None) -> tuple[Model]:
    return create_explanation().given_the_serialization(
        to_be_explained_serialization
    ).compute_explanation_dags(up_to=up_to).explanation_dags
