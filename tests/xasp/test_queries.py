import logging

import pytest

from xasp.primitives import Model
from xasp.queries import compute_stable_model, compute_minimal_assumption_set, \
    compute_explanation, compute_explanation_dag, compute_serialization, compute_minimal_assumption_sets, \
    compute_explanations, compute_explanation_dags, compute_atoms_explained_by_initial_well_founded

logging.getLogger().setLevel(logging.DEBUG)


def test_compute_stable_model():
    model = compute_stable_model("a.")
    assert len(model) == 1
    assert model[0].name == "a"


def test_compute_stable_may_return_none():
    model = compute_stable_model("a :- not a.")
    assert model is None


def test_compute_program_serialization():
    model = compute_serialization("""
        a.
        b :- a, not c.
    """, answer_set=Model.of_atoms("a", "b"), additional_atoms_in_base=Model.of_atoms("a", "b", "c"))
    assert model == compute_stable_model("""
        rule(r1).
          head(r1,a).
        
        rule(r2).
          head(r2,b).
          pos_body(r2,a).
          neg_body(r2,c).
      
        true(a).
        true(b).
        false(c).
    """)


def test_compute_program_serialization_for_aggregates_with_two_bounds():
    model = compute_serialization("""
        :- 0 <= #sum{X : p(X)} <= 1.
    """, answer_set=Model.of_atoms("p(-1)", "p(1)"), additional_atoms_in_base=Model.of_atoms("p(-1)", "p(1)", "p(2)"))
    assert model == compute_stable_model("""
        rule(r1).
          pos_body(r1,agg1).

        aggregate(agg1, sum, "in", (0,1)).
          agg_set(agg1,p(-1), -1, ()).
          agg_set(agg1,p(1), 1, ()).
          agg_set(agg1,p(2), 2, ()).

        true(p(-1)).
        true(p(1)).
        false(p(2)).
    """)


@pytest.fixture
def running_example_1():
    return compute_serialization("""
        1 <= {arc(X,Y); arc(Y,X)} <= 1 :- edge(X,Y).
        reach(X,X) :- source(X).
        reach(X,Y) :- reach(X,Z), arc(Z,Y).
        fail(X,Y) :- source(X), sink(Y), not reach(X,Y).
        :- threshold(T), #sum{1,X,Y : fail(X,Y)} > T.
        
        edge(a,b).
        edge(a,d).
        edge(d,c).
        
        source(a).
        source(b).
        
        sink(c).
        
        threshold(0).
    """, answer_set=Model.of_atoms(atom.strip() for atom in """
        edge(a,b)
        edge(a,d)
        edge(d,c)
        source(a)
        source(b)
        sink(c)
        reach(a,a)
        reach(b,b)
        reach(b,a)
        reach(a,d)
        reach(a,c)
        reach(b,d)
        reach(b,c)
        arc(b,a)
        arc(a,d)
        arc(d,c)
        threshold(0)
    """.strip().split('\n')), additional_atoms_in_base=Model.of_atoms(atom.strip() for atom in """
        arc(a,b)
        arc(d,a)
        arc(c,d)
        fail(a,c)
        fail(b,c)
        reach(a,b)
        reach(c,a)
        reach(c,b)
        reach(c,c)
        reach(c,d)
        reach(d,a)
        reach(d,b)
        reach(d,c)
        reach(d,d)
    """.strip().split('\n')))


def test_running_example_1(running_example_1):
    minimal_assumption_set = compute_minimal_assumption_set(running_example_1)
    assert len(minimal_assumption_set) == 0
    explanation = compute_explanation(running_example_1)
    assert len(explanation) == 32


def test_process_aggregate_with_variables():
    assert compute_serialization(
        """
            :- a(X), #sum{Y : b(X,Y)} > 0.
        """,
        answer_set=Model.of_atoms("a(1) a(2) b(1,2)".split()),
        additional_atoms_in_base=Model.of_atoms("b(2,1)")) == compute_stable_model("""
        rule(r1(1)).
            pos_body(r1(1), a(1)).
            pos_body(r1(1), agg1(1)).
            aggregate(agg1(1), sum, ">", 0).
            agg_set(agg1(1), b(1,2), 2, ()).
        rule(r1(2)).
            pos_body(r1(2), a(2)).
            pos_body(r1(2), agg1(2)).
            aggregate(agg1(2), sum, ">", 0).
            agg_set(agg1(2), b(2,1), 1, ()).
        true(a(1)).
        true(a(2)).
        true(b(1,2)).
        false(b(2,1)).
    """)


