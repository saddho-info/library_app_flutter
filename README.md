# PubTrack Library App

Flutter client for library staff.

- **Phase 3** — login with tokens in `flutter_secure_storage`
- **Phase 13** — authenticated shell: `go_router` + bottom nav (Home / Scan / Stock / Sales / More), Ink & Paper Material theme
- **Phase 14** — QR scanning via `mobile_scanner`, `GET /copies/by-qr/:token` lookup, copy/book details screen (manual token entry for simulators)
- **Phase 15** — online sale checkout: Confirm sale → Sale completed; Sales tab lists history + KPIs via `POST/GET /api/v1/sales`
- **Phase 16** — mobile stock receiving: inbound shipment list, Review → Verify → Confirm stepper, discrepancy flags, and receipt confirmation
- **Phase 17** — Hive offline database: pending sale/sale-item storage, copy cache, inventory snapshots, sync-state transitions, and Riverpod repository access

## Run

1. Start the API (`pubtrack-backend` on port 3000) and seed demo users:
   `npm run prisma:seed`
2. Launch the app:

```bash
flutter run
```

Android emulators automatically use `http://10.0.2.2:3000` (host machine). Override when needed:

```bash
# Physical device on the same LAN (replace with your Mac's IP):
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:3000
```

Demo library account: `walt.e@example.net` / `ChangeMe123!`

### Scanning and selling without a camera

On simulators, open **Scan** → use **Enter token** (keyboard icon) and paste an opaque QR token from a seeded/printed copy label. On a sellable copy, tap **Confirm sale**, optionally adjust price/notes, then confirm. Successful sales open the completion screen; history is under **Sales**.

### Receiving stock

Sign in as library staff and open **Stock**. Select an inbound shipment, review its editions, verify each physical copy (including missing/damaged discrepancies), and confirm. Confirmation is sent with an idempotency key and moves received copies into on-hand inventory.
