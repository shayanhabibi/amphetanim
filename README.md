# Amphetanim

WIP

Is my work at lower level hacking deeper type information and data.

Will follow with fixing up assume iteration to work for loony by iterating over all nodes from the head of the graph and ensuring no node are referenced outside the scope of the graph.

Post asserting this fact, an atomic_thread_fence release will be set.

Receiving the graph on the other end of the loony queue will require an atomic_thread_fence acquire after attaining the head of the graph. After this memory should be safe to read.