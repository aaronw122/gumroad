import { cast } from "ts-safe-cast";

import { request, ResponseError } from "$app/utils/request";

export const createAccountSession = async () => fetchAccountSession();

export const createOnboardingAccountSession = async () => fetchAccountSession("account_onboarding");

const fetchAccountSession = async (component?: string) => {
  const response = await request({
    method: "POST",
    accept: "json",
    url: Routes.stripe_account_sessions_url(),
    data: component ? { component } : {},
  });

  const responseData = cast<{ success: true; client_secret: string } | { success: false; error_message: string }>(
    await response.json(),
  );

  if (!responseData.success) throw new ResponseError(responseData.error_message);

  return responseData.client_secret;
};
