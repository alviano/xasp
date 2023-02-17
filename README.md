# xasp

API for eXplainable Answer Set Programming.


# Prerequisites

Almost all dependencies are handled via `poetry`.
The following tools must be already installed:  
- Python 3.10+ 
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

After cloning the repository, install dependencies:
```bash
$ poetry install
$ poetry shell
```


# Usage

The computation of an explanation can be performed step-by-step.
For example, a minimal assumption set can be computed by using the following snipped of code:
```python
from xasp.entities import Explain
from dumbo_asp.primitives import Model

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
from dumbo_asp.primitives import Model

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
from dumbo_asp.primitives import Model

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
