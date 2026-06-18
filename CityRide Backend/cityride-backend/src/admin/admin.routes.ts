import { Router } from "express";
import bcrypt from "bcryptjs";
import { HttpError } from "../lib/http-error";
import { prisma } from "../lib/prisma";
import { requireAuth, requireRole } from "../middleware/auth";
import { validate } from "../middleware/validate";
import {
  adminCreateUserSchema,
  adminListRidesSchema,
  adminListUsersSchema
} from "./admin.schemas";

export const adminRouter = Router();

adminRouter.use(requireAuth, requireRole("ADMIN"));

adminRouter.get("/overview", async (_req, res, next) => {
  try {
    const [
      totalUsers,
      riders,
      drivers,
      admins,
      availableDrivers,
      searchingRides,
      activeRides,
      completedRides,
      cancelledRides
    ] = await Promise.all([
      prisma.user.count(),
      prisma.user.count({ where: { role: "RIDER" } }),
      prisma.user.count({ where: { role: "DRIVER" } }),
      prisma.user.count({ where: { role: "ADMIN" } }),
      prisma.driverProfile.count({ where: { isAvailable: true } }),
      prisma.ride.count({ where: { status: "SEARCHING" } }),
      prisma.ride.count({
        where: {
          status: {
            in: [
              "DRIVER_ASSIGNED",
              "DRIVER_EN_ROUTE",
              "DRIVER_ARRIVED",
              "IN_PROGRESS"
            ]
          }
        }
      }),
      prisma.ride.count({ where: { status: "COMPLETED" } }),
      prisma.ride.count({ where: { status: "CANCELLED" } })
    ]);

    return res.json({
      users: { total: totalUsers, riders, drivers, admins },
      drivers: { available: availableDrivers },
      rides: {
        searching: searchingRides,
        active: activeRides,
        completed: completedRides,
        cancelled: cancelledRides
      }
    });
  } catch (error) {
    return next(error);
  }
});

adminRouter.get(
  "/users",
  validate(adminListUsersSchema),
  async (req, res, next) => {
    try {
      const query = req.query as unknown as {
        role?: "RIDER" | "DRIVER" | "ADMIN";
        limit: number;
        offset: number;
      };

      const [users, total] = await Promise.all([
        prisma.user.findMany({
          where: query.role ? { role: query.role } : undefined,
          select: adminUserSelect,
          orderBy: { createdAt: "desc" },
          take: query.limit,
          skip: query.offset
        }),
        prisma.user.count({
          where: query.role ? { role: query.role } : undefined
        })
      ]);

      return res.json({ users, total, limit: query.limit, offset: query.offset });
    } catch (error) {
      return next(error);
    }
  }
);

adminRouter.post(
  "/users",
  validate(adminCreateUserSchema),
  async (req, res, next) => {
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
      const user = await prisma.user.create({
        data: {
          firstName,
          lastName,
          email,
          phone,
          passwordHash,
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
        select: adminUserSelect
      });

      return res.status(201).json({ user });
    } catch (error) {
      return next(error);
    }
  }
);

adminRouter.get(
  "/drivers",
  validate(adminListUsersSchema),
  async (req, res, next) => {
    try {
      const query = req.query as unknown as {
        limit: number;
        offset: number;
      };

      const [drivers, total] = await Promise.all([
        prisma.driverProfile.findMany({
          include: {
            user: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                email: true,
                phone: true,
                createdAt: true
              }
            }
          },
          orderBy: { updatedAt: "desc" },
          take: query.limit,
          skip: query.offset
        }),
        prisma.driverProfile.count()
      ]);

      return res.json({ drivers, total, limit: query.limit, offset: query.offset });
    } catch (error) {
      return next(error);
    }
  }
);

adminRouter.get(
  "/rides",
  validate(adminListRidesSchema),
  async (req, res, next) => {
    try {
      const query = req.query as unknown as {
        status?: string;
        limit: number;
        offset: number;
      };

      const where = query.status ? { status: query.status as never } : undefined;
      const [rides, total] = await Promise.all([
        prisma.ride.findMany({
          where,
          include: {
            rider: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                email: true,
                phone: true
              }
            },
            driver: {
              select: {
                id: true,
                firstName: true,
                lastName: true,
                email: true,
                phone: true
              }
            }
          },
          orderBy: { createdAt: "desc" },
          take: query.limit,
          skip: query.offset
        }),
        prisma.ride.count({ where })
      ]);

      return res.json({ rides, total, limit: query.limit, offset: query.offset });
    } catch (error) {
      return next(error);
    }
  }
);

const adminUserSelect = {
  id: true,
  firstName: true,
  lastName: true,
  email: true,
  phone: true,
  role: true,
  createdAt: true,
  updatedAt: true,
  driver: true
} as const;
