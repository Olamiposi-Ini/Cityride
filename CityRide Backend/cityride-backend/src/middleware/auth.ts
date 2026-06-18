import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { env } from "../config/env";
import { HttpError } from "../lib/http-error";

type JwtPayload = {
  sub: string;
  role: "RIDER" | "DRIVER" | "ADMIN";
};

export function signAuthToken(payload: JwtPayload) {
  return jwt.sign(payload, env.JWT_SECRET, { expiresIn: "7d" });
}

export function requireAuth(req: Request, _res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  const token = header?.startsWith("Bearer ") ? header.slice(7) : undefined;

  if (!token) {
    return next(new HttpError(401, "Authentication token is required."));
  }

  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as JwtPayload;
    req.user = {
      id: payload.sub,
      role: payload.role
    };
    return next();
  } catch {
    return next(new HttpError(401, "Authentication token is invalid or expired."));
  }
}

export function requireRole(...roles: Array<"RIDER" | "DRIVER" | "ADMIN">) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!req.user) {
      return next(new HttpError(401, "Authentication token is required."));
    }

    if (!roles.includes(req.user.role)) {
      return next(new HttpError(403, "You do not have permission for this action."));
    }

    return next();
  };
}
