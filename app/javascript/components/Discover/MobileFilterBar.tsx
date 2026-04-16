import { range } from "lodash-es";
import * as React from "react";

import { SearchRequest } from "$app/data/search";
import { SORT_KEYS } from "$app/parsers/product";
import { CurrencyCode, getShortCurrencySymbol } from "$app/utils/currency";

import { NumberInput } from "$app/components/NumberInput";
import { Action, SORT_BY_LABELS, State } from "$app/components/Product/CardGrid";
import { RatingStars } from "$app/components/RatingStars";
import { showAlert } from "$app/components/server-components/Alert";
import { BottomSheet, BottomSheetHeader } from "$app/components/ui/BottomSheet";
import { Checkbox } from "$app/components/ui/Checkbox";
import { Fieldset, FieldsetTitle } from "$app/components/ui/Fieldset";
import { Input } from "$app/components/ui/Input";
import { InputGroup } from "$app/components/ui/InputGroup";
import { Label } from "$app/components/ui/Label";
import { Pill } from "$app/components/ui/Pill";
import { Radio } from "$app/components/ui/Radio";
import { useDebouncedCallback } from "$app/components/useDebouncedCallback";
import { useOnChange } from "$app/components/useOnChange";

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
  const currencySymbol = getShortCurrencySymbol(currencyCode);
  const [openFilter, setOpenFilter] = React.useState<"sort" | "tags" | "contains" | "price" | "rating" | null>(null);

  const { params: searchParams, results } = state;

  const updateParams = (newParams: Partial<SearchRequest>) => {
    const { from: _, ...params } = searchParams;
    dispatchAction({ type: "set-params", params: { ...params, ...newParams } });
  };

  const [enteredMinPrice, setEnteredMinPrice] = React.useState(searchParams.min_price ?? null);
  const [enteredMaxPrice, setEnteredMaxPrice] = React.useState(searchParams.max_price ?? null);

  useOnChange(() => {
    setEnteredMinPrice(searchParams.min_price ?? null);
    setEnteredMaxPrice(searchParams.max_price ?? null);
  }, [searchParams]);

  const debouncedTrySetPrice = useDebouncedCallback((minPrice: number | null, maxPrice: number | null) => {
    trySetPrice(minPrice, maxPrice);
  }, 500);

  const trySetPrice = (minPrice: number | null, maxPrice: number | null) => {
    if (minPrice == null || maxPrice == null || maxPrice > minPrice) {
      updateParams({ min_price: minPrice ?? undefined, max_price: maxPrice ?? undefined });
    } else showAlert("Please set the price minimum to be lower than the maximum.", "error");
  };

  let anyFilters = false;
  for (const key of Object.keys(searchParams)) {
    if (
      !["from", "curated_product_ids"].includes(key) &&
      searchParams[key] != null &&
      searchParams[key] !== defaults[key]
    )
      anyFilters = true;
  }

  const sortActive = searchParams.sort !== defaults.sort && searchParams.sort != null;
  const sortLabel = SORT_BY_LABELS[searchParams.sort as keyof typeof SORT_BY_LABELS];

  const tagsActive = (searchParams.tags?.length ?? 0) > 0;
  const showTags = (results?.tags_data?.length ?? 0) > 0 || tagsActive;

  const filetypesActive = (searchParams.filetypes?.length ?? 0) > 0;
  const showContains = (results?.filetypes_data?.length ?? 0) > 0 || filetypesActive;

  const minPriceSet = searchParams.min_price != null;
  const maxPriceSet = searchParams.max_price != null;
  const priceActive = minPriceSet || maxPriceSet;

  const priceLabel = (() => {
    if (minPriceSet && maxPriceSet)
      return `${currencySymbol}${searchParams.min_price}\u2013${currencySymbol}${searchParams.max_price}`;
    if (minPriceSet) return `${currencySymbol}${searchParams.min_price}+`;
    if (maxPriceSet) return `Up to ${currencySymbol}${searchParams.max_price}`;
    return "Price";
  })();

  const ratingActive = searchParams.rating != null;

  const uid = React.useId();
  const minPriceUid = React.useId();
  const maxPriceUid = React.useId();

  const concatFoundAndNotFound = (
    resultsData: { key: string; doc_count: number }[] | undefined,
    searchedKeys: string[] | undefined,
  ) => {
    const foundData = resultsData ?? [];
    const notFoundKeys = searchedKeys?.filter((s) => !foundData.some((f) => f.key === s)) ?? [];
    return notFoundKeys.map((key) => ({ key, doc_count: 0 })).concat(foundData);
  };

  return (
    <>
      <div
        role="toolbar"
        aria-label="Filters"
        className="sticky top-0 z-20 flex overflow-x-auto gap-2 bg-background py-3 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      >
        {hideSort ? null : (
          <Pill asChild color={sortActive ? "primary" : undefined} className="shrink-0 cursor-pointer">
            <button onClick={() => setOpenFilter("sort")} aria-haspopup="dialog">
              {sortActive ? `Sort: ${sortLabel}` : "Sort by"}
            </button>
          </Pill>
        )}
        {showTags ? (
          <Pill asChild color={tagsActive ? "primary" : undefined} className="shrink-0 cursor-pointer">
            <button onClick={() => setOpenFilter("tags")} aria-haspopup="dialog">
              {tagsActive ? `Tags (${searchParams.tags!.length})` : "Tags"}
            </button>
          </Pill>
        ) : null}
        {showContains ? (
          <Pill asChild color={filetypesActive ? "primary" : undefined} className="shrink-0 cursor-pointer">
            <button onClick={() => setOpenFilter("contains")} aria-haspopup="dialog">
              {filetypesActive ? `Contains (${searchParams.filetypes!.length})` : "Contains"}
            </button>
          </Pill>
        ) : null}
        <Pill asChild color={priceActive ? "primary" : undefined} className="shrink-0 cursor-pointer">
          <button onClick={() => setOpenFilter("price")} aria-haspopup="dialog">
            {priceLabel}
          </button>
        </Pill>
        <Pill asChild color={ratingActive ? "primary" : undefined} className="shrink-0 cursor-pointer">
          <button onClick={() => setOpenFilter("rating")} aria-haspopup="dialog">
            {ratingActive ? `${searchParams.rating}+ stars` : "Rating"}
          </button>
        </Pill>
        {anyFilters ? (
          <Pill asChild className="shrink-0 cursor-pointer">
            <button onClick={() => dispatchAction({ type: "set-params", params: defaults })}>Clear all</button>
          </Pill>
        ) : null}
      </div>

      <BottomSheet
        open={openFilter === "sort"}
        onOpenChange={(open) => {
          if (!open) setOpenFilter(null);
        }}
      >
        <BottomSheetHeader>Sort by</BottomSheetHeader>
        <Fieldset role="group">
          {SORT_KEYS.map((key) => (
            <Label key={key} className="w-full">
              {SORT_BY_LABELS[key]}
              <Radio
                wrapperClassName="ml-auto"
                name={`${uid}-mobile-sortBy`}
                checked={(searchParams.sort ?? defaults.sort) === key}
                onChange={() => updateParams({ sort: key })}
              />
            </Label>
          ))}
        </Fieldset>
      </BottomSheet>

      <BottomSheet
        open={openFilter === "tags"}
        onOpenChange={(open) => {
          if (!open) setOpenFilter(null);
        }}
      >
        <BottomSheetHeader>Tags</BottomSheetHeader>
        <Fieldset role="group">
          <Label className="w-full">
            All Products
            <Checkbox
              wrapperClassName="ml-auto"
              checked={!searchParams.tags?.length}
              disabled={!searchParams.tags?.length}
              onChange={() => updateParams({ tags: undefined })}
            />
          </Label>
          {results
            ? concatFoundAndNotFound(results.tags_data, searchParams.tags).map((option) => (
                <Label key={option.key} className="w-full">
                  {option.key} ({option.doc_count})
                  <Checkbox
                    wrapperClassName="ml-auto"
                    checked={(searchParams.tags ?? []).includes(option.key)}
                    onChange={() =>
                      updateParams({
                        tags: (searchParams.tags ?? []).includes(option.key)
                          ? (searchParams.tags ?? []).filter((t) => t !== option.key)
                          : [...(searchParams.tags ?? []), option.key],
                      })
                    }
                  />
                </Label>
              ))
            : null}
        </Fieldset>
      </BottomSheet>

      <BottomSheet
        open={openFilter === "contains"}
        onOpenChange={(open) => {
          if (!open) setOpenFilter(null);
        }}
      >
        <BottomSheetHeader>Contains</BottomSheetHeader>
        <Fieldset role="group">
          {results
            ? concatFoundAndNotFound(results.filetypes_data, searchParams.filetypes).map((option) => (
                <Label key={option.key} className="w-full">
                  {option.key} ({option.doc_count})
                  <Checkbox
                    wrapperClassName="ml-auto"
                    checked={(searchParams.filetypes ?? []).includes(option.key)}
                    onChange={() =>
                      updateParams({
                        filetypes: (searchParams.filetypes ?? []).includes(option.key)
                          ? (searchParams.filetypes ?? []).filter((t) => t !== option.key)
                          : [...(searchParams.filetypes ?? []), option.key],
                      })
                    }
                  />
                </Label>
              ))
            : null}
        </Fieldset>
      </BottomSheet>

      <BottomSheet
        open={openFilter === "price"}
        onOpenChange={(open) => {
          if (!open) setOpenFilter(null);
        }}
      >
        <BottomSheetHeader>Price</BottomSheetHeader>
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(var(--dynamic-grid), 1fr))",
            gridAutoFlow: "row",
            gap: "var(--spacer-3)",
          }}
        >
          <Fieldset>
            <FieldsetTitle>
              <Label htmlFor={minPriceUid}>Minimum price</Label>
            </FieldsetTitle>
            <InputGroup>
              <Pill className="-ml-2 shrink-0">{currencySymbol}</Pill>
              <NumberInput
                onChange={(value) => {
                  setEnteredMinPrice(value);
                  debouncedTrySetPrice(value, enteredMaxPrice);
                }}
                value={enteredMinPrice ?? null}
              >
                {(props) => <Input id={minPriceUid} placeholder="0" {...props} />}
              </NumberInput>
            </InputGroup>
          </Fieldset>
          <Fieldset>
            <FieldsetTitle>
              <Label htmlFor={maxPriceUid}>Maximum price</Label>
            </FieldsetTitle>
            <InputGroup>
              <Pill className="-ml-2 shrink-0">{currencySymbol}</Pill>
              <NumberInput
                onChange={(value) => {
                  setEnteredMaxPrice(value);
                  debouncedTrySetPrice(enteredMinPrice, value);
                }}
                value={enteredMaxPrice ?? null}
              >
                {(props) => <Input id={maxPriceUid} placeholder="\u221E" {...props} />}
              </NumberInput>
            </InputGroup>
          </Fieldset>
        </div>
      </BottomSheet>

      <BottomSheet
        open={openFilter === "rating"}
        onOpenChange={(open) => {
          if (!open) setOpenFilter(null);
        }}
      >
        <BottomSheetHeader>Rating</BottomSheetHeader>
        <Fieldset role="group">
          {range(4, 0).map((number) => (
            <Label key={number} className="w-full">
              <span className="flex shrink-0 items-center gap-1">
                <RatingStars rating={number} />
                and up
              </span>
              <Radio
                wrapperClassName="ml-auto"
                value={number}
                aria-label={`${number} ${number === 1 ? "star" : "stars"} and up`}
                checked={number === searchParams.rating}
                readOnly
                onClick={() => updateParams(searchParams.rating === number ? { rating: undefined } : { rating: number })}
              />
            </Label>
          ))}
        </Fieldset>
      </BottomSheet>
    </>
  );
};
