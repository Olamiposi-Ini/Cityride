# Setup Guide

This guide explains how to run the backend from zero.

## 1. Requirements

Install these first:

- Node.js
- npm
- PostgreSQL

The project was built with Node `24.13.0` in this workspace.

## 2. Install Packages

```bash
npm install
```

## 3. Create Environment Variables

```bash
cp .env.example .env
```

Required values:

```env
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/cityride?schema=public"
JWT_SECRET="change-this-to-a-long-random-secret"
ADMIN_BOOTSTRAP_SECRET="change-this-before-creating-the-first-admin"
PORT=4000
CORS_ORIGIN="http://localhost:3000"
MATCHING_RADIUS_KM=5
```

`DATABASE_URL` points to PostgreSQL.

`JWT_SECRET` signs login tokens.

`ADMIN_BOOTSTRAP_SECRET` is used once to create the first admin.

`CORS_ORIGIN` should be the frontend URL.

`MATCHING_RADIUS_KM` controls how far the system searches for drivers.

## 4. Create the Database

The easiest development option is Docker:

```bash
npm run db:up
```

This starts PostgreSQL with:

```text
user: postgres
password: postgres
database: cityride
port: 5432
```

This matches the default `.env.example` connection string.

If you prefer a manually installed PostgreSQL server, create a PostgreSQL database named `cityride`, or change `DATABASE_URL` to match your database name.

Example with `createdb`:

```bash
createdb cityride
```

## 5. Generate Prisma Client

```bash
npm run prisma:generate
```

## 6. Run Migrations

```bash
npm run prisma:migrate
```

## 7. Start the Backend

```bash
npm run dev
```

Expected log:

```text
CityRide backend listening on http://localhost:4000
```

## 8. Test the Health Endpoint

```bash
curl http://localhost:4000/health
```

Expected:

```json
{
  "status": "ok",
  "service": "cityride-backend"
}
```

## Troubleshooting

If Prisma complains about missing generated client, run:

```bash
npm run prisma:generate
```

If database commands fail, confirm PostgreSQL is running and `DATABASE_URL` is correct.

If login or protected routes fail, confirm you are sending:

```text
Authorization: Bearer YOUR_TOKEN
```
