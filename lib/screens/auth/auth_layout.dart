import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../theme/app_palette.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
  });

  final String title;
  final String subtitle;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final formPane = Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 48 : 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!wide) ...[
                        const _MobileBrandHeader(),
                        const SizedBox(height: 32),
                      ],
                      Text(
                        AppConstants.appName,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: palette.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(title, style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: palette.muted,
                        ),
                      ),
                      const SizedBox(height: 28),
                      form,
                    ],
                  ),
                ),
              ),
            );
            if (!wide) return formPane;
            return Row(
              children: [
                const Expanded(child: _BrandPanel()),
                Expanded(child: formPane),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MobileBrandHeader extends StatelessWidget {
  const _MobileBrandHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: context.palette.primary,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      'Every complaint, on the record.',
      style: Theme.of(context).textTheme.headlineSmall
          ?.copyWith(color: Colors.white),
    ),
  );
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: context.palette.primary,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Every complaint, on the record.',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 36),
                const _AuditPreview(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuditPreview extends StatelessWidget {
  const _AuditPreview();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .1),
      border: Border.all(color: Colors.white24),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Column(
      children: [
        _PreviewEvent(label: 'Complaint recorded', complete: true),
        _PreviewEvent(label: 'Technician assigned', complete: true),
        _PreviewEvent(label: 'Visit update due', complete: false),
      ],
    ),
  );
}

class _PreviewEvent extends StatelessWidget {
  const _PreviewEvent({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: complete ? Colors.white : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
