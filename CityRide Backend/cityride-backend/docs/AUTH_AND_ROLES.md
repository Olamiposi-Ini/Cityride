# Auth and Roles

The backend supports three roles:

```text
RIDER
DRIVER
ADMIN
```

All users are stored in the `User` table. The `role` field controls what they can do.

## Rider Auth

Riders register publicly:

```http
POST /auth/register
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

Riders can:

- Estimate fares.
- Request rides.
- View their active rides.
- Cancel their rides.
- Chat/call during active rides.

Riders must verify email before estimating fares or requesting rides.

## Driver Auth

Drivers register publicly:

```http
POST /auth/register
```

Request:

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

Driver `vehicleType` must be one of:

```text
CAB
BUS
KEKE
```

Drivers can:

- Toggle availability.
- Update location.
- Receive incoming ride requests.
- Accept or decline rides.
- Move rides through lifecycle states.
- Chat/call during active rides.

Drivers must verify email before going available or updating live location.

## Admin Auth

Admins should not be created through public signup.

Create the first admin with:

```http
POST /auth/bootstrap-admin
```

Request:

```json
{
  "firstName": "CityRide",
  "lastName": "Admin",
  "email": "admin@cityride.local",
  "phone": "08000000000",
  "password": "adminsecret123",
  "bootstrapSecret": "value-from-ADMIN_BOOTSTRAP_SECRET"
}
```

This only works if no admin exists yet.

After that, an admin can create more users or admins:

```http
POST /admin/users
```

Admins can:

- View platform overview counts.
- List users.
- Create riders, drivers, or admins.
- List drivers.
- List rides.

## Login

All roles log in the same way:

```http
POST /auth/login
```

Request:

```json
{
  "email": "rider.one@example.com",
  "password": "secret123"
}
```

Response includes:

```json
{
  "user": {},
  "token": "JWT_TOKEN"
}
```

Login only returns a token after email verification. If the email is not verified, login returns `403` with a fresh `verification.otp` and no token. That fresh OTP replaces any previous unexpired OTP.

## Email Verification

Email verification is implemented with a 6-digit OTP.

For now, because the project does not have a sender domain yet, the backend returns the OTP directly in the API response:

```json
{
  "verification": {
    "deliveryMode": "api_response",
    "expiresAt": "2026-06-16T00:00:00.000Z",
    "otp": "483921"
  }
}
```

Registration does not return a JWT token. The token is generated only after successful email verification.

The frontend should collect that OTP and call:

```http
POST /auth/verify-email
```

Request:

```json
{
  "email": "rider.one@example.com",
  "code": "483921"
}
```

If the code expires, call:

```http
POST /auth/resend-verification-code
```

Request:

```json
{
  "email": "rider.one@example.com"
}
```

Later, when an email provider/domain is ready, the backend can keep the same verify/resend endpoints and send the OTP by email instead of returning it in the response.

Use the token on protected endpoints:

```text
Authorization: Bearer JWT_TOKEN
```

## Role Checks in Code

Protected routes use:

```ts
requireAuth
requireRole("RIDER")
requireRole("DRIVER")
requireRole("ADMIN")
```

This means the frontend cannot simply pretend to be another role. The backend decides.
