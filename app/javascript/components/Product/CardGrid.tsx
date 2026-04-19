import { Archive } from "@boxicons/react";
import { range } from "lodash-es";
import * as React from "react";

import { getSearchResults, ProductFilter, SearchRequest, SearchResults } from "$app/data/search";
import { PROFILE_SORT_KEYS, SORT_KEYS } from "$app/parsers/product";
import { classNames } from "$app/utils/classNames";
import { CurrencyCode, getShortCurrencySymbol } from "$app/utils/currency";
import { asyncVoid } from "$app/utils/promise";
import { AbortError, assertResponseError } from "$app/utils/request";

import { Button } from "$app/components/Button";
import { NumberInput } from "$app/components/NumberInput";
import { RatingStars } from "$app/components/RatingStars";
import { showAlert } from "$app/components/server-components/Alert";
import { Skeleton } from "$app/components/Skeleton";
import { CardContent, Card as UICard } from "$app/components/ui/Card";
import { Checkbox } from "$app/components/ui/Checkbox";
import { Details, DetailsToggle } from "$app/components/ui/Details";
import { Fieldset, FieldsetTitle } from "$app/components/ui/Fieldset";
import { Input } from "$app/components/ui/Input";
import { InputGroup } from "$app/components/ui/InputGroup";
import { Label } from "$app/components/ui/Label";
import { Pill } from "$app/components/ui/Pill";
import { Placeholder } from "$app/components/ui/Placeholder";
import { ProductCardGrid } from "$app/components/ui/ProductCardGrid";
import { Radio } from "$app/components/ui/Radio";
import { useDebouncedCallback } from "$app/components/useDebouncedCallback";
import { useOnChange } from "$app/components/useOnChange";

import { Card } from "./Card";

export const SORT_BY_LABELS = {
  default: "Default",
  highest_rated: "Highest rated",
  hot_and_new: "Hot and new",
  most_reviewed: "Most reviewed",
  newest: "Newest",
  page_layout: "Custom",
  price_asc: "Price (Low to High)",
  price_desc: "Price (High to Low)",
};

export type State = {
  params: SearchRequest;
  results: SearchResults | null;
  offset?: number | undefined;
};

export type Action =
  | { type: "set-params"; params: SearchRequest }
  | { type: "set-results"; results: SearchResults }
  | { type: "load-more" };

export const useSearchReducer = (initial: Omit<State, "offset">) => {
  const activeRequest = React.useRef<{ cancel: () => void } | null>(null);

  const [state, dispatch] = React.useReducer(
    (state: State, action: Action) => {
      switch (action.type) {
        case "set-params": {
          const params = {
            ...action.params,
            taxonomy: action.params.taxonomy === "discover" ? undefined : action.params.taxonomy,
          };
          return { params, results: null, offset: action.params.from };
        }
        case "set-results":
          return { ...state, results: action.results };
        case "load-more":
          if (
            !state.results ||
            state.results.total < (state.offset ?? 1) + state.results.products.length ||
            activeRequest.current
          )
            return state;
          return {
            ...state,
            params: { ...state.params, from: (state.offset ?? 1) + state.results.products.length },
          };
      }
    },
    { ...initial, offset: initial.params.from },
  );

  useOnChange(
    asyncVoid(async () => {
      try {
        const request = getSearchResults(state.params);
        activeRequest.current = request;
        const results = await request.response;
        dispatch({
          type: "set-results",
          results:
            state.results == null
              ? results
              : { ...results, products: [...state.results.products, ...results.products] },
        });
        activeRequest.current = null;
      } catch (e) {
        if (!(e instanceof AbortError)) {
          assertResponseError(e);
          showAlert("Something went wrong. Please try refreshing the page.", "error");
        }
      }
    }),
    [state.params],
  );
  return [state, dispatch] as const;
};

