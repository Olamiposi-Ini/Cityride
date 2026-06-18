# CityRide Backend

CityRide is a hyperlocal ride-booking backend for Redemption City, based on the attached PRD. It is intentionally built as a clear MVP: simple enough to understand, but structured like a real backend that a mobile app can connect to.

## Current Answer on Auth

Yes, authentication now covers all three roles:

- `RIDER`: public registration through `POST /auth/register`.
- `DRIVER`: public registration through `POST /auth/register`, with an attached driver profile.
- `ADMIN`: created safely through `POST /auth/bootstrap-admin` for the first admin, or later through `POST /admin/users` by an existing admin.

All roles log in through the same endpoint: `POST /auth/login`.

Public signup does not allow `ADMIN`, because letting anyone register as an admin would be a serious security bug.

## What This Backend Supports

- Rider, driver, and admin authentication.
- Email verification OTP endpoints. For now, OTPs are returned by the API for frontend integration.
- Role-based access control.
- Driver availability toggle.
- Driver location updates every 3-5 seconds from the mobile app.
- Fare estimation.
- Ride request creation.
- Nearest available driver assignment.
- Driver accept and decline flow.
- Backend-controlled ride lifecycle.
- Rider/driver cancellation.
- Active-ride chat.
- Simulated call state.
- Admin dashboard data endpoints.
- Socket.IO events for live ride updates.

## Tech Stack

- Node.js
- TypeScript
- Express
- PostgreSQL
- Prisma 7
- Socket.IO
- JWT
- bcrypt
- Zod

## Project Structure

```text
.
├── prisma/
│   └── schema.prisma
├── src/
│   ├── admin/
│   ├── auth/
│   ├── config/
│   ├── drivers/
│   ├── lib/
│   ├── middleware/
│   ├── realtime/
│   ├── rides/
│   ├── types/
│   ├── utils/
│   ├── app.ts
│   └── server.ts
├── docs/
├── .env.example
├── package.json
└── tsconfig.json
```

## Quick Start

Create your environment file:

```bash
cp .env.example .env
```

Edit `.env`:

```env
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/cityride?schema=public"
JWT_SECRET="use-a-long-random-secret-here"
ADMIN_BOOTSTRAP_SECRET="use-another-long-random-secret-here"
PORT=4000
CORS_ORIGIN="http://localhost:3000"
MATCHING_RADIUS_KM=5
```

Generate Prisma Client and run the database migration:

```bash
npm run prisma:generate
npm run prisma:migrate
```

Start the backend:

```bash
npm run dev
```

Check that it is alive:

```bash
curl http://localhost:4000/health
```

Expected response:

```json
{
  "status": "ok",
  "service": "cityride-backend"
}
```

Interactive API documentation is available at:

```text
http://localhost:4000/docs
```

The raw OpenAPI document is available at:

```text
http://localhost:4000/openapi.json
```

## First Admin Setup

Create the first admin using the secret in `.env`:

```bash
curl -X POST http://localhost:4000/auth/bootstrap-admin \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "CityRide",
    "lastName": "Admin",
    "email": "admin@cityride.local",
    "phone": "08000000000",
    "password": "adminsecret123",
    "bootstrapSecret": "use-another-long-random-secret-here"
  }'
```

After the first admin exists, this endpoint rejects more bootstrap attempts. Additional admins should be created by an existing admin through `POST /admin/users`.

## Documentation

Read these files next:

- [docs/SETUP.md](/Users/emmanuelademuyiwa/Documents/Uber-like backend/docs/SETUP.md)
- [docs/ARCHITECTURE.md](/Users/emmanuelademuyiwa/Documents/Uber-like backend/docs/ARCHITECTURE.md)
- [docs/AUTH_AND_ROLES.md](/Users/emmanuelademuyiwa/Documents/Uber-like backend/docs/AUTH_AND_ROLES.md)
- [docs/API.md](/Users/emmanuelademuyiwa/Documents/Uber-like backend/docs/API.md)
- [docs/REALTIME.md](/Users/emmanuelademuyiwa/Documents/Uber-like backend/docs/REALTIME.md)
- [docs/FRONTEND_SOCKET_INTEGRATION.md](/Users/emmanuelademuyiwa/Documents/Uber-like backend/docs/FRONTEND_SOCKET_INTEGRATION.md)
- [docs/PRD_COMPLIANCE.md](/Users/emmanuelademuyiwa/Documents/Uber-like backend/docs/PRD_COMPLIANCE.md)
- [docs/DEPLOYMENT.md](/Users/emmanuelademuyiwa/Documents/Uber-like backend/docs/DEPLOYMENT.md)
- [docs/DEVELOPMENT_STATUS.md](/Users/emmanuelademuyiwa/Documents/Uber-like backend/docs/DEVELOPMENT_STATUS.md)

## Useful Commands

```bash
npm run dev
npm run build
npm run typecheck
npm run prisma:generate
npm run prisma:migrate
npm run prisma:studio
```

## Important MVP Limits

This backend is ready for a Kingdomhack-style demo foundation, but it is not finished as a production Uber-scale system. Payments, ratings, analytics, advanced dispatch queues, push notifications, and full production hardening are intentionally out of scope for this first version.
