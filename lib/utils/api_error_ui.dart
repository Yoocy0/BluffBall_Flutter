import 'package:flutter/material.dart';

import '../models/api_error.dart';

void showApiErrorSnackBar(BuildContext context, ApiError error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error.message),
      backgroundColor: const Color(0xFF3A1A05),
    ),
  );
}

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF3A1A05),
    ),
  );
}
