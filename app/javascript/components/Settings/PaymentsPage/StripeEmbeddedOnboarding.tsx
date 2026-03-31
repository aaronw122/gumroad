import { StripeConnectInstance } from "@stripe/connect-js";
import { ConnectAccountOnboarding, ConnectComponentsProvider } from "@stripe/react-connect-js";
import * as React from "react";

import { getStripeConnectOnboardingInstance } from "$app/utils/stripe_loader";

import { Skeleton } from "$app/components/Skeleton";
import { useRunOnce } from "$app/components/useRunOnce";
import { showAlert } from "$app/components/server-components/Alert";

export const StripeEmbeddedOnboarding = ({ onOnboardingComplete }: { onOnboardingComplete: () => void }) => {
  const [connectInstance, setConnectInstance] = React.useState<null | StripeConnectInstance>(null);
  const [isLoading, setIsLoading] = React.useState(true);

  useRunOnce(() => {
    setConnectInstance(getStripeConnectOnboardingInstance());
  });

  const loader = <Skeleton className="h-96" />;

  return (
    <section>
      {connectInstance ? (
        <ConnectComponentsProvider connectInstance={connectInstance}>
          <ConnectAccountOnboarding
            collectionOptions={{
              fields: "eventually_due",
              futureRequirements: "include",
            }}
            fullTermsOfServiceUrl={Routes.terms_url()}
            privacyPolicyUrl={Routes.privacy_url()}
            onExit={() => {
              onOnboardingComplete();
              showAlert("Your payment information has been submitted.", "success");
            }}
            onLoadError={() => setIsLoading(false)}
            onLoaderStart={() => setIsLoading(false)}
          />
          {isLoading ? loader : null}
        </ConnectComponentsProvider>
      ) : (
        loader
      )}
    </section>
  );
};
