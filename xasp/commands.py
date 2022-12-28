from pathlib import Path
from typing import Final

import igraph

from xasp.primitives import Model
from xasp.utils import validate

TRUE_COLOR: Final = "green"
FALSE_COLOR: Final = "red"


def save_explanation_dag(dag: Model, answer_set: Model, atoms_to_explain: Model, target: Path, **kwargs):
    answer_set_as_strings = [str(atom) for atom in answer_set]
    graph = igraph.Graph(directed=True)
    graph.add_vertex('"true"', color=TRUE_COLOR, label="#true")
    graph.add_vertex('"false"', color=FALSE_COLOR, label="#false")
    for link in dag:
        validate("link name", link.name, equals="link")
        _, source, label, sink = (str(x) for x in link.arguments)
        validate("sink is present", graph.vs.select(name=sink), length=1)
        if len(graph.vs.select(name=source)) == 0:
            color = TRUE_COLOR if source in answer_set_as_strings else FALSE_COLOR
            graph.add_vertex(source, color=color, label=source)
        graph.add_edge(source, sink, label=label)

    reachable_nodes = graph.neighborhood(
        vertices=[str(atom) for atom in atoms_to_explain],
        order=len(graph.vs),
        mode="out"
    )
    nodes = []
    for reachable_nodes_element in reachable_nodes:
        nodes.extend(reachable_nodes_element)
    graph = graph.induced_subgraph(nodes)
    igraph.plot(
        graph,
        layout=graph.layout_kamada_kawai(),
        margin=140,
        target=target,
        vertex_label_dist=2,
        vertex_size=8,
        **kwargs,
    )
