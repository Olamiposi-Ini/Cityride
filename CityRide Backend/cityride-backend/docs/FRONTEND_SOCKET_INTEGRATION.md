# Frontend Socket.IO Integration Guide

This guide is for the frontend team integrating CityRide realtime updates.

Base Socket.IO URL is the same as the API base URL:

```text
Local:   http://localhost:4000
Staging: https://YOUR_RENDER_URL
```

## Install

```bash
npm install socket.io-client
```

## When To Connect

Connect only after the user has a JWT token.

Important auth flow:

1. User registers.
2. API returns `verification.otp`, but no token.
3. Frontend calls `POST /auth/verify-email`.
4. API returns `token`.
5. Frontend connects Socket.IO with that token.

For returning users, `POST /auth/login` returns a token only after email verification.

## Basic Client

```ts
import { io, Socket } from "socket.io-client";

const API_URL = "https://YOUR_RENDER_URL";

let socket: Socket | null = null;

export function connectCityRideSocket(token: string) {
  socket = io(API_URL, {
    transports: ["websocket"],
    auth: { token },
    autoConnect: true,
    reconnection: true,
    reconnectionAttempts: 10,
    reconnectionDelay: 1000
  });

  socket.on("connect", () => {
    console.log("CityRide socket connected", socket?.id);
  });

  socket.on("connect_error", (error) => {
    console.log("CityRide socket connect error", error.message);
  });

  socket.on("disconnect", (reason) => {
    console.log("CityRide socket disconnected", reason);
  });

  return socket;
}

export function getCityRideSocket() {
  return socket;
}

export function disconnectCityRideSocket() {
  socket?.disconnect();
  socket = null;
}
```

## Authentication

The backend reads the JWT from:

```ts
auth: { token: "JWT_TOKEN" }
```

The backend also accepts an authorization header during the Socket.IO handshake, but `auth.token` is recommended for frontend apps.

If the token is missing, invalid, or expired, the connection fails with:

```text
Authentication token is required.
Authentication token is invalid or expired.
```

## Rooms

### User Room

After connection, the backend automatically joins the socket to:

```text
user:USER_ID
```

The frontend does not need to emit anything for this.

Events delivered through the user room include:

- `ride:request`
- `location:update`
- `notification:new`
- some `ride:update` cases

### Ride Room

When the user opens an active ride screen, join the ride room:

```ts
socket.emit("ride:join", { rideId });
```

When leaving the active ride screen:

```ts
socket.emit("ride:leave", { rideId });
```

The backend only allows joining if the user is the rider or assigned driver for that ride.

Ride-room events include:

- `ride:update`
- `message:new`
- `call:update`

## Client Events To Emit

These are the only socket events the frontend currently emits.

### `ride:join`

Use on rider tracking screen, driver active ride screen, chat screen, and call screen.

```ts
socket.emit("ride:join", { rideId });
```

Payload:

```ts
type RideJoinPayload = {
  rideId: string;
};
```

### `ride:leave`

Use when leaving a ride-specific screen.

```ts
socket.emit("ride:leave", { rideId });
```

Payload:

```ts
type RideLeavePayload = {
  rideId: string;
};
```

## Backend Events To Listen For

### `ride:request`

Driver receives this when the backend assigns them a rider request.

```ts
socket.on("ride:request", ({ ride }) => {
  // Show incoming ride request screen/modal.
});
```

Payload shape:

```ts
type RideRequestEvent = {
  ride: Ride;
};
```

Frontend action after receiving this:

- Driver accepts with `PATCH /rides/:rideId/accept`
- Driver declines with `PATCH /rides/:rideId/decline`

### `ride:update`

Rider/driver receives this when ride state changes.

```ts
socket.on("ride:update", ({ ride, message }) => {
  // Update ride state in store.
});
```

Payload shape:

```ts
type RideUpdateEvent = {
  ride: Ride;
  message: string;
};
```

Common statuses:

```text
SEARCHING
DRIVER_ASSIGNED
DRIVER_EN_ROUTE
DRIVER_ARRIVED
IN_PROGRESS
COMPLETED
CANCELLED
```

### `location:update`

Rider receives this when the assigned driver updates location.

```ts
socket.on("location:update", (payload) => {
  // Move driver marker on map.
});
```

Payload shape:

```ts
type LocationUpdateEvent = {
  rideId: string;
  driverId: string;
  lat: number;
  lng: number;
  updatedAt: string;
};
```

Important: driver location is sent to the backend over REST, not Socket.IO:

```http
PATCH /drivers/me/location
Authorization: Bearer DRIVER_TOKEN
```

Body:

```json
{
  "lat": 6.8123,
  "lng": 3.4389
}
```

The driver app should call this every 3-5 seconds during active rides.

### `message:new`

Rider/driver receives this in a ride room when a chat message is sent.

```ts
socket.on("message:new", ({ message }) => {
  // Append message to chat thread.
});
```

Payload shape:

```ts
type MessageNewEvent = {
  message: ChatMessage;
};
```

Messages are sent over REST:

```http
POST /rides/:rideId/messages
Authorization: Bearer TOKEN
```

Body:

```json
{
  "message": "I'm at the gate."
}
```

Quick replies are fetched over REST:

