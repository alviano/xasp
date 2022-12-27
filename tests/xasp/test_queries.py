import logging

import pytest

from xasp.queries import compute_stable_model, process_aggregates, compute_minimal_assumption_set, \
    compute_explanation, compute_explanation_dag, compute_serialization, compute_minimal_assumption_sets, \
    compute_explanations, compute_explanation_dags

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
    """, true_atoms="a b".split(), false_atoms="c".split())
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
    """, true_atoms="p(-1) p(1)".split(), false_atoms="p(2)".split())
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
def example1():
    return compute_stable_model("""
%* program

(r1)    a.
(r2)    b :- #sum{1 : a; 1 : c} >= 1.

*%


rule(r1).
  head(r1,a).

rule(r2).
  head(r2,b).
  pos_body(r2,agg1).

aggregate(agg1, sum, ">=", 1).
  agg_set(agg1, a, 1, ()).
  agg_set(agg1, c, 1, ()).


% answer set: a b
false(c).
true(a).
true(b).
    """)


@pytest.fixture
def example2():
    return compute_stable_model("""
%* program

(r1)    a.
(r2)    b :- #sum{1 : a; 1 : c} < 1.

*%


rule(r1).
  head(r1,a).

rule(r2).
  head(r2,b).
  pos_body(r2,agg1).

aggregate(agg1, sum, "<", 1).
  agg_set(agg1, a, 1, ()).
  agg_set(agg1, c, 1, ()).


% answer set: a
false(c).
true(a).
false(b).
    """)


@pytest.fixture
def example3():
    return compute_stable_model("""
%* program

(r1)    body.
(r2)    1 <= {a; b; c} <= 2 :- body.
(r3)    d :- b.

*%


rule(r1).
  head(r1,body).

rule(r2).
  choice(r2,1,2).
  head(r2,a).
  head(r2,b).
  head(r2,c).
  pos_body(r2,body).

rule(r3).
    head(r3,d).
    pos_body(r3,b).
    

% answer set: body, a
true(body).
true(a).
false(b).
false(c).
false(d).
    """)


@pytest.fixture
def example4():
    return compute_stable_model("""
%* program

(r1)    {a(1); a(2)}.
(r2)    {b(X)} :- a(X).
(r3)    c(X) :- a(X), not b(X).

*%


rule(r1).
  choice(r1, 0, unbounded).
  head(r1,a(1)).
  head(r1,a(2)).

rule(r2(X)) :- atom(a(X)).
  choice(r2(X), 0, unbounded) :- rule(r2(X)).
  head(r2(X),b(X)) :- rule(r2(X)).
  pos_body(r2(X),a(X)) :- rule(r2(X)).

rule(r3(X)) :- atom(a(X)), atom(b(X)).
  head(r3(X),c(X)) :- rule(r3(X)).
  pos_body(r3(X),a(X)) :- rule(r3(X)).
  neg_body(r3(X),b(X)) :- rule(r3(X)).

% answer set: a(1) a(2) b(1) c(2)
true(a(1)).
true(a(2)).
true(b(1)).
false(b(2)).
false(c(1)).
true(c(2)).
atom(Atom) :- true(Atom).
atom(Atom) :- false(Atom).
    """).drop("atom")


@pytest.fixture
def example5():
    return compute_stable_model("""
%* program

(r1)    a(1).
(r2)    {b(X,0); b(X,1)} :- a(X).
(r3)    c :- a(X), #sum{Y : b(X,Y)} >= X.

*%


rule(r1).
  head(r1,a(1)).

rule(r2(X)) :- atom(a(X)).
  choice(r2(X), 0, unbounded) :- rule(r2(X)).
  head(r2(X),b(X,0)) :- rule(r2(X)).
  head(r2(X),b(X,1)) :- rule(r2(X)).
  pos_body(r2(X),a(X)) :- rule(r2(X)).

rule(r3(X)) :- atom(a(X)).  %, #sum{Y : true(b(X,Y))} >= X.
  head(r3(X),c) :- rule(r3(X)).
  pos_body(r3(X),a(X)) :- rule(r3(X)).
  pos_body(r3(X),agg1(X)) :- rule(r3(X)).

aggregate(agg1(X), sum, ">=", X) :- rule(r3(X)).
  agg_set(agg1(X), b(X,Y), Y, ()) :- rule(r3(X)), atom(b(X,Y)).
  
  
% answer set: a(1) b(1,0)
true(a(1)).
true(b(1,0)).
false(b(1,1)).
false(c).
atom(Atom) :- true(Atom).
atom(Atom) :- false(Atom).
    """).drop("atom")


