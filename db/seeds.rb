User.find_or_create_by!(email: ENV['SUPERADMIN_EMAIL']) do |user|
  user.password = ENV['SUPERADMIN_PASSWORD']
  user.password_confirmation = ENV['SUPERADMIN_PASSWORD']
  user.role = 'superadmin'
  user.confirmed_at = Time.current if user.respond_to?(:confirmed_at)
end

puts "Superadmin created: #{ENV['SUPERADMIN_EMAIL']}"