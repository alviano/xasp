import json

from dumbo_asp.primitives.models import Model

from xasp.entities import Explain


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


def test_dag_keeps_true_head_atoms_in_choice_rules():
    graph = Explain.the_program(
        "{a; b} <= 1.",
        the_answer_set=Model.of_atoms("a"),
        the_atoms_to_explain=Model.of_atoms("b")
    ).navigator_graph()
    assert "a\\nsupport" in str(graph)


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


def test_explain_aggregate_variables():
    graph = Explain.the_program(
        """
            foo(X) :- #sum{Y : bar(Y,Z)} = X, X = 0..3.
            bar(1,1).
        """,
        the_answer_set=Model.of_atoms("foo(1)", "bar(1,1)"),
        the_atoms_to_explain=Model.of_atoms("foo(1)"),
    ).navigator_graph()
    assert 'agg1(1)\\nsupport' in json.dumps(graph)
