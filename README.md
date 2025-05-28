# Tax Form Hub

A web application built with Ruby on Rails for securely submitting and managing tax-related documents.

## 🚀 Requirements

- Ruby 3.2.2 (use [rbenv](https://github.com/rbenv/rbenv) or [rvm](https://rvm.io/))
- Rails 7.2.2+
- Node.js (for JavaScript runtime)
- PostgreSQL (or your chosen DB)
- [jsbundling-rails](https://github.com/rails/jsbundling-rails) with esbuild (for asset compilation)

## 📦 Setup Instructions

1. **Clone the repository**
git clone https://github.com/ronaldo-os/tax_form_hub.git
cd tax_form_hub

2. **Install Dependencies**
bundle install
npm install

3. **Set Up the Database**
rails db:setup
rails db:create
rails db:migrate
rails db:seed

4. **Configure Environment Variables**
Populate the env.sample file

5. **Build JavaScript Assets**
./bin/dev
# or for production build
rails assets:precompile

6. **Run the Server**


