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
end
