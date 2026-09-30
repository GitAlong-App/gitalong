import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class SignInWithGitHubEvent extends AuthEvent {}

class SignInWithGoogleEvent extends AuthEvent {}

class SignInWithAppleEvent extends AuthEvent {}

class SignOutEvent extends AuthEvent {}

class DeleteAccountEvent extends AuthEvent {}

/// The Supabase session ended outside the app's control (signed out
/// elsewhere, refresh token revoked/expired, user deleted).
class AuthSessionEndedEvent extends AuthEvent {}
