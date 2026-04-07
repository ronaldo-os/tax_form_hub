puts "Running seeds..."

superadmin_email = ENV['SUPERADMIN_EMAIL']
superadmin_password = ENV['SUPERADMIN_PASSWORD']
company_name = ENV['SUPERADMIN_COMPANY_NAME']

raise "SUPERADMIN_EMAIL is missing" if superadmin_email.blank?
raise "SUPERADMIN_PASSWORD is missing" if superadmin_password.blank?
raise "SUPERADMIN_COMPANY_NAME is missing" if company_name.blank?

superadmin = User.find_or_create_by!(email: superadmin_email) do |u|
  u.password = superadmin_password
  u.password_confirmation = superadmin_password
  u.role = 'superadmin'
  u.confirmed_at = Time.current if u.respond_to?(:confirmed_at)
end

superadmin.update!(
  password: superadmin_password,
  password_confirmation: superadmin_password,
  role: 'superadmin'
)

puts "Superadmin ensured: #{superadmin.email}"

company = Company.find_or_create_by!(name: company_name) do |c|
  c.user = superadmin
end

if superadmin.company != company
  superadmin.update!(company: company)
end

puts "Company ensured and linked: #{company.name}"

standard_units = ["pcs", "h", "kg", "box"]

standard_units.each do |unit_name|
  Unit.find_or_create_by!(name: unit_name, company: nil) do |u|
    u.custom = false
  end
end

puts "Standard units seeded: #{standard_units.join(', ')}"

superadmins = User.where(role: 'superadmin')
puts "Superadmin count: #{superadmins.count}"
puts "Emails: #{superadmins.pluck(:email).join(', ')}"

puts "Seeding completed."