def test_lack_of_explanation_1():
    serialization = compute_serialization("""
        a :- not b. 
        b :- not a.
    """, answer_set=Model.of_atoms('b'), additional_atoms_in_base=Model.of_atoms('a'),
                                          atoms_to_explain=Model.of_atoms('a'))
    minimal_assumption_set = compute_minimal_assumption_set(serialization)
    assert len(minimal_assumption_set) == 1
    assert minimal_assumption_set == compute_stable_model("assume_false(a).")


def test_lack_of_explanation_2():
    serialization = compute_serialization("{a}.", answer_set=Model.of_atoms(),
                                          additional_atoms_in_base=Model.of_atoms('a'),
                                          atoms_to_explain=Model.of_atoms('a'))
    minimal_assumption_set = compute_minimal_assumption_set(serialization)
    assert len(minimal_assumption_set) == 1
    assert minimal_assumption_set == compute_stable_model("assume_false(a).")


def test_lack_of_explanation_3():
    serialization = compute_serialization("a :- #sum{1 : a} >= 0.", answer_set=Model.of_atoms('a'),
                                          additional_atoms_in_base=Model.of_atoms(),
                                          atoms_to_explain=Model.of_atoms('a'))
    with pytest.raises(TypeError):
        compute_minimal_assumption_set(serialization)


def test_atom_inferred_by_constraint_like_rules_can_be_linked_to_false():
    serialization = compute_serialization(
        """
            a :- not b.
            b :- not a.
            :- b.
        """,
        answer_set=Model.of_atoms('a'),
        additional_atoms_in_base=Model.of_atoms('b'),
        atoms_to_explain=Model.of_atoms("a"))
    dag = compute_explanation_dag(serialization)
    assert dag == compute_stable_model("""
        link(1,b,(required_to_falsify_body,r3),"false").
        link(2,a,(support,r1),b).
    """)


def test_atom_inferred_by_choice_rules_can_be_linked_to_false():
    serialization = compute_serialization("""
        {a} <= 0.
    """, answer_set=Model.of_atoms(), additional_atoms_in_base=Model.of_atoms('a'),
                                          atoms_to_explain=Model.of_atoms("a"))
    dag = compute_explanation_dag(serialization)
    assert dag == compute_stable_model("""
        link(1,a,(choice_rule,r1),"false").
    """)


def test_3_col():
    true_atoms = [atom.strip() for atom in """
    color(red)
    color(blue)
    color(yellow)
    node(1)
    node(2)
    node(3)
    node(4)
    node(5)
    edge(1,3)
    edge(2,4)
    edge(2,5)
    edge(3,4)
    edge(3,5)
    colored(3,blue)
    colored(1,yellow)
    colored(4,red)
    colored(2,blue)
    colored(5,yellow)
    """.strip().split('\n')]
    serialization = compute_serialization("""
    node(1).
    node(2).
    node(3).
    node(4).
    node(5).
    edge(1,3).
    edge(2,4).
    edge(2,5).
    edge(3,4).
    edge(3,5).

    {colored(X,C)} :- node(X), color(C).
    :- node(X), #count{C : colored(X,C)} != 1.

    color(red).
    color(blue).
    color(yellow).

    :- edge(X,Y), colored(X, Z), colored(Y, Z).
    """, answer_set=Model.of_atoms(true_atoms), additional_atoms_in_base=Model.of_atoms(atom.strip() for atom in """
    colored(3,yellow)
    colored(3,red)
    colored(2,yellow)
    colored(1,blue)
    colored(4,blue)
    colored(5,red)
    colored(4,yellow)
    colored(1,red)
    colored(5,blue)
    colored(2,red)
    """.strip().split('\n')), atoms_to_explain=Model.of_atoms("colored(4,red)"))
    dag = compute_explanation_dag(serialization)
    assert len(dag) == 55


def test_compute_all_minimal_assumption_sets():
    serialization = compute_serialization(
        """
            a :- not b.
            b :- not a.
            c :- not a.
            a :- not c.
        """,
        answer_set=Model.of_atoms("a"),
        additional_atoms_in_base=Model.of_atoms("b", "c"),
        atoms_to_explain=Model.of_atoms("a")
    )
    minimal_assumption_sets = compute_minimal_assumption_sets(serialization, atoms_to_explain=Model.of_atoms("a"))
    assert len(minimal_assumption_sets) == 2


def test_rule_with_arithmetic():
    serialization = compute_serialization(
        """
            a(X) :- X = 1..2.
        """,
        answer_set=Model.of_atoms("a(1)", "a(2)"),
        additional_atoms_in_base=Model.of_atoms(),
        atoms_to_explain=Model.of_atoms("a(1)")
    )
    minimal_assumption_set = compute_minimal_assumption_set(serialization)
    assert len(minimal_assumption_set) == 0
    assert compute_explanation(serialization) == compute_stable_model("""
        explained_by(1,a(2),(support,r1(2))).
        explained_by(2,a(1),(support,r1(1))).
    """)
    assert compute_explanation_dag(serialization) == compute_stable_model("""
        link(1,a(2),(support,r1(2)),"true").
        link(2,a(1),(support,r1(1)),"true").
    """)


