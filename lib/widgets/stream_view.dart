import 'dart:async';

import 'package:flutter/material.dart';

import '../services/errors/app_failure.dart';
import '../services/errors/firebase_error_mapper.dart';
import '../theme/app_palette.dart';
import 'app_spacing.dart';
import 'error_banner.dart';
import 'error_state.dart';
import 'skeleton_box.dart';

/// A reactive widget that consumes a [Stream<T>] and provides standard UX handling:
/// - Skeleton shimmer during initial load (before any stream event arrives).
/// - Full [ErrorState] on initial load failure.
/// - Preserves previously rendered data when a transient stream error occurs,
///   rendering an inline [ErrorBanner] above the content with retry or dismiss.
/// - Automatically handles app lifecycle resumes (e.g. reconnecting on resume).
class StreamView<T> extends StatefulWidget {
  const StreamView({
    super.key,
    required this.stream,
    required this.builder,
    this.initialData,
    this.skeletonBuilder,
    this.emptyBuilder,
    this.isEmpty,
    this.errorBuilder,
    this.onRetry,
    this.onReconnect,
    this.showLiveChip = false,
  });

  /// The source stream to observe.
  final Stream<T> stream;

  /// Builder for rendering data once available.
  final Widget Function(BuildContext context, T data) builder;

  /// Optional initial data to avoid loading shimmer if known.
  final T? initialData;

  /// Optional custom skeleton builder.
  final Widget Function(BuildContext context)? skeletonBuilder;

  /// Optional empty state builder when [isEmpty] returns true.
  final Widget Function(BuildContext context)? emptyBuilder;

  /// Predicate to check if [data] represents an empty state.
  final bool Function(T data)? isEmpty;

  /// Optional custom error builder on full-screen/initial error.
  final Widget Function(BuildContext context, AppFailure failure)? errorBuilder;

  /// Callback when user taps retry on an error.
  final VoidCallback? onRetry;

  /// Callback when app resumes from background to reconnect/resubscribe if needed.
  final VoidCallback? onReconnect;

  /// Whether to display a [LiveStatusChip] indicator in the top header.
  final bool showLiveChip;

  @override
  State<StreamView<T>> createState() => _StreamViewState<T>();
}

class _StreamViewState<T> extends State<StreamView<T>>
    with WidgetsBindingObserver {
  StreamSubscription<T>? _subscription;
  T? _lastData;
  Object? _lastError;
  bool _hasEmitted = false;
  bool _dismissedBanner = false;
  int _updateCounter = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialData != null) {
      _lastData = widget.initialData;
      _hasEmitted = true;
    }
    _subscribe();
  }

  @override
  void didUpdateWidget(StreamView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _subscription?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = widget.stream.listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _lastData = data;
          _lastError = null;
          _hasEmitted = true;
          _dismissedBanner = false;
          _updateCounter++;
        });
      },
      onError: (Object err) {
        if (!mounted) return;
        setState(() {
          _lastError = err;
          _dismissedBanner = false;
        });
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.onReconnect?.call();
      if (_subscription == null) {
        _subscribe();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Initial loading (no data emitted yet and no error)
    if (!_hasEmitted && _lastError == null) {
      if (widget.skeletonBuilder != null) {
        return widget.skeletonBuilder!(context);
      }
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SkeletonList(itemCount: 4),
      );
    }

    // 2. Initial error (error occurred before any valid data arrived)
    if (!_hasEmitted && _lastError != null) {
      final failure = _lastError is AppFailure
          ? _lastError! as AppFailure
          : FirebaseErrorMapper.map(_lastError!);
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, failure);
      }
      return ErrorState.fromFailure(
        failure: failure,
        onRetry: () {
          setState(() {
            _lastError = null;
          });
          widget.onRetry?.call();
          _subscription?.cancel();
          _subscribe();
        },
      );
    }

    // 3. We have cached data
    final data = _lastData as T;
    final isDataEmpty = widget.isEmpty != null
        ? widget.isEmpty!(data)
        : (data is Iterable && data.isEmpty);

    Widget content;
    if (isDataEmpty && widget.emptyBuilder != null) {
      content = widget.emptyBuilder!(context);
    } else {
      content = widget.builder(context, data);
    }

    // Check for transient error with cached data
    final hasTransientError = _lastError != null && !_dismissedBanner;
    final banner = hasTransientError
        ? ErrorBanner(
            failure: _lastError is AppFailure
                ? _lastError! as AppFailure
                : FirebaseErrorMapper.map(_lastError!),
            onRetry: () {
              setState(() {
                _lastError = null;
              });
              widget.onRetry?.call();
              _subscription?.cancel();
              _subscribe();
            },
            onDismiss: () {
              setState(() {
                _dismissedBanner = true;
              });
            },
          )
        : null;

    if (banner == null && !widget.showLiveChip) {
      return content;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isBounded = constraints.hasBoundedHeight;
        final childWidget = isBounded ? Expanded(child: content) : content;
        return Column(
          mainAxisSize: isBounded ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?banner,
            if (widget.showLiveChip)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: LiveStatusChip(updateCounter: _updateCounter),
                ),
              ),
            childWidget,
          ],
        );
      },
    );
  }
}

/// A subtle pulse indicator showing live stream connection and update status.
class LiveStatusChip extends StatefulWidget {
  const LiveStatusChip({
    super.key,
    this.updateCounter = 0,
    this.label = 'Live',
    this.isActive = true,
  });

  final int updateCounter;
  final String label;
  final bool isActive;

  @override
  State<LiveStatusChip> createState() => _LiveStatusChipState();
}

class _LiveStatusChipState extends State<LiveStatusChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LiveStatusChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final color = widget.isActive ? palette.success : palette.muted;

    return Semantics(
      liveRegion: true,
      label: '${widget.label} updates ${widget.isActive ? "active" : "paused"}',
      child: Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: widget.isActive ? _pulseAnimation.value : 0.4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