def test_process_true_aggregate(example1):
    model = process_aggregates(example1)
    assert model.as_facts == '\n'.join(sorted([
        "rule(r1).",
        "head(r1,a).",
        "rule(r2).",
        "head(r2,b).",
        "pos_body(r2,agg1).",
        "aggregate(agg1).",
        "true(agg1).",
        "rule(agg1).",
        "head(agg1,agg1).",
        "pos_body(agg1,a).",
        "neg_body(agg1,c).",
        "false(c).",
        "true(a).",
        "true(b).",
    ]))


def test_process_false_aggregate(example2):
    model = process_aggregates(example2)
    assert model == compute_stable_model('\n'.join([
        "rule(r1).",
        "head(r1,a).",
        "rule(r2).",
        "head(r2,b).",
        "pos_body(r2,agg1).",
        "aggregate(agg1).",
        "false(agg1).",
        "rule((agg1,a)).",
        "head((agg1,a),agg1).",
        "neg_body((agg1,a),a).",
        "rule((agg1,c)).",
        "head((agg1,c),agg1).",
        "pos_body((agg1,c),c).",
        "false(c).",
        "true(a).",
        "false(b).",
    ]))


def test_compute_minimal_assumption_set(example1, example2, example3):
    model = compute_minimal_assumption_set(example1)
    assert len(model) == 0
    model = compute_minimal_assumption_set(example2)
    assert len(model) == 0
    model = compute_minimal_assumption_set(example3)
    assert model in [
        compute_stable_model("""
            assume_false(b).
            assume_false(c).
        """),
        compute_stable_model("""
            assume_false(c).
            assume_false(d).
        """),
    ]


def test_compute_explanation(example1, example2, example3):
    model = compute_explanation(example1)
    assert model in [
        compute_stable_model("""
            explained_by(1, c, initial_well_founded).
            explained_by(2, a, (support,r1)).
            explained_by(3, agg1, (support,agg1)).
            explained_by(4, b, (support,r2)).
        """),
        compute_stable_model("""
            explained_by(1, c, initial_well_founded).
            explained_by(2, b, (support,r2)).
            explained_by(3, a, (support,r1)).
            explained_by(4, agg1, (support,agg1)).
        """)
    ]
    model = compute_explanation(example2)
    assert model in [
        compute_stable_model("""
            explained_by(1, c, initial_well_founded).
            explained_by(2, b, initial_well_founded).
            explained_by(3, agg1, initial_well_founded).
            explained_by(4, a, (support,r1)).
        """),
        compute_stable_model("""
            explained_by(1,agg1,initial_well_founded).
            explained_by(2,b,initial_well_founded).
            explained_by(3,c,initial_well_founded).
            explained_by(4,a,(support,r1)).
        """)
    ]
    model = compute_explanation(example3)
    assert model in [
        compute_stable_model("""
            explained_by(1,c,assumption).
            explained_by(2,b,assumption).
            explained_by(3,d,lack_of_support).
            explained_by(4,body,(support,r1)).
            explained_by(5,a,(support,r2)).
        """),
        compute_stable_model("""
            explained_by(1,d,assumption).
            explained_by(2,c,assumption).
            explained_by(3,body,(support,r1)).
            explained_by(4,b,(required_to_falsify_body,r3)).
            explained_by(5,a,(support,r2)).
        """),
        compute_stable_model("""
            explained_by(1,c,assumption).
            explained_by(2,d,assumption).
            explained_by(3,body,(support,r1)).
            explained_by(4,a,(support,r2)).
            explained_by(5,b,(required_to_falsify_body,r3)).
        """),
        compute_stable_model("""
            explained_by(1,c,assumption).
            explained_by(2,d,assumption).
            explained_by(3,body,(support,r1)).
            explained_by(4,b,(required_to_falsify_body,r3)).
            explained_by(5,a,(support,r2)).
        """),
    ]


