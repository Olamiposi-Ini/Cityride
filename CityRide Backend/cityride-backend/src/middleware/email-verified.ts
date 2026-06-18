import type { NextFunction, Request, Response } from "express";
import { HttpError } from "../lib/http-error";
import { prisma } from "../lib/prisma";

export async function requireEmailVerified(
  req: Request,
  _res: Response,
  next: NextFunction
) {
  try {
    if (!req.user) {
      throw new HttpError(401, "Authentication token is required.");
    }

    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: { emailVerifiedAt: true }
    });

    if (!user) {
      throw new HttpError(404, "User account was not found.");
    }

    if (!user.emailVerifiedAt) {
      throw new HttpError(403, "Please verify your email before continuing.");
    }

    return next();
  } catch (error) {
    return next(error);
  }
}
