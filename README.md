# PubTrack Library App

Flutter client for library staff. Phase 3 adds login with tokens stored in
`flutter_secure_storage`.

## Run

1. Start the API (`pubtrack-backend` on port 3000) and seed demo users:
   `npm run prisma:seed`
2. Launch the app:

```bash
flutter run
# Android emulator talking to host machine:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Demo library account: `walt.e@example.net` / `ChangeMe123!`
