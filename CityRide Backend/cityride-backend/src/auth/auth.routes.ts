import { Router } from "express";
import bcrypt from "bcryptjs";
import { env } from "../config/env";
import { prisma } from "../lib/prisma";
import { validate } from "../middleware/validate";
import {
  bootstrapAdminSchema,
  loginSchema,
  registerSchema,
  resendEmailVerificationSchema,
  verifyEmailSchema
} from "./auth.schemas";
import { HttpError } from "../lib/http-error";
import { requireAuth, signAuthToken } from "../middleware/auth";
import {
  emailOtpExpiryDate,
  generateEmailOtp,
  hashEmailOtp,
  publicVerificationPayload,
  verifyEmailOtp
} from "./email-verification";

export const authRouter = Router();

authRouter.post("/register", validate(registerSchema), async (req, res, next) => {
  try {
    const { firstName, lastName, email, phone, password, role, vehicleType, plateNumber } =
      req.body;
    const existing = await prisma.user.findFirst({
      where: { OR: [{ email }, { phone }] }
    });

    if (existing) {
      throw new HttpError(409, "A user with this email or phone number already exists.");
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const verificationCode = generateEmailOtp();
    const verificationExpiresAt = emailOtpExpiryDate();
    const verificationCodeHash = await hashEmailOtp(verificationCode);
    const user = await prisma.user.create({
      data: {
        firstName,
        lastName,
        email,
        phone,
        passwordHash,
        emailVerificationCodeHash: verificationCodeHash,
        emailVerificationExpiresAt: verificationExpiresAt,
        role,
        driver:
          role === "DRIVER"
            ? {
                create: {
                  vehicleType,
                  plateNumber
                }
              }
            : undefined
      },
      select: userSelect
    });

    return res
      .status(201)
      .json({ user, ...publicVerificationPayload(verificationCode, verificationExpiresAt) });
  } catch (error) {
    return next(error);
  }
});

authRouter.post(
  "/bootstrap-admin",
  validate(bootstrapAdminSchema),
  async (req, res, next) => {
    try {
      if (!env.ADMIN_BOOTSTRAP_SECRET) {
        throw new HttpError(503, "Admin bootstrap is not configured on this server.");
      }

      if (req.body.bootstrapSecret !== env.ADMIN_BOOTSTRAP_SECRET) {
        throw new HttpError(403, "Invalid admin bootstrap secret.");
      }

      const existingAdmin = await prisma.user.findFirst({
        where: { role: "ADMIN" },
        select: { id: true }
      });

      if (existingAdmin) {
        throw new HttpError(
          409,
          "An admin already exists. Log in as admin to create more admin users."
        );
      }

      const existingUser = await prisma.user.findFirst({
        where: { OR: [{ email: req.body.email }, { phone: req.body.phone }] },
        select: { id: true }
      });

      if (existingUser) {
        throw new HttpError(409, "A user with this email or phone number already exists.");
      }

      const passwordHash = await bcrypt.hash(req.body.password, 12);
      const verificationCode = generateEmailOtp();
      const verificationExpiresAt = emailOtpExpiryDate();
      const verificationCodeHash = await hashEmailOtp(verificationCode);
      const user = await prisma.user.create({
        data: {
          firstName: req.body.firstName,
          lastName: req.body.lastName,
          email: req.body.email,
          phone: req.body.phone,
          passwordHash,
          emailVerificationCodeHash: verificationCodeHash,
          emailVerificationExpiresAt: verificationExpiresAt,
          role: "ADMIN"
        },
        select: userSelect
      });

      return res
        .status(201)
        .json({ user, ...publicVerificationPayload(verificationCode, verificationExpiresAt) });
    } catch (error) {
      return next(error);
    }
  }
);

authRouter.post(
  "/verify-email",
  validate(verifyEmailSchema),
  async (req, res, next) => {
    try {
      const user = await prisma.user.findUnique({
        where: { email: req.body.email },
        select: {
          id: true,
          role: true,
          emailVerifiedAt: true,
          emailVerificationCodeHash: true,
          emailVerificationExpiresAt: true
        }
      });

      if (!user) {
        throw new HttpError(404, "User account was not found.");
      }

      if (user.emailVerifiedAt) {
        return res.json({ message: "Email is already verified." });
      }

      if (!user.emailVerificationCodeHash || !user.emailVerificationExpiresAt) {
        throw new HttpError(409, "No active verification code. Please request a new code.");
      }

      if (user.emailVerificationExpiresAt.getTime() < Date.now()) {
        throw new HttpError(409, "Verification code has expired. Please request a new code.");
      }

      const codeMatches = await verifyEmailOtp(
        req.body.code,
        user.emailVerificationCodeHash
      );

      if (!codeMatches) {
        throw new HttpError(400, "Verification code is invalid.");
      }

      const verifiedUser = await prisma.user.update({
        where: { id: user.id },
        data: {
          emailVerifiedAt: new Date(),
          emailVerificationCodeHash: null,
          emailVerificationExpiresAt: null
        },
        select: userSelect
      });
      const token = signAuthToken({ sub: verifiedUser.id, role: verifiedUser.role });

      return res.json({
        message: "Email verified successfully.",
        user: verifiedUser,
        token
      });
    } catch (error) {
      return next(error);
    }
  }
);

authRouter.post(
  "/resend-verification-code",
  validate(resendEmailVerificationSchema),
  async (req, res, next) => {
    try {
      const user = await prisma.user.findUnique({
        where: { email: req.body.email },
        select: { id: true, emailVerifiedAt: true }
      });

      if (!user) {
        throw new HttpError(404, "User account was not found.");
      }

      if (user.emailVerifiedAt) {
        return res.json({ message: "Email is already verified." });
      }

      const verificationCode = generateEmailOtp();
      const verificationExpiresAt = emailOtpExpiryDate();
      const verificationCodeHash = await hashEmailOtp(verificationCode);

      await prisma.user.update({
        where: { id: user.id },
        data: {
          emailVerificationCodeHash: verificationCodeHash,
          emailVerificationExpiresAt: verificationExpiresAt
        }
      });

      return res.json({
        message: "Verification code generated.",
        ...publicVerificationPayload(verificationCode, verificationExpiresAt)
      });
    } catch (error) {
      return next(error);
    }
  }
);

authRouter.post("/login", validate(loginSchema), async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const user = await prisma.user.findUnique({
      where: { email },
      select: {
        ...userSelect,
        passwordHash: true
      }
    });

    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      throw new HttpError(401, "Invalid email or password.");
    }

    if (!user.emailVerifiedAt) {
      const verificationCode = generateEmailOtp();
      const verificationExpiresAt = emailOtpExpiryDate();
      const verificationCodeHash = await hashEmailOtp(verificationCode);

      await prisma.user.update({
        where: { id: user.id },
        data: {
          emailVerificationCodeHash: verificationCodeHash,
          emailVerificationExpiresAt: verificationExpiresAt
        }
      });

      const { passwordHash: _passwordHash, ...safeUser } = user;
      return res.status(403).json({
        message: "Please verify your email before logging in.",
        user: safeUser,
        ...publicVerificationPayload(verificationCode, verificationExpiresAt)
      });
    }

    const token = signAuthToken({ sub: user.id, role: user.role });
    const { passwordHash: _passwordHash, ...safeUser } = user;
    return res.json({ user: safeUser, token });
  } catch (error) {
    return next(error);
  }
});

authRouter.get("/me", requireAuth, async (req, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: userSelect
    });

    if (!user) {
      throw new HttpError(404, "User account was not found.");
    }

    return res.json({ user });
  } catch (error) {
    return next(error);
  }
});

const userSelect = {
  id: true,
  firstName: true,
  lastName: true,
  email: true,
  phone: true,
  emailVerifiedAt: true,
  role: true,
  createdAt: true,
  driver: true
} as const;
