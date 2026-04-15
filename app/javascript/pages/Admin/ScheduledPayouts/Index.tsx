import { usePage, router } from "@inertiajs/react";
import React from "react";
import { cast } from "ts-safe-cast";

import { formatPriceCentsWithCurrencySymbol } from "$app/utils/currency";

import { AdminActionButton } from "$app/components/Admin/ActionButton";
import AdminEmptyState from "$app/components/Admin/EmptyState";
import { Button } from "$app/components/Button";
import { Pagination, type PaginationProps } from "$app/components/Pagination";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "$app/components/ui/Table";

type ScheduledPayoutUser = {
  external_id: string;
  email: string;
  name: string | null;
};

type ScheduledPayout = {
  external_id: string;
  action: "refund" | "payout" | "hold";
  status: "pending" | "executed" | "cancelled" | "flagged" | "held";
  delay_days: number;
  scheduled_at: string;
  executed_at: string | null;
  payout_amount_cents: number | null;
  created_at: string;
  user: ScheduledPayoutUser;
  created_by: { name: string } | null;
};

type PageProps = {
  scheduled_payouts: ScheduledPayout[];
  pagination: PaginationProps;
  current_status_filter: string | null;
};

const STATUS_BADGE_STYLES: Record<string, string> = {
  pending: "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200",
  executed: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200",
  cancelled: "bg-filled text-muted",
  flagged: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200",
  held: "bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200",
};

const StatusBadge = ({ status }: { status: string }) => (
  <span
    className={`inline-flex items-center rounded px-2 py-0.5 text-xs font-medium capitalize ${STATUS_BADGE_STYLES[status] ?? ""}`}
  >
    {status}
  </span>
);

const AdminScheduledPayoutsIndex = () => {
  const { scheduled_payouts, pagination, current_status_filter } = cast<PageProps>(usePage().props);

  const onChangePage = (page: number) => {
    router.reload({ data: { page: page.toString(), status: current_status_filter ?? undefined } });
  };

  const onFilterStatus = (status: string | null) => {
    router.reload({ data: { status: status ?? undefined } });
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex gap-2">
        {[null, "pending", "flagged", "executed", "cancelled", "held"].map((status) => (
          <Button
            key={status ?? "all"}
            size="sm"
            color={current_status_filter === status ? "primary" : undefined}
            outline={current_status_filter !== status}
            onClick={() => onFilterStatus(status)}
          >
            {status ? status.charAt(0).toUpperCase() + status.slice(1) : "All"}
          </Button>
        ))}
      </div>

      {scheduled_payouts.length === 0 ? (
        <AdminEmptyState message="No scheduled payouts found." />
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>User</TableHead>
              <TableHead>Action</TableHead>
              <TableHead>Amount</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Scheduled</TableHead>
              <TableHead>Created by</TableHead>
              <TableHead>Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {scheduled_payouts.map((sp) => (
              <TableRow key={sp.external_id}>
                <TableCell>
                  <a href={Routes.admin_user_path(sp.user.external_id)} className="hover:underline">
                    {sp.user.name || sp.user.email}
                  </a>
                </TableCell>
                <TableCell className="capitalize">{sp.action}</TableCell>
                <TableCell>
                  {sp.payout_amount_cents != null
                    ? formatPriceCentsWithCurrencySymbol("usd", sp.payout_amount_cents, { symbolFormat: "short" })
                    : "-"}
                </TableCell>
                <TableCell>
                  <StatusBadge status={sp.status} />
                </TableCell>
                <TableCell>{new Date(sp.scheduled_at).toLocaleDateString()}</TableCell>
                <TableCell>{sp.created_by?.name ?? "-"}</TableCell>
                <TableCell>
                  {(sp.status === "pending" || sp.status === "flagged") && (
                    <div className="flex gap-2">
                      <AdminActionButton
                        url={Routes.execute_admin_scheduled_payout_path(sp.external_id)}
                        label={sp.action === "refund" ? "Refund now" : sp.action === "hold" ? "Hold now" : "Pay now"}
                        confirm_message={`Execute ${sp.action} for ${sp.user.name || sp.user.email}?`}
                        success_message="Executed"
                      />
                      <AdminActionButton
                        url={Routes.cancel_admin_scheduled_payout_path(sp.external_id)}
                        label="Cancel"
                        confirm_message={`Cancel scheduled ${sp.action} for ${sp.user.name || sp.user.email}?`}
                        success_message="Cancelled"
                        color="danger"
                        outline
                      />
                    </div>
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}

      {pagination.pages > 1 && <Pagination pagination={pagination} onChangePage={onChangePage} />}
    </div>
  );
};

export default AdminScheduledPayoutsIndex;
