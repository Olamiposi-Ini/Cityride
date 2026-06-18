import { Router } from "express";
import { HttpError } from "../lib/http-error";
import { prisma } from "../lib/prisma";
import { requireAuth, requireRole } from "../middleware/auth";
import { requireEmailVerified } from "../middleware/email-verified";
import { validate } from "../middleware/validate";
import { findNearestAvailableDriver } from "../drivers/driver.routes";
import { emitToRide, emitToUser } from "../realtime/realtime";
import { estimateFare } from "../utils/fare";
import {
  createCallSchema,
  createMessageSchema,
  createRideSchema,
  fareEstimateSchema,
  rideIdSchema,
  updateCallSchema,
  updateRideStatusSchema
} from "./ride.schemas";

export const rideRouter = Router();

const activeRideStatuses = [
  "DRIVER_ASSIGNED",
  "DRIVER_EN_ROUTE",
  "DRIVER_ARRIVED",
  "IN_PROGRESS"
] as const;

const allowedTransitions: Record<string, string[]> = {
  DRIVER_ASSIGNED: ["DRIVER_EN_ROUTE", "CANCELLED"],
  DRIVER_EN_ROUTE: ["DRIVER_ARRIVED", "CANCELLED"],
  DRIVER_ARRIVED: ["IN_PROGRESS", "CANCELLED"],
  IN_PROGRESS: ["COMPLETED", "CANCELLED"]
};

const quickReplies = {
  rider: ["I'm at the gate.", "Please wait 2 minutes.", "I can see you."],
  driver: ["I've arrived.", "I'm nearby.", "Traffic is slowing me down."]
};

rideRouter.get("/quick-replies", requireAuth, (_req, res) => {
  return res.json({ quickReplies });
});

rideRouter.post(
  "/estimate",
  requireAuth,
  requireRole("RIDER"),
  requireEmailVerified,
  validate(fareEstimateSchema),
  (req, res) => {
    return res.json({
      estimate: estimateFare(req.body.pickupLocation, req.body.destination)
    });
  }
);

rideRouter.post(
  "/",
  requireAuth,
  requireRole("RIDER"),
  requireEmailVerified,
  validate(createRideSchema),
  async (req, res, next) => {
    try {
      const { pickupLocation, destination } = req.body;
      const estimate = estimateFare(pickupLocation, destination);
      const candidate = await findNearestAvailableDriver(pickupLocation);

      const ride = await prisma.ride.create({
        data: {
          riderId: req.user!.id,
          driverId: candidate?.driver.userId,
          status: candidate ? "DRIVER_ASSIGNED" : "SEARCHING",
          pickupLatitude: pickupLocation.lat,
          pickupLongitude: pickupLocation.lng,
          destinationLatitude: destination.lat,
          destinationLongitude: destination.lng,
          pickupLabel: pickupLocation.label,
          destinationLabel: destination.label,
          fareEstimate: estimate.fareEstimate,
          distanceKm: estimate.distanceKm
        },
        include: rideInclude
      });

      if (candidate) {
        emitToUser(candidate.driver.userId, "ride:request", { ride });
        emitToUser(req.user!.id, "ride:update", {
          ride,
          message: "A nearby driver has been assigned."
        });
        notifyRideUsers(ride, "notification:new", {
          type: "DRIVER_ASSIGNED",
          rideId: ride.id,
          status: ride.status,
          message: "A nearby driver has been assigned."
        });
      } else {
        emitToUser(req.user!.id, "ride:update", {
          ride,
          message: "No available driver was found nearby. Keep searching or retry."
        });
        emitToUser(req.user!.id, "notification:new", {
          type: "NO_AVAILABLE_DRIVERS",
          rideId: ride.id,
          status: ride.status,
          message: "No available driver was found nearby. Keep searching or retry."
        });
      }

      return res.status(201).json({ ride });
    } catch (error) {
      return next(error);
    }
  }
);

rideRouter.get("/me/active", requireAuth, async (req, res, next) => {
  try {
    const rides = await prisma.ride.findMany({
      where: {
        OR: [{ riderId: req.user!.id }, { driverId: req.user!.id }],
        status: { in: [...activeRideStatuses, "SEARCHING"] }
      },
      include: rideInclude,
      orderBy: { createdAt: "desc" }
    });

    return res.json({ rides });
  } catch (error) {
    return next(error);
  }
});

rideRouter.get(
  "/:rideId",
  requireAuth,
  validate(rideIdSchema),
  async (req, res, next) => {
    try {
      const rideId = String(req.params.rideId);
      const ride = await getRideForUser(rideId, req.user!.id);
      return res.json({ ride });
    } catch (error) {
      return next(error);
    }
  }
);

