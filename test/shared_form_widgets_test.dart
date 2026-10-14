import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grihsetu/theme/app_theme.dart';
import 'package:grihsetu/widgets/app_dropdown.dart';
import 'package:grihsetu/widgets/app_loading_button.dart';
import 'package:grihsetu/widgets/app_switch.dart';
import 'package:grihsetu/widgets/app_text_field.dart';

Widget _buildTestApp(Widget child, {Size size = const Size(360, 640)}) {
  return MaterialApp(
    theme: AppTheme.light(webFonts: false),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTextField', () {
    testWidgets('renders label, hint text, and helper text', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const AppTextField(
            label: 'Title',
            hintText: 'Enter title here',
            helperText: 'Keep it concise',
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Enter title here'), findsOneWidget);
      expect(find.text('Keep it concise'), findsOneWidget);
    });

    testWidgets('validation error displays upon form validation', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        _buildTestApp(
          Form(
            key: formKey,
            child: AppTextField(
              label: 'Email',
              validator: (val) =>
                  val == null || val.isEmpty ? 'Email is required' : null,
            ),
          ),
        ),
      );

      expect(find.text('Email is required'), findsNothing);

      final valid = formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(valid, isFalse);
      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets(
      'explicit errorText displays immediately without form validation',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            const AppTextField(
              label: 'Username',
              errorText: 'Username already taken',
            ),
          ),
        );

        expect(find.text('Username already taken'), findsOneWidget);
      },
    );

    testWidgets('controller and onChanged receive user input', (tester) async {
      final controller = TextEditingController();
      String changedText = '';

      await tester.pumpWidget(
        _buildTestApp(
          AppTextField(
            label: 'Notes',
            controller: controller,
            onChanged: (val) => changedText = val,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Hello GrihSetu');
      await tester.pump();

      expect(controller.text, equals('Hello GrihSetu'));
      expect(changedText, equals('Hello GrihSetu'));
    });

    testWidgets('disabled state prevents editing', (tester) async {
      final controller = TextEditingController(text: 'Read only text');

      await tester.pumpWidget(
        _buildTestApp(
          AppTextField(label: 'Locked', controller: controller, enabled: false),
        ),
      );

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.enabled, isFalse);
    });

    testWidgets('obscureText and multiline configurations work', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          const Column(
            children: [
              AppTextField(label: 'Password', obscureText: true),
              AppTextField(label: 'MultiLine', minLines: 3, maxLines: 5),
            ],
          ),
        ),
      );

      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields[0].obscureText, isTrue);
      expect(fields[0].maxLines, equals(1));
      expect(fields[1].minLines, equals(3));
      expect(fields[1].maxLines, equals(5));
    });
  });

  group('AppDropdown', () {
    testWidgets('renders initial value and triggers onChanged on selection', (
      tester,
    ) async {
      String? selected = 'option1';

      await tester.pumpWidget(
        _buildTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              return AppDropdown<String>(
                label: 'Options',
                value: selected,
                items: const [
                  DropdownMenuItem(value: 'option1', child: Text('Option One')),
                  DropdownMenuItem(value: 'option2', child: Text('Option Two')),
                ],
                onChanged: (val) => setState(() => selected = val),
              );
            },
          ),
        ),
      );

      expect(find.text('Option One'), findsOneWidget);

      await tester.tap(find.text('Option One'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Option Two').last);
      await tester.pumpAndSettle();

      expect(selected, equals('option2'));
      expect(find.text('Option Two'), findsOneWidget);
    });

    testWidgets('displays validation error when invalid', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        _buildTestApp(
          Form(
            key: formKey,
            child: AppDropdown<String>(
              label: 'Choice',
              items: const [
                DropdownMenuItem(value: 'a', child: Text('Choice A')),
              ],
              validator: (val) =>
                  val == null ? 'Please choose an option' : null,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('Please choose an option'), findsOneWidget);
    });

    testWidgets('disabled dropdown does not open', (tester) async {
      var changed = false;

      await tester.pumpWidget(
        _buildTestApp(
          AppDropdown<String>(
            label: 'Disabled',
            value: 'val',
            enabled: false,
            items: const [
              DropdownMenuItem(value: 'val', child: Text('Disabled Option')),
            ],
            onChanged: (_) => changed = true,
          ),
        ),
      );

      await tester.tap(find.text('Disabled Option'));
      await tester.pumpAndSettle();

      expect(changed, isFalse);
    });

    testWidgets('long label does not overflow on narrow screens (320px)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          AppDropdown<String>(
            label: 'Category',
            value: 'long',
            items: [
              AppDropdown.item(
                value: 'long',
                label: 'Extremely long category name describing an intricate residential maintenance scenario',
              ),
            ],
            onChanged: (_) {},
          ),
          size: const Size(320, 600),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('AppSwitch', () {
    testWidgets('renders title, subtitle and responds to toggle', (
      tester,
    ) async {
      bool switchValue = false;

      await tester.pumpWidget(
        _buildTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              return AppSwitch(
                title: 'Enable Notifications',
                subtitle: 'Receive updates about complaint status changes',
                value: switchValue,
                onChanged: (val) => setState(() => switchValue = val),
              );
            },
          ),
        ),
      );

      expect(find.text('Enable Notifications'), findsOneWidget);
      expect(
        find.text('Receive updates about complaint status changes'),
        findsOneWidget,
      );

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(switchValue, isTrue);
    });

    testWidgets('disabled switch ignores taps', (tester) async {
      bool switchValue = false;

      await tester.pumpWidget(
        _buildTestApp(
          AppSwitch(
            title: 'Locked Setting',
            value: switchValue,
            enabled: false,
            onChanged: (val) => switchValue = val,
          ),
        ),
      );

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(switchValue, isFalse);
    });

    testWidgets('displays helper text and error text', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const Column(
            children: [
              AppSwitch(
                title: 'Help switch',
                value: false,
                helperText: 'Optional feature explanation',
                onChanged: null,
              ),
              AppSwitch(
                title: 'Error switch',
                value: false,
                errorText: 'This toggle is required to continue',
                onChanged: null,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Optional feature explanation'), findsOneWidget);
      expect(find.text('This toggle is required to continue'), findsOneWidget);
    });
  });

  group('AppLoadingButton', () {
    testWidgets('renders action label and invokes onPressed on tap', (
      tester,
    ) async {
      var tapped = 0;

      await tester.pumpWidget(
        _buildTestApp(
          AppLoadingButton(label: 'Submit form', onPressed: () => tapped++),
        ),
      );

      expect(find.text('Submit form'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.byType(AppLoadingButton));
      await tester.pump();

      expect(tapped, equals(1));
    });

    testWidgets(
      'shows loading label and progress indicator when isLoading is true',
      (tester) async {
        await tester.pumpWidget(
          _buildTestApp(
            AppLoadingButton(
              label: 'Submit',
              loadingLabel: 'Submitting…',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        );

        expect(find.text('Submitting…'), findsOneWidget);
        expect(find.text('Submit'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('disables repeated taps during loading state', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        _buildTestApp(
          AppLoadingButton(
            label: 'Save',
            isLoading: true,
            onPressed: () => callCount++,
          ),
        ),
      );

      // Tap multiple times rapidly
      await tester.tap(find.byType(AppLoadingButton));
      await tester.pump();
      await tester.tap(find.byType(AppLoadingButton));
      await tester.pump();

      expect(callCount, equals(0));
    });

    testWidgets('disabled interaction when onPressed is null', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const AppLoadingButton(label: 'Disabled button', onPressed: null),
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('has at least 48px tap target size', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          AppLoadingButton(label: 'Accessible button', onPressed: () {}),
        ),
      );

      final buttonSize = tester.getSize(find.byType(AppLoadingButton));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));
      expect(buttonSize.width, greaterThanOrEqualTo(48.0));
    });

    testWidgets('stretches to full width when isFullWidth is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          SizedBox(
            width: 320,
            child: AppLoadingButton(
              label: 'Full width button',
              isFullWidth: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      final buttonSize = tester.getSize(find.byType(AppLoadingButton));
      expect(buttonSize.width, equals(320.0));
    });
  });
}
