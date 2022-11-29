from xasp.queries import compute_stable_model


def test_compute_stable_model():
    model = compute_stable_model("a.")
    assert len(model) == 1
    assert model[0].name == "a"


def test_compute_stable_may_return_none():
    model = compute_stable_model("a :- not a.")
    assert model is None
