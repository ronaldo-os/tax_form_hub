module TaxSubmissionsHelper
  def tax_submission_status_text(submission)
    return "N/A" unless submission

    if submission.reviewed? && submission.processed?
      "Processed & Reviewed"
    elsif submission.reviewed?
      "Reviewed"
    elsif submission.processed?
      "Processed"
    else
      "Pending"
    end
  end

  # Returns the allowed bulk action keys for a tax submission matching its row Actions dropdown.
  def allowed_tax_submission_bulk_actions(submission, archived_table = false, is_incoming = false)
    return [] unless submission

    actions = []
    actions << (archived_table ? "unarchive" : "archive")
    # Delete is only available if not reviewed/processed (and not an incoming submission without delete)
    actions << "destroy" unless is_incoming || submission.processed? || submission.reviewed?
    actions
  end
end
