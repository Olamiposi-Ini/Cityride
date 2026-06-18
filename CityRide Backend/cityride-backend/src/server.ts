import { createServer } from "node:http";
import { Server } from "socket.io";
import { createApp } from "./app";
import { env } from "./config/env";
import { prisma } from "./lib/prisma";
import { attachRealtime } from "./realtime/realtime";
import { registerSocketHandlers } from "./realtime/socket";

async function bootstrap() {
  const app = createApp();
  const httpServer = createServer(app);
  const io = new Server(httpServer, {
    cors: {
      origin: env.CORS_ORIGIN === "*" ? true : env.CORS_ORIGIN,
      credentials: true
    }
  });

  attachRealtime(io);
  registerSocketHandlers(io);

  httpServer.listen(env.PORT, () => {
    console.log(`CityRide backend listening on http://localhost:${env.PORT}`);
  });

  const shutdown = async () => {
    console.log("Shutting down CityRide backend...");
    httpServer.close();
    io.close();
    await prisma.$disconnect();
    process.exit(0);
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

bootstrap().catch(async (error) => {
  console.error(error);
  await prisma.$disconnect();
  process.exit(1);
});
