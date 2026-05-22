import 'package:objectbox/objectbox.dart';
import 'graph_edge.dart';

@Entity()
class GraphNode {
  @Id()
  int id = 0;

  /// The note ID this node wraps
  int noteId;

  /// Timestamp when node was created in graph
  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  /// Timestamp when node was last updated
  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  /// Bidirectional: edges where this node is source
  final outgoingEdges = <GraphEdge>[];

  /// Bidirectional: edges where this node is target
  final incomingEdges = <GraphEdge>[];

  GraphNode({
    required this.noteId,
  });
}
