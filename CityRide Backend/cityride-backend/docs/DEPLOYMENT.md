# Deployment Guide

You can deploy this now as a staging API for frontend integration.

The goal of the first deployment is not final production hardening. The goal is to give the frontend team a stable HTTPS base URL they can call while we keep improving the backend.

## Minimum Deployment Requirements

You need:

- A Node.js hosting service.
- A managed PostgreSQL database.
- Environment variables configured on the hosting service.
- The Prisma migration applied to the managed database.

Good beginner-friendly deployment options include Render, Railway, Fly.io, and similar Node-capable platforms.

## Required Environment Variables

Set these in the hosting dashboard:

```env
DATABASE_URL="postgresql://USER:PASSWORD@HOST:PORT/DATABASE?schema=public"
JWT_SECRET="a-long-random-production-secret"
ADMIN_BOOTSTRAP_SECRET="a-long-random-one-time-admin-secret"
PORT=4000
CORS_ORIGIN="https://your-frontend-domain.com"
MATCHING_RADIUS_KM=5
```

For early frontend testing, you may temporarily use:

```env
CORS_ORIGIN="*"
```

Before real users, set it to the actual frontend domain.

## Build Command

Use:

```bash
npm install --include=dev && npm run deploy:build
```

This runs:

```bash
npm install --include=dev
prisma generate
tsc
```

## Start Command

Use:

```bash
npm run deploy:start
```

This runs pending production migrations and starts the server:

```bash
prisma migrate deploy
node dist/server.js
```

If your hosting provider has a separate release command, use this instead:

Release command:

```bash
npm run prisma:migrate:deploy
```

Start command:

```bash
npm start
```

## Render Blueprint Option

This repo includes `render.yaml`, so you can also deploy through Render Blueprints.

In Render:

1. Click **New +**.
2. Choose **Blueprint**.
3. Select this GitHub repo.
4. Render will create both:
   - `cityride-backend`
   - `cityride-postgres`

You still need to fill the secret environment variables:

```env
JWT_SECRET
ADMIN_BOOTSTRAP_SECRET
```

The blueprint uses Frankfurt for both the backend and database.

## Health Check

After deployment, test:

```bash
curl https://YOUR_API_URL/health
```

Open the deployed API docs:

```text
https://YOUR_API_URL/docs
```

Open the raw OpenAPI document:

```text
https://YOUR_API_URL/openapi.json
```

Expected response:

```json
{
  "status": "ok",
  "service": "cityride-backend"
}
```

## First Admin on Staging

After deployment, create the first admin:

```bash
curl -X POST https://YOUR_API_URL/auth/bootstrap-admin \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "CityRide",
    "lastName": "Admin",
    "email": "admin@cityride.local",
    "phone": "08000000000",
    "password": "adminsecret123",
    "bootstrapSecret": "YOUR_ADMIN_BOOTSTRAP_SECRET"
  }'
```

Use the returned OTP with `POST /auth/verify-email`. The token is returned only after email verification succeeds.

## Frontend Integration Base URL

Give the frontend team:

```text
https://YOUR_API_URL
```

They should call endpoints like:

```text
POST https://YOUR_API_URL/auth/login
GET  https://YOUR_API_URL/auth/me
POST https://YOUR_API_URL/rides
```

Socket.IO should connect to the same base URL:

```ts
const socket = io("https://YOUR_API_URL", {
  auth: { token }
});
```

## Staging Checklist

Before handing the URL to frontend:

- `/health` returns `200`.
- `POST /auth/bootstrap-admin` works once.
- `POST /auth/register` works for rider and driver.
- `POST /auth/login` returns a JWT.
- `GET /auth/me` works with `Authorization: Bearer TOKEN`.
- Driver can set availability.
- Driver can update location.
- Rider can request a ride.

## Important Notes

- Do not deploy with the local Docker `DATABASE_URL`.
- Do not commit real production secrets.
- Do not use `ADMIN_BOOTSTRAP_SECRET` that is easy to guess.
- The first deployment should be treated as staging, not final production.
