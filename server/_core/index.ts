import "dotenv/config";
import express from "express";
import { createServer } from "http";
import net from "net";
import { execSync } from "child_process";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { createExpressMiddleware } from "@trpc/server/adapters/express";
import { registerOAuthRoutes } from "./oauth";
import { appRouter } from "../routers";
import { createContext } from "./context";
import { serveStatic, setupVite } from "./vite";

function isPortAvailable(port: number): Promise<boolean> {
  return new Promise(resolve => {
    const server = net.createServer();
    server.listen(port, () => {
      server.close(() => resolve(true));
    });
    server.on("error", () => resolve(false));
  });
}

async function findAvailablePort(startPort: number = 3000): Promise<number> {
  for (let port = startPort; port < startPort + 20; port++) {
    if (await isPortAvailable(port)) {
      return port;
    }
  }
  throw new Error(`No available port found starting from ${startPort}`);
}

async function runMigrations() {
  if (!process.env.DATABASE_URL) {
    console.warn("[migrate] DATABASE_URL not set, skipping auto-migration");
    return;
  }
  try {
    const __dirname = dirname(fileURLToPath(import.meta.url));
    const projectRoot = join(__dirname, "../..");
    const schemaPath = join(projectRoot, "drizzle/schema.ts");
    console.log("[migrate] Running drizzle-kit push to sync database schema...");
    execSync(
      `npx drizzle-kit push --dialect mysql --schema "${schemaPath}" --url "${process.env.DATABASE_URL}" --force`,
      { cwd: projectRoot, stdio: "pipe", timeout: 30000 }
    );
    console.log("[migrate] Database schema synced successfully");
  } catch (error: any) {
    console.warn("[migrate] Auto-migration failed (tables may already exist):", error.stderr?.toString().slice(0, 200) || error.message);
  }
}

async function startServer() {
  await runMigrations();
  const app = express();
  const server = createServer(app);
  // Configure body parser with larger size limit for file uploads
  app.use(express.json({ limit: "50mb" }));
  app.use(express.urlencoded({ limit: "50mb", extended: true }));
  // OAuth callback under /api/oauth/callback
  registerOAuthRoutes(app);
  // tRPC API
  app.use(
    "/api/trpc",
    createExpressMiddleware({
      router: appRouter,
      createContext,
    })
  );
  // development mode uses Vite, production mode uses static files
  if (process.env.NODE_ENV === "development") {
    await setupVite(app, server);
  } else {
    serveStatic(app);
  }

  const preferredPort = parseInt(process.env.PORT || "3000");
  const port = await findAvailablePort(preferredPort);

  if (port !== preferredPort) {
    console.log(`Port ${preferredPort} is busy, using port ${port} instead`);
  }

  server.listen(port, () => {
    console.log(`Server running on http://localhost:${port}/`);
  });
}

startServer().catch(console.error);
