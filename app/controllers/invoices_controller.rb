class InvoicesController < ApplicationController
  def index
    @invoices = Invoice.order(issue_date: :desc)
  end
end
