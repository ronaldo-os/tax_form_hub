superadmin = User.find_or_initialize_by(email: ENV['SUPERADMIN_EMAIL'])

superadmin.password              = ENV['SUPERADMIN_PASSWORD']
superadmin.password_confirmation = ENV['SUPERADMIN_PASSWORD']
superadmin.role                  = 'superadmin'
superadmin.confirmed_at          = Time.current if superadmin.respond_to?(:confirmed_at)
superadmin.save!

if superadmin.previously_new_record?
  puts "✅ Superadmin created: #{superadmin.email}"
else
  puts "♻️ Superadmin updated: #{superadmin.email}"
end

company_name = ENV['SUPERADMIN_COMPANY_NAME']
existing_company = Company.find_by(name: company_name)

if existing_company
  superadmin.update!(company: existing_company)
  puts "✅ Linked Superadmin to existing company: #{existing_company.name}"
else
  company = Company.create!(name: company_name, user: superadmin)
  superadmin.update!(company: company)
  puts "✅ Company created and linked to Superadmin: #{company.name}"
end
