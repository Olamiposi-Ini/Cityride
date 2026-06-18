import { z } from "zod";

const vehicleTypeSchema = z.enum(["CAB", "BUS", "KEKE"]);

export const adminCreateUserSchema = z.object({
  body: z.object({
    firstName: z.string().trim().min(2),
    lastName: z.string().trim().min(2),
    email: z.string().trim().email().toLowerCase(),
    phone: z.string().trim().min(7).max(20),
    password: z.string().min(6),
    role: z.enum(["RIDER", "DRIVER", "ADMIN"]),
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

export const adminListUsersSchema = z.object({
  query: z.object({
    role: z.enum(["RIDER", "DRIVER", "ADMIN"]).optional(),
    limit: z.coerce.number().int().positive().max(100).default(50),
    offset: z.coerce.number().int().min(0).default(0)
  })
});

export const adminListRidesSchema = z.object({
  query: z.object({
    status: z
      .enum([
        "SEARCHING",
        "DRIVER_ASSIGNED",
        "DRIVER_EN_ROUTE",
        "DRIVER_ARRIVED",
        "IN_PROGRESS",
        "COMPLETED",
        "CANCELLED"
      ])
      .optional(),
    limit: z.coerce.number().int().positive().max(100).default(50),
    offset: z.coerce.number().int().min(0).default(0)
  })
});