type Props = {
  state: State;
  dispatchAction: React.Dispatch<Action>;
  currencyCode: CurrencyCode;
  title?: string | null;
  hideFilters?: boolean;
  disableFilters?: boolean;
  defaults?: SearchRequest;
  hideSort?: boolean;
  prependFilters?: React.ReactNode;
  appendFilters?: React.ReactNode;
  pagination?: "scroll" | "button";
};

export const FilterCheckboxes = ({
  selection,
  setSelection,
  filters,
  disabled,
}: {
  filters: ProductFilter[];
  selection: string[];
  setSelection: (value: string[]) => void;
  disabled: boolean;
}) => {
  const [showingAll, setShowingAll] = React.useState(false);
  return (
    <>
      {(showingAll ? filters : filters.slice(0, 5)).map((option) => (
        <Label key={option.key} className="w-full">
          {option.key} ({option.doc_count})
          <Checkbox
            wrapperClassName="ml-auto"
            checked={selection.includes(option.key)}
            disabled={disabled}
            onChange={() =>
              setSelection(
                selection.includes(option.key)
                  ? selection.filter((type) => type !== option.key)
                  : [...selection, option.key],
              )
            }
          />
        </Label>
      ))}
      {filters.length > 5 && !showingAll ? (
        <button className="cursor-pointer underline all-unset" onClick={() => setShowingAll(true)}>
          Show more
        </button>
      ) : null}
    </>
  );
};

export const RatingFilterOptions = ({
  rating,
  onRatingChange,
}: {
  rating: number | undefined;
  onRatingChange: (rating: number | undefined) => void;
}) => (
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
          checked={number === rating}
          readOnly
          onClick={() => onRatingChange(rating === number ? undefined : number)}
        />
      </Label>
    ))}
  </Fieldset>
);

export type FilterDefinition = {
  key: string;
  title: string;
  triggerLabel: string;
  active: boolean;
  clear?: () => void;
  content: React.ReactNode;
  isVisible: boolean;
  hasData: boolean;
};

