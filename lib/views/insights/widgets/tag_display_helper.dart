import 'package:flutter/material.dart';
import 'package:trovara/models/activity_tag.dart';
import 'package:trovara/models/custom_tag.dart';
import 'package:trovara/models/mood_tag.dart';
import 'package:trovara/models/personal_growth_tag.dart';
import 'package:trovara/models/time_tag.dart';

class TagDisplayInfo {
  final String label;
  final Color color;
  final Widget? bottomWidget;

  const TagDisplayInfo({required this.label, required this.color, this.bottomWidget});
}

class TagDisplayHelper {
  const TagDisplayHelper._();

  static TagDisplayInfo getInfo(BuildContext context, String category, String idOrName) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color fallbackColor = scheme.primary;

    return switch (category) {
      'mood' => _getMoodInfo(idOrName, fallbackColor, context),
      'activity' => _getActivityInfo(idOrName, fallbackColor, scheme),
      'time' => _getTimeInfo(idOrName, fallbackColor, scheme),
      'growth' => _getGrowthInfo(idOrName, fallbackColor, scheme),
      _ => _getCustomInfo(idOrName, fallbackColor, scheme, context),
    };
  }

  static TagDisplayInfo _getMoodInfo(String id, Color fallback, BuildContext context) {
    final tag = MoodTags.getById(id);
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return TagDisplayInfo(
      label: tag?.label ?? id,
      color: tag?.color ?? fallback,
      bottomWidget: Text(tag?.emoji ?? '🙂', style: style),
    );
  }

  static TagDisplayInfo _getActivityInfo(String id, Color fallback, ColorScheme scheme) {
    final tag = ActivityTags.getById(id);
    return TagDisplayInfo(
      label: tag?.label ?? id,
      color: tag?.color ?? fallback,
      bottomWidget: Icon(tag?.icon ?? Icons.local_activity_outlined, size: 14, color: scheme.onSurfaceVariant),
    );
  }

  static TagDisplayInfo _getTimeInfo(String id, Color fallback, ColorScheme scheme) {
    final tag = TimeTags.getById(id);
    return TagDisplayInfo(
      label: tag?.label ?? id,
      color: tag?.color ?? fallback,
      bottomWidget: Icon(tag?.icon ?? Icons.schedule_outlined, size: 14, color: scheme.onSurfaceVariant),
    );
  }

  static TagDisplayInfo _getGrowthInfo(String id, Color fallback, ColorScheme scheme) {
    final tag = PersonalGrowthTags.getById(id);
    return TagDisplayInfo(
      label: tag?.label ?? id,
      color: tag?.color ?? fallback,
      bottomWidget: Icon(tag?.icon ?? Icons.trending_up_outlined, size: 14, color: scheme.onSurfaceVariant),
    );
  }

  static TagDisplayInfo _getCustomInfo(String name, Color fallback, ColorScheme scheme, BuildContext context) {
    final tag = CustomTags.getByName(name);
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return TagDisplayInfo(
      label: name,
      color: tag?.displayColor ?? fallback,
      bottomWidget: Text(_truncate(name, 6), style: style, overflow: TextOverflow.ellipsis),
    );
  }

  static String _truncate(String s, int maxChars) {
    final String t = s.trim();
    if (t.length <= maxChars) return t;
    if (maxChars <= 1) return '…';
    return '${t.substring(0, maxChars - 1)}…';
  }

  static String categoryLabel(String category) => switch (category) {
    'mood' => 'Mood',
    'activity' => 'Activity',
    'time' => 'Time',
    'growth' => 'Growth',
    'custom' => 'Custom',
    _ => category,
  };
}
