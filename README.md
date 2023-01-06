# blind

API for eXplainable Answer Set Programming.


# Prerequisites

Almost all dependencies are handled via `conda` and `poetry`.
The following tools must be already installed:  
- [Conda](https://conda.io/) or [Miniconda](https://docs.conda.io/en/latest/miniconda.html) to create a [Python 3.10](https://www.python.org/downloads/release/python-3109/) environment 
- [Cairo](https://www.cairographics.org/) library 

# Tested Environments 

OSes: 
- CentOS 7
- Debian sid
- MacOS Big Sur Version 11.6
- Ubuntu 20.04.5 LTS

Browsers:
- Chrome
- Firefox   
- Safari


# Setup

Create a conda environment (named `blind` or as you like) using the provided script:
```bash
$ ./bin/create-environment.sh
```

Activate the environment and install dependencies:
```bash
$ conda activate blind
(blind) $ poetry install
```


# Usage

Try the example main.py:
```bash
(blind) $ python xasp/main.py
```

Your browser will open the explanation [DAG](https://blind-navigator.netlify.app/#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).

The computation of an explanation can be performed step-by-step.
For example, a minimal assumption set can be computed by using the following snipped of code:
```python
from xasp.entities import Explain
from xasp.primitives import Model

explain = Explain.the_program(
    "[A PROGRAM HERE]",
    the_answer_set=Model.of_atoms("[ATOM1]", "[ATOM2]", ...),
    the_atoms_to_explain=Model.of_atoms("[ATOM]"),
)
explain.compute_minimal_assumption_set()  # it can also be omitted
print(explain.minimal_assumption_set())
```

An explanation sequence can be computed by using the following snipped of code:
```python
from xasp.entities import Explain
from xasp.primitives import Model

explain = Explain.the_program(
    "[A PROGRAM HERE]",
    the_answer_set=Model.of_atoms("[ATOM1]", "[ATOM2]", ...),
    the_atoms_to_explain=Model.of_atoms("[ATOM]"),
)
explain.compute_explanation_sequence()  # it can also be omitted
print(explain.explanation_sequence())
```

An explanation DAG can be computed by using the following snipped of code:
```python
from xasp.entities import Explain
from xasp.primitives import Model

explain = Explain.the_program(
    "[A PROGRAM HERE]",
    the_answer_set=Model.of_atoms("[ATOM1]", "[ATOM2]", ...),
    the_atoms_to_explain=Model.of_atoms("[ATOM]"),
)
explain.compute_explanation_dag()  # it can also be omitted
print(explain.explanation_dag())
```

All the above commands and queries can be combined.
Actually, required steps are performed automatically when required.
Finally, it is possible to ask for more minimal assumption sets, explanation sequences and DAGs either by using the keyword `repeat=<int>` in the `compute_*` commands, or the keyword `index=<int>` in the queries (`minimal_assumption_set()`, `explanation_sequence()`, `explanation_dag`, `show_navigator_graph()`).
