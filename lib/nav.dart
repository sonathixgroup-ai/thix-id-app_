import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/auth/auth_controller.dart';
import 'package:thix_id/models/app_user.dart';

// Import all screens
import 'presentation/home/home_page.dart';
import 'presentation/auth/login_page.dart';
import 'presentation/auth/personal_registration_page.dart';
import 'presentation/auth/enterprise_registration_page.dart';
import 'presentation/payment/payment_gateway_page.dart';
import 'presentation/payment/activation_receipt_page.dart';
import 'presentation/profile/public_profile_page.dart';
import 'presentation/dashboard/user_dashboard_page.dart';
import 'presentation/enterprise/enterprise_dashboard_page.dart';
import 'package:thix_id/presentation/enterprise/enterprise_portal_page.dart';
import 'package:thix_id/presentation/enterprise/enterprise_dashboard_shell_page.dart';
import 'presentation/chat/thix_chat_page.dart';
import 'presentation/vault/document_vault_page.dart';
import 'presentation/settings/settings_page.dart';
import 'presentation/network/network_page.dart';
import 'presentation/jobs/jobs_page.dart';
import 'package:thix_id/presentation/jobs/job_apply_page.dart';
import 'package:thix_id/presentation/jobs/job_details_page.dart';
import 'package:thix_id/presentation/jobs/job_dashboard_page.dart';
import 'package:thix_id/presentation/recruiter/recruiter_portal_page.dart';
import 'package:thix_id/presentation/opportunities/opportunities_page.dart';
import 'package:thix_id/presentation/opportunities/opportunity_apply_page.dart';
import 'package:thix_id/presentation/opportunities/opportunity_details_page.dart';
import 'presentation/events/events_page.dart';
import 'package:thix_id/presentation/events/event_details_page.dart';
import 'package:thix_id/presentation/events/event_register_page.dart';
import 'package:thix_id/presentation/events/event_ticket_page.dart';
import 'package:thix_id/presentation/events/user_event_dashboard_page.dart';
import 'presentation/education/education_page.dart';
import 'package:thix_id/presentation/training/training_home_page.dart';
import 'package:thix_id/presentation/training/training_details_page.dart';
import 'package:thix_id/presentation/training/learning_dashboard_page.dart';
import 'package:thix_id/presentation/training/lesson_player_page.dart';
import 'package:thix_id/presentation/admin/admin_page.dart';
import 'package:thix_id/presentation/admin/admin_routes.dart';

