enum AdminModule {
  overview,
  accessRequests,
  users,
  verification,
  events,
  trainings,
  uid,
  jobs,
  news,
  chat,
  sos,
  institutions,
  analytics,
  cybersecurity,
  api,
  settings,
  audit,
}

extension AdminModuleX on AdminModule {
  String get slug {
    switch (this) {
      case AdminModule.overview:
        return 'overview';
      case AdminModule.accessRequests:
        return 'access-requests';
      case AdminModule.users:
        return 'users';
      case AdminModule.verification:
        return 'verification';
      case AdminModule.events:
        return 'events';
      case AdminModule.trainings:
        return 'trainings';
      case AdminModule.uid:
        return 'uid';
      case AdminModule.jobs:
        return 'jobs';
      case AdminModule.news:
        return 'news';
      case AdminModule.chat:
        return 'chat';
      case AdminModule.sos:
        return 'sos';
      case AdminModule.institutions:
        return 'institutions';
      case AdminModule.analytics:
        return 'analytics';
      case AdminModule.cybersecurity:
        return 'cybersecurity';
      case AdminModule.api:
        return 'api';
      case AdminModule.settings:
        return 'settings';
      case AdminModule.audit:
        return 'audit';
    }
  }

  static AdminModule fromSlug(String? slug) {
    final s = (slug ?? '').trim().toLowerCase();
    for (final m in AdminModule.values) {
      if (m.slug == s) return m;
    }
    return AdminModule.overview;
  }
}
