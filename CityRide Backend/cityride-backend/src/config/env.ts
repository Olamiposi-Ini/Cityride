import "dotenv/config";
import { z } from "zod";

const envSchema = z.object({
  DATABASE_URL: z.string().url("DATABASE_URL must be a valid PostgreSQL connection URL"),
  JWT_SECRET: z.string().min(16, "JWT_SECRET must be at least 16 characters"),
  ADMIN_BOOTSTRAP_SECRET: z.string().min(16).optional(),
  PORT: z.coerce.number().default(4000),
  CORS_ORIGIN: z.string().default("*"),
  MATCHING_RADIUS_KM: z.coerce.number().positive().default(5)
});

export const env = envSchema.parse(process.env);
