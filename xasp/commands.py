from pathlib import Path

import igraph

from xasp.primitives import Model
from xasp.utils import validate


def save_explanation_dag(dag: Model, target: Path):
    graph = igraph.Graph()
    graph.add_vertex('"true"', label="#true")
    graph.add_vertex('"false"', label="#false")
    for link in dag:
        validate("link name", link.name, equals="link")
        _, source, label, sink = (str(x) for x in link.arguments)
        validate("sink is present", graph.vs.select(name=sink), length=1)
        if len(graph.vs.select(name=source)) == 0:
            graph.add_vertex(source, label=source)
        graph.add_edge(source, sink, label=label)
    igraph.plot(graph, target=target)