export const useDiscoverFilters = ({
  state,
  dispatchAction,
  defaults = {},
  currencyCode,
  hideSort,
  disableFilters,
}: {
  state: State;
  dispatchAction: React.Dispatch<Action>;
  defaults?: SearchRequest;
  currencyCode: CurrencyCode;
  hideSort?: boolean | undefined;
  disableFilters?: boolean | undefined;
}) => {
  const currencySymbol = getShortCurrencySymbol(currencyCode);
  const { params: searchParams } = state;

  const lastResultsRef = React.useRef(state.results);
  if (state.results != null) lastResultsRef.current = state.results;
  const results = state.results ?? lastResultsRef.current;

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

  const resetFilters = () => dispatchAction({ type: "set-params", params: defaults });

  let anyFilters = false;
  for (const key of Object.keys(searchParams))
    if (
      !["from", "curated_product_ids"].includes(key) &&
      searchParams[key] != null &&
      searchParams[key] !== defaults[key]
    )
      anyFilters = true;

  const uid = React.useId();
  const minPriceUid = React.useId();
  const maxPriceUid = React.useId();
  const onProfile = !!searchParams.user_id;

  const concatFoundAndNotFound = (
    resultsData: ProductFilter[] | undefined,
    searchedKeys: ProductFilter["key"][] | undefined,
  ): ProductFilter[] => {
    const foundData = resultsData ?? [];
    const notFoundKeys = searchedKeys?.filter((s) => !foundData.some((f) => f.key === s)) ?? [];
    return notFoundKeys.map((key) => ({ key, doc_count: 0 })).concat(foundData);
  };

  const sortLabels: Partial<Record<string, string>> = SORT_BY_LABELS;
  const selectedTagsCount = searchParams.tags?.length ?? 0;
  const selectedFiletypesCount = searchParams.filetypes?.length ?? 0;
  const sortActive = searchParams.sort !== defaults.sort && searchParams.sort != null;
  const priceActive = searchParams.min_price != null || searchParams.max_price != null;

  const priceLabel = (() => {
    const minSet = searchParams.min_price != null;
    const maxSet = searchParams.max_price != null;
    if (minSet && maxSet)
      return `${currencySymbol}${searchParams.min_price}\u2013${currencySymbol}${searchParams.max_price}`;
    if (minSet) return `${currencySymbol}${searchParams.min_price}+`;
    if (maxSet) return `Up to ${currencySymbol}${searchParams.max_price}`;
    return "Price";
  })();

  const filters: FilterDefinition[] = [
    {
      key: "sort",
      title: "Sort by",
      triggerLabel:
        sortActive && searchParams.sort ? `Sort: ${sortLabels[searchParams.sort] ?? searchParams.sort}` : "Sort by",
      active: sortActive,
      isVisible: !hideSort,
      hasData: true,
      ...(sortActive ? { clear: () => updateParams({ sort: defaults.sort }) } : {}),
      content: (
        <Fieldset role="group">
          {(onProfile ? PROFILE_SORT_KEYS : SORT_KEYS).map((key) => (
            <Label key={key} className="w-full">
              {SORT_BY_LABELS[key]}
              <Radio
                wrapperClassName="ml-auto"
                disabled={disableFilters}
                name={`${uid}-sortBy`}
                checked={(searchParams.sort ?? defaults.sort) === key}
                onChange={() => updateParams({ sort: key })}
              />
            </Label>
          ))}
        </Fieldset>
      ),
    },
    {
      key: "tags",
      title: "Tags",
      triggerLabel: selectedTagsCount > 0 ? `Tags (${selectedTagsCount})` : "Tags",
      active: selectedTagsCount > 0,
      isVisible: true,
      hasData: (results?.tags_data.length ?? 0) > 0 || selectedTagsCount > 0,
      ...(selectedTagsCount > 0 ? { clear: () => updateParams({ tags: undefined }) } : {}),
      content: (
        <Fieldset role="group">
          <Label className="w-full">
            All Products
            <Checkbox
              wrapperClassName="ml-auto"
              checked={!searchParams.tags?.length}
              disabled={disableFilters || !searchParams.tags?.length}
              onChange={() => updateParams({ tags: undefined })}
            />
          </Label>
          {results ? (
            <FilterCheckboxes
              filters={concatFoundAndNotFound(results.tags_data, searchParams.tags)}
              selection={searchParams.tags ?? []}
              setSelection={(tags) => updateParams({ tags })}
              disabled={disableFilters ?? false}
            />
          ) : null}
        </Fieldset>
      ),
    },
    {
      key: "contains",
      title: "Contains",
      triggerLabel: selectedFiletypesCount > 0 ? `Contains (${selectedFiletypesCount})` : "Contains",
      active: selectedFiletypesCount > 0,
      isVisible: true,
      hasData: (results?.filetypes_data.length ?? 0) > 0 || selectedFiletypesCount > 0,
      ...(selectedFiletypesCount > 0 ? { clear: () => updateParams({ filetypes: undefined }) } : {}),
      content: (
        <Fieldset role="group">
          {results ? (
            <FilterCheckboxes
              filters={concatFoundAndNotFound(results.filetypes_data, searchParams.filetypes)}
              selection={searchParams.filetypes ?? []}
              setSelection={(filetypes) => updateParams({ filetypes })}
              disabled={disableFilters ?? false}
            />
          ) : null}
        </Fieldset>
      ),
    },
    {
      key: "price",
      title: "Price",
      triggerLabel: priceLabel,
      active: priceActive,
      isVisible: true,
      hasData: true,
      ...(priceActive ? { clear: () => updateParams({ min_price: undefined, max_price: undefined }) } : {}),
      content: (
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
                {(inputProps) => <Input id={minPriceUid} placeholder="0" disabled={disableFilters} {...inputProps} />}
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
                {(inputProps) => <Input id={maxPriceUid} placeholder="∞" disabled={disableFilters} {...inputProps} />}
              </NumberInput>
            </InputGroup>
          </Fieldset>
        </div>
      ),
    },
    {
      key: "rating",
      title: "Rating",
      triggerLabel: searchParams.rating != null ? `${searchParams.rating}+ stars` : "Rating",
      active: searchParams.rating != null,
      isVisible: true,
      hasData: true,
      ...(searchParams.rating != null ? { clear: () => updateParams({ rating: undefined }) } : {}),
      content: (
        <RatingFilterOptions rating={searchParams.rating} onRatingChange={(rating) => updateParams({ rating })} />
      ),
    },
  ];

  return { filters, updateParams, resetFilters, anyFilters, results };
};

