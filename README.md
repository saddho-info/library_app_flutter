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

Android emulators / iOS simulators automatically reach the host machine (`http://10.0.2.2:3000` / `http://127.0.0.1:3000`, see `lib/core/network/api_config.dart`) — no extra config needed.

**Physical device on the same Wi-Fi:** the app needs your machine's LAN IP baked in via `--dart-define`. Use `scripts/run.sh`, which auto-detects it for you instead of guessing (a common source of "can't connect to local server"):

```bash
./scripts/run.sh                     # auto-detects your LAN IP, runs `flutter run`
./scripts/run.sh --emulator          # emulator/simulator, no IP override
./scripts/run.sh --ip=192.168.1.42   # force a specific IP
./scripts/run.sh -- -d <deviceId>    # forward extra args to `flutter run`
```

Equivalent manual command, if you'd rather not use the script:

```bash
ipconfig getifaddr en0   # find your Mac's LAN IP
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:3000
```

If the app still can't connect: confirm the backend is running (`curl http://<your-ip>:3000` from the Mac), confirm the phone and Mac are on the *same* Wi-Fi network (not a guest network with client isolation), and check **System Settings → Network → Firewall** isn't blocking incoming connections to `node`.

Demo library account: `walt.e@example.net` / `ChangeMe123!`

### Scanning and selling without a camera

On simulators, open **Scan** → use **Enter token** (keyboard icon) and paste an opaque QR token from a seeded/printed copy label. On a sellable copy, tap **Confirm sale**, optionally adjust price/notes, then confirm. Successful sales open the completion screen; history is under **Sales**.

### Receiving stock

Sign in as library staff and open **Stock**. Select an inbound shipment, review its editions, verify each physical copy (including missing/damaged discrepancies), and confirm. Confirmation is sent with an idempotency key and moves received copies into on-hand inventory.
