# PRD Compliance Review

This document compares the CityRide PRD against the current backend.

## Overall Status

The backend is in good shape for a Kingdomhack/staging integration build. It covers the core required backend scope: authentication, ride requests, matching, driver acceptance, live location updates, lifecycle state control, in-app messaging, simulated calls, and in-app realtime notifications.

The main backend gap is a true request-timeout/dispatch worker. The current matching flow assigns the nearest available driver immediately and supports decline/reassignment, but it does not yet expire unanswered driver requests automatically.

## Implemented Backend Scope

| PRD Requirement | Current Status |
| --- | --- |
| Rider/driver authentication | Implemented |
| Email verification | Implemented with API-response OTP for now; token is issued after verification |
| Role-based login/access | Implemented |
| Basic profile creation | Implemented |
| Rider pickup/destination ride request | Implemented |
| Fare estimation | Implemented |
| Driver assignment system | Implemented with nearest available driver |
| Drivers filtered by availability | Implemented |
| Drivers filtered by radius | Implemented via `MATCHING_RADIUS_KM` |
| Incoming ride requests | Implemented via REST + Socket.IO `ride:request` |
| Driver accept/decline | Implemented |
| Backend-controlled ride states | Implemented |
| Live driver location updates | Implemented via `PATCH /drivers/me/location` + `location:update` |
| Chat during active rides only | Implemented |
| Messages linked to `rideId` | Implemented |
| Realtime message delivery | Implemented via `message:new` |
| PRD quick replies | Implemented via `GET /rides/quick-replies` |
| Simulated calls during active rides | Implemented |
| In-app notifications | Implemented via `notification:new` |
| Payments/wallets/ratings | Correctly not implemented; out of PRD hackathon scope |

## Frontend-Owned PRD Items

These PRD requirements are mostly handled by the mobile app, while the backend provides the data/events:

- Mobile-responsive UI.
- React Native screens.
- Leaflet map rendering.
- Pickup/destination markers.
- Smooth marker movement.
- GPS permission handling.
- Network failure retry UI.
- Low-end Android performance tuning.
- Chat/call screens.

## Partial Backend Items

| PRD Item | Current State | Recommended Next Step |
| --- | --- | --- |
| Request timeout | Not implemented as a background worker | Add ride offer records and a timeout/reassignment worker |
| Driver response determines assignment | Accept/decline exists, but initial assignment is immediate | Add explicit offer lifecycle |
| Notifications and alerts | In-app realtime notifications exist | Add persistent notification table later |
| Chat read receipts | Message status model exists, but no read endpoint | Add mark-read endpoint if needed |
| Session persistence | JWT works for app sessions | Add refresh tokens later |

## Current Registration Shape

Rider registration:

```json
{
  "firstName": "Rider",
  "lastName": "One",
  "email": "rider.one@example.com",
  "phone": "08020000001",
  "password": "secret123",
  "role": "RIDER"
}
```

Driver registration:

```json
{
  "firstName": "Driver",
  "lastName": "One",
  "email": "driver.one@example.com",
  "phone": "08010000001",
  "password": "secret123",
  "role": "DRIVER",
  "vehicleType": "KEKE",
  "plateNumber": "RC-123"
}
```

Allowed driver vehicle types:

```text
CAB
BUS
KEKE
```

## Conclusion

The project is ready for frontend integration and staging demos. The backend should not be called fully production-complete yet, but it is aligned with the Kingdomhack delivery scope.
