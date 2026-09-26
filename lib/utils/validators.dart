String? validateName(String? v) =>
    (v ?? '').trim().length < 2 ? 'Please enter your full name' : null;

String? validateEmail(String? v) =>
    RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch((v ?? '').trim())
        ? null
        : 'Enter a valid email address';

String? validatePassword(String? v) =>
    (v ?? '').length < 6 ? 'Password must be at least 6 characters' : null;
