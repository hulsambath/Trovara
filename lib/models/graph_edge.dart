import 'package:objectbox/objectbox.dart';
import 'graph_node.dart';

@Entity()
class GraphEdge {
  @Id()
  int id = 0;

  /// Type: 'semantic', 'source', or 'hierarchical'
  @Index()
  late String edgeType; // semantic | source | hierarchical

  /// Strength score (0.0-1.0) for semantic edges
  double strength = 1.0;

  /// JSON metadata (URL for source edges, notes for hierarchical)
  late String? metadata;

  /// Timestamp when edge was created
  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  /// Bidirectional: source node
  final sourceNode = ToOne<GraphNode>();

  /// Bidirectional: target node
  final targetNode = ToOne<GraphNode>();

  GraphEdge({
    required this.edgeType,
    this.strength = 1.0,
    this.metadata,
  });
}
