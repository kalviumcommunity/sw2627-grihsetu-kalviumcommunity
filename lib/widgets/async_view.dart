import 'package:flutter/material.dart';

import '../services/errors/app_failure.dart';
import '../services/errors/firebase_error_mapper.dart';
import '../services/errors/run_guarded.dart';
import 'error_state.dart';
import 'skeleton_box.dart';

/// Renders asynchronous state: skeleton while loading, [ErrorState] with retry
/// on failure, optional empty view, and data view on success.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    this.state,
    this.isLoading = false,
    this.data,
    this.error,
    required this.builder,
    this.skeletonBuilder,
    this.emptyBuilder,
    this.isEmpty,
    this.errorBuilder,
    this.onRetry,
    this.isRetrying = false,
  });

  /// Factory directly accepting a [Loadable] state.
  factory AsyncView.fromLoadable({
    Key? key,
    required Loadable<T> state,
    required Widget Function(BuildContext context, T data) builder,
    Widget Function(BuildContext context)? skeletonBuilder,
    Widget Function(BuildContext context)? emptyBuilder,
    bool Function(T data)? isEmpty,
    Widget Function(BuildContext context, AppFailure failure)? errorBuilder,
    VoidCallback? onRetry,
    bool isRetrying = false,
  }) {
    return AsyncView<T>(
      key: key,
      state: state,
      builder: builder,
      skeletonBuilder: skeletonBuilder,
      emptyBuilder: emptyBuilder,
      isEmpty: isEmpty,
      errorBuilder: errorBuilder,
      onRetry: onRetry,
      isRetrying: isRetrying,
    );
  }

  final Loadable<T>? state;
  final bool isLoading;
  final T? data;
  final Object? error;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? skeletonBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final bool Function(T data)? isEmpty;
  final Widget Function(BuildContext context, AppFailure failure)? errorBuilder;
  final VoidCallback? onRetry;
  final bool isRetrying;

  @override
  Widget build(BuildContext context) {
    if (state != null) {
      return state!.when(
        loading: () => _buildLoading(context),
        error: (failure) => _buildError(context, failure),
        data: (d) => _buildData(context, d),
      );
    }

    if (isLoading) {
      return _buildLoading(context);
    }

    if (error != null) {
      final failure = error is AppFailure
          ? error! as AppFailure
          : FirebaseErrorMapper.map(error!);
      return _buildError(context, failure);
    }

    if (data != null) {
      return _buildData(context, data as T);
    }

    return _buildLoading(context);
  }

  Widget _buildLoading(BuildContext context) {
    if (skeletonBuilder != null) {
      return skeletonBuilder!(context);
    }
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: SkeletonList(itemCount: 3),
    );
  }

  Widget _buildError(BuildContext context, AppFailure failure) {
    if (errorBuilder != null) {
      return errorBuilder!(context, failure);
    }
    return ErrorState.fromFailure(
      failure: failure,
      onRetry: onRetry,
      isRetrying: isRetrying,
    );
  }

  Widget _buildData(BuildContext context, T resolvedData) {
    final isDataEmpty = isEmpty != null
        ? isEmpty!(resolvedData)
        : (resolvedData is Iterable && resolvedData.isEmpty);

    if (isDataEmpty && emptyBuilder != null) {
      return emptyBuilder!(context);
    }

    return builder(context, resolvedData);
  }
}
