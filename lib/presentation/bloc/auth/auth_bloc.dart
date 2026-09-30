import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../core/utils/logger.dart';
import '../../../domain/usecases/auth/get_current_user_usecase.dart';
import '../../../domain/usecases/auth/sign_in_with_github_usecase.dart';
import '../../../domain/usecases/auth/sign_in_with_google_usecase.dart';
import '../../../domain/usecases/auth/sign_in_with_apple_usecase.dart';
import '../../../domain/usecases/auth/sign_out_usecase.dart';
import '../../../domain/usecases/auth/delete_account_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

@lazySingleton
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final SignInWithGitHubUseCase _signInWithGitHubUseCase;
  final SignInWithGoogleUseCase _signInWithGoogleUseCase;
  final SignInWithAppleUseCase _signInWithAppleUseCase;
  final SignOutUseCase _signOutUseCase;
  final DeleteAccountUseCase _deleteAccountUseCase;

  StreamSubscription<dynamic>? _authSubscription;

  AuthBloc(
    this._getCurrentUserUseCase,
    this._signInWithGitHubUseCase,
    this._signInWithGoogleUseCase,
    this._signInWithAppleUseCase,
    this._signOutUseCase,
    this._deleteAccountUseCase,
  ) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<SignInWithGitHubEvent>(_onSignInWithGitHub);
    on<SignInWithGoogleEvent>(_onSignInWithGoogle);
    on<SignInWithAppleEvent>(_onSignInWithApple);
    on<SignOutEvent>(_onSignOut);
    on<DeleteAccountEvent>(_onDeleteAccount);
    on<AuthSessionEndedEvent>(_onSessionEnded);

    // Follow the Supabase session: OAuth deep-link callbacks sign the user
    // in, and a revoked/expired session or deleted user must sign them out
    // (otherwise the app keeps showing a "logged in" user with no session).
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        add(AuthCheckRequested());
      } else if (event == AuthChangeEvent.signedOut ||
          // `userDeleted` is deprecated in gotrue; compare by name so this
          // compiles whether or not the enum value still exists.
          event.name == 'userDeleted') {
        add(AuthSessionEndedEvent());
      }
    }, onError: (Object error, StackTrace stackTrace) {
      AppLogger.w('Auth state stream error', error, stackTrace);
    });
  }

  Future<void> _onAuthCheckRequested(
      AuthCheckRequested event, Emitter<AuthState> emit) async {
    try {
      final user = await _getCurrentUserUseCase.call();
      // The session may have ended (sign-out) while the profile was loading.
      if (user != null && Supabase.instance.client.auth.currentUser != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e, stackTrace) {
      AppLogger.w('Auth check failed', e, stackTrace);
      // A failed re-check (e.g. right after saving the profile) must not
      // throw a signed-in user out of the app.
      if (state is AuthAuthenticated &&
          Supabase.instance.client.auth.currentUser != null) {
        return;
      }
      emit(const AuthError(
        "Couldn't load your profile. Check your connection and try again.",
      ));
      emit(AuthUnauthenticated());
    }
  }

  void _onSessionEnded(AuthSessionEndedEvent event, Emitter<AuthState> emit) {
    emit(AuthUnauthenticated());
  }

  Future<void> _onSignInWithGitHub(
      SignInWithGitHubEvent event, Emitter<AuthState> emit) async {
    // The browser launch is external. We don't block or emit AuthAuthenticated here.
    // The stream listener for onAuthStateChange handles exactly when we are signed in.
    try {
      await _signInWithGitHubUseCase.call();
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSignOut(SignOutEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _signOutUseCase.call();
      emit(AuthUnauthenticated());
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSignInWithGoogle(
      SignInWithGoogleEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _signInWithGoogleUseCase.call();
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSignInWithApple(
      SignInWithAppleEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _signInWithAppleUseCase.call();
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onDeleteAccount(
      DeleteAccountEvent event, Emitter<AuthState> emit) async {
    final previous = state;
    emit(AuthLoading());
    try {
      await _deleteAccountUseCase.call();
      emit(AuthUnauthenticated());
    } catch (e, stackTrace) {
      AppLogger.e('Account deletion failed', e, stackTrace);
      emit(const AuthError(
        "We couldn't delete your account. Check your connection and try again.",
      ));
      // Nothing was deleted (or we can't tell): stay signed in.
      if (previous is AuthAuthenticated &&
          Supabase.instance.client.auth.currentUser != null) {
        emit(previous);
        return;
      }
      try {
        final user = await _getCurrentUserUseCase.call();
        emit(user != null ? AuthAuthenticated(user) : AuthUnauthenticated());
      } catch (_) {
        emit(AuthUnauthenticated());
      }
    }
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    return super.close();
  }
}
