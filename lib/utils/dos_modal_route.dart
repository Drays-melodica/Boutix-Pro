import 'package:flutter/material.dart';

import 'modal_tracker.dart';

Future<T?> pushDosModal<T>(BuildContext context, WidgetBuilder builder) {
  FocusManager.instance.primaryFocus?.unfocus();
  return ModalTracker.track(
    showDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: builder,
    ),
  );
}