def test_compute_explanation_dag(example1, example2, example3):
    model = compute_explanation_dag(example1)
    assert model in [
        compute_stable_model("""
            link(1,c,initial_well_founded,"false").
            link(2,a,(support,r1),"true").
            link(3,agg1,(support,agg1),a).
            link(3,agg1,(support,agg1),c).
            link(4,b,(support,r2),agg1).
        """),
        compute_stable_model("""
            link(1,c,initial_well_founded,"false").
            link(2,b,(support,r2),agg1).
            link(3,a,(support,r1),"true").
            link(4,agg1,(support,agg1),a).
            link(4,agg1,(support,agg1),c).
        """),
    ]
    model = compute_explanation_dag(example2)
    assert model in [
        compute_stable_model("""
            link(1,c,initial_well_founded,"false").
            link(2,b,initial_well_founded,"false").
            link(3,agg1,initial_well_founded,"false").
            link(4,a,(support,r1),"true").
        """),
        compute_stable_model("""
            link(1,agg1,initial_well_founded,"false").
            link(2,b,initial_well_founded,"false").
            link(3,c,initial_well_founded,"false").
            link(4,a,(support,r1),"true").
        """),
    ]
    model = compute_explanation_dag(example3)
    assert model in [
        compute_stable_model("""        
            link(1,c,assumption,"false").
            link(2,b,assumption,"false").
            link(3,d,(lack_of_support,r3),(b,"false")).
            link(4,body,(support,r1),"true").
            link(5,a,(support,r2),body).
        """),
        compute_stable_model("""
            link(1,d,assumption,"false").
            link(2,c,assumption,"false").
            link(3,body,(support,r1),"true").
            link(4,b,(required_to_falsify_body,r3),d).
            link(5,a,(support,r2),true).
        """),
        compute_stable_model("""
            link(1,c,assumption,"false").
            link(2,d,assumption,"false").
            link(3,body,(support,r1),"true").
            link(4,a,(support,r2),body).
            link(5,b,(required_to_falsify_body,r3),d).
        """),
        compute_stable_model("""
            link(1,c,assumption,"false").
            link(2,d,assumption,"false").
            link(3,body,(support,r1),"true").
            link(4,b,(required_to_falsify_body,r3),d).
            link(5,a,(support,r2),body).
        """),
    ]


def test_deal_with_symbolic_program(example4):
    model = compute_minimal_assumption_set(example4)
    assert model == compute_stable_model("assume_false(b(2)).")
    model = compute_explanation(example4)
    assert model in [
        compute_stable_model("""
            explained_by(1,b(2),assumption).
            explained_by(2,c(1),initial_well_founded).
            explained_by(3,a(1),(support,r1)).
            explained_by(4,a(2),(support,r1)).
            explained_by(5,b(1),(support,r2(1))).
            explained_by(6,c(2),(support,r3(2))).
        """),
        compute_stable_model("""
            explained_by(1,b(2),assumption).
            explained_by(2,c(1),initial_well_founded).
            explained_by(3,a(2),(support,r1)).
            explained_by(4,a(1),(support,r1)).
            explained_by(5,b(1),(support,r2(1))).
            explained_by(6,c(2),(support,r3(2))).
        """),
        compute_stable_model("""
            explained_by(1,c(1),initial_well_founded).
            explained_by(2,b(2),assumption).
            explained_by(3,c(2),(support,r3(2))).
            explained_by(4,b(1),(support,r2(1))).
            explained_by(5,a(1),(support,r1)).
            explained_by(6,a(2),(support,r1)).
        """),
        compute_stable_model("""
            explained_by(1,c(1),initial_well_founded).
            explained_by(2,b(2),assumption).
            explained_by(3,a(1),(support,r1)).
            explained_by(4,a(2),(support,r1)).
            explained_by(5,c(2),(support,r3(2))).
            explained_by(6,b(1),(support,r2(1))).
        """),
    ]
    model = compute_explanation_dag(example4)
    assert model in [
        compute_stable_model("""
            link(1,b(2),assumption,"false").
            link(2,c(1),initial_well_founded,"false").
            link(3,a(1),(support,r1),"true").
            link(4,a(2),(support,r1),"true").
            link(5,b(1),(support,r2(1)),a(1)).
            link(6,c(2),(support,r3(2)),a(2)).
            link(6,c(2),(support,r3(2)),b(2)).
        """),
        compute_stable_model("""
            link(1,b(2),assumption,"false").
            link(2,c(1),initial_well_founded,"false").
            link(3,a(2),(support,r1),"true").
            link(4,a(1),(support,r1),"true").
            link(5,b(1),(support,r2(1)),a(1)).
            link(6,c(2),(support,r3(2)),a(2)).
            link(6,c(2),(support,r3(2)),b(2)).
        """),
        compute_stable_model("""
            link(1,c(1),initial_well_founded,"false").
            link(2,b(2),assumption,"false").
            link(3,c(2),(support,r3(2)),a(2)).
            link(3,c(2),(support,r3(2)),b(2)).
            link(4,b(1),(support,r2(1)),a(1)).
            link(5,a(1),(support,r1),"true").
            link(6,a(2),(support,r1),"true").
        """),
        compute_stable_model("""
            link(1,c(1),initial_well_founded,"false").
            link(2,b(2),assumption,"false").
            link(3,a(1),(support,r1),"true").
            link(4,a(2),(support,r1),"true").
            link(5,c(2),(support,r3(2)),a(2)).
            link(5,c(2),(support,r3(2)),b(2)).
            link(6,b(1),(support,r2(1)),a(1)).
        """),
    ]