rideRouter.patch(
  "/:rideId/accept",
  requireAuth,
  requireRole("DRIVER"),
  validate(rideIdSchema),
  async (req, res, next) => {
    try {
      const rideId = String(req.params.rideId);
      const ride = await prisma.ride.findFirst({
        where: {
          id: rideId,
          driverId: req.user!.id,
          status: "DRIVER_ASSIGNED"
        },
        include: rideInclude
      });

      if (!ride) {
        throw new HttpError(404, "Ride request is not available to accept.");
      }

      const updatedRide = await prisma.ride.update({
        where: { id: ride.id },
        data: { acceptedAt: new Date() },
        include: rideInclude
      });

      emitRideUpdate(updatedRide, "Ride request accepted.", "RIDE_REQUEST_ACCEPTED");
      return res.json({ ride: updatedRide });
    } catch (error) {
      return next(error);
    }
  }
);

rideRouter.patch(
  "/:rideId/decline",
  requireAuth,
  requireRole("DRIVER"),
  validate(rideIdSchema),
  async (req, res, next) => {
    try {
      const rideId = String(req.params.rideId);
      const ride = await prisma.ride.findFirst({
        where: {
          id: rideId,
          driverId: req.user!.id,
          status: "DRIVER_ASSIGNED"
        }
      });

      if (!ride) {
        throw new HttpError(404, "Ride request is not available to decline.");
      }

      const nextDriver = await findNearestAvailableDriver({
        lat: ride.pickupLatitude,
        lng: ride.pickupLongitude
      });

      const updatedRide = await prisma.ride.update({
        where: { id: ride.id },
        data:
          nextDriver && nextDriver.driver.userId !== req.user!.id
            ? { driverId: nextDriver.driver.userId, status: "DRIVER_ASSIGNED" }
            : { driverId: null, status: "SEARCHING" },
        include: rideInclude
      });

      if (updatedRide.driverId) {
        emitToUser(updatedRide.driverId, "ride:request", { ride: updatedRide });
      }

      emitRideUpdate(
        updatedRide,
        "Driver declined. Searching for another driver.",
        updatedRide.driverId ? "DRIVER_ASSIGNED" : "NO_AVAILABLE_DRIVERS"
      );
      return res.json({ ride: updatedRide });
    } catch (error) {
      return next(error);
    }
  }
);

rideRouter.patch(
  "/:rideId/status",
  requireAuth,
  requireRole("DRIVER"),
  validate(updateRideStatusSchema),
  async (req, res, next) => {
    try {
      const rideId = String(req.params.rideId);
      const ride = await prisma.ride.findFirst({
        where: {
          id: rideId,
          driverId: req.user!.id
        }
      });

      if (!ride) {
        throw new HttpError(404, "Ride was not found for this driver.");
      }

      assertTransition(ride.status, req.body.status);

      const updatedRide = await prisma.ride.update({
        where: { id: ride.id },
        data: {
          status: req.body.status,
          startedAt: req.body.status === "IN_PROGRESS" ? new Date() : ride.startedAt,
          completedAt: req.body.status === "COMPLETED" ? new Date() : ride.completedAt
        },
        include: rideInclude
      });

      if (updatedRide.status === "COMPLETED") {
        await prisma.driverProfile.updateMany({
          where: { userId: updatedRide.driverId ?? undefined },
          data: { isAvailable: true }
        });
      }

      emitRideUpdate(
        updatedRide,
        `Ride status changed to ${updatedRide.status}.`,
        notificationTypeForStatus(updatedRide.status)
      );
      return res.json({ ride: updatedRide });
    } catch (error) {
      return next(error);
    }
  }
);

rideRouter.patch(
  "/:rideId/cancel",
  requireAuth,
  validate(rideIdSchema),
  async (req, res, next) => {
    try {
      const rideId = String(req.params.rideId);
      const ride = await getRideForUser(rideId, req.user!.id);
      assertTransition(ride.status, "CANCELLED");

      const updatedRide = await prisma.ride.update({
        where: { id: ride.id },
        data: {
          status: "CANCELLED",
          cancelledAt: new Date()
        },
        include: rideInclude
      });

      emitRideUpdate(updatedRide, "Ride cancelled.", "RIDE_CANCELLED");
      return res.json({ ride: updatedRide });
    } catch (error) {
      return next(error);
    }
  }
);

rideRouter.get(
  "/:rideId/messages",
  requireAuth,
  validate(rideIdSchema),
  async (req, res, next) => {
    try {
      const rideId = String(req.params.rideId);
      const ride = await getRideForUser(rideId, req.user!.id);
      ensureActiveCommunication(ride.status);

      const messages = await prisma.chatMessage.findMany({
        where: { rideId: ride.id },
        include: {
          sender: {
            select: { id: true, firstName: true, lastName: true, role: true }
          }
        },
        orderBy: { createdAt: "asc" }
      });

      return res.json({ messages });
    } catch (error) {
      return next(error);
    }
  }
);