def test_compute_explanations():
    serialization = compute_serialization(
        """
            {a; b}.
            :- a, not b.
            :- b, not a.
            c :- a, b.
        """,
        answer_set=Model.of_atoms(),
        additional_atoms_in_base=Model.of_atoms("a", "b", "c"),
        atoms_to_explain=Model.of_atoms("c")
    )
    explanations = compute_explanations(serialization, atoms_to_explain=Model.of_atoms("c"))
    assert len(explanations) == 2


def test_compute_dags():
    serialization = compute_serialization(
        """
            {a; b}.
            c :- a, b.
        """,
        answer_set=Model.of_atoms(),
        additional_atoms_in_base=Model.of_atoms("a", "b", "c"),
        atoms_to_explain=Model.of_atoms("c")
    )
    assert len(compute_explanation_dags(serialization, Model.of_atoms("c"))) == 2


def test_choice_rule_with_condition_arithmetic():
    serialization = compute_serialization(
        """
            {a(X) : X = 1..2} = 1.
        """,
        answer_set=Model.of_atoms("a(1)"),
        additional_atoms_in_base=Model.of_atoms("a(2)"),
        atoms_to_explain=Model.of_atoms("a(2)")
    )
    explanation = compute_explanation(serialization)
    assert "explained_by(2,a(2),(choice_rule,r1))." in explanation.as_facts


def test_choice_rule_with_condition_involving_atoms():
    serialization = compute_serialization(
        """
            {a(X) : X = 1..5, b(X)} = 1.
            b(0).
            b(3).
        """,
        answer_set=Model.of_atoms("a(3)", "b(0)", "b(3)"),
        additional_atoms_in_base=Model.of_atoms(),
        atoms_to_explain=Model.of_atoms("a(3)")
    )
    dag = compute_explanation_dag(serialization)
    assert 'link(3,a(3),(support,r1),"true").' in dag.as_facts


def test_rule_with_compressed_head():
    serialization = compute_serialization(
        "a(1;2).",
        answer_set=Model.of_atoms("a(1)", "a(2)"),
        additional_atoms_in_base=Model.of_atoms(),
        atoms_to_explain=Model.of_atoms("a(1)")
    )
    explanation = compute_explanation(serialization)
    assert "explained_by(1,a(1),(support,r1))." in explanation.as_facts


def test_strong_negation():
    serialization = compute_serialization("""
        {a; -a}.
    """, answer_set=Model.of_atoms("a"), additional_atoms_in_base=Model.of_atoms("a", "-a"),
                                          atoms_to_explain=Model.of_atoms("a"))
    explanation = compute_explanation(serialization)
    assert "explained_by(2,-a,(required_to_falsify_body,r2))." in explanation.as_facts


def test_atoms_in_negative_literals_are_added_to_the_base_during_serialization():
    serialization = compute_serialization("a :- not b.", answer_set=Model.of_atoms("a"),
                                          additional_atoms_in_base=Model.empty(),
                                          atoms_to_explain=Model.of_atoms("a"))
    assert "false(b)." in serialization.as_facts
    minimal_assumption_set = compute_minimal_assumption_set(serialization)
    assert len(minimal_assumption_set) == 0


def test_compute_well_founded():
    serialization = compute_serialization("""
        a :- c, not b.
        b :- not a.
        c.
        d :- e, not f.
        d :- f, not g.
        d :- h.
        e :- d.
        f :- e.
        f :- not c.
        i :- c, not d.
    """, answer_set=Model.of_atoms("c", "i", "a"), additional_atoms_in_base=Model.of_atoms("a b c d e f g h i".split()),
                                          atoms_to_explain=Model.empty())
    well_founded = compute_atoms_explained_by_initial_well_founded(serialization)
    assert compute_stable_model("""
        explained_by(d,initial_well_founded).
        explained_by(e,initial_well_founded).
        explained_by(f,initial_well_founded).
        explained_by(g,initial_well_founded).
        explained_by(h,initial_well_founded).
    """) == well_founded


def test_minimal_assumption_set_block_up_must_take_into_account_weights():
    serialization = compute_serialization("""
        {a; b}.
        c :- a.
        c :- b.
    """, answer_set=Model.empty(), atoms_to_explain=Model.of_atoms("c"))
    sets = compute_minimal_assumption_sets(serialization, Model.of_atoms("c"))
    for s in sets: print(s.as_facts ,'-')
    assert "c." not in sets[0].as_facts
    assert len(sets) == 1
