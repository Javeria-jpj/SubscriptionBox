# SubBox

Flutter subscription management app (Firebase + Riverpod).

**Module 1:** project setup, Firebase integration, email/password authentication
(sign up, sign in, password reset, sign out). User profiles are saved to Firestore `users/{uid}`.

```
lib/
  main.dart               # Firebase init + auth routing
  theme.dart              # colors & theme
  services/auth_service.dart
  screens/                # login, signup, forgot password, home
  widgets/auth_widgets.dart
  utils/validators.dart
```
