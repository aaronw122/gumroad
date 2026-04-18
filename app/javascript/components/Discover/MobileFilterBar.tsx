import { ChevronDown, X } from "@boxicons/react";
import * as React from "react";

import { SearchRequest } from "$app/data/search";
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

  const visibleFilters = filters.filter((f) => {
    if (f.key === "sort") return !hideSort;
    return true;
  });

  const disabledFilters = new Set(visibleFilters.filter((f) => !f.hasData && !f.active).map((f) => f.key));

  const containerRef = React.useRef<HTMLDivElement>(null);
  const filterLabels = visibleFilters.map((f) => f.label).join(",");

  React.useLayoutEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    const children: HTMLElement[] = Array.from(container.children).filter(
      (c): c is HTMLElement => c instanceof HTMLElement,
    );
    if (children.length < 2) return;

    container.style.removeProperty("gap");
    const computedStyles = getComputedStyle(container);
    const containerPadding = parseFloat(computedStyles.paddingLeft) || 16;
    const defaultGap = parseFloat(computedStyles.columnGap) || 8;
    const minGap = 4;
    const maxGap = 24;
    const minPeek = 0.2;
    const maxPeek = 0.8;
    const candidatePeekIndices = [3, 4];
    const containerWidth = container.clientWidth;
    const pillWidths = children.map((c) => c.getBoundingClientRect().width);

    const cumulativeWidths = pillWidths.reduce<number[]>((acc, w) => {
      acc.push((acc[acc.length - 1] ?? 0) + w);
      return acc;
    }, []);
    const sumWidthsBefore = (index: number) => cumulativeWidths[index - 1] ?? 0;

    const visibleFraction = (pillIndex: number, gap: number) => {
      const width = pillWidths[pillIndex];
      if (width == null) return -1;
      const pillStart = containerPadding + sumWidthsBefore(pillIndex) + pillIndex * gap;
      return Math.max(0, Math.min(1, (containerWidth - pillStart) / width));
    };

    const alreadyHasPeek = candidatePeekIndices.some((i) => {
      const fraction = visibleFraction(i, defaultGap);
      return fraction >= minPeek && fraction <= maxPeek;
    });
    if (alreadyHasPeek) return;

    let bestGap = defaultGap;
    let smallestGapDelta = Infinity;
    for (const pillIndex of candidatePeekIndices) {
      if (pillIndex >= pillWidths.length) continue;
      const fraction = visibleFraction(pillIndex, defaultGap);
      const targetFraction = fraction < minPeek ? minPeek : maxPeek;
      const pillWidth = pillWidths[pillIndex];
      if (pillWidth == null) continue;
      const candidateGap =
        (containerWidth - containerPadding - sumWidthsBefore(pillIndex) - pillWidth * targetFraction) / pillIndex;
      if (candidateGap >= minGap && candidateGap <= maxGap && Math.abs(candidateGap - defaultGap) < smallestGapDelta) {
        smallestGapDelta = Math.abs(candidateGap - defaultGap);
        bestGap = candidateGap;
      }
    }

    if (bestGap !== defaultGap) container.style.gap = `${bestGap}px`;
  }, [filterLabels, hasOfferCode]);

  return (
    <>
      <div
        ref={containerRef}
        role="toolbar"
        aria-label="Filters"
        className="flex gap-2 overflow-x-auto px-4 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      >
        {hasOfferCode ? (
          <Pill asChild color="primary" className="shrink-0 cursor-pointer">
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
              className={`shrink-0 ${disabled ? "cursor-default opacity-50" : "cursor-pointer"} ${filter.active ? "border-foreground bg-accent/20" : "bg-transparent"}`}
            >
              <button
                onClick={() => {
                  if (!disabled) setOpenFilter(filter.key);
                }}
                disabled={disabled}
                aria-haspopup="dialog"
                className="inline-flex min-h-11 items-center gap-1 text-base"
              >
                {filter.label}
                <ChevronDown className="size-4" />
              </button>
            </Pill>
          );
        })}
      </div>

      {filters.map((filter) => (
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
              className={`mr-auto underline all-unset ${filter.onClear ? "cursor-pointer text-foreground" : "cursor-default text-muted"}`}
              onClick={() => filter.onClear?.()}
              disabled={!filter.onClear}
            >
              Clear
            </button>
          </BottomSheetFooter>
        </BottomSheet>
      ))}
    </>
  );
};