export const CardGrid = ({
  state,
  dispatchAction,
  title,
  hideFilters,
  disableFilters,
  currencyCode,
  defaults = {},
  prependFilters,
  appendFilters,
  hideSort,
  pagination = "scroll",
}: Props) => {
  const gridRef = React.useRef<HTMLDivElement | null>(null);
  const { results } = state;

  const { filters, resetFilters, anyFilters } = useDiscoverFilters({
    state,
    dispatchAction,
    defaults,
    currencyCode,
    hideSort,
    disableFilters,
  });

  React.useEffect(() => {
    if (pagination !== "scroll") return;
    const observer = new IntersectionObserver((e) => {
      if (e[0]?.isIntersecting) dispatchAction({ type: "load-more" });
    });
    if (results?.products && gridRef.current?.lastElementChild) observer.observe(gridRef.current.lastElementChild);
    return () => observer.disconnect();
  }, [pagination, results?.products]);

  const [tagsOpen, setTagsOpen] = React.useState(false);
  const [filetypesOpen, setFiletypesOpen] = React.useState(false);
  const localOpenState: Record<string, { open: boolean; onToggle: (v: boolean) => void }> = {
    tags: { open: tagsOpen, onToggle: setTagsOpen },
    contains: { open: filetypesOpen, onToggle: setFiletypesOpen },
  };

  return (
    <div
      className={classNames(
        "grid grid-cols-1 items-start gap-x-16 gap-y-8",
        !hideFilters && "lg:grid-cols-[var(--grid-cols-sidebar)]",
      )}
    >
      {hideFilters ? null : (
        <UICard className="overflow-y-auto lg:sticky lg:inset-y-4 lg:max-h-[calc(100vh-2rem)]" aria-label="Filters">
          <CardContent asChild>
            <header>
              {title ?? "Filters"}
              {anyFilters ? (
                <div className="grow text-right">
                  <button className="cursor-pointer underline all-unset" onClick={resetFilters}>
                    Clear
                  </button>
                </div>
              ) : null}
            </header>
          </CardContent>
          {prependFilters}
          {filters.map((filter) => {
            const local = localOpenState[filter.key];
            const shouldShow = filter.isVisible && (filter.hasData || local?.open);
            if (!shouldShow) return null;
            return (
              <CardContent key={filter.key} asChild details>
                <Details {...(local ? { open: local.open, onToggle: local.onToggle } : {})}>
                  <DetailsToggle chevronPosition="right" className="grow">
                    {filter.title}
                  </DetailsToggle>
                  {filter.content}
                </Details>
              </CardContent>
            );
          })}
          {appendFilters}
        </UICard>
      )}
      {results?.products.length === 0 ? (
        <Placeholder>
          <Archive pack="filled" className="size-5" />
          No products found
        </Placeholder>
      ) : (
        <div>
          <ProductCardGrid ref={gridRef}>
            {results?.products.map((result, idx) => <Card key={result.permalink} product={result} eager={idx < 4} />) ??
              Array(6)
                .fill(0)
                .map((_, i) => <Skeleton key={i} className="h-75 sm:h-95" />)}
          </ProductCardGrid>
          {pagination === "button" &&
          !((state.results?.total ?? 0) < (state.offset ?? 1) + (state.results?.products.length ?? 0)) ? (
            <div className="mt-8 w-full text-center">
              <Button onClick={() => dispatchAction({ type: "load-more" })}>Load more</Button>
            </div>
          ) : null}
        </div>
      )}
    </div>
  );
};
