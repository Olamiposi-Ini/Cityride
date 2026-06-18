import bcrypt from "bcryptjs";

const OTP_EXPIRY_MINUTES = 15;

export function generateEmailOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

export async function hashEmailOtp(code: string) {
  return bcrypt.hash(code, 12);
}

export function emailOtpExpiryDate() {
  return new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);
}

export async function verifyEmailOtp(code: string, codeHash: string) {
  return bcrypt.compare(code, codeHash);
}

export function publicVerificationPayload(code: string, expiresAt: Date) {
  return {
    verification: {
      deliveryMode: "api_response",
      expiresAt,
      otp: code
    }
  };
}
