import clingo
import pytest

from xasp.primitives import Model


def test_model():
    control = clingo.Control()
    control.add("base", [], "c. a. b.")
    control.ground([("base", [])])
    model = Model.of(control)
    assert len(model) == 3
    assert model[0].name == "a"
    assert model[1].name == "b"
    assert model[2].name == "c"


def test_no_model():
    control = clingo.Control()
    control.add("base", [], "a :- not a.")
    control.ground([("base", [])])
    assert Model.of(control) is None


def test_model_of_control_cannot_be_used_for_more_than_one_model():
    control = clingo.Control(["0"])
    control.add("base", [], "{a}.")
    control.ground([("base", [])])
    with pytest.raises(ValueError):
        Model.of(control)


def test_model_as_facts():
    control = clingo.Control()
    control.add("base", [], "a. b. c.")
    control.ground([("base", [])])
    assert Model.of(control).as_facts() == "a.\nb.\nc."


def test_model_drop():
    control = clingo.Control()
    control.add("base", [], "a. b. c.")
    control.ground([("base", [])])
    assert Model.of(control).drop("a").as_facts() == "b.\nc."
