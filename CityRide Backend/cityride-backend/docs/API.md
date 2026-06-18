# API Reference

Base URL during local development:

```text
http://localhost:4000
```

Interactive Scalar docs:

```text
http://localhost:4000/docs
```

Raw OpenAPI document:

```text
http://localhost:4000/openapi.json
```

Protected endpoints require:

```text
Authorization: Bearer JWT_TOKEN
```

## Health

### `GET /health`

Checks whether the server is running.

Response:

```json
{
  "status": "ok",
  "service": "cityride-backend"
}
```

## Auth

### `POST /auth/register`

Registers a rider or driver.

Allowed roles:

```text
RIDER
DRIVER
```

Request:

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

Registration currently returns a temporary verification payload for frontend integration. It does not return a JWT token until email verification succeeds:

```json
{
  "verification": {
    "deliveryMode": "api_response",
    "expiresAt": "2026-06-16T00:00:00.000Z",
    "otp": "483921"
  }
}
```

Later, the same OTP can be sent by email instead of being returned by the API.

Driver request:

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

### `POST /auth/bootstrap-admin`

Creates the first admin. Requires `ADMIN_BOOTSTRAP_SECRET`.

Request:

```json
{
  "firstName": "CityRide",
  "lastName": "Admin",
  "email": "admin@cityride.local",
  "phone": "08000000000",
  "password": "adminsecret123",
  "bootstrapSecret": "value-from-env"
}
```

### `POST /auth/login`

Logs in rider, driver, or admin.

Request:

```json
{
  "email": "rider.one@example.com",
  "password": "secret123"
}
```

Login only returns a JWT after email verification. If the email is not verified, login returns `403` with a fresh `verification.otp` and no token. That fresh OTP replaces any previous unexpired OTP.

### `POST /auth/verify-email`

Verifies a user's email with the OTP returned by registration or resend.

Request:

```json
{
  "email": "rider.one@example.com",
  "code": "483921"
}
```

Successful verification returns the JWT token:

```json
{
  "message": "Email verified successfully.",
  "user": {},
  "token": "JWT_TOKEN"
}
```

### `POST /auth/resend-verification-code`

Generates a new OTP and returns it to the frontend for now.

Request:

```json
{
  "email": "rider.one@example.com"
}
```

Response:

```json
{
  "message": "Verification code generated.",
  "verification": {
    "deliveryMode": "api_response",
    "expiresAt": "2026-06-16T00:00:00.000Z",
    "otp": "483921"
  }
}
```

### `GET /auth/me`

Returns the logged-in user.

## Admin

All admin endpoints require `ADMIN`.

### `GET /admin/overview`

Returns platform counts for users, drivers, and rides.

### `GET /admin/users`

Query params:

```text
role=RIDER|DRIVER|ADMIN
limit=50
offset=0
```

### `POST /admin/users`

Creates a rider, driver, or admin.

Request:

```json
{
  "firstName": "New",
  "lastName": "Admin",
  "email": "new.admin@example.com",
  "phone": "08030000001",
  "password": "secret123",
  "role": "ADMIN"
}
```

### `GET /admin/drivers`

Lists driver profiles with user details.

### `GET /admin/rides`

Query params:

```text
status=SEARCHING|DRIVER_ASSIGNED|DRIVER_EN_ROUTE|DRIVER_ARRIVED|IN_PROGRESS|COMPLETED|CANCELLED
limit=50
offset=0
```

## Drivers

### `PATCH /drivers/me/availability`

Role: `DRIVER`

Requires verified email.

Request:

```json
{
  "isAvailable": true
}
```

### `PATCH /drivers/me/location`

Role: `DRIVER`

Requires verified email.

Request:

```json
{
  "lat": 6.8123,
  "lng": 3.4389
}
```

If the driver has an active ride, the rider receives `location:update`.

### `GET /drivers/nearby`

Query params:

```text
lat=6.8123
lng=3.4389
radiusKm=5
```

### `GET /drivers/me/requests`

Role: `DRIVER`

Returns assigned ride requests waiting for driver action.

## Rides

### `GET /rides/quick-replies`

Returns PRD-defined chat quick replies for rider and driver UIs.

Response:

```json
{
  "quickReplies": {
    "rider": [
      "I'm at the gate.",
      "Please wait 2 minutes.",
      "I can see you."
    ],
    "driver": [
      "I've arrived.",
      "I'm nearby.",
      "Traffic is slowing me down."
    ]
  }
}
```

### `POST /rides/estimate`

Role: `RIDER`

Requires verified email.

Request:

```json
{
  "pickupLocation": {
    "lat": 6.812,
    "lng": 3.439,
    "label": "Main Gate"
  },
  "destination": {
    "lat": 6.82,
    "lng": 3.45,
    "label": "Auditorium"
  }
}
```

### `POST /rides`

Role: `RIDER`

Requires verified email.

Creates a ride request and attempts to assign the nearest available driver.

### `GET /rides/me/active`

Returns active rides for the logged-in rider or driver.

### `GET /rides/:rideId`

Returns a ride if the logged-in user is the rider or assigned driver.

### `PATCH /rides/:rideId/accept`

Role: `DRIVER`

Marks that the driver accepted the assigned request.

### `PATCH /rides/:rideId/decline`

Role: `DRIVER`

Declines the assigned request and attempts to reassign another driver.

### `PATCH /rides/:rideId/status`

Role: `DRIVER`

Request:

```json
{
  "status": "DRIVER_EN_ROUTE"
}
```

Allowed status values for this endpoint:

```text
DRIVER_EN_ROUTE
DRIVER_ARRIVED
IN_PROGRESS
COMPLETED
```

### `PATCH /rides/:rideId/cancel`

Role: `RIDER` or assigned `DRIVER`

Cancels the ride if cancellation is allowed from the current state.

## Messages

### `GET /rides/:rideId/messages`

Returns chat messages for an active ride.

### `POST /rides/:rideId/messages`

Request:

```json
{
  "message": "I am at the gate."
}
```

Chat is only available during active rides.

## Calls

### `POST /rides/:rideId/calls`

Creates a simulated call session.

### `PATCH /rides/calls/:callId`

Request:

```json
{
  "status": "CONNECTED"
}
```

Allowed statuses:

```text
RINGING
CONNECTED
ENDED
MISSED
```