def test_deal_with_symbolic_program_and_aggregates(example5):
    model = compute_minimal_assumption_set(example5)
    assert model == compute_stable_model("assume_false(b(1,1)).")
    model = compute_explanation(example5)
    assert model in [
        compute_stable_model("""
            explained_by(1,b(1,1),assumption).
            explained_by(2,a(1),(support,r1)).
            explained_by(3,b(1,0),(support,r2(1))).
            explained_by(4,agg1(1),lack_of_support).
            explained_by(5,c,lack_of_support).
        """),
        compute_stable_model("""
            explained_by(1,b(1,1),assumption).
            explained_by(2,agg1(1),lack_of_support).
            explained_by(3,c,lack_of_support).
            explained_by(4,b(1,0),(support,r2(1))).
            explained_by(5,a(1),(support,r1)).
        """),
    ]
    model = compute_explanation_dag(example5)
    assert model in [
        compute_stable_model("""
            link(1,b(1,1),assumption,"false").
            link(2,a(1),(support,r1),"true").
            link(3,b(1,0),(support,r2(1)),a(1)).
            link(4,agg1(1),(lack_of_support,(agg1(1),b(1,0))),b(1,0)).
            link(4,agg1(1),(lack_of_support,(agg1(1),b(1,1))),b(1,1)).
            link(5,c,(lack_of_support,r3(1)),agg1(1)).
        """),
        compute_stable_model("""
            link(1,b(1,1),assumption,"false").
            link(2,agg1(1),(lack_of_support,(agg1(1),b(1,0))),b(1,0)).
            link(2,agg1(1),(lack_of_support,(agg1(1),b(1,1))),b(1,1)).
            link(3,c,(lack_of_support,r3(1)),agg1(1)).
            link(4,b(1,0),(support,r2(1)),a(1)).
            link(5,a(1),(support,r1),"true").
        """),
    ]


def test_serialization_with_propositional_aggregates(example1, example2, example3):
    assert compute_serialization("a. b :- #sum{1 : a; 1 : c} >= 1.", true_atoms=["a", "b"],
                                 false_atoms=["c"]) == example1
    assert compute_serialization("a. b :- #sum{1 : a; 1 : c} < 1.", true_atoms=["a"],
                                 false_atoms=["b", "c"]) == example2
    assert compute_serialization("body.  1 <= {a; b; c} <= 2 :- body.  d :- b.",
                                 true_atoms=["body", "a"], false_atoms="b c d".split()) == example3


def test_serialization_with_symbolic_program(example4, example5):
    assert compute_serialization("""
        {a(1); a(2)}.
        {b(X)} :- a(X).
        c(X) :- a(X), not b(X).
    """, true_atoms="a(1) a(2) b(1) c(2)".split(), false_atoms="b(2) c(1)".split()) == example4
    assert compute_serialization("""
        a(1).
        {b(X,0); b(X,1)} :- a(X).
        c :- a(X), #sum{Y : b(X,Y)} >= X.
    """, true_atoms="a(1) b(1,0)".split(), false_atoms="b(1,1) c".split()) == example5


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
    """, true_atoms=[atom.strip() for atom in """
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
    """.split('\n')], false_atoms=[atom.strip() for atom in """
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
    """.split('\n')])


def test_running_example_1(running_example_1):
    minimal_assumption_set = compute_minimal_assumption_set(running_example_1)
    assert len(minimal_assumption_set) == 0
    explanation = compute_explanation(running_example_1)
    assert len(explanation) == 32


def test_process_aggregate_with_variables():
    assert compute_serialization("""
        :- a(X), #sum{Y : b(X,Y)} > 0.
    """, true_atoms="a(1) a(2) b(1,2)".split(), false_atoms=["b(2,1)"]) == compute_stable_model("""
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
    """, true_atoms=['b'], false_atoms=['a'], atom_to_explain='a')
    minimal_assumption_set = compute_minimal_assumption_set(serialization)
    assert len(minimal_assumption_set) == 1
    assert minimal_assumption_set == compute_stable_model("assume_false(a).")


def test_lack_of_explanation_2():
    serialization = compute_serialization("{a}.", true_atoms=[], false_atoms=['a'], atom_to_explain='a')
    minimal_assumption_set = compute_minimal_assumption_set(serialization)
    assert len(minimal_assumption_set) == 1
    assert minimal_assumption_set == compute_stable_model("assume_false(a).")


def test_lack_of_explanation_3():
    serialization = compute_serialization("a :- #sum{1 : a} >= 0.", true_atoms=['a'], false_atoms=[],
                                          atom_to_explain='a')
    with pytest.raises(TypeError):
        compute_minimal_assumption_set(serialization)


def test_atom_inferred_by_constraint_like_rules_can_be_linked_to_false():
    serialization = compute_serialization("""
        a :- not b.
        b :- not a.
        :- b.
    """, true_atoms=['a'], false_atoms=['b'], atom_to_explain="a")
    dag = compute_explanation_dag(serialization)
    assert dag == compute_stable_model("""
        link(1,b,(required_to_falsify_body,r3),"false").
        link(2,a,(support,r1),b).
    """)


def test_atom_inferred_by_choice_rules_can_be_linked_to_false():
    serialization = compute_serialization("""
        {a} <= 0.
    """, true_atoms=[], false_atoms=['a'], atom_to_explain="a")
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
    """, true_atoms=true_atoms, false_atoms=[atom.strip() for atom in """
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
    """.strip().split('\n')], atom_to_explain="colored(4,red)")
    dag = compute_explanation_dag(serialization)
    assert len(dag) == 55