class AppRouter {
  /// Creates a [GoRouter] instance.
  ///
  /// Note: we accept an optional [extraRefreshListenable] so the router can
  /// refresh (and therefore rebuild route pages) when global app state changes
  /// that is not auth-related (e.g. runtime locale changes).
  static GoRouter create(AuthController auth, {Listenable? extraRefreshListenable}) {
    final refresh = extraRefreshListenable == null ? auth : Listenable.merge([auth, extraRefreshListenable]);
    return GoRouter(
      initialLocation: AppRoutes.home,
      refreshListenable: refresh,
      redirect: (context, state) {
        final location = state.matchedLocation;
        final isLoggedIn = auth.isAuthenticated;
        final isAuthPage = location == AppRoutes.login || location == AppRoutes.personalReg || location == AppRoutes.enterpriseReg;
        final isAdmin = location == AppRoutes.admin || location.startsWith('${AppRoutes.admin}/');
        final isEnterprisePortal = location.startsWith('${AppRoutes.enterprisePortalBasePath}/') || location == AppRoutes.enterprisePortalBasePath;
        final isPublic = location == AppRoutes.home ||
            location == AppRoutes.publicProfile ||
            location == AppRoutes.jobs ||
            location == AppRoutes.opportunities ||
            location == AppRoutes.events ||
            location == AppRoutes.education ||
            location == AppRoutes.trainingHome ||
            location.startsWith('${AppRoutes.trainingDetails}/');

        final isProtected = !isPublic && !isAuthPage;
        if (!isLoggedIn && isProtected) return AppRoutes.login;

        // Admin area: authenticated + RBAC role required.
        // NOTE: We also enforce this at UI level (AdminPage), but keeping a router
        // redirect avoids exposing admin shells to unauthorized sessions.
        if (isAdmin) {
          if (!isLoggedIn) return AppRoutes.login;
          // Best-effort synchronous guard: if role is not cached yet, UI will
          // show a protected screen. For hard security, rely on Supabase RLS.
          // We do not block navigation here with async calls.
        }

        // Payment-gated activation: block protected areas until UID is assigned.
        if (isLoggedIn) {
          final u = auth.currentUser;
          final isActivated = (u?.hasRealThixId ?? false);
          final hasActiveTrial = (u?.hasActiveTrial ?? false);
          final isPaymentOrReceipt = location == AppRoutes.payment || location == AppRoutes.activationReceipt;
          // Allow users to access their dashboard(s) before activation to review
          // their submitted information. Keep other protected areas gated.
          final isDashboard = location == AppRoutes.userDashboard || location == AppRoutes.enterpriseDashboard;
          if (!isActivated && !hasActiveTrial && !isAuthPage && !isPublic && !isPaymentOrReceipt && !isDashboard) {
            final receiptReturn = Uri.encodeComponent(AppRoutes.activationReceipt);
            return '${AppRoutes.payment}?returnTo=$receiptReturn';
          }
        }

        // Enforce strict separation between Personal and Enterprise spaces.
        if (isLoggedIn) {
          final t = auth.currentUser?.accountType;
          if (location == AppRoutes.userDashboard && t == AccountType.enterprise) return AppRoutes.enterpriseDashboard;
          if (location == AppRoutes.enterpriseDashboard && t == AccountType.personal) return AppRoutes.userDashboard;
        }

        if (isLoggedIn && isAuthPage) {
          final t = auth.currentUser?.accountType;
          return t == AccountType.enterprise ? AppRoutes.enterpriseDashboard : AppRoutes.userDashboard;
        }

        // Enterprise portal: allow unauthenticated access (verification portal flow).
        // Actual enforcement happens in pages with hard web+host guards + RBAC.
        if (isEnterprisePortal) return null;
        return null;
      },
      routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: HomePage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.personalReg,
        name: 'personalReg',
        pageBuilder: (context, state) {
          final stepStr = state.uri.queryParameters['step'];
          final step = int.tryParse(stepStr ?? '') ?? 1;
          return NoTransitionPage(child: PersonalRegistrationPage(initialStep: step));
        },
      ),
      GoRoute(
        path: AppRoutes.enterpriseReg,
        name: 'enterpriseReg',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: EnterpriseRegistrationPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.payment,
        name: 'payment',
        pageBuilder: (context, state) {
          final returnTo = state.uri.queryParameters['returnTo'];
          return NoTransitionPage(child: PaymentGatewayPage(returnTo: returnTo));
        },
      ),
      GoRoute(
        path: AppRoutes.activationReceipt,
        name: 'activationReceipt',
        pageBuilder: (context, state) {
          final qp = state.uri.queryParameters;
          final paidAt = DateTime.tryParse((qp['paidAt'] ?? '').trim());
          return NoTransitionPage(
            child: ActivationReceiptPage(
              txRef: qp['txRef'],
              method: qp['method'],
              amount: qp['amount'],
              currency: qp['currency'],
              paidAt: paidAt,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.publicProfile,
        name: 'publicProfile',
        pageBuilder: (context, state) => NoTransitionPage(
          child: PublicProfilePage(initialThixId: state.uri.queryParameters['thixId']),
        ),
      ),
      GoRoute(
        path: AppRoutes.userDashboard,
        name: 'userDashboard',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: UserDashboardPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.enterpriseDashboard,
        name: 'enterpriseDashboard',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: EnterpriseDashboardPage(),
        ),
      ),

      // Convenience entrypoint used by shared links.
      // Note: the public web verification portal uses /company/:slug.
      // /enterprise is meant to land authenticated users into their enterprise space.
      GoRoute(
        path: AppRoutes.enterprise,
        name: 'enterpriseEntry',
        redirect: (context, state) {
          final isLoggedIn = auth.isAuthenticated;
          if (!isLoggedIn) return AppRoutes.login;

          final t = auth.currentUser?.accountType;
          if (t == AccountType.enterprise) return AppRoutes.enterpriseDashboard;

          // If a personal account opens this link, send them to the web-only enterprise registration.
          return AppRoutes.enterpriseReg;
        },
      ),

      // ==============================================================
      // THIX ID Web Verification Portal (Enterprise entrypoint)
      // Example: https://verify.thixid.com/company/company-name
      // ==============================================================
      GoRoute(
        path: '/entreprise/:slug',
        name: 'enterprisePortalAliasFr',
        redirect: (context, state) {
          final slug = (state.pathParameters['slug'] ?? '').trim();
          return '${AppRoutes.enterprisePortalBase(slug)}/dashboard/overview';
        },
      ),
      GoRoute(
        path: '${AppRoutes.enterprisePortalBasePath}/:slug',
        name: 'enterprisePortal',
        pageBuilder: (context, state) {
          final slug = (state.pathParameters['slug'] ?? '').trim();
          return NoTransitionPage(child: EnterprisePortalPage(companySlug: slug));
        },
        routes: [
          GoRoute(
            path: 'dashboard/:section',
            name: 'enterprisePortalDashboard',
            pageBuilder: (context, state) {
              final slug = (state.pathParameters['slug'] ?? '').trim();
              final section = (state.pathParameters['section'] ?? 'overview').trim();
              return NoTransitionPage(child: EnterpriseDashboardShellPage(companySlug: slug, section: section));
            },
          ),
          GoRoute(
            path: 'dashboard',
            name: 'enterprisePortalDashboardRoot',
            redirect: (context, state) {
              final slug = (state.pathParameters['slug'] ?? '').trim();
              return '${AppRoutes.enterprisePortalBase(slug)}/dashboard/overview';
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.chat,
        name: 'chat',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: ThixChatPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.vault,
        name: 'vault',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: DocumentVaultPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: SettingsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.network,
        name: 'network',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: NetworkPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.jobs,
        name: 'jobs',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: JobsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.jobDashboard,
        name: 'jobDashboard',
        pageBuilder: (context, state) => const NoTransitionPage(child: JobDashboardPage()),
      ),
      GoRoute(
        path: AppRoutes.recruiter,
        name: 'recruiter',
        pageBuilder: (context, state) => const NoTransitionPage(child: RecruiterPortalPage()),
      ),
      GoRoute(
        path: AppRoutes.opportunities,
        name: 'opportunities',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: OpportunitiesPage(),
        ),
      ),
      GoRoute(
        path: '/opportunities/:opportunityId',
        name: 'opportunityDetails',
        pageBuilder: (context, state) {
          final opportunityId = state.pathParameters['opportunityId'] ?? '';
          final applied = (state.uri.queryParameters['applied'] ?? '').trim() == '1';
          return NoTransitionPage(child: OpportunityDetailsPage(opportunityId: opportunityId, applied: applied));
        },
      ),
      GoRoute(
        path: '/opportunities/:opportunityId/apply',
        name: 'opportunityApply',
        pageBuilder: (context, state) {
          final opportunityId = state.pathParameters['opportunityId'] ?? '';
          return NoTransitionPage(child: OpportunityApplyPage(opportunityId: opportunityId));
        },
      ),
      GoRoute(
        path: '/jobs/:jobId',
        name: 'jobDetails',
        pageBuilder: (context, state) {
          final jobId = state.pathParameters['jobId'] ?? '';
          final applied = (state.uri.queryParameters['applied'] ?? '').trim() == '1';
          return NoTransitionPage(child: JobDetailsPage(jobId: jobId, applied: applied));
        },
      ),
      GoRoute(
        path: '/jobs/:jobId/apply',
        name: 'jobApply',
        pageBuilder: (context, state) {
          final jobId = state.pathParameters['jobId'] ?? '';
          return NoTransitionPage(child: JobApplyPage(jobId: jobId));
        },
      ),
      GoRoute(
        path: AppRoutes.events,
        name: 'events',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: EventsPage(),
        ),
      ),
      GoRoute(
        path: '/events/:eventId',
        name: 'eventDetails',
        pageBuilder: (context, state) {
          final eventId = state.pathParameters['eventId'] ?? '';
          final registered = (state.uri.queryParameters['registered'] ?? '').trim() == '1';
          return NoTransitionPage(child: EventDetailsPage(eventId: eventId, registered: registered));
        },
      ),
      GoRoute(
        path: '/events/:eventId/register',
        name: 'eventRegister',
        pageBuilder: (context, state) {
          final eventId = state.pathParameters['eventId'] ?? '';
          return NoTransitionPage(child: EventRegisterPage(eventId: eventId));
        },
      ),
      GoRoute(
        path: '/events/:eventId/ticket/:registrationId',
        name: 'eventTicket',
        pageBuilder: (context, state) {
          final eventId = state.pathParameters['eventId'] ?? '';
          final registrationId = state.pathParameters['registrationId'] ?? '';
          return NoTransitionPage(child: EventTicketPage(eventId: eventId, registrationId: registrationId));
        },
      ),
      GoRoute(
        path: '/events/me',
        name: 'userEventsDashboard',
        pageBuilder: (context, state) => const NoTransitionPage(child: UserEventDashboardPage()),
      ),
      GoRoute(
        path: AppRoutes.education,
        name: 'education',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: EducationPage(),
        ),
      ),

      // Ultra-premium THIX Learning ecosystem
      GoRoute(
        path: AppRoutes.trainingHome,
        name: 'trainingHome',
        pageBuilder: (context, state) => const NoTransitionPage(child: TrainingHomePage()),
      ),
      GoRoute(
        path: '${AppRoutes.trainingDetails}/:trainingId',
        name: 'trainingDetails',
        pageBuilder: (context, state) {
          final id = state.pathParameters['trainingId'] ?? '';
          return NoTransitionPage(child: TrainingDetailsPage(trainingId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.learningDashboard,
        name: 'learningDashboard',
        pageBuilder: (context, state) => const NoTransitionPage(child: LearningDashboardPage()),
      ),
      GoRoute(
        path: '${AppRoutes.lessonPlayer}/:enrollmentId',
        name: 'lessonPlayer',
        pageBuilder: (context, state) {
          final id = state.pathParameters['enrollmentId'] ?? '';
          return NoTransitionPage(child: LessonPlayerPage(enrollmentId: id));
        },
      ),

       // Admin web portal (RBAC enforced at page + RLS at DB).
       GoRoute(
         path: '${AppRoutes.admin}/:module',
         name: 'admin',
         pageBuilder: (context, state) {
           final module = AdminModuleX.fromSlug(state.pathParameters['module']);
           return NoTransitionPage(child: AdminPage(module: module));
         },
       ),
       GoRoute(
         path: AppRoutes.admin,
         name: 'adminRoot',
         redirect: (_, __) => '${AppRoutes.admin}/${AdminModule.overview.slug}',
       ),
      ],
    );
  }

}

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String personalReg = '/personal-reg';
  static const String enterpriseReg = '/enterprise-reg';
  static const String enterprise = '/enterprise';
  static const String payment = '/payment';
  static const String activationReceipt = '/activation-receipt';
  static const String publicProfile = '/public-profile';
  static const String userDashboard = '/user-dashboard';
  static const String enterpriseDashboard = '/enterprise-dashboard';
  static const String enterprisePortalBasePath = '/company';
  static String enterprisePortalBase(String slug) => '${enterprisePortalBasePath}/$slug';
  static String enterprisePortalDashboard(String slug, String section) => '/company/$slug/dashboard/$section';
  static const String chat = '/chat';
  static const String vault = '/vault';
  static const String settings = '/settings';
  static const String network = '/network';
  static const String jobs = '/jobs';
  static const String jobDashboard = '/jobs/dashboard';
  static const String recruiter = '/recruiter';
  static const String opportunities = '/opportunities';
  static const String events = '/events';
  static const String education = '/education';
  static const String trainingHome = '/training';
  static const String trainingDetails = '/training';
  static const String learningDashboard = '/learn';
  static const String lessonPlayer = '/learn/player';
  static const String admin = '/admin';
}

extension GoRouterBackHelpers on BuildContext {
  /// Pops if possible; otherwise navigates to [fallbackLocation].
  void popOrGo(String fallbackLocation) {
    final router = GoRouter.of(this);
    if (router.canPop()) {
      pop();
      return;
    }
    go(fallbackLocation);
  }
}
