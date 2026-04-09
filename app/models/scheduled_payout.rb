# frozen_string_literal: true

class ScheduledPayout < ApplicationRecord
  include ExternalId

  ACTIONS = %w[refund payout hold].freeze
  STATUSES = %w[pending executed cancelled flagged].freeze

  AUTO_PAYOUT_THRESHOLD_CENTS = 100_000

  belongs_to :user
  belongs_to :created_by, class_name: "User", optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :delay_days, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :scheduled_at, presence: true

  scope :pending, -> { where(status: "pending") }
  scope :executed, -> { where(status: "executed") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :flagged, -> { where(status: "flagged") }
  scope :due, -> { pending.where(scheduled_at: ..Time.current) }
  scope :for_user, ->(user) { where(user: user) }

  before_validation :set_scheduled_at, on: :create

  def execute!
    raise "Cannot execute a #{status} scheduled payout" if status != "pending"

    if action == "payout" && payout_amount_cents.present? && payout_amount_cents > AUTO_PAYOUT_THRESHOLD_CENTS
      flag_for_review!
      return
    end

    transaction do
      case action
      when "refund"
        RefundUnpaidPurchasesWorker.perform_async(user_id, created_by_id)
      when "payout"
        payout_date = Date.yesterday
        Payouts.create_instant_payouts_for_balances_up_to_date_for_users(payout_date, [user], from_admin: true)
      when "hold"
        return
      end

      update!(status: "executed", executed_at: Time.current)
    end
  end

  def cancel!
    raise "Cannot cancel a #{status} scheduled payout" if !%w[pending flagged].include?(status)

    update!(status: "cancelled")
  end

  def flag_for_review!
    raise "Cannot flag a #{status} scheduled payout" if status != "pending"

    update!(status: "flagged")
  end

  def pending?
    status == "pending"
  end

  def executed?
    status == "executed"
  end

  def cancelled?
    status == "cancelled"
  end

  def flagged?
    status == "flagged"
  end

  private
    def set_scheduled_at
      self.scheduled_at ||= delay_days.days.from_now if delay_days.present?
    end
end
