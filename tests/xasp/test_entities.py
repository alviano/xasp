import time

from xasp import utils, commands
from xasp.primitives import Model
from xasp.queries import create_explanation


def test_xai_example():
    assert False
    start = time.time()
    with open(utils.PROJECT_ROOT / f"examples/xai.lp") as f:
        program = '\n'.join(f.readlines())
    with open(utils.PROJECT_ROOT / f"examples/xai.answer_set.lp") as f:
        # $ clingo xai.lp --outf=1 | grep -v "^ANSWER$" | grep -v "^%" > xai_small.answer_set.lp
        answer_set = Model.of_program('\n'.join(f.readlines()))
    explanation = create_explanation().given(
        the_asp_program=program,
        the_answer_set=answer_set,
        the_atoms_to_explain=Model.of_atoms("behaves_inertially(testing_posTestNeg,121)"),
    )
    explanation.compute_atoms_explained_by_initial_well_founded()
    print(time.time() - start)
    explanation.compute_minimal_assumption_sets()
    print(time.time() - start)
    minimal_assumption_set = explanation.minimal_assumption_sets[-1]
    assert len(minimal_assumption_set) == 1
    explanation.compute_explanation_sequences()
    print(time.time() - start)
    # explanation_sequence = explanation.explanation_sequences[-1]
    explanation.compute_explanation_dags()
    print(time.time() - start)
    dag = explanation.explanation_dags[-1]
    commands.save_explanation_dag(dag, answer_set, explanation.atoms_to_explain, "/tmp/a.png",
                                  bbox=(8000, 4000))
    print(time.time() - start)
    assert False
