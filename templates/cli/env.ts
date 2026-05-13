import { existsSync } from "node:fs";
import { loadEnvFile } from "node:process";

const DOTENV_FILE_PATH = ".env";

if (existsSync(DOTENV_FILE_PATH)) {
  loadEnvFile(DOTENV_FILE_PATH);
}

export const FIREBASE_PROJECT_ID =
  process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "";
