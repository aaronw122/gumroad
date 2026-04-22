import { ChevronDown, X } from "@boxicons/react";
import * as React from "react";

import { SearchRequest } from "$app/data/search";
import { classNames } from "$app/utils/classNames";
import { CurrencyCode } from "$app/utils/currency";

import { Action, State, useDiscoverFilters } from "$app/components/Product/CardGrid";
import { BottomSheet, BottomSheetFooter, BottomSheetHeader } from "$app/components/ui/BottomSheet";
import { Pill } from "$app/components/ui/Pill";

type MobileFilterBarProps = {
  state: State;
  dispatchAction: React.Dispatch<Action>;
  defaults: SearchRequest;
  currencyCode: CurrencyCode;
  hideSort?: boolean;
  hasOfferCode?: boolean;
};

export const MobileFilterBar = ({
  state,
  dispatchAction,
  defaults,
  currencyCode,
  hideSort,
  hasOfferCode,
}: MobileFilterBarProps) => {
  const [openFilter, setOpenFilter] = React.useState<string | null>(null);

  const { params: searchParams } = state;

  const { filters, updateParams, results } = useDiscoverFilters({
    state,
    dispatchAction,
    defaults,
    currencyCode,
    hideSort,
  });

  const visibleFilters = filters.filter((filter) => filter.isVisible);

  const disabledFilters = new Set(visibleFilters.filter((f) => !f.hasData && !f.active).map((f) => f.key));

  return (
    <>
      <div role="toolbar" aria-label="Filters" className="flex flex-wrap gap-2 px-4">
        {hasOfferCode ? (
          <Pill asChild color="primary" className="cursor-pointer">
            <button
              onClick={() => updateParams({ offer_code: undefined })}
              aria-label="Remove offer code filter"
              className="inline-flex items-center gap-1"
            >
              {searchParams.offer_code}
              <X className="size-4" />
            </button>
          </Pill>
        ) : null}
        {visibleFilters.map((filter) => {
          const disabled = disabledFilters.has(filter.key);
          return (
            <Pill
              key={filter.key}
              asChild
              className={classNames(
                disabled ? "cursor-default opacity-50" : "cursor-pointer",
                filter.active ? "border-foreground bg-accent/20" : "bg-transparent",
              )}
            >
              <button
                onClick={() => {
                  if (!disabled) setOpenFilter(filter.key);
                }}
                disabled={disabled}
                aria-haspopup="dialog"
                className="inline-flex min-h-11 items-center gap-1 text-base"
              >
                {filter.triggerLabel}
                <ChevronDown className="size-4" />
              </button>
            </Pill>
          );
        })}
      </div>

      {visibleFilters.map((filter) => (
        <BottomSheet
          key={filter.key}
          open={openFilter === filter.key}
          onOpenChange={(open) => {
            if (!open) setOpenFilter(null);
          }}
        >
          <BottomSheetHeader>{filter.title}</BottomSheetHeader>
          {filter.content}
          <BottomSheetFooter
            buttonLabel={
              results
                ? `Show ${results.total >= 99 ? "99+" : results.total} ${results.total === 1 ? "result" : "results"}`
                : "Show results"
            }
            buttonDisabled={results?.total === 0}
          >
            <button
              className={classNames(
                "mr-auto underline all-unset",
                filter.clear ? "cursor-pointer text-foreground" : "cursor-default text-muted",
              )}
              onClick={() => filter.clear?.()}
              disabled={!filter.clear}
            >
              Clear
            </button>
          </BottomSheetFooter>
        </BottomSheet>
      ))}
    </>
  );
};
