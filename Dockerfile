FROM ruby:3.0.2-alpine3.14 as base
ENV APP /opt
WORKDIR $APP
COPY Gemfile Gemfile.lock harmoniser.gemspec Rakefile $APP/

FROM base as test
RUN apk --update add --virtual build_deps build-base
COPY lib $APP/lib/ 
COPY spec $APP/spec/
RUN bundle install -j 10 --quiet
RUN apk del build_deps
