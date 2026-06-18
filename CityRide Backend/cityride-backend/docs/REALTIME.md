# Realtime Events

The backend uses Socket.IO for live updates.

## Connecting

```ts
import { io } from "socket.io-client";

const socket = io("http://localhost:4000", {
  auth: {
    token: "JWT_TOKEN"
  }
});
```

The token is returned from `POST /auth/login` only after email verification, or from `POST /auth/verify-email` immediately after successful verification.

## User Rooms

When a socket connects, the backend automatically joins it to:

```text
user:USER_ID
```

This lets the server send private updates to one rider or driver.

## Ride Rooms

When opening an active ride screen, the frontend should join the ride room:

```ts
socket.emit("ride:join", { rideId });
```

To leave:

```ts
socket.emit("ride:leave", { rideId });
```

The backend only allows a user to join a ride room if they are the rider or assigned driver.

## Events Sent by Backend

### `ride:request`

Sent to a driver when a rider requests a ride and the backend assigns that driver.

Payload:

```json
{
  "ride": {}
}
```

### `ride:update`

Sent when ride state changes.

Payload:

```json
{
  "ride": {},
  "message": "Ride status changed to DRIVER_EN_ROUTE."
}
```

### `location:update`

Sent to a rider when the assigned driver updates location.

Payload:

```json
{
  "rideId": "ride_id",
  "driverId": "driver_user_id",
  "lat": 6.8123,
  "lng": 3.4389,
  "updatedAt": "timestamp"
}
```

### `message:new`

Sent to the ride room when a rider or driver sends a chat message.

Payload:

```json
{
  "message": {}
}
```

### `call:update`

Sent to the ride room when a simulated call changes state.

Payload:

```json
{
  "call": {}
}
```

### `notification:new`

Sent to rider and driver for app-level notifications.

Payload:

```json
{
  "type": "RIDE_REQUEST_ACCEPTED",
  "rideId": "ride_id",
  "status": "DRIVER_ASSIGNED",
  "message": "Ride request accepted."
}
```

Current notification types include:

```text
DRIVER_ASSIGNED
NO_AVAILABLE_DRIVERS
RIDE_REQUEST_ACCEPTED
DRIVER_EN_ROUTE
DRIVER_ARRIVING
RIDE_STARTED
RIDE_COMPLETED
RIDE_CANCELLED
NEW_MESSAGE
RIDE_UPDATE
```

## Frontend Usage Pattern

1. User logs in through HTTP.
2. Frontend stores the JWT token securely.
3. Frontend connects Socket.IO with the token.
4. Rider creates a ride over HTTP.
5. Driver receives `ride:request`.
6. Rider and driver join `ride:join`.
7. Driver sends GPS updates over HTTP.
8. Rider receives `location:update`.
9. Chat and call updates flow through ride room events.
