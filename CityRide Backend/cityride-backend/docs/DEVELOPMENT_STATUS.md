# Development Status

This file tracks what exists, what is partial, and what is still missing.

## Implemented

- Rider registration and login.
- Driver registration and login.
- Admin bootstrap and login.
- Admin-only overview/users/drivers/rides endpoints.
- JWT authentication.
- Email verification OTP generation, resend, and verify endpoints.
- Role-based route protection.
- PostgreSQL schema through Prisma.
- Driver availability.
- Driver location updates.
- Nearby driver lookup.
- Fare estimation.
- Ride creation.
- Nearest-driver assignment.
- Driver accept and decline.
- Backend-controlled ride status updates.
- Rider or assigned-driver cancellation.
- Active-ride chat.
- PRD quick replies endpoint for rider and driver chat.
- Simulated active-ride calls.
- Socket.IO authentication.
- Socket.IO user rooms and ride rooms.
- Realtime ride, location, chat, call, and notification events.
- Docker Compose for local PostgreSQL.

## Partial or Basic

- Driver matching is nearest-driver only. It does not yet have request timeouts or a robust dispatch queue.
- Driver decline attempts reassignment, but there is no full declined-driver history yet.
- Notifications are in-app Socket.IO events only. Push notifications are not implemented.
- Email OTP delivery currently returns the code via API response; real email delivery is not connected yet.
- Fare estimation is simple distance-based pricing.
- Admin panel is API-only. There is no web dashboard UI yet.
- Chat has message storage and delivery event, but read receipts are not fully modeled in endpoints.
- Simulated calls store state, but there is no real VoIP.
- Network failure and GPS unavailability recovery are primarily frontend/mobile concerns; the backend returns clear validation and state errors.

## Missing From Production

- Payments.
- Wallets.
- Ratings and reviews.
- Advanced analytics.
- Multi-city support.
- Push notifications.
- Driver onboarding verification.
- Vehicle document upload.
- Password reset.
- Real email/SMS OTP delivery provider.
- Refresh tokens.
- Rate limiting.
- Request timeout worker.
- Production logging/monitoring.
- Automated tests.
- CI/CD pipeline.

## Recommended Next Build Steps

1. Add automated tests for auth, ride lifecycle, and admin routes.
2. Add request timeout and declined-driver tracking.
3. Add refresh tokens or shorter JWT sessions.
4. Add frontend integration examples.
5. Add push notification provider later.
