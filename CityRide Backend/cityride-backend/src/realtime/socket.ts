import type { Server, Socket } from "socket.io";
import jwt from "jsonwebtoken";
import { env } from "../config/env";
import { prisma } from "../lib/prisma";

type SocketUser = {
  id: string;
  role: "RIDER" | "DRIVER" | "ADMIN";
};

type JwtPayload = {
  sub: string;
  role: "RIDER" | "DRIVER" | "ADMIN";
};

type AuthenticatedSocket = Socket & {
  user?: SocketUser;
};

export function registerSocketHandlers(io: Server) {
  io.use((socket: AuthenticatedSocket, next) => {
    const token =
      socket.handshake.auth.token ||
      socket.handshake.headers.authorization?.replace("Bearer ", "");

    if (!token || typeof token !== "string") {
      return next(new Error("Authentication token is required."));
    }

    try {
      const payload = jwt.verify(token, env.JWT_SECRET) as JwtPayload;
      socket.user = {
        id: payload.sub,
        role: payload.role
      };
      return next();
    } catch {
      return next(new Error("Authentication token is invalid or expired."));
    }
  });

  io.on("connection", (socket: AuthenticatedSocket) => {
    if (!socket.user) {
      return socket.disconnect(true);
    }

    socket.join(`user:${socket.user.id}`);

    socket.on("ride:join", async ({ rideId }: { rideId?: string }) => {
      if (!rideId) return;

      const ride = await prisma.ride.findFirst({
        where: {
          id: rideId,
          OR: [{ riderId: socket.user!.id }, { driverId: socket.user!.id }]
        },
        select: { id: true }
      });

      if (ride) {
        socket.join(`ride:${ride.id}`);
      }
    });

    socket.on("ride:leave", ({ rideId }: { rideId?: string }) => {
      if (rideId) {
        socket.leave(`ride:${rideId}`);
      }
    });
  });
}
