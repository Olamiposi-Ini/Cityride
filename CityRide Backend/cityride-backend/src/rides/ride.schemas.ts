import { z } from "zod";

const coordinate = z.coerce.number().finite();

const locationSchema = z.object({
  lat: coordinate.min(-90).max(90),
  lng: coordinate.min(-180).max(180),
  label: z.string().trim().min(2).optional()
});

export const fareEstimateSchema = z.object({
  body: z.object({
    pickupLocation: locationSchema,
    destination: locationSchema
  })
});

export const createRideSchema = fareEstimateSchema;

export const rideIdSchema = z.object({
  params: z.object({
    rideId: z.string().min(1)
  })
});

export const updateRideStatusSchema = z.object({
  params: z.object({
    rideId: z.string().min(1)
  }),
  body: z.object({
    status: z.enum([
      "DRIVER_EN_ROUTE",
      "DRIVER_ARRIVED",
      "IN_PROGRESS",
      "COMPLETED"
    ])
  })
});

export const createMessageSchema = z.object({
  params: z.object({
    rideId: z.string().min(1)
  }),
  body: z.object({
    message: z.string().trim().min(1).max(500)
  })
});

export const createCallSchema = z.object({
  params: z.object({
    rideId: z.string().min(1)
  })
});

export const updateCallSchema = z.object({
  params: z.object({
    callId: z.string().min(1)
  }),
  body: z.object({
    status: z.enum(["RINGING", "CONNECTED", "ENDED", "MISSED"])
  })
});
