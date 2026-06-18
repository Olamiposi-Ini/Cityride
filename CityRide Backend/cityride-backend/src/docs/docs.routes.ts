import { apiReference } from "@scalar/express-api-reference";
import { Router } from "express";
import { openApiDocument } from "./openapi";

export const docsRouter = Router();

docsRouter.get("/openapi.json", (_req, res) => {
  res.json(openApiDocument);
});

docsRouter.use(
  "/docs",
  apiReference({
    content: openApiDocument,
    theme: "kepler"
  })
);