```http
GET /rides/quick-replies
Authorization: Bearer TOKEN
```

### `call:update`

Rider/driver receives this in a ride room when simulated call state changes.

```ts
socket.on("call:update", ({ call }) => {
  // Update call UI state.
});
```

Payload shape:

```ts
type CallUpdateEvent = {
  call: CallSession;
};
```

Create call over REST:

```http
POST /rides/:rideId/calls
Authorization: Bearer TOKEN
```

Update call over REST:

```http
PATCH /rides/calls/:callId
Authorization: Bearer TOKEN
```

Body:

```json
{
  "status": "CONNECTED"
}
```

Allowed call statuses:

```text
CALLING
RINGING
CONNECTED
ENDED
MISSED
```

### `notification:new`

Rider/driver receives this for app-level alerts.

```ts
socket.on("notification:new", (notification) => {
  // Show toast, banner, badge, or local in-app alert.
});
```

Payload shape:

```ts
type NotificationNewEvent = {
  type:
    | "DRIVER_ASSIGNED"
    | "NO_AVAILABLE_DRIVERS"
    | "RIDE_REQUEST_ACCEPTED"
    | "DRIVER_EN_ROUTE"
    | "DRIVER_ARRIVING"
    | "RIDE_STARTED"
    | "RIDE_COMPLETED"
    | "RIDE_CANCELLED"
    | "NEW_MESSAGE"
    | "RIDE_UPDATE";
  rideId: string;
  status?: RideStatus;
  message: string;
};
```

## Suggested App Integration

### After Email Verification Or Login

```ts
const token = response.token;
saveToken(token);
connectCityRideSocket(token);
```

### On App Boot

```ts
const token = await loadToken();

if (token) {
  connectCityRideSocket(token);
}
```

### On Logout

```ts
disconnectCityRideSocket();
clearToken();
```

### On Active Ride Screen

```ts
useEffect(() => {
  const socket = getCityRideSocket();

  if (!socket || !rideId) return;

  socket.emit("ride:join", { rideId });

  return () => {
    socket.emit("ride:leave", { rideId });
  };
}, [rideId]);
```

## Rider Flow

1. Rider verifies email and receives token.
2. Frontend connects Socket.IO.
3. Rider creates ride via `POST /rides`.
4. If driver is assigned, rider receives `ride:update` and `notification:new`.
5. Rider opens tracking screen and emits `ride:join`.
6. Rider listens for:
   - `ride:update`
   - `location:update`
   - `message:new`
   - `call:update`
   - `notification:new`

## Driver Flow

1. Driver verifies email and receives token.
2. Frontend connects Socket.IO.
3. Driver toggles availability via `PATCH /drivers/me/availability`.
4. Driver updates location via `PATCH /drivers/me/location`.
5. Driver listens for `ride:request`.
6. Driver accepts or declines via REST.
7. Driver opens active ride screen and emits `ride:join`.
8. Driver updates ride status via `PATCH /rides/:rideId/status`.

## Type Definitions

These types are intentionally partial and focused on fields commonly used by the UI.

```ts
type UserRole = "RIDER" | "DRIVER" | "ADMIN";

type RideStatus =
  | "SEARCHING"
  | "DRIVER_ASSIGNED"
  | "DRIVER_EN_ROUTE"
  | "DRIVER_ARRIVED"
  | "IN_PROGRESS"
  | "COMPLETED"
  | "CANCELLED";

type VehicleType = "CAB" | "BUS" | "KEKE";

type User = {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  role: UserRole;
  emailVerifiedAt: string | null;
};

type DriverProfile = {
  id: string;
  userId: string;
  vehicleType: VehicleType | null;
  plateNumber: string | null;
  isAvailable: boolean;
  lastLatitude: number | null;
  lastLongitude: number | null;
  lastLocationAt: string | null;
};

type Ride = {
  id: string;
  riderId: string;
  driverId: string | null;
  pickupLatitude: number;
  pickupLongitude: number;
  destinationLatitude: number;
  destinationLongitude: number;
  pickupLabel: string | null;
  destinationLabel: string | null;
  status: RideStatus;
  fareEstimate: number;
  distanceKm: number;
  createdAt: string;
  updatedAt: string;
  rider?: User;
  driver?: User & { driver?: DriverProfile };
};

type ChatMessage = {
  id: string;
  rideId: string;
  senderId: string;
  message: string;
  status: "SENT" | "DELIVERED" | "READ";
  createdAt: string;
  sender?: Pick<User, "id" | "firstName" | "lastName" | "role">;
};

type CallSession = {
  id: string;
  rideId: string;
  initiatorId: string;
  status: "CALLING" | "RINGING" | "CONNECTED" | "ENDED" | "MISSED";
  createdAt: string;
  updatedAt: string;
  endedAt: string | null;
};
```

## Common Mistakes To Avoid

- Do not connect Socket.IO before email verification, because registration does not return a token.
- Do not send driver location through Socket.IO; use `PATCH /drivers/me/location`.
- Do not forget `ride:join` on chat/tracking/call screens.
- Do not assume every event is delivered globally; ride-specific events require joining the ride room.
- Do not use socket events to accept/decline rides; use REST endpoints.
