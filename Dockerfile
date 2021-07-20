FROM ruby:3.0.2-alpine3.14 as base
ENV APP /opt
WORKDIR $APP
COPY Gemfile Gemfile.lock harmoniser.gemspec Rakefile $APP/

FROM base as test
COPY lib $APP/lib/ 
COPY spec $APP/spec/
RUN bundle install -j 10 --quiet
