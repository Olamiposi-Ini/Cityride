import { Router } from "express";
import { env } from "../config/env";
import { HttpError } from "../lib/http-error";
import { prisma } from "../lib/prisma";
import { requireAuth, requireRole } from "../middleware/auth";
import { requireEmailVerified } from "../middleware/email-verified";
import { validate } from "../middleware/validate";
import { emitToUser } from "../realtime/realtime";
import { distanceKm } from "../utils/geo";
import {
  availabilitySchema,
  locationSchema,
  nearbyDriversSchema
} from "./driver.schemas";

export const driverRouter = Router();

driverRouter.patch(
  "/me/availability",
  requireAuth,
  requireRole("DRIVER"),
  requireEmailVerified,
  validate(availabilitySchema),
  async (req, res, next) => {
    try {
      const driver = await prisma.driverProfile.update({
        where: { userId: req.user!.id },
        data: { isAvailable: req.body.isAvailable }
      });

      return res.json({ driver });
    } catch (error) {
      return next(error);
    }
  }
);

driverRouter.patch(
  "/me/location",
  requireAuth,
  requireRole("DRIVER"),
  requireEmailVerified,
  validate(locationSchema),
  async (req, res, next) => {
    try {
      const driver = await prisma.driverProfile.update({
        where: { userId: req.user!.id },
        data: {
          lastLatitude: req.body.lat,
          lastLongitude: req.body.lng,
          lastLocationAt: new Date()
        }
      });

      const activeRide = await prisma.ride.findFirst({
        where: {
          driverId: req.user!.id,
          status: {
            in: ["DRIVER_ASSIGNED", "DRIVER_EN_ROUTE", "DRIVER_ARRIVED", "IN_PROGRESS"]
          }
        },
        select: { id: true, riderId: true }
      });

      if (activeRide) {
        emitToUser(activeRide.riderId, "location:update", {
          rideId: activeRide.id,
          driverId: req.user!.id,
          lat: req.body.lat,
          lng: req.body.lng,
          updatedAt: driver.lastLocationAt
        });
      }

      return res.json({ driver });
    } catch (error) {
      return next(error);
    }
  }
);

driverRouter.get(
  "/nearby",
  requireAuth,
  validate(nearbyDriversSchema),
  async (req, res, next) => {
    try {
      const query = req.query as unknown as {
        lat: number;
        lng: number;
        radiusKm?: number;
      };
      const radiusKm = query.radiusKm ?? env.MATCHING_RADIUS_KM;
      const drivers = await prisma.driverProfile.findMany({
        where: {
          isAvailable: true,
          lastLatitude: { not: null },
          lastLongitude: { not: null },
          user: {
            driverRides: {
              none: {
                status: {
                  in: [
                    "SEARCHING",
                    "DRIVER_ASSIGNED",
                    "DRIVER_EN_ROUTE",
                    "DRIVER_ARRIVED",
                    "IN_PROGRESS"
                  ]
                }
              }
            }
          }
        },
        include: {
          user: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              email: true,
              phone: true
            }
          }
        }
      });

      const nearby = drivers
        .map((driver) => ({
          ...driver,
          distanceKm: distanceKm(
            { lat: query.lat, lng: query.lng },
            { lat: driver.lastLatitude!, lng: driver.lastLongitude! }
          )
        }))
        .filter((driver) => driver.distanceKm <= radiusKm)
        .sort((a, b) => a.distanceKm - b.distanceKm);

      return res.json({
        drivers: nearby.map((driver) => ({
          ...driver,
          distanceKm: Number(driver.distanceKm.toFixed(2))
        }))
      });
    } catch (error) {
      return next(error);
    }
  }
);

driverRouter.get(
  "/me/requests",
  requireAuth,
  requireRole("DRIVER"),
  async (req, res, next) => {
    try {
      const rides = await prisma.ride.findMany({
        where: {
          driverId: req.user!.id,
          status: "DRIVER_ASSIGNED"
        },
        include: {
          rider: {
            select: {
              id: true,
              firstName: true,
              lastName: true,
              email: true,
              phone: true
            }
          }
        },
        orderBy: { createdAt: "desc" }
      });

      return res.json({ rides });
    } catch (error) {
      return next(error);
    }
  }
);

export async function findNearestAvailableDriver(pickup: { lat: number; lng: number }) {
  const drivers = await prisma.driverProfile.findMany({
    where: {
      isAvailable: true,
      lastLatitude: { not: null },
      lastLongitude: { not: null },
      user: {
        driverRides: {
          none: {
            status: {
              in: ["DRIVER_ASSIGNED", "DRIVER_EN_ROUTE", "DRIVER_ARRIVED", "IN_PROGRESS"]
            }
          }
        }
      }
    },
    include: {
      user: {
        select: { id: true, firstName: true, lastName: true, email: true, phone: true }
      }
    }
  });

  const candidates = drivers
    .map((driver) => ({
      driver,
      distanceKm: distanceKm(pickup, {
        lat: driver.lastLatitude!,
        lng: driver.lastLongitude!
      })
    }))
    .filter((candidate) => candidate.distanceKm <= env.MATCHING_RADIUS_KM)
    .sort((a, b) => a.distanceKm - b.distanceKm);

  return candidates[0] ?? null;
}

export function assertDriverProfile(driver: unknown) {
  if (!driver) {
    throw new HttpError(404, "Driver profile was not found.");
  }
}
