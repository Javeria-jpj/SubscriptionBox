# SubBox

Flutter subscription management app (Firebase + Riverpod).

- **Module 1:** Firebase setup and email/password authentication (sign up, sign in, reset, sign out).
- **Module 2:** Subscriptions with categories — add, edit, delete, filter — stored in Firestore
  at `users/{uid}/subscriptions`.

```
lib/
  main.dart                           # Firebase init + auth routing (Login <-> Home)
  theme.dart                          # colors & theme
  models/subscription.dart            # Subscription model, categories, cycles, presets
  services/auth_service.dart          # sign up / in / reset / out
  services/subscription_service.dart  # Firestore CRUD for subscriptions
  screens/                            # login, signup, forgot password, home, subscription form
  widgets/app_widgets.dart            # shared layout, text field, button, logo
  utils/validators.dart
```

Logo icon by [bqlqn](https://www.flaticon.com/authors/bqlqn) from [Flaticon](https://www.flaticon.com/).