def test_compute_second_minimal_assumption_set():
    serialization = compute_serialization("""
        a :- not b.
        b :- not a.
        c :- not a.
        a :- not c.
    """, true_atoms=["a"], false_atoms=["b", "c"], atom_to_explain="a")
    minimal_assumption_set = compute_minimal_assumption_set(serialization)
    assert len(minimal_assumption_set) == 1
    minimal_assumption_set = compute_minimal_assumption_set(serialization, [minimal_assumption_set])
    assert len(minimal_assumption_set) == 1


def test_compute_all_minimal_assumption_sets():
    serialization = compute_serialization("""
            a :- not b.
            b :- not a.
            c :- not a.
            a :- not c.
        """, true_atoms=["a"], false_atoms=["b", "c"], atom_to_explain="a")
    minimal_assumption_sets = compute_minimal_assumption_sets(serialization)
    assert len(minimal_assumption_sets) == 2


def test_rule_with_arithmetic():
    serialization = compute_serialization("""
        a(X) :- X = 1..2.
    """, true_atoms=["a(1)", "a(2)"], false_atoms=[], atom_to_explain="a(1)")
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


def test_second_explanation():
    serialization = compute_serialization("""
        a :- not b.
        a :- m.
        m.
    """, true_atoms=["m", "a"], false_atoms=["b"], atom_to_explain="a")
    minimal_assumption_set = compute_minimal_assumption_set(serialization)
    assert len(minimal_assumption_set) == 0
    explanations = [compute_explanation(serialization, minimal_assumption_set)]
    assert "explained_by(3,a,(support,r2))." in explanations[-1].as_facts
    explanations.append(compute_explanation(serialization, minimal_assumption_set, explanations))
    assert "explained_by(3,a,(support,r1))." in explanations[-1].as_facts
    assert compute_explanation(serialization, minimal_assumption_set, explanations) is None


def test_compute_explanations():
    serialization = compute_serialization("""
        {a; b}.
        :- a, not b.
        :- b, not a.
        c :- a, b.
    """, true_atoms=[], false_atoms=["a", "b", "c"], atom_to_explain="c")
    explanations = compute_explanations(serialization)
    assert len(explanations) == 2


def test_second_dag():
    serialization = compute_serialization("""
            {a; b}.
            c :- a, b.
        """, true_atoms=[], false_atoms=["a", "b", "c"], atom_to_explain="c")
    explanation = compute_explanation(serialization)
    dags = [compute_explanation_dag(serialization, explanation)]
    assert "link(3,c,(lack_of_support,r2),b)." in dags[-1].as_facts
    dags.append(compute_explanation_dag(serialization, explanation, dags))
    assert "link(3,c,(lack_of_support,r2),a)." in dags[-1].as_facts
    assert compute_explanation_dag(serialization, explanation, dags) is None


def test_compute_dags():
    serialization = compute_serialization("""
            {a; b}.
            c :- a, b.
        """, true_atoms=[], false_atoms=["a", "b", "c"], atom_to_explain="c")
    assert len(compute_explanation_dags(serialization)) == 2


def test_choice_rule_with_condition():
    serialization = compute_serialization("""
                {a(X) : X = 1..2} = 1.
            """, true_atoms=["a(1)"], false_atoms=["a(2)"], atom_to_explain="a(2)")
    explanation = compute_explanation(serialization)
    assert "explained_by(2,a(2),(choice_rule,r1))." in explanation.as_facts
