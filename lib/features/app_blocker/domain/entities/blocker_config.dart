class BlockerConfig {
  final bool isShieldActive;
  final int? scheduleStartHour;
  final int? scheduleStartMinute;
  final int? scheduleEndHour;
  final int? scheduleEndMinute;
  final int? usageLimitMinutes;
  final bool hasAppsSelected;

  const BlockerConfig({
    required this.isShieldActive,
    this.scheduleStartHour,
    this.scheduleStartMinute,
    this.scheduleEndHour,
    this.scheduleEndMinute,
    this.usageLimitMinutes,
    required this.hasAppsSelected,
  });

  BlockerConfig copyWith({
    bool? isShieldActive,
    int? scheduleStartHour,
    int? scheduleStartMinute,
    int? scheduleEndHour,
    int? scheduleEndMinute,
    int? usageLimitMinutes,
    bool? hasAppsSelected,
  }) {
    return BlockerConfig(
      isShieldActive: isShieldActive ?? this.isShieldActive,
      scheduleStartHour: scheduleStartHour ?? this.scheduleStartHour,
      scheduleStartMinute: scheduleStartMinute ?? this.scheduleStartMinute,
      scheduleEndHour: scheduleEndHour ?? this.scheduleEndHour,
      scheduleEndMinute: scheduleEndMinute ?? this.scheduleEndMinute,
      usageLimitMinutes: usageLimitMinutes ?? this.usageLimitMinutes,
      hasAppsSelected: hasAppsSelected ?? this.hasAppsSelected,
    );
  }

  Map<String, dynamic> toJson() => {
        'isShieldActive': isShieldActive,
        'scheduleStartHour': scheduleStartHour,
        'scheduleStartMinute': scheduleStartMinute,
        'scheduleEndHour': scheduleEndHour,
        'scheduleEndMinute': scheduleEndMinute,
        'usageLimitMinutes': usageLimitMinutes,
        'hasAppsSelected': hasAppsSelected,
      };

  factory BlockerConfig.fromJson(Map<String, dynamic> json) => BlockerConfig(
        isShieldActive: json['isShieldActive'] as bool? ?? false,
        scheduleStartHour: json['scheduleStartHour'] as int?,
        scheduleStartMinute: json['scheduleStartMinute'] as int?,
        scheduleEndHour: json['scheduleEndHour'] as int?,
        scheduleEndMinute: json['scheduleEndMinute'] as int?,
        usageLimitMinutes: json['usageLimitMinutes'] as int?,
        hasAppsSelected: json['hasAppsSelected'] as bool? ?? false,
      );
}
