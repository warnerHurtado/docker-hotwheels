# syntax = docker/dockerfile:1

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t my-app .
# docker run -d -p 80:80 -p 443:443 --name my-app -e RAILS_MASTER_KEY=<value from config/master.key> my-app

# ========================================
# STAGE 1: BASE IMAGE SETUP
# ========================================
# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.1.7
# This AS is a STATE  that i will run for build
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here (THIS IS LIKE SAY CD RAILS, IS THE WORK DIRECTORY OF THE IMAGE IN THE 9 LINE)
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# ========================================
# STAGE 2: BUILD STAGE (THROW-AWAY)
# ========================================
# Throw-away build stage to reduce size of final image
# When you see other from is a new phase or state in this case this is called build
FROM base AS build

# Install packages needed to build gems
# whe could do something like the comment above, but it is only for files not installed packages
# COPY --from=base /usr/local/bundle /usr/local/bundle
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev pkg-config libyaml-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Gemfile and Gemfile.lock are the two files being copied from your local directory to the image    
COPY Gemfile Gemfile.lock ./

# Install application gems
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# ========================================
# STAGE 3: TEST STAGE (OPTIONAL)
# ========================================
# Test stage to ensure everything works correctly
FROM build AS test

# Install test dependencies if needed
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set test environment
ENV RAILS_ENV="test"

# Run tests (uncomment the line below to enable tests)
# RUN bundle exec rspec
# RUN bundle exec rails test

# ========================================
# STAGE 4: FINAL PRODUCTION IMAGE
# ========================================
# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server"]
