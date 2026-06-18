import cors from "cors";
import express from "express";
import helmet from "helmet";
import morgan from "morgan";
import { adminRouter } from "./admin/admin.routes";
import { env } from "./config/env";
import { authRouter } from "./auth/auth.routes";
import { docsRouter } from "./docs/docs.routes";
import { driverRouter } from "./drivers/driver.routes";
import { errorHandler, notFound } from "./middleware/error-handler";
import { rideRouter } from "./rides/ride.routes";

export function createApp() {
  const app = express();

  app.set("trust proxy", 1);
  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          "script-src": ["'self'", "'unsafe-inline'", "https://cdn.jsdelivr.net"],
          "style-src": ["'self'", "'unsafe-inline'", "https:"],
          "img-src": ["'self'", "data:", "https:"],
          "connect-src": ["'self'", "https:"]
        }
      }
    })
  );
  app.use(
    cors({
      origin: env.CORS_ORIGIN === "*" ? true : env.CORS_ORIGIN,
      credentials: true
    })
  );
  app.use(express.json({ limit: "1mb" }));
  app.use(morgan("dev"));

  app.get("/health", (_req, res) => {
    res.json({
      status: "ok",
      service: "cityride-backend"
    });
  });

  app.use("/auth", authRouter);
  app.use("/admin", adminRouter);
  app.use("/drivers", driverRouter);
  app.use("/rides", rideRouter);
  app.use(docsRouter);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}
