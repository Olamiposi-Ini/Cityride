import { z } from "zod";

const coordinate = z.coerce.number().finite();

export const availabilitySchema = z.object({
  body: z.object({
    isAvailable: z.boolean()
  })
});

export const locationSchema = z.object({
  body: z.object({
    lat: coordinate.min(-90).max(90),
    lng: coordinate.min(-180).max(180)
  })
});

export const nearbyDriversSchema = z.object({
  query: z.object({
    lat: coordinate.min(-90).max(90),
    lng: coordinate.min(-180).max(180),
    radiusKm: z.coerce.number().positive().max(20).optional()
  })
});
