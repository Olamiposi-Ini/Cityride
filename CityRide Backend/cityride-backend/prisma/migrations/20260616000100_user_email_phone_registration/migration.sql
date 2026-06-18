-- Move users from name+phone auth to firstName+lastName+email+phone auth.
-- Existing staging users receive a temporary legacy email so deploy migrations
-- do not fail if the User table is already populated.

ALTER TABLE "User" ADD COLUMN "firstName" TEXT;
ALTER TABLE "User" ADD COLUMN "lastName" TEXT;
ALTER TABLE "User" ADD COLUMN "email" TEXT;

UPDATE "User"
SET
  "firstName" = COALESCE(NULLIF(split_part("name", ' ', 1), ''), 'CityRide'),
  "lastName" = COALESCE(
    NULLIF(trim(substr("name", length(split_part("name", ' ', 1)) + 1)), ''),
    'User'
  ),
  "email" = lower(regexp_replace("phone", '[^a-zA-Z0-9]+', '', 'g')) || '@legacy.cityride.local'
WHERE "email" IS NULL;

ALTER TABLE "User" ALTER COLUMN "firstName" SET NOT NULL;
ALTER TABLE "User" ALTER COLUMN "lastName" SET NOT NULL;
ALTER TABLE "User" ALTER COLUMN "email" SET NOT NULL;

ALTER TABLE "User" DROP COLUMN "name";

CREATE UNIQUE INDEX "User_email_key" ON "User"("email");
