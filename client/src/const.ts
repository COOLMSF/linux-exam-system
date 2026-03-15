export { COOKIE_NAME, ONE_YEAR_MS } from "@shared/const";

/**
 * Returns the OAuth login URL when Manus OAuth is configured,
 * or falls back to "/" (local login page) for standalone deployments.
 *
 * In local/Kylin deployment, VITE_OAUTH_PORTAL_URL and VITE_APP_ID are empty,
 * so we must NOT call new URL("") which throws TypeError and crashes the app.
 */
export const getLoginUrl = () => {
  const oauthPortalUrl = import.meta.env.VITE_OAUTH_PORTAL_URL;
  const appId = import.meta.env.VITE_APP_ID;

  // Local deployment mode: no OAuth configured → use local login page
  if (!oauthPortalUrl || !appId) {
    return "/";
  }

  try {
    const redirectUri = `${window.location.origin}/api/oauth/callback`;
    const state = btoa(redirectUri);
    const url = new URL(`${oauthPortalUrl}/app-auth`);
    url.searchParams.set("appId", appId);
    url.searchParams.set("redirectUri", redirectUri);
    url.searchParams.set("state", state);
    url.searchParams.set("type", "signIn");
    return url.toString();
  } catch {
    // Fallback: if URL construction fails for any reason, go to local login
    return "/";
  }
};
