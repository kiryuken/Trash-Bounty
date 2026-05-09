class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final int points;
  final double walletBalance;
  final int? rank;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    required this.points,
    required this.walletBalance,
    this.rank,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        avatarUrl: json['avatar_url'] as String?,
        points: (json['points'] as num?)?.toInt() ?? 0,
        walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0,
        rank: json['rank'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'avatar_url': avatarUrl,
        'points': points,
        'wallet_balance': walletBalance,
        'rank': rank,
      };
}

class AuthResponse {
  final String token;
  final String refreshToken;
  final UserModel user;

  const AuthResponse({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['token'] as String,
        refreshToken: json['refresh_token'] as String,
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class HomeStats {
  final int totalReports;
  final int totalPoints;
  final int? currentRank;
  final double walletBalance;
  final int pendingBounties;

  const HomeStats({
    required this.totalReports,
    required this.totalPoints,
    this.currentRank,
    required this.walletBalance,
    required this.pendingBounties,
  });

  factory HomeStats.fromJson(Map<String, dynamic> json) => HomeStats(
        totalReports: (json['total_reports'] as num?)?.toInt() ?? 0,
        totalPoints: (json['total_points'] as num?)?.toInt() ?? 0,
        currentRank: json['current_rank'] as int?,
        walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0,
        pendingBounties: (json['pending_bounties'] as num?)?.toInt() ?? 0,
      );
}

class ReportModel {
  final String id;
  final String? imageUrl;
  final String locationText;
  final String? wasteType;
  final int severity;
  final String status;
  final String? aiReasoning;
  final double? aiConfidence;
  final int? pointsEarned;
  final double? rewardIdr;
  final String? createdAt;

  const ReportModel({
    required this.id,
    this.imageUrl,
    required this.locationText,
    this.wasteType,
    required this.severity,
    required this.status,
    this.aiReasoning,
    this.aiConfidence,
    this.pointsEarned,
    this.rewardIdr,
    this.createdAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) => ReportModel(
        id: json['id'] as String,
        imageUrl: json['image_url'] as String?,
        locationText: (json['location_text'] ?? json['location'] ?? '') as String,
        wasteType: json['waste_type'] as String?,
        severity: (json['severity'] as num?)?.toInt() ?? 0,
        status: json['status'] as String,
        aiReasoning: json['ai_reasoning'] as String?,
        aiConfidence: (json['ai_confidence'] as num?)?.toDouble(),
        pointsEarned: (json['points_earned'] as num?)?.toInt(),
        rewardIdr: (json['reward_idr'] as num?)?.toDouble(),
        createdAt: json['created_at'] as String?,
      );
}

class ReportStatus {
  final String status;
  final int progress;

  const ReportStatus({required this.status, required this.progress});

  factory ReportStatus.fromJson(Map<String, dynamic> json) => ReportStatus(
        status: json['status'] as String,
        progress: (json['progress'] as num?)?.toInt() ?? 0,
      );
}

class BountyModel {
  final String id;
  final String? reportId;
  final String location;
  final String? address;
  final String? distance;
  final int severity;
  final String? wasteType;
  final int? rewardPoints;
  final double reward;
  final int? estimatedTime;
  final String? image;
  final String status;
  final double? latitude;
  final double? longitude;
  final double? score;
  final String? reasoning;

  const BountyModel({
    required this.id,
    this.reportId,
    required this.location,
    this.address,
    this.distance,
    required this.severity,
    this.wasteType,
    this.rewardPoints,
    required this.reward,
    this.estimatedTime,
    this.image,
    required this.status,
    this.latitude,
    this.longitude,
    this.score,
    this.reasoning,
  });

  factory BountyModel.fromJson(Map<String, dynamic> json) => BountyModel(
        id: json['id'] as String,
        reportId: json['report_id'] as String?,
        location: (json['location'] ?? '') as String,
        address: json['address'] as String?,
        distance: json['distance'] as String?,
        severity: (json['severity'] as num?)?.toInt() ?? 0,
        wasteType: json['waste_type'] as String?,
        rewardPoints: (json['reward_points'] as num?)?.toInt(),
        reward: (json['reward'] as num?)?.toDouble() ?? 0,
        estimatedTime: (json['estimated_time'] as num?)?.toInt(),
        image: json['image'] as String?,
        status: json['status'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        score: (json['score'] as num?)?.toDouble(),
        reasoning: json['reasoning'] as String?,
      );
}

class LeaderboardEntry {
  final int rank;
  final String id;
  final String name;
  final String? avatar;
  final int points;
  final int tasks;
  final String badge;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.id,
    required this.name,
    this.avatar,
    required this.points,
    required this.tasks,
    required this.badge,
    required this.isCurrentUser,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        id: json['id'] as String,
        name: json['name'] as String,
        avatar: json['avatar'] as String?,
        points: (json['points'] as num?)?.toInt() ?? 0,
        tasks: (json['tasks'] as num?)?.toInt() ?? 0,
        badge: (json['badge'] ?? '') as String,
        isCurrentUser: json['is_current_user'] as bool? ?? false,
      );
}

class LeaderboardResponse {
  final String period;
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? currentUserRank;

  const LeaderboardResponse({
    required this.period,
    required this.entries,
    this.currentUserRank,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> json) => LeaderboardResponse(
        period: json['period'] as String,
        entries: (json['entries'] as List?)
                ?.map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        currentUserRank: json['current_user_rank'] != null
            ? LeaderboardEntry.fromJson(json['current_user_rank'] as Map<String, dynamic>)
            : null,
      );
}

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;
  final int points;
  final double walletBalance;
  final int? rank;
  final int totalReports;
  final int totalBounties;
  final double successRate;
  final String? joinedAt;
  final bool telegramConnected;
  final String? telegramLinkedAt;
  final List<Achievement> achievements;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    required this.points,
    required this.walletBalance,
    this.rank,
    required this.totalReports,
    required this.totalBounties,
    required this.successRate,
    this.joinedAt,
    required this.telegramConnected,
    this.telegramLinkedAt,
    required this.achievements,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        avatarUrl: json['avatar_url'] as String?,
        points: (json['points'] as num?)?.toInt() ?? 0,
        walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0,
        rank: json['rank'] as int?,
        totalReports: (json['total_reports'] as num?)?.toInt() ?? 0,
        totalBounties: (json['total_bounties'] as num?)?.toInt() ?? 0,
        successRate: (json['success_rate'] as num?)?.toDouble() ?? 0,
        joinedAt: json['joined_at'] as String?,
        telegramConnected: json['telegram_connected'] as bool? ?? false,
        telegramLinkedAt: json['telegram_linked_at'] as String?,
        achievements: (json['achievements'] as List?)
                ?.map((e) => Achievement.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class Achievement {
  final String type;
  final String icon;
  final String name;
  final bool unlocked;
  final String? earnedAt;

  const Achievement({
    required this.type,
    required this.icon,
    required this.name,
    required this.unlocked,
    this.earnedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        type: json['type'] as String,
        icon: json['icon'] as String,
        name: json['name'] as String,
        unlocked: json['unlocked'] as bool? ?? false,
        earnedAt: json['earned_at'] as String?,
      );
}

class HistoryItem {
  final String id;
  final String? type;
  final String status;
  final String location;
  final int severity;
  final double reward;
  final int? pointsEarned;
  final String? date;
  final String? duration;
  final String? createdAt;

  const HistoryItem({
    required this.id,
    this.type,
    required this.status,
    required this.location,
    required this.severity,
    required this.reward,
    this.pointsEarned,
    this.date,
    this.duration,
    this.createdAt,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as String,
        type: json['type'] as String?,
        status: json['status'] as String,
        location: (json['location'] ?? '') as String,
        severity: (json['severity'] as num?)?.toInt() ?? 0,
        reward: (json['reward'] as num?)?.toDouble() ?? 0,
        pointsEarned: (json['points_earned'] as num?)?.toInt(),
        date: json['date'] as String?,
        duration: json['duration'] as String?,
        createdAt: json['created_at'] as String?,
      );
}

class NotificationModel {
  final String id;
  final String type;
  final String message;
  final bool isRead;
  final String createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
        id: json['id'] as String,
        type: json['type'] as String,
        message: json['message'] as String,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: json['created_at'] as String,
      );
}

class PrivacySettings {
  final bool publicProfile;
  final bool locationSharing;
  final bool twoFactorEnabled;

  const PrivacySettings({
    required this.publicProfile,
    required this.locationSharing,
    required this.twoFactorEnabled,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) => PrivacySettings(
        publicProfile: json['public_profile'] as bool? ?? false,
        locationSharing: json['location_sharing'] as bool? ?? false,
        twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'public_profile': publicProfile,
        'location_sharing': locationSharing,
        'two_factor_enabled': twoFactorEnabled,
      };
}

class WasteTypeStat {
  final String wasteType;
  final int count;
  final double avgSeverity;

  const WasteTypeStat({
    required this.wasteType,
    required this.count,
    required this.avgSeverity,
  });

  factory WasteTypeStat.fromJson(Map<String, dynamic> json) => WasteTypeStat(
        wasteType: (json['waste_type'] ?? '') as String,
        count: (json['count'] as num?)?.toInt() ?? 0,
        avgSeverity: (json['avg_severity'] as num?)?.toDouble() ?? 0,
      );
}

class CleanupStats {
  final String period;
  final int totalCompleted;
  final int totalPointsAwarded;
  final double totalRewardIdr;
  final double totalWeightKg;
  final List<WasteTypeStat> wasteTypes;

  const CleanupStats({
    required this.period,
    required this.totalCompleted,
    required this.totalPointsAwarded,
    required this.totalRewardIdr,
    required this.totalWeightKg,
    required this.wasteTypes,
  });

  factory CleanupStats.fromJson(Map<String, dynamic> json) => CleanupStats(
        period: (json['period'] ?? 'alltime') as String,
        totalCompleted: (json['total_completed'] as num?)?.toInt() ?? 0,
        totalPointsAwarded: (json['total_points_awarded'] as num?)?.toInt() ?? 0,
        totalRewardIdr: (json['total_reward_idr'] as num?)?.toDouble() ?? 0,
        totalWeightKg: (json['total_weight_kg'] as num?)?.toDouble() ?? 0,
        wasteTypes: (json['waste_types'] as List? ?? [])
            .map((e) => WasteTypeStat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
