import 'package:equatable/equatable.dart';
import '../../../domain/entities/user_entity.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileUpdating extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final UserEntity user;
  final int matchCount;
  final int chatCount;

  const ProfileLoaded({
    required this.user,
    required this.matchCount,
    required this.chatCount,
  });

  @override
  List<Object?> get props => [user, matchCount, chatCount];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
