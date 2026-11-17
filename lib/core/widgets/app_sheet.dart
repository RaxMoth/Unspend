import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'content_width.dart';

/// Shows [builder]'s content in the app's standard bottom sheet.
///
/// The sheet is as tall as its content, never taller than the screen, and
/// scrolls when the content does not fit (small phones, landscape, large
/// text). It moves above the keyboard and stays clear of the home indicator.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: kSurface,
  constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius)),
  ),
  builder: (context) => AppSheet(title: title, child: builder(context)),
);

/// The body of a sheet shown with [showAppSheet]: drag handle, optional
/// title and scrolling content.
class AppSheet extends StatelessWidget {
  const AppSheet({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (title != null) ...[
                Semantics(
                  header: true,
                  child: Text(
                    title!,
                    style: TextStyle(
                      color: kTextPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}
