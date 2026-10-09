# frozen_string_literal: true

class PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_invoice, only: [:create, :destroy]

  def create
    if @invoice.invoice_type != "sale"
      redirect_back fallback_location: invoices_path, status: :see_other,
                    alert: "Receiver of invoice cannot log payments. Only the issuer can log payments."
      return
    end

    if @invoice.has_associated_credit_note?
      redirect_back fallback_location: invoices_path, status: :see_other,
                    alert: "Cannot log payments on an invoice with an associated credit note."
      return
    end

    if @invoice.status == "draft" || @invoice.quote?
      redirect_back fallback_location: invoices_path, status: :see_other,
                    alert: "Draft invoices and quotes cannot receive payments."
      return
    end

    payment_params = params.require(:payment).permit(:payment_method, :reference_number, :payment_date, :amount, :notes)
    @payment = @invoice.payments.build(payment_params)
    @payment.user = current_user

    ActiveRecord::Base.transaction do
      if @payment.save
        new_total_paid = @invoice.payments.sum(:amount).to_f
        is_fully_paid = (new_total_paid >= @invoice.grand_total - 0.001)
        new_status = is_fully_paid ? "paid" : "partially_paid"
        @invoice.update!(status: new_status)

        # Synchronize counterpart purchase invoice if present
        sync_purchase_invoice_payment(@invoice, @payment, new_status)

        # Log activity
        ActivityLogger.log_invoice_payment_recorded(@invoice, current_user, @payment)

        # Notify counterparty
        counterparty = @invoice.recipient_company&.user
        if counterparty
          if is_fully_paid
            NotificationService.notify_invoice_paid(@invoice, counterparty, current_user)
          else
            NotificationService.notify_invoice_partially_paid(@invoice, counterparty, current_user, @payment)
          end
        end

        target_path = resolve_redirect_path(@invoice)
        status_label = is_fully_paid ? "Paid" : "Partially Paid"
        redirect_to target_path, status: :see_other,
                    notice: "Payment of #{@payment.formatted_amount} recorded via #{@payment.payment_method}. Invoice marked as #{status_label}."
      else
        target_path = resolve_redirect_path(@invoice)
        redirect_to target_path, status: :see_other,
                    alert: "Failed to record payment: #{@payment.errors.full_messages.join(', ')}"
      end
    end
  end

  def destroy
    @payment = @invoice.payments.find(params[:id])

    ActiveRecord::Base.transaction do
      old_status = @invoice.status
      payment_amount = @payment.amount
      payment_formatted = @payment.formatted_amount
      payment_ref = @payment.reference_number
      payment_method = @payment.payment_method

      @payment.destroy!

      remaining_paid = @invoice.payments.sum(:amount).to_f
      new_status = if remaining_paid > 0
                     (remaining_paid >= @invoice.grand_total - 0.001) ? "paid" : "partially_paid"
                   else
                     "sent"
                   end
      @invoice.update!(status: new_status)

      ActivityLogger.log(
        trackable: @invoice,
        actor: current_user,
        action: "payment_removed",
        description: "#{current_user.display_name} removed payment receipt of #{payment_formatted} (Ref: #{payment_ref})",
        metadata: {
          invoice_number: @invoice.invoice_number,
          removed_amount: payment_amount.to_f,
          payment_method: payment_method,
          reference_number: payment_ref,
          status: new_status
        }
      )

      if old_status != new_status
        ActivityLogger.log_invoice_status_changed(@invoice, current_user, old_status, new_status)
      end

      # Sync counterpart purchase invoice
      sale_company_id = @invoice.user.company&.id || @invoice.user.companies.first&.id
      purchase_invoice = Invoice.find_by(
        invoice_number: @invoice.invoice_number,
        invoice_type: "purchase",
        invoice_category: @invoice.invoice_category,
        sale_from_id: sale_company_id,
        recipient_company_id: @invoice.recipient_company_id
      )
      if purchase_invoice
        prev_p_status = purchase_invoice.status
        purchase_invoice.update!(status: new_status)
        # Delete counterpart payment if found by reference number and amount
        counter_payment = purchase_invoice.payments.find_by(
          reference_number: payment_ref,
          amount: payment_amount
        )
        counter_payment&.destroy

        ActivityLogger.log(
          trackable: purchase_invoice,
          actor: current_user,
          action: "payment_removed",
          description: "#{current_user.display_name} removed payment receipt of #{payment_formatted} (Ref: #{payment_ref})",
          metadata: {
            invoice_number: purchase_invoice.invoice_number,
            removed_amount: payment_amount.to_f,
            payment_method: payment_method,
            reference_number: payment_ref,
            status: new_status
          }
        )

        if prev_p_status != new_status
          ActivityLogger.log_invoice_status_changed(purchase_invoice, current_user, prev_p_status, new_status)
        end
      end

      target_path = resolve_redirect_path(@invoice)
      respond_to do |format|
        format.html { redirect_to target_path, status: :see_other, notice: "Payment receipt removed. Invoice status updated to #{new_status.titleize}." }
        format.json { render json: { success: true, message: "Payment receipt removed. Invoice status updated to #{new_status.titleize}." } }
      end
    end
  end

  private

  def set_invoice
    @invoice = current_user.invoices.find(params[:invoice_id])
  end

  def resolve_redirect_path(invoice)
    return params[:redirect_url] if params[:redirect_url].present?
    if params[:from_show] == "true"
      invoice_path(invoice, tab: params[:tab])
    else
      invoices_path(tab: params[:tab] || "sales-invoices")
    end
  end

  def sync_purchase_invoice_payment(sale_invoice, payment, new_status)
    sale_company_id = sale_invoice.user.company&.id || sale_invoice.user.companies.first&.id
    purchase_invoice = Invoice.find_by(
      invoice_number: sale_invoice.invoice_number,
      invoice_type: "purchase",
      invoice_category: sale_invoice.invoice_category,
      sale_from_id: sale_company_id,
      recipient_company_id: sale_invoice.recipient_company_id
    )
    return unless purchase_invoice

    purchase_invoice.update!(status: new_status)
    counter_payment = purchase_invoice.payments.build(
      payment_method: payment.payment_method,
      reference_number: payment.reference_number,
      payment_date: payment.payment_date,
      amount: payment.amount,
      notes: payment.notes
    )
    counter_payment.user = purchase_invoice.user
    counter_payment.save(validate: false)
    ActivityLogger.log_invoice_payment_recorded(purchase_invoice, current_user, payment)
  end
end
