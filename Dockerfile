FROM ruby:3.4.2

LABEL org.opencontainers.image.authors="Jonas Hellmann <mail@jonas-hellmann.de>"

RUN mkdir -p /var/everydocs-files
WORKDIR /usr/src/app
ENV RAILS_ENV=production
ENV EVERYDOCS_DB_ADAPTER=mysql2
ENV EVERYDOCS_DB_NAME=everydocs
ENV EVERYDOCS_DB_USER=everydocs
ENV EVERYDOCS_DB_HOST=localhost
ENV EVERYDOCS_DB_PORT=3306

COPY . .
RUN rm -f Gemfile.lock
RUN rm -rf .git/
RUN bundle install

RUN apt-get update
RUN apt-get install nodejs -y --no-install-recommends

RUN EDITOR="mate --wait" bin/rails credentials:edit

ENTRYPOINT ["./bin/entrypoint.sh"]
CMD ["rails", "server", "-b", "0.0.0.0", "--port", "5678"]
