import json

from xasp.entities import Explain
from xasp.primitives import Model


def test_xai_navigator_support():
    graph = Explain.the_program(
        "a.",
        the_answer_set=Model.of_atoms("a"),
        the_atoms_to_explain=Model.of_atoms("a"),
    ).navigator_graph()
    assert "a\\nsupport" in json.dumps(graph)


def test_xai_navigator_lack_of_support():
    graph = Explain.the_program(
        """
            {b}.
            a :- b.
        """,
        the_answer_set=Model.empty(),
        the_atoms_to_explain=Model.of_atoms("a"),
        the_additional_atoms_in_the_base=Model.of_atoms("b")
    ).navigator_graph()
    assert 'a\\nlack of support' in json.dumps(graph)


def test_xai_navigator_choice_rule():
    graph = Explain.the_program(
        """
            {b} <= 0.
        """,
        the_answer_set=Model.empty(),
        the_atoms_to_explain=Model.of_atoms("b"),
    ).navigator_graph()
    assert 'b\\nchoice rule' in json.dumps(graph)


def test_xai_navigator_constraint():
    graph = Explain.the_program(
        """
            {a}.
            :- a.
        """,
        the_answer_set=Model.empty(),
        the_atoms_to_explain=Model.of_atoms("a"),
    ).navigator_graph()
    assert 'a\\nrequired to falsify body' in json.dumps(graph)


# def test_xai_example():
#     start = time.time()
#     with open(utils.PROJECT_ROOT / f"examples/xai.lp") as f:
#         program = '\n'.join(f.readlines())
#     with open(utils.PROJECT_ROOT / f"examples/xai.answer_set.lp") as f:
#         # $ clingo xai.lp --outf=1 | grep -v "^ANSWER$" | grep -v "^%" > xai.answer_set.lp
#         answer_set = Model.of_program('\n'.join(f.readlines()))
#     explanation = Explain.given_the_program(
#         program,
#         the_answer_set=answer_set,
#         the_atoms_to_explain=Model.of_atoms("behaves_inertially(testing_posTestNeg,121)"),
#     )
#     explanation.compute_atoms_explained_by_initial_well_founded()
#     print(time.time() - start)
#     explanation.compute_minimal_assumption_sets()
#     print(time.time() - start)
#     minimal_assumption_set = explanation.minimal_assumption_sets[-1]
#     assert len(minimal_assumption_set) == 1
#     explanation.compute_explanation_sequences()
#     print(time.time() - start)
#     # explanation_sequence = explanation.explanation_sequences[-1]
#     explanation.compute_explanation_dags()
#     print(time.time() - start)
#     dag = explanation.explanation_dags[-1]
#     commands.save_explanation_dag(dag, answer_set, explanation.atoms_to_explain, Path("/tmp/a.png"),
#                                   bbox=(8000, 4000))
#     print(time.time() - start)
#     assert False

