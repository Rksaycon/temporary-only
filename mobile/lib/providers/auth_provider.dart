import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import 'package:may_laud/core/local_storage.dart';
import 'package:may_laud/services/supabase_service.dart';
import 'package:may_laud/services/push_notification_service.dart';
import 'package:may_laud/providers/content_providers.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? profileImage;
  final String? address;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.profileImage,
    this.address,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id:           json['id'] ?? '',
      name:         json['name'] ?? '',
      email:        json['email'] ?? '',
      phone:        json['phone'],
      profileImage: json['avatar_url'],
      address:      json['address'],
      createdAt:    json['created_at'] != null
                      ? DateTime.parse(json['created_at'])
                      : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':         id,
    'name':       name,
    'email':      email,
    'phone':      phone,
    'avatar_url': profileImage,
    'address':    address,
    'created_at': createdAt?.toIso8601String(),
  };
}

const _unset = Object();

class AuthState {
  final bool isLoading;
  final User? user;
  final String? error;
  final bool isAuthenticated;
  final bool isGuest;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.error,
    this.isAuthenticated = false,
    this.isGuest = false,
  });

  AuthState copyWith({
    bool? isLoading,
    Object? user = _unset,
    Object? error = _unset,
    bool? isAuthenticated,
    bool? isGuest,
  }) {
    return AuthState(
      isLoading:       isLoading       ?? this.isLoading,
      user:            user  == _unset ? this.user  : user  as User?,
      error:           error == _unset ? this.error : error as String?,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isGuest:         isGuest         ?? this.isGuest,
    );
  }
}

class AuthProvider extends StateNotifier<AuthState> {
  AuthProvider(this._ref) : super(const AuthState()) {
    _checkAuthStatus();
  }

  final Ref _ref;

  SupabaseClient get _client => SupabaseService.client;

  // FIX — notificationsProvider/announcementsProvider are global providers
  // that stay alive (and keep their in-memory `state`) for the whole app
  // session. Without this, switching accounts on the same device without
  // a full app restart (log out as A, log in as B) left B looking at A's
  // last-fetched notification list until something happened to trigger a
  // manual refetch — the two accounts appeared to "share" notifications
  // even though the backend query itself was correctly scoped by user_id.
  // Invalidating here disposes that stale state and forces the provider's
  // constructor (and its fetchNotifications() call) to run again fresh,
  // scoped to whichever uid is signed in at that moment.
  void _resetPerUserProviders() {
    _ref.invalidate(notificationsProvider);
    _ref.invalidate(announcementsProvider);
    _ref.invalidate(documentRequestsProvider);
  }

  Future<void> _checkAuthStatus() async {
    try {
      final session = _client.auth.currentSession;
      if (session != null) {
        await _loadProfile(session.user.id, session.user.email ?? '');
      }
    } catch (e) {
      debugPrint('[AuthProvider] _checkAuthStatus skipped: $e');
    }
  }

