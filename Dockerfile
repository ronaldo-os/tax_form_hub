# Use the official Ruby image
FROM ruby:3.2.2


# Create a non-root user
RUN addgroup --system appgroup && adduser --system --group appuser


# Set the working directory
WORKDIR /var/www/html/


# Copy Gemfile and Gemfile.lock first for caching
COPY --chown=appuser:appgroup Gemfile Gemfile.lock ./


# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y build-essential libpq-dev curl ffmpeg cron vim git && \
    curl -sL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs yarn && \
    apt-get clean && rm -rf /var/lib/apt/lists/*


# Install esbuild globally
RUN npm install -g esbuild


# Install gems (including development and test gems for staging)
RUN gem install bundler && bundle install


# Copy application source code
COPY --chown=appuser:appgroup . .


# Install JavaScript dependencies
RUN yarn install || true


# Set environment variables for development/staging
ENV RAILS_ENV=development


# Create tmp directory with proper permissions
RUN mkdir -p tmp/pids && chown -R appuser:appgroup tmp


# Switch to non-root user
USER appuser


# Expose Rails port (using different port for staging)
EXPOSE 9007

CMD ["sh", "-c", "rm -f tmp/pids/server.pid && bin/dev"]
