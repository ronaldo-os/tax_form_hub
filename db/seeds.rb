superadmin = User.find_or_create_by!(email: ENV['SUPERADMIN_EMAIL']) do |user|
  user.password = ENV['SUPERADMIN_PASSWORD']
  user.password_confirmation = ENV['SUPERADMIN_PASSWORD']
  user.role = 'superadmin'
  user.confirmed_at = Time.current if user.respond_to?(:confirmed_at)
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

puts "Superadmin created: #{superadmin.email}"
