import { StripeConnectInstance } from "@stripe/connect-js";
import { ConnectAccountOnboarding, ConnectComponentsProvider } from "@stripe/react-connect-js";
import * as React from "react";

import { getStripeConnectInstance } from "$app/utils/stripe_loader";

import { Skeleton } from "$app/components/Skeleton";
import { useRunOnce } from "$app/components/useRunOnce";

export const StripeConnectEmbeddedOnboarding = ({ onExit }: { onExit: () => void }) => {
  const [connectInstance, setConnectInstance] = React.useState<null | StripeConnectInstance>(null);
  const [isLoading, setIsLoading] = React.useState(true);

  useRunOnce(() => {
    setConnectInstance(getStripeConnectInstance());
  });

  const loader = <Skeleton className="h-96" />;

  return (
    <section>
      {connectInstance ? (
        <ConnectComponentsProvider connectInstance={connectInstance}>
          <ConnectAccountOnboarding
            onExit={() => {
              setIsLoading(false);
              onExit();
            }}
            onLoadError={() => setIsLoading(false)}
          />
          {isLoading ? loader : null}
        </ConnectComponentsProvider>
      ) : (
        loader
      )}
    </section>
  );
};
