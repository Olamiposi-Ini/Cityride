# Architecture

CityRide has three major layers:

1. HTTP API for normal app actions.
2. PostgreSQL database through Prisma.
3. Socket.IO realtime layer for live ride updates.

## Request Flow

```text
Mobile app
  -> Express route
  -> Auth middleware
  -> Zod validation
  -> Prisma database operation
  -> JSON response
  -> Optional Socket.IO event
```

## Main Modules

`src/auth`

Handles registration, login, current user lookup, and first-admin bootstrap.

`src/admin`

Admin-only visibility and user creation routes.

`src/drivers`

Driver availability, location updates, nearby driver lookup, and incoming requests.

`src/rides`

Fare estimates, ride creation, matching, lifecycle transitions, cancellation, chat, and simulated calls.

`src/realtime`

Socket.IO setup and helper functions for sending events to users and ride rooms.

`src/middleware`

Authentication, role checks, validation, not-found handling, and error responses.

`src/utils`

Fare and distance helpers.

## Database Models

`User`

Stores riders, drivers, and admins. A driver user has one `DriverProfile`.

`DriverProfile`

Stores vehicle information, availability, and latest location.

`Ride`

Stores pickup, destination, fare estimate, status, rider, and assigned driver.

`ChatMessage`

Stores active-ride chat messages.

`CallSession`

Stores simulated call states for the app UI.

## Ride Lifecycle

Allowed states:

```text
SEARCHING
DRIVER_ASSIGNED
DRIVER_EN_ROUTE
DRIVER_ARRIVED
IN_PROGRESS
COMPLETED
CANCELLED
```

The backend controls transitions. The frontend listens and displays the current state.

Current allowed transitions:

```text
DRIVER_ASSIGNED -> DRIVER_EN_ROUTE
DRIVER_EN_ROUTE -> DRIVER_ARRIVED
DRIVER_ARRIVED -> IN_PROGRESS
IN_PROGRESS -> COMPLETED
```

Cancellation is allowed during active states where the route permits it.

## Matching Logic

When a rider requests a ride:

1. Backend calculates fare estimate.
2. Backend finds available drivers with known locations.
3. Backend filters drivers inside `MATCHING_RADIUS_KM`.
4. Backend picks the nearest driver.
5. Driver receives `ride:request` over Socket.IO.

This is intentionally simple for the MVP. Later, this should become a queue with timeouts and driver response tracking.
