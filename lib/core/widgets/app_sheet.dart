import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_dialog.dart';

/// Shows [builder]'s content in the app's standard bottom sheet.
///
/// The sheet is as tall as its content, never taller than the screen, and
/// scrolls when the content does not fit (small phones, landscape, large
/// text). It moves above the keyboard and stays clear of the home indicator.
/// A second request while something is already in front is ignored.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
}) async {
  if (!isFrontmost(context)) return null;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
    builder: (context) => AppSheet(title: title, child: builder(context)),
  );
}

/// The body of a sheet shown with [showAppSheet]: grabber, optional title
/// and scrolling content.
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
          padding: AppInsets.sheet,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: AppSizes.grabberWidth,
                  height: AppSizes.grabberHeight,
                  decoration: ShapeDecoration(
                    color: context.colors.border,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              Gap.vXl,
              if (title != null) ...[
                Semantics(
                  header: true,
                  child: Text(title!, style: context.text.title),
                ),
                Gap.vLg,
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}
