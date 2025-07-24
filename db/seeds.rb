superadmin = User.find_or_create_by!(email: ENV['SUPERADMIN_EMAIL']) do |user|
  user.password = ENV['SUPERADMIN_PASSWORD']
  user.password_confirmation = ENV['SUPERADMIN_PASSWORD']
  user.role = 'superadmin'
  user.confirmed_at = Time.current if user.respond_to?(:confirmed_at)
end

company_name = ENV['SUPERADMIN_COMPANY_NAME']

# Check for company name conflict using correct column: name
existing_company = Company.find_by(name: company_name)

if existing_company
  abort("❌ Seed aborted: Company name '#{company_name}' already exists.")
end

if superadmin.company.nil?
  Company.create!(name: company_name, user: superadmin)
  puts "Company created for Superadmin: #{company_name}"
else
  puts "Superadmin already has an associated company: #{superadmin.company.name}"
end

puts "Superadmin created: #{superadmin.email}"
