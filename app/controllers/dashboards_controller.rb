# frozen_string_literal: true

class DashboardsController < ApplicationController
  before_action :authenticate_user!

  def index
    @time_frame = params[:time_frame].presence || "this_month"
    @currency = params[:currency].presence || "all"
    @dashboard_data = calculate_dashboard_metrics(@time_frame, @currency)

    respond_to do |format|
      format.html
      format.json { render json: @dashboard_data }
    end
  end

  def analytics_data
    time_frame = params[:time_frame].presence || "this_month"
    currency = params[:currency].presence || "all"
    data = calculate_dashboard_metrics(time_frame, currency)
    render json: data
  end

  private

  def calculate_dashboard_metrics(time_frame, selected_currency)
    range, prev_range, range_label = resolve_time_range(time_frame, params[:start_date], params[:end_date])

    # Company IDs associated with the current user
    my_company_ids = (current_user.companies.pluck(:id) << current_user.company_id).compact.uniq

    # Invoices base scope (excluding quotes unless specified)
    base_invoices = current_user.invoices
                                .includes(:recipient_company, :sale_from)
                                .where(invoice_category: ["standard", "credit_note"])
                                .where(archived: [false, nil])

    if selected_currency.present? && selected_currency != "all"
      base_invoices = base_invoices.where(currency: selected_currency)
    end

    # Current period and previous period scopes
    current_invoices = base_invoices.where(issue_date: range)
    prev_invoices = base_invoices.where(issue_date: prev_range)

    # 1. SALES / REVENUE METRICS
    sales_current = current_invoices.where(invoice_type: "sale")
    sales_prev = prev_invoices.where(invoice_type: "sale")

    total_sales_revenue = sum_invoice_totals(sales_current.where(status: ["approved", "paid"]))
    prev_sales_revenue = sum_invoice_totals(sales_prev.where(status: ["approved", "paid"]))
    sales_revenue_growth = calculate_percentage_change(total_sales_revenue, prev_sales_revenue)

    total_sales_count = sales_current.count
    paid_sales_count = sales_current.where(status: "paid").count
    pending_sales_count = sales_current.where(status: ["sent", "pending", "draft"]).count

    # Receivables (Outstanding unpaid sales)
    unpaid_sales_scope = base_invoices.where(invoice_type: "sale", status: ["sent", "pending", "approved"])
    total_receivables = sum_invoice_totals(unpaid_sales_scope)
    receivables_count = unpaid_sales_scope.count

    # 2. PURCHASES / EXPENSES METRICS
    purchases_current = current_invoices.where(invoice_type: "purchase")
    purchases_prev = prev_invoices.where(invoice_type: "purchase")

    total_purchases_expense = sum_invoice_totals(purchases_current.where(status: ["approved", "paid"]))
    prev_purchases_expense = sum_invoice_totals(purchases_prev.where(status: ["approved", "paid"]))
    purchases_growth = calculate_percentage_change(total_purchases_expense, prev_purchases_expense)

    total_purchases_count = purchases_current.count
    paid_purchases_count = purchases_current.where(status: "paid").count

    # Payables (Outstanding unpaid purchases)
    unpaid_purchases_scope = base_invoices.where(invoice_type: "purchase", status: ["sent", "pending", "approved"])
    total_payables = sum_invoice_totals(unpaid_purchases_scope)
    payables_count = unpaid_purchases_scope.count

    # 3. NET OPERATING CASH FLOW & MARGIN
    net_operating_income = total_sales_revenue - total_purchases_expense
    prev_net_income = prev_sales_revenue - prev_purchases_expense
    net_income_growth = calculate_percentage_change(net_operating_income, prev_net_income)
    profit_margin = total_sales_revenue.positive? ? ((net_operating_income / total_sales_revenue) * 100).round(1) : 0.0

    # 4. SUBSCRIPTIONS & RECURRING REVENUE (MRR / ARR)
    all_parents = current_user.invoices.where(recurring_parent_invoice_id: nil)
    subscription_contracts = all_parents.select(&:subscription_contract?)
    
    active_subscriptions_count = 0
    total_mrr = 0.0

    subscription_contracts.each do |invoice|
      if invoice.line_items_data.is_a?(Array)
        invoice.line_items_data.each_with_index do |item, idx|
          if item.is_a?(Hash) && item['optional_fields'].is_a?(Hash) && item['optional_fields'].keys.any? { |k| k.to_s.start_with?('subscription') }
            wrapper = SubscriptionItemWrapper.new(invoice, item, idx)
            if wrapper.subscription_active?
              active_subscriptions_count += 1
              cycle = invoice.extract_subscription_field(item, 'billing_cycle') || 'monthly'
              item_total = wrapper.total_amount
              mrr_val = case cycle.downcase
                        when 'monthly' then item_total
                        when 'yearly', 'annual' then item_total / 12.0
                        when 'quarterly' then item_total / 3.0
                        when 'weekly' then item_total * 4.33
                        else item_total
                        end
              total_mrr += mrr_val
            end
          end
        end
      end
    end

    total_arr = total_mrr * 12.0

    # 5. TAX SUBMISSIONS & FORM 2307 COMPLIANCE METRICS
    tax_scope = TaxSubmission.where(company_id: my_company_ids)
                             .or(TaxSubmission.where(email: current_user.email))
    tax_total_count = tax_scope.count
    tax_reviewed_count = tax_scope.where(reviewed: true).count
    tax_processed_count = tax_scope.where(processed: true).count
    tax_pending_count = tax_scope.where(reviewed: [false, nil], processed: [false, nil], archived: [false, nil]).count
    tax_compliance_rate = tax_total_count.positive? ? ((tax_processed_count.to_f / tax_total_count) * 100).round(1) : 100.0

    # 6. CHART DATASETS
    trend_data = build_revenue_expense_trends(base_invoices, time_frame)

    sales_status_counts = aggregate_status_counts(sales_current)
    purchases_status_counts = aggregate_status_counts(purchases_current)

    top_customers = calculate_top_partners(sales_current, :recipient_company)
    top_vendors = calculate_top_partners(purchases_current, :sale_from)

    # 7. RECENT ACTIVITIES & URGENT ACTION ITEMS
    recent_invoices = current_user.invoices
                                  .includes(:recipient_company, :sale_from)
                                  .order(created_at: :desc)
                                  .limit(8)

    recent_submissions = tax_scope.includes(:company, :invoice)
                                  .order(created_at: :desc)
                                  .limit(5)

    urgent_actions = build_urgent_action_items(base_invoices, tax_scope)

    # Available Currencies for filtering
    available_currencies = current_user.invoices.where.not(currency: [nil, ""]).pluck(:currency).uniq
    available_currencies = ["USD", "PHP", "EUR"] if available_currencies.blank?

    {
      time_frame: time_frame,
      range_label: range_label,
      currency: selected_currency,
      available_currencies: available_currencies,
      kpis: {
        total_sales_revenue: total_sales_revenue.round(2),
        sales_revenue_growth: sales_revenue_growth,
        total_sales_count: total_sales_count,
        paid_sales_count: paid_sales_count,
        pending_sales_count: pending_sales_count,
        total_receivables: total_receivables.round(2),
        receivables_count: receivables_count,

        total_purchases_expense: total_purchases_expense.round(2),
        purchases_growth: purchases_growth,
        total_purchases_count: total_purchases_count,
        paid_purchases_count: paid_purchases_count,
        total_payables: total_payables.round(2),
        payables_count: payables_count,

        net_operating_income: net_operating_income.round(2),
        net_income_growth: net_income_growth,
        profit_margin: profit_margin,

        active_subscriptions_count: active_subscriptions_count,
        total_mrr: total_mrr.round(2),
        total_arr: total_arr.round(2),

        tax_total_count: tax_total_count,
        tax_reviewed_count: tax_reviewed_count,
        tax_processed_count: tax_processed_count,
        tax_pending_count: tax_pending_count,
        tax_compliance_rate: tax_compliance_rate,
        locations_count: current_user.locations.count,
        networks_count: current_user.networks.count
      },
      charts: {
        trends: trend_data,
        sales_status: sales_status_counts,
        purchases_status: purchases_status_counts,
        top_customers: top_customers,
        top_vendors: top_vendors,
        tax_compliance: {
          processed: tax_processed_count,
          reviewed: [tax_reviewed_count - tax_processed_count, 0].max,
          pending: tax_pending_count
        }
      },
      recent_invoices: recent_invoices.as_json(
        only: [:id, :invoice_number, :invoice_type, :invoice_category, :status, :currency, :issue_date, :created_at],
        methods: [:grand_total],
        include: {
          recipient_company: { only: [:id, :name] },
          sale_from: { only: [:id, :name] }
        }
      ),
      recent_tax_submissions: recent_submissions.as_json(
        only: [:id, :email, :details, :reviewed, :processed, :archived, :created_at],
        include: {
          company: { only: [:id, :name] },
          invoice: { only: [:id, :invoice_number] }
        }
      ),
      urgent_actions: urgent_actions
    }
  end

  def resolve_time_range(time_frame, custom_start = nil, custom_end = nil)
    now = Time.current
    case time_frame
    when "7d"
      range = 6.days.ago.beginning_of_day..now.end_of_day
      prev_range = 13.days.ago.beginning_of_day..7.days.ago.end_of_day
      [range, prev_range, "Last 7 Days"]
    when "30d"
      range = 29.days.ago.beginning_of_day..now.end_of_day
      prev_range = 59.days.ago.beginning_of_day..30.days.ago.end_of_day
      [range, prev_range, "Last 30 Days"]
    when "last_month"
      range = 1.month.ago.beginning_of_month..1.month.ago.end_of_month
      prev_range = 2.months.ago.beginning_of_month..2.months.ago.end_of_month
      [range, prev_range, "Last Month (#{1.month.ago.strftime('%B %Y')})"]
    when "this_quarter"
      range = now.beginning_of_quarter..now.end_of_quarter
      prev_range = 1.quarter.ago.beginning_of_quarter..1.quarter.ago.end_of_quarter
      [range, prev_range, "This Quarter (Q#{(now.month - 1) / 3 + 1} #{now.year})"]
    when "ytd"
      range = now.beginning_of_year..now.end_of_day
      prev_range = 1.year.ago.beginning_of_year..1.year.ago.end_of_day
      [range, prev_range, "Year to Date (#{now.year})"]
    when "all_time"
      range = 10.years.ago.beginning_of_day..now.end_of_day
      prev_range = 20.years.ago.beginning_of_day..10.years.ago.end_of_day
      [range, prev_range, "All Time"]
    when "custom"
      start_d = Date.parse(custom_start).beginning_of_day rescue 30.days.ago.beginning_of_day
      end_d = Date.parse(custom_end).end_of_day rescue now.end_of_day
      duration = (end_d - start_d)
      prev_range = (start_d - duration)..(start_d - 1.second)
      [start_d..end_d, prev_range, "Custom (#{start_d.strftime('%b %d')} - #{end_d.strftime('%b %d, %Y')})"]
    else # "this_month" default
      range = now.beginning_of_month..now.end_of_month
      prev_range = 1.month.ago.beginning_of_month..1.month.ago.end_of_month
      [range, prev_range, "This Month (#{now.strftime('%B %Y')})"]
    end
  end

  def sum_invoice_totals(invoices_relation)
    invoices_relation.to_a.sum(&:grand_total)
  end

  def calculate_percentage_change(current_val, previous_val)
    return 0.0 if previous_val.zero? && current_val.zero?
    return 100.0 if previous_val.zero? && current_val.positive?
    return -100.0 if previous_val.positive? && current_val.zero?

    (((current_val - previous_val).to_f / previous_val) * 100).round(1)
  end

  def aggregate_status_counts(invoices_relation)
    counts = {
      paid: invoices_relation.where(status: "paid").count,
      approved: invoices_relation.where(status: "approved").count,
      sent: invoices_relation.where(status: "sent").count,
      pending: invoices_relation.where(status: "pending").count,
      draft: invoices_relation.where(status: "draft").count,
      rejected: invoices_relation.where(status: "rejected").count
    }
    counts[:total] = counts.values.sum
    counts
  end

  def build_revenue_expense_trends(relation, time_frame)
    labels = []
    revenue_series = []
    expense_series = []
    net_flow_series = []

    case time_frame
    when "7d"
      7.times.reverse_each do |i|
        day_start = i.days.ago.beginning_of_day
        day_end = i.days.ago.end_of_day
        labels << day_start.strftime("%a (%b %d)")
        
        day_sales = sum_invoice_totals(relation.where(invoice_type: "sale", status: ["approved", "paid"], issue_date: day_start..day_end))
        day_purchases = sum_invoice_totals(relation.where(invoice_type: "purchase", status: ["approved", "paid"], issue_date: day_start..day_end))
        
        revenue_series << day_sales.round(2)
        expense_series << day_purchases.round(2)
        net_flow_series << (day_sales - day_purchases).round(2)
      end
    when "30d"
      4.times.reverse_each do |i|
        week_start = (i * 7 + 6).days.ago.beginning_of_day
        week_end = (i * 7).days.ago.end_of_day
        labels << "Week #{4 - i} (#{week_start.strftime('%b %d')})"

        w_sales = sum_invoice_totals(relation.where(invoice_type: "sale", status: ["approved", "paid"], issue_date: week_start..week_end))
        w_purchases = sum_invoice_totals(relation.where(invoice_type: "purchase", status: ["approved", "paid"], issue_date: week_start..week_end))

        revenue_series << w_sales.round(2)
        expense_series << w_purchases.round(2)
        net_flow_series << (w_sales - w_purchases).round(2)
      end
    else
      # Default 6-month view
      6.times.reverse_each do |i|
        month_start = i.months.ago.beginning_of_month
        month_end = i.months.ago.end_of_month
        labels << month_start.strftime("%b %Y")

        m_sales = sum_invoice_totals(relation.where(invoice_type: "sale", status: ["approved", "paid"], issue_date: month_start..month_end))
        m_purchases = sum_invoice_totals(relation.where(invoice_type: "purchase", status: ["approved", "paid"], issue_date: month_start..month_end))

        revenue_series << m_sales.round(2)
        expense_series << m_purchases.round(2)
        net_flow_series << (m_sales - m_purchases).round(2)
      end
    end

    {
      labels: labels,
      revenue: revenue_series,
      expenses: expense_series,
      net_flow: net_flow_series
    }
  end

  def calculate_top_partners(relation, association_name)
    grouped = {}
    relation.includes(association_name).where(status: ["approved", "paid"]).find_each do |invoice|
      partner = invoice.send(association_name)
      partner_name = partner&.name || "Direct Client / Non-Network"
      grouped[partner_name] ||= 0.0
      grouped[partner_name] += invoice.grand_total
    end

    top = grouped.sort_by { |_k, v| -v }.first(5)
    total_amount = top.sum { |_k, v| v }

    top.map do |name, amount|
      {
        name: name,
        amount: amount.round(2),
        percentage: total_amount.positive? ? ((amount / total_amount) * 100).round(1) : 0.0
      }
    end
  end

  def build_urgent_action_items(invoices_relation, tax_scope)
    actions = []

    # 1. Invoices pending review/approval
    pending_approval_invoices = invoices_relation.where(status: "pending").count
    if pending_approval_invoices.positive?
      actions << {
        type: "warning",
        icon: "fa-clock",
        title: "#{pending_approval_invoices} Pending #{'Invoice'.pluralize(pending_approval_invoices)}",
        description: "Invoices awaiting payment or partner approval",
        link_text: "Review Invoices",
        link_url: "/invoices"
      }
    end

    # 2. Tax submissions awaiting processing
    pending_tax = tax_scope.where(reviewed: [false, nil], processed: [false, nil], archived: [false, nil]).count
    if pending_tax.positive?
      actions << {
        type: "danger",
        icon: "fa-file-shield",
        title: "#{pending_tax} Tax #{'Submission'.pluralize(pending_tax)} Awaiting Review",
        description: "Form 2307 documents ready for verification",
        link_text: "Open Taxes Hub",
        link_url: "/tax_submissions/home"
      }
    end

    # 3. Draft invoices that can be sent
    drafts = invoices_relation.where(status: "draft").count
    if drafts.positive?
      actions << {
        type: "info",
        icon: "fa-pen-to-square",
        title: "#{drafts} Draft #{'Invoice'.pluralize(drafts)}",
        description: "Unsent draft invoices ready for finalization",
        link_text: "Open Drafts",
        link_url: "/invoices"
      }
    end

    actions
  end
end
