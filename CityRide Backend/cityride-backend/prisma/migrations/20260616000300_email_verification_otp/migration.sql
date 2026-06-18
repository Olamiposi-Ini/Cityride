ALTER TABLE "User" ADD COLUMN "emailVerifiedAt" TIMESTAMP(3);
ALTER TABLE "User" ADD COLUMN "emailVerificationCodeHash" TEXT;
ALTER TABLE "User" ADD COLUMN "emailVerificationExpiresAt" TIMESTAMP(3);

-- Treat existing staging users as verified so this migration does not disrupt
-- accounts created before the verification flow existed.
UPDATE "User"
SET "emailVerifiedAt" = NOW()
WHERE "emailVerifiedAt" IS NULL;
