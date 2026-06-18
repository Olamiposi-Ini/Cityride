import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "@prisma/client";
import pg from "pg";
import { env } from "../config/env";

const { Pool } = pg;

const pool = new Pool({
  connectionString: env.DATABASE_URL
});

const adapter = new PrismaPg(pool);

export const prisma = new PrismaClient({ adapter });
