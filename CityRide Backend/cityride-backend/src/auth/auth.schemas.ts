import { z } from "zod";

const vehicleTypeSchema = z.enum(["CAB", "BUS", "KEKE"]);

export const registerSchema = z.object({
  body: z.object({
    firstName: z.string().trim().min(2),
    lastName: z.string().trim().min(2),
    email: z.string().trim().email().toLowerCase(),
    phone: z.string().trim().min(7).max(20),
    password: z.string().min(6),
    role: z.enum(["RIDER", "DRIVER"]),
    vehicleType: vehicleTypeSchema.optional(),
    plateNumber: z.string().trim().min(2).optional()
  }).superRefine((value, ctx) => {
    if (value.role === "DRIVER" && !value.vehicleType) {
      ctx.addIssue({
        code: "custom",
        path: ["vehicleType"],
        message: "Vehicle type is required for drivers."
      });
    }
  })
});

export const bootstrapAdminSchema = z.object({
  body: z.object({
    firstName: z.string().trim().min(2),
    lastName: z.string().trim().min(2),
    email: z.string().trim().email().toLowerCase(),
    phone: z.string().trim().min(7).max(20),
    password: z.string().min(8),
    bootstrapSecret: z.string().min(16)
  })
});

export const loginSchema = z.object({
  body: z.object({
    email: z.string().trim().email().toLowerCase(),
    password: z.string().min(1)
  })
});

export const verifyEmailSchema = z.object({
  body: z.object({
    email: z.string().trim().email().toLowerCase(),
    code: z.string().trim().regex(/^\d{6}$/, "Verification code must be 6 digits.")
  })
});

export const resendEmailVerificationSchema = z.object({
  body: z.object({
    email: z.string().trim().email().toLowerCase()
  })
});