rideRouter.post(
  "/:rideId/messages",
  requireAuth,
  validate(createMessageSchema),
  async (req, res, next) => {
    try {
      const rideId = String(req.params.rideId);
      const ride = await getRideForUser(rideId, req.user!.id);
      ensureActiveCommunication(ride.status);

      const message = await prisma.chatMessage.create({
        data: {
          rideId: ride.id,
          senderId: req.user!.id,
          message: req.body.message,
          status: "DELIVERED"
        },
        include: {
          sender: {
            select: { id: true, firstName: true, lastName: true, role: true }
          }
        }
      });

      emitToRide(ride.id, "message:new", { message });
      notifyRideUsers(ride, "notification:new", {
        type: "NEW_MESSAGE",
        rideId: ride.id,
        message: "New ride message."
      });

      return res.status(201).json({ message });
    } catch (error) {
      return next(error);
    }
  }
);

rideRouter.post(
  "/:rideId/calls",
  requireAuth,
  validate(createCallSchema),
  async (req, res, next) => {
    try {
      const rideId = String(req.params.rideId);
      const ride = await getRideForUser(rideId, req.user!.id);
      ensureActiveCommunication(ride.status);

      const call = await prisma.callSession.create({
        data: {
          rideId: ride.id,
          initiatorId: req.user!.id,
          status: "CALLING"
        }
      });

      emitToRide(ride.id, "call:update", { call });
      return res.status(201).json({ call });
    } catch (error) {
      return next(error);
    }
  }
);

rideRouter.patch(
  "/calls/:callId",
  requireAuth,
  validate(updateCallSchema),
  async (req, res, next) => {
    try {
      const callId = String(req.params.callId);
      const existingCall = await prisma.callSession.findUnique({
        where: { id: callId },
        include: { ride: true }
      });

      if (!existingCall) {
        throw new HttpError(404, "Call session was not found.");
      }

      if (
        existingCall.ride.riderId !== req.user!.id &&
        existingCall.ride.driverId !== req.user!.id
      ) {
        throw new HttpError(403, "You cannot update this call session.");
      }

      ensureActiveCommunication(existingCall.ride.status);

      const call = await prisma.callSession.update({
        where: { id: existingCall.id },
        data: {
          status: req.body.status,
          endedAt: ["ENDED", "MISSED"].includes(req.body.status) ? new Date() : undefined
        }
      });

      emitToRide(existingCall.ride.id, "call:update", { call });
      return res.json({ call });
    } catch (error) {
      return next(error);
    }
  }
);

const rideInclude = {
  rider: {
    select: { id: true, firstName: true, lastName: true, email: true, phone: true }
  },
  driver: {
    select: {
      id: true,
      firstName: true,
      lastName: true,
      email: true,
      phone: true,
      driver: true
    }
  }
} as const;

async function getRideForUser(rideId: string, userId: string) {
  const ride = await prisma.ride.findFirst({
    where: {
      id: rideId,
      OR: [{ riderId: userId }, { driverId: userId }]
    },
    include: rideInclude
  });

  if (!ride) {
    throw new HttpError(404, "Ride was not found.");
  }

  return ride;
}

function assertTransition(currentStatus: string, nextStatus: string) {
  if (!allowedTransitions[currentStatus]?.includes(nextStatus)) {
    throw new HttpError(
      409,
      `Cannot change ride status from ${currentStatus} to ${nextStatus}.`
    );
  }
}

function ensureActiveCommunication(status: string) {
  if (!activeRideStatuses.includes(status as (typeof activeRideStatuses)[number])) {
    throw new HttpError(409, "Chat and calls are only available during active rides.");
  }
}

function emitRideUpdate(
  ride: { id: string; riderId: string; driverId: string | null; status: string },
  message: string,
  type = "RIDE_UPDATE"
) {
  emitToRide(ride.id, "ride:update", { ride, message });
  notifyRideUsers(ride, "notification:new", {
    type,
    rideId: ride.id,
    status: ride.status,
    message
  });
}

function notificationTypeForStatus(status: string) {
  if (status === "DRIVER_EN_ROUTE") return "DRIVER_EN_ROUTE";
  if (status === "DRIVER_ARRIVED") return "DRIVER_ARRIVING";
  if (status === "IN_PROGRESS") return "RIDE_STARTED";
  if (status === "COMPLETED") return "RIDE_COMPLETED";
  return "RIDE_UPDATE";
}

function notifyRideUsers(
  ride: { riderId: string; driverId: string | null },
  event: string,
  payload: unknown
) {
  emitToUser(ride.riderId, event, payload);

  if (ride.driverId) {
    emitToUser(ride.driverId, event, payload);
  }
}
