import 'package:moamen_project/core/error/failure.dart';

class SettingState {
  final bool isLoading;
  final Failure? failureInMainScreen;
  final bool isSuccess;
  final Failure? failureInEditScreen;
  final bool isUpdateBottonEnabled;

  const SettingState({
    this.isLoading = false,
    this.failureInMainScreen,
    this.isSuccess = false,
    this.failureInEditScreen,
    this.isUpdateBottonEnabled = false,
  });

  SettingState copyWith({
    bool? isLoading,
    Failure? failureInMainScreen,
    bool? isSuccess,
    Failure? failureInEditScreen,
    bool? isUpdateBottonEnabled,
  }) {
    return SettingState(
      isLoading: isLoading ?? this.isLoading,
      failureInMainScreen: failureInMainScreen ?? this.failureInMainScreen,
      isSuccess: isSuccess ?? this.isSuccess,
      failureInEditScreen: failureInEditScreen ?? this.failureInEditScreen,
      isUpdateBottonEnabled:
          isUpdateBottonEnabled ?? this.isUpdateBottonEnabled,
    );
  }
}

// class settingModel {
//   final bool isDark;
//   final bool isLocalMap;
//   final bool 
// }
