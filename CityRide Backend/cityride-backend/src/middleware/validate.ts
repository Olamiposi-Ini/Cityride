import type { NextFunction, Request, Response } from "express";
import type { ZodType } from "zod";

export function validate(schema: ZodType) {
  return (req: Request, _res: Response, next: NextFunction) => {
    const result = schema.safeParse({
      body: req.body,
      params: req.params,
      query: req.query
    });

    if (!result.success) {
      return next(result.error);
    }

    const data = result.data as {
      body?: unknown;
      params?: Request["params"];
      query?: Request["query"];
    };

    req.body = data.body ?? req.body;
    req.params = data.params ?? req.params;

    if (data.query) {
      Object.defineProperty(req, "query", {
        value: data.query,
        configurable: true
      });
    }

    return next();
  };
}
