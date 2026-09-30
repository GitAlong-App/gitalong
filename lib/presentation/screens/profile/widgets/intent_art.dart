import '../../../../core/constants/illustrations.dart';

/// The 3D illustration for a collaboration intent (`looking_for` key), per
/// docs/DESIGN_SYSTEM.md §5.
String intentIllustration(String key) => switch (key) {
      'cofounder' => Illustrations.rocket,
      'side_project' => Illustrations.hammerAndWrench,
      'open_source' => Illustrations.globe,
      'hackathon' => Illustrations.highVoltage,
      'mentor' => Illustrations.graduationCap,
      'mentee' => Illustrations.seedling,
      _ => Illustrations.sparkles,
    };
