// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:google_sign_in/google_sign_in.dart' as _i116;
import 'package:injectable/injectable.dart' as _i526;
import 'package:supabase_flutter/supabase_flutter.dart' as _i454;

import '../../data/repositories/auth_repository_impl.dart' as _i895;
import '../../data/repositories/chat_repository_impl.dart' as _i838;
import '../../data/repositories/match_repository_impl.dart' as _i395;
import '../../data/repositories/notification_repository_impl.dart' as _i9998;
import '../../data/repositories/progress_repository_impl.dart' as _i9996;
import '../../data/repositories/swipe_repository_impl.dart' as _i1047;
import '../../data/repositories/user_repository_impl.dart' as _i790;
import '../../data/services/backend_api_client.dart' as _i1031;
import '../../domain/repositories/auth_repository.dart' as _i1073;
import '../../domain/repositories/chat_repository.dart' as _i1072;
import '../../domain/repositories/match_repository.dart' as _i568;
import '../../domain/repositories/notification_repository.dart' as _i9999;
import '../../domain/repositories/progress_repository.dart' as _i9997;
import '../../domain/repositories/swipe_repository.dart' as _i280;
import '../../domain/repositories/user_repository.dart' as _i271;
import '../../domain/usecases/auth/delete_account_usecase.dart' as _i778;
import '../../domain/usecases/auth/get_current_user_usecase.dart' as _i408;
import '../../domain/usecases/auth/sign_in_with_apple_usecase.dart' as _i792;
import '../../domain/usecases/auth/sign_in_with_github_usecase.dart' as _i959;
import '../../domain/usecases/auth/sign_in_with_google_usecase.dart' as _i474;
import '../../domain/usecases/auth/sign_out_usecase.dart' as _i1014;
import '../../domain/usecases/chat/get_messages_usecase.dart' as _i105;
import '../../domain/usecases/chat/send_message_usecase.dart' as _i188;
import '../../domain/usecases/match/get_matches_usecase.dart' as _i229;
import '../../domain/usecases/swipe/swipe_user_usecase.dart' as _i796;
import '../../domain/usecases/user/get_recommended_users_usecase.dart' as _i850;
import '../../domain/usecases/user/update_user_profile_usecase.dart' as _i688;
import '../../presentation/bloc/auth/auth_bloc.dart' as _i605;
import '../../presentation/bloc/chat/chat_bloc.dart' as _i573;
import '../../presentation/bloc/discover/discover_bloc.dart' as _i600;
import '../../presentation/bloc/matches/matches_bloc.dart' as _i556;
import '../../presentation/bloc/profile/profile_bloc.dart' as _i636;
import '../../presentation/bloc/progress/progress_cubit.dart' as _i9995;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    gh.lazySingleton<_i1072.ChatRepository>(
      () => _i838.ChatRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i9999.NotificationRepository>(
      () => _i9998.NotificationRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i9997.ProgressRepository>(
      () => _i9996.ProgressRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i280.SwipeRepository>(
      () => _i1047.SwipeRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i1031.BackendApiClient>(
      () => _i1031.BackendApiClient(gh<_i454.SupabaseClient>()),
    );
    gh.factory<_i105.GetMessagesUseCase>(
      () => _i105.GetMessagesUseCase(gh<_i1072.ChatRepository>()),
    );
    gh.factory<_i188.SendMessageUseCase>(
      () => _i188.SendMessageUseCase(gh<_i1072.ChatRepository>()),
    );
    gh.factory<_i573.ChatBloc>(
      () => _i573.ChatBloc(gh<_i1072.ChatRepository>()),
    );
    gh.lazySingleton<_i9995.ProgressCubit>(
      () => _i9995.ProgressCubit(gh<_i9997.ProgressRepository>()),
    );
    gh.lazySingleton<_i568.MatchRepository>(
      () => _i395.MatchRepositoryImpl(gh<_i454.SupabaseClient>()),
    );
    gh.lazySingleton<_i1073.AuthRepository>(
      () => _i895.AuthRepositoryImpl(
        gh<_i454.SupabaseClient>(),
        gh<_i116.GoogleSignIn>(),
        gh<_i1031.BackendApiClient>(),
      ),
    );
    gh.factory<_i796.SwipeUserUseCase>(
      () => _i796.SwipeUserUseCase(gh<_i280.SwipeRepository>()),
    );
    gh.lazySingleton<_i271.UserRepository>(
      () => _i790.UserRepositoryImpl(
        gh<_i454.SupabaseClient>(),
        gh<_i1031.BackendApiClient>(),
      ),
    );
    gh.factory<_i408.GetCurrentUserUseCase>(
      () => _i408.GetCurrentUserUseCase(gh<_i1073.AuthRepository>()),
    );
    gh.factory<_i959.SignInWithGitHubUseCase>(
      () => _i959.SignInWithGitHubUseCase(gh<_i1073.AuthRepository>()),
    );
    gh.factory<_i1014.SignOutUseCase>(
      () => _i1014.SignOutUseCase(gh<_i1073.AuthRepository>()),
    );
    gh.lazySingleton<_i778.DeleteAccountUseCase>(
      () => _i778.DeleteAccountUseCase(gh<_i1073.AuthRepository>()),
    );
    gh.factory<_i792.SignInWithAppleUseCase>(
      () => _i792.SignInWithAppleUseCase(gh<_i1073.AuthRepository>()),
    );
    gh.factory<_i474.SignInWithGoogleUseCase>(
      () => _i474.SignInWithGoogleUseCase(gh<_i1073.AuthRepository>()),
    );
    gh.factory<_i850.GetRecommendedUsersUseCase>(
      () => _i850.GetRecommendedUsersUseCase(gh<_i271.UserRepository>()),
    );
    gh.factory<_i688.UpdateUserProfileUseCase>(
      () => _i688.UpdateUserProfileUseCase(gh<_i271.UserRepository>()),
    );
    gh.factory<_i229.GetMatchesUseCase>(
      () => _i229.GetMatchesUseCase(gh<_i568.MatchRepository>()),
    );
    gh.factory<_i600.DiscoverBloc>(
      () => _i600.DiscoverBloc(
        gh<_i850.GetRecommendedUsersUseCase>(),
        gh<_i796.SwipeUserUseCase>(),
        gh<_i568.MatchRepository>(),
      ),
    );
    gh.factory<_i636.ProfileBloc>(
      () => _i636.ProfileBloc(
        gh<_i408.GetCurrentUserUseCase>(),
        gh<_i229.GetMatchesUseCase>(),
        gh<_i688.UpdateUserProfileUseCase>(),
        gh<_i1031.BackendApiClient>(),
      ),
    );
    gh.factory<_i556.MatchesBloc>(
      () => _i556.MatchesBloc(gh<_i229.GetMatchesUseCase>()),
    );
    gh.lazySingleton<_i605.AuthBloc>(
      () => _i605.AuthBloc(
        gh<_i408.GetCurrentUserUseCase>(),
        gh<_i959.SignInWithGitHubUseCase>(),
        gh<_i474.SignInWithGoogleUseCase>(),
        gh<_i792.SignInWithAppleUseCase>(),
        gh<_i1014.SignOutUseCase>(),
        gh<_i778.DeleteAccountUseCase>(),
      ),
    );
    return this;
  }
}
