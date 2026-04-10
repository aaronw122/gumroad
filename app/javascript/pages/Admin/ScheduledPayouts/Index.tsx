import { usePage, router } from "@inertiajs/react";
import React from "react";
import { cast } from "ts-safe-cast";

import { formatPriceCentsWithCurrencySymbol } from "$app/utils/currency";

import { AdminActionButton } from "$app/components/Admin/ActionButton";
import AdminEmptyState from "$app/components/Admin/EmptyState";
import { Button } from "$app/components/Button";
import { Pagination, type PaginationProps } from "$app/components/Pagination";

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

const STATUS_COLORS: Record<string, string> = {
  pending: "text-yellow-600",
  executed: "text-green-600",
  cancelled: "text-muted",
  flagged: "text-red-600",
  held: "text-orange-600",
};

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
      <h1 className="text-2xl font-bold">Scheduled Payouts</h1>

      <div className="flex gap-2">
        {[null, "pending", "flagged", "executed", "cancelled", "held"].map((status) => (
          <Button
            key={status ?? "all"}
            size="sm"
            color={current_status_filter === status ? "primary" : undefined}
            outline={current_status_filter !== status}
            onClick={() => onFilterStatus(status)}
          >
            {status ?? "All"}
          </Button>
        ))}
      </div>

      {scheduled_payouts.length === 0 ? (
        <AdminEmptyState message="No scheduled payouts found." />
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border text-left">
                <th className="p-2">User</th>
                <th className="p-2">Action</th>
                <th className="p-2">Amount</th>
                <th className="p-2">Status</th>
                <th className="p-2">Scheduled</th>
                <th className="p-2">Created by</th>
                <th className="p-2">Actions</th>
              </tr>
            </thead>
            <tbody>
              {scheduled_payouts.map((sp) => (
                <tr key={sp.external_id} className="border-b border-border">
                  <td className="p-2">
                    <a
                      href={Routes.admin_user_path(sp.user.external_id)}
                      className="text-link hover:underline"
                    >
                      {sp.user.name || sp.user.email}
                    </a>
                  </td>
                  <td className="p-2 capitalize">{sp.action}</td>
                  <td className="p-2">
                    {sp.payout_amount_cents != null
                      ? formatPriceCentsWithCurrencySymbol("usd", sp.payout_amount_cents, { symbolFormat: "short" })
                      : "-"}
                  </td>
                  <td className={`p-2 capitalize font-medium ${STATUS_COLORS[sp.status] ?? ""}`}>{sp.status}</td>
                  <td className="p-2">{new Date(sp.scheduled_at).toLocaleDateString()}</td>
                  <td className="p-2">{sp.created_by?.name ?? "-"}</td>
                  <td className="p-2">
                    <div className="flex gap-2">
                      {(sp.status === "pending" || sp.status === "flagged") && (
                        <>
                          <AdminActionButton
                            url={Routes.execute_admin_scheduled_payout_path(sp.external_id)}
                            label="Pay now"
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
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {pagination.pages > 1 && <Pagination pagination={pagination} onChangePage={onChangePage} />}
    </div>
  );
};

export default AdminScheduledPayoutsIndex;