  Future<void> _loadProfile(String uid, String email) async {
    try {
      // .limit(1) instead of .single() so a missing row comes back as an
      // empty list instead of throwing — we want to handle that case
      // ourselves below, not fall into the catch-all.
      final rows =
          await _client.from('profiles').select().eq('id', uid).limit(1);
      var data = rows.isEmpty ? null : rows.first;

      if (data == null) {
        // FIX — register() intentionally leaves `profiles` empty until
        // completeRegistration() runs after OTP verification (RLS blocks
        // writing it any earlier — see register()'s comment). If that OTP
        // step never finished (user closed the app, never got the code,
        // the "Confirm signup" email template doesn't send a token, etc.),
        // signing in later used to hit this exact case, throw out of
        // .single(), and get swallowed by the catch below with zero
        // feedback — the login button just stopped spinning and nothing
        // happened, as if the tap did nothing at all. We already have a
        // valid authenticated session at this point (signInWithPassword
        // / session restore just succeeded), so RLS now allows us to
        // create our own row — self-heal instead of leaving the resident
        // stuck.
        final metadata = _client.auth.currentUser?.userMetadata ?? {};
        await _client.from('profiles').upsert({
          'id':    uid,
          'name':  metadata['name'] ?? '',
          'email': email,
          'phone': metadata['phone'],
        });
        data = await _client.from('profiles').select().eq('id', uid).single();
      }

      // Enforce mobile-resident-only access: if this profile's role is
      // 'admin' (a web-registered account, per AuthContext.jsx's own
      // symmetric check on the admin panel), it doesn't belong here — kick
      // it straight back out instead of letting it in as a resident.
      if (data['role'] == 'admin') {
        await _client.auth.signOut();
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
          error:
              'This is an Admin account. Please use the Maylaud web portal to log in.',
        );
        return;
      }

      final user = User.fromJson({...data, 'email': email});
      state = state.copyWith(
          user: user, isAuthenticated: true, isLoading: false, error: null);

      // Fresh sign-in or session restore — make sure notifications /
      // announcements reflect THIS uid, not whatever was left over from
      // a previous account in this same app session.
      _resetPerUserProviders();

      await LocalStorage.saveUserData(
        userId:    user.id,
        userName:  user.name,
        userEmail: user.email,
      );

      // Register this device's FCM token against the now-known profile
      // so pushes (announcements, doc-request status changes, etc.) can
      // be targeted at it. Covers both a fresh login and session restore
      // on cold start.
      //
      // FIX — `PushNotificationService.instance` eagerly reads
      // `FirebaseMessaging.instance` the moment it's first constructed,
      // which throws *synchronously* wherever Firebase was never
      // initialized (e.g. this app's Firebase project isn't configured
      // for web yet — see the same guard in main.dart's initState).
      // unawaited() only discards the returned Future; it does nothing
      // for a throw that happens before syncTokenWithSupabase() ever
      // returns one, on the `.instance` access itself. Unguarded, that
      // exception landed in *this* try block — after login had already
      // succeeded above — and got caught below, silently flipping
      // isAuthenticated back to false. Every login was failing for this
      // reason on web, with nothing wrong in the credentials at all.
      try {
        unawaited(PushNotificationService.instance.syncTokenWithSupabase());
      } catch (e) {
        debugPrint('[AuthProvider] Push token sync skipped: $e');
      }
    } catch (e) {
      debugPrint('[AuthProvider] _loadProfile failed: $e');
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        // FIX — previously left null here, so a failure at this stage
        // (this self-heal upsert included) showed the resident nothing:
        // the login screen just sat there as if the button hadn't been
        // tapped. _checkAuthStatus() also calls this on cold start before
        // any UI is listening for it, so keep this message generic rather
        // than assuming a login is in progress.
        error: 'Could not load your profile. Please try again.',
      );
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.auth.signInWithPassword(
        email:    email,
        password: password,
      );
      if (response.user != null) {
        await _loadProfile(response.user!.id, email);
      }
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Login failed. Please try again.');
    }
  }

  /// Returns true on success, false on failure.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String address,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.auth.signUp(
        email:    email,
        password: password,
        data: {'name': name, 'phone': phone},
        emailRedirectTo: null,
      );

      if (response.user != null) {
        final uid = response.user!.id;

        // Attempt to save profile now. This may fail if Supabase RLS blocks
        // writes for unconfirmed users — we catch it silently so it never
        // prevents navigating to OTP. Profile will be saved after OTP.
        try {
          await _client.from('profiles').upsert({
            'id':      uid,
            'name':    name,
            'email':   email,
            'phone':   phone,
            'address': address,
          });
        } catch (upsertErr) {
          debugPrint('[AuthProvider] profiles upsert skipped (will retry after OTP): $upsertErr');
        }

        await LocalStorage.saveUserData(
          userId:    uid,
          userName:  name,
          userEmail: email,
        );

        // Auth user was created — go to OTP
        state = state.copyWith(isLoading: false, error: null);
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Registration failed. Please try again.',
        );
        return false;
      }
    } on AuthException catch (e) {
      debugPrint('[AuthProvider] register AuthException: ${e.message}');
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      debugPrint('[AuthProvider] register unexpected error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Registration failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> completeRegistration({
    required String name,
    required String phone,
    required String address,
  }) async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    try {
      // FIX — this used to be .update(...), which only touches a row that
      // already exists. register()'s earlier upsert attempt is *expected*
      // to fail at that point (no confirmed session yet, so RLS blocks it
      // — see the comment there), and nothing else ever creates the row.
      // So on every single registration, this .update() was silently
      // updating zero rows — no profile ever got created, and the
      // resident could never log in afterward (_loadProfile() found
      // nothing to load). .upsert() creates the row here instead, now
      // that OTP verification means there's a real authenticated session.
      await _client.from('profiles').upsert({
        'id':      uid,
        'name':    name,
        'phone':   phone,
        'address': address,
        'email':   _client.auth.currentUser?.email,
      });
      // First time this brand-new profile row is guaranteed to exist —
      // safe point to attach this device's push token to it.
      unawaited(PushNotificationService.instance.syncTokenWithSupabase());
    } catch (_) {}
  }

  Future<void> loginAsGuest() async {
    state = state.copyWith(isLoading: true, error: null);
    await Future.delayed(const Duration(milliseconds: 400));
    await LocalStorage.clearAll();
    state = state.copyWith(
      isLoading: false,
      user: User(
        id:    'guest_${DateTime.now().millisecondsSinceEpoch}',
        name:  'Guest User',
        email: '',
      ),
      isAuthenticated: true,
      isGuest: true,
    );
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    if (!state.isGuest) {
      // Detach this device's push token from the profile *before*
      // signing out — clearTokenOnLogout needs the still-valid session
      // to know whose profile row to update.
      //
      // FIX — same gap as the syncTokenWithSupabase() call above:
      // `PushNotificationService.instance` throws synchronously on
      // first access wherever Firebase isn't initialized (e.g. web).
      // Unguarded, that took down the entire logout — signOut() and
      // the state reset below never ran, so tapping "Log out" just
      // left the app stuck on a loading spinner forever.
      try {
        await PushNotificationService.instance.clearTokenOnLogout();
      } catch (e) {
        debugPrint('[AuthProvider] Push token clear skipped: $e');
      }
      // FIX — signOut() was unguarded too: if it throws (offline,
      // Supabase never finished initializing, etc.) the exception
      // propagated out of logout() entirely, so LocalStorage.clearAll()
      // and the final state reset below never ran. From the resident's
      // point of view, "Log out" should always clear their session on
      // this device even if the network round-trip to Supabase fails.
      try {
        await _client.auth.signOut();
      } catch (e) {
        debugPrint('[AuthProvider] Supabase signOut skipped: $e');
      }
    }
    await LocalStorage.clearAll();
    // Drop the outgoing user's cached notifications/announcements state so
    // whoever logs in next (or the guest/login screen in between) never
    // sees a flash of the previous account's data.
    _resetPerUserProviders();
    state = const AuthState(isLoading: false);
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? address,
    String? profileImage,
  }) async {
    if (state.user == null || state.isGuest) return;

    final updates = <String, dynamic>{};
    if (name         != null) updates['name']       = name;
    if (phone        != null) updates['phone']      = phone;
    if (address      != null) updates['address']    = address;
    if (profileImage != null) updates['avatar_url'] = profileImage;

    await _client.from('profiles').update(updates).eq('id', state.user!.id);

    final updated = User(
      id:           state.user!.id,
      name:         name         ?? state.user!.name,
      email:        state.user!.email,
      phone:        phone        ?? state.user!.phone,
      address:      address      ?? state.user!.address,
      profileImage: profileImage ?? state.user!.profileImage,
      createdAt:    state.user!.createdAt,
    );

    await LocalStorage.saveUserData(
      userId:    updated.id,
      userName:  updated.name,
      userEmail: updated.email,
    );

    state = state.copyWith(user: updated);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  void clearError() => state = state.copyWith(error: null);
}

final authProvider = StateNotifierProvider<AuthProvider, AuthState>(
  (ref) => AuthProvider(ref),
);