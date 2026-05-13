import { styleText } from "util";
import { App, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { FIREBASE_PROJECT_ID } from "./env";

let currentApp: App | null = null;

const getApp = () => {
  if (!currentApp) {
    currentApp = initializeApp({
      projectId: FIREBASE_PROJECT_ID
    });
    // eslint-disable-next-line no-console
    console.log(
      styleText("green", `[projectId] ${currentApp.options.projectId}`)
    );
  }
  return currentApp;
};

export const firebaseAuth = () => getAuth(getApp());
export const firebaseFirestore = () => getFirestore(getApp());
export const firebaseStorage = () => getStorage(getApp());

export const getFirebaseProjectId = () => getApp().options.projectId || "";
