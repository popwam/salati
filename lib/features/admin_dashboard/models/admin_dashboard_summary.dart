class AdminDashboardSummary {
  const AdminDashboardSummary({
    required this.totalUsers,
    required this.activeUsersToday,
    required this.activeUsersLast7Days,
    required this.premiumUsers,
    required this.blockedUsers,
    required this.adminUsers,
    required this.usersWithAiLimitOverride,
    required this.totalPrayerPoints,
    required this.totalDhikrCategories,
    required this.totalDuas,
    required this.totalStoreItems,
    required this.availableAiTokens,
  });

  final int totalUsers;
  final int activeUsersToday;
  final int activeUsersLast7Days;
  final int premiumUsers;
  final int blockedUsers;
  final int adminUsers;
  final int usersWithAiLimitOverride;
  final int totalPrayerPoints;
  final int totalDhikrCategories;
  final int totalDuas;
  final int totalStoreItems;
  final int availableAiTokens;
}
