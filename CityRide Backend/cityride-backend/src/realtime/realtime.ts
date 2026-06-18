import type { Server } from "socket.io";

let io: Server | undefined;

export function attachRealtime(server: Server) {
  io = server;
}

export function emitToUser(userId: string, event: string, payload: unknown) {
  io?.to(`user:${userId}`).emit(event, payload);
}

export function emitToRide(rideId: string, event: string, payload: unknown) {
  io?.to(`ride:${rideId}`).emit(event, payload);
}
