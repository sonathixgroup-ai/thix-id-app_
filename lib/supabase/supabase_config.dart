import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  /// Supabase credentials.
  ///
  /// Dreamflow typically injects these at build/runtime. We keep project defaults
  /// as fallback, but allow secure overrides via `--dart-define`.
  static const String supabaseUrl = String.fromEnvironment('', defaultValue: 'https://kfzkxaadtbapqwxcegly.supabase.co');
  static const String anonKey = String.fromEnvironment(
    '',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtmemt4YWFkdGJhcHF3eGNlZ2x5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxNTQ4NDQsImV4cCI6MjA5MTczMDg0NH0.7JWalFAF9XaHTHqypt-bMokd2B3sU9Rm6X3YkVm3BTE',
  );

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (supabaseUrl.trim().isEmpty || anonKey.trim().isEmpty) {
        throw Exception('Missing  or ');
      }
      debugPrint('SupabaseConfig: initializing url=$supabaseUrl');
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: anonKey,
        debug: kDebugMode,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
      rethrow;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;

  /// Convenience: current authenticated user (or null)
  static User? get currentUser => auth.currentUser;

  /// Convenience: auth state changes.
  static Stream<AuthState> get onAuthStateChange => auth.onAuthStateChange;
}

/// Generic database service for CRUD operations
class SupabaseService {
  /// Select multiple records from a table
  static Future<List<Map<String, dynamic>>> select(
    String table, {
    String? select,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).select(select ?? '*');

      // Apply filters
      if (filters != null) {
        for (final entry in filters.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }

      // Apply ordering
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      final res = await query;
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      throw _handleDatabaseError('select', table, e);
    }
  }

  /// Select a single record from a table
  static Future<Map<String, dynamic>?> selectSingle(
    String table, {
    String? select,
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).select(select ?? '*');

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      return await query.maybeSingle();
    } catch (e) {
      throw _handleDatabaseError('selectSingle', table, e);
    }
  }

  /// Insert a record into a table
  static Future<List<Map<String, dynamic>>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await SupabaseConfig.client.from(table).insert(data).select();
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      throw _handleDatabaseError('insert', table, e);
    }
  }

  /// Insert multiple records into a table
  static Future<List<Map<String, dynamic>>> insertMultiple(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      final res = await SupabaseConfig.client.from(table).insert(data).select();
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      throw _handleDatabaseError('insertMultiple', table, e);
    }
  }

  /// Update records in a table
  static Future<List<Map<String, dynamic>>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).update(data);

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      final res = await query.select();
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      throw _handleDatabaseError('update', table, e);
    }
  }

  /// Delete records from a table
  static Future<void> delete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).delete();

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      await query;
    } catch (e) {
      throw _handleDatabaseError('delete', table, e);
    }
  }

  /// Get direct table reference for complex queries
  static SupabaseQueryBuilder from(String table) =>
      SupabaseConfig.client.from(table);

  /// Handle database errors
  static Exception _handleDatabaseError(
    String operation,
    String table,
    dynamic error,
  ) {
    if (error is PostgrestException) {
      return Exception('Failed to $operation on $table: ${error.message}');
    }
    return Exception('Failed to $operation on $table: ${error.toString()}');
  }
}
