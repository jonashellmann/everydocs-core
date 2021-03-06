# EveryDocs Core

[![Build Status](https://img.shields.io/github/workflow/status/jonashellmann/everydocs-core/Ruby?style=flat-square)](https://github.com/jonashellmann/everydocs-core/actions?query=workflow%3ARuby)
![Lines of Code](https://img.shields.io/tokei/lines/github/jonashellmann/everydocs-core?style=flat-square)
![License](https://img.shields.io/github/license/jonashellmann/everydocs-core?style=flat-square)
![GitHub Repo
Stars](https://img.shields.io/github/stars/jonashellmann/everydocs-core?style=social)
[![Commit activity](https://img.shields.io/github/commit-activity/y/jonashellmann/everydocs-core?style=flat-square)](https://github.com/jonashellmann/everydocs-core/commits/)
[![Last commit](https://img.shields.io/github/last-commit/jonashellmann/everydocs-core?style=flat-square)](https://github.com/jonashellmann/everydocs-core/commits/)

EveryDocs Core is the server-side part of EveryDocs. This project will contain an [web interface](https://github.com/jonashellmann/everydocs-web/) and a mobile app in the near future. All in all, EveryDocs is a simple Document Management System (DMS) for private use. It contains basic functionality to organize your documents digitally. 

## Installation

1. Make sure you have Ruby installed. For an installation guide, check here: [Ruby installation guide](https://guides.rubyonrails.org/getting_started.html#installing-rails)
2. If you haven't installed the Rails Gem, you can run the following command: ``gem install rails``
3. Download the newest release and unzip it in a location of your own choice.
4. Configure your database connection in config/database.yml. For this, there must be a corresponding database and an authorized user
5. Configure the folder where documents are stored in config/settings.yml
6. Install required dependencies by running: ``bundle install``
7. You might want to change the port of the application in start-app.sh.
8. Setup your database by running: ``rake db:migrate RAILS_ENV=production``. If there is an error, you might need to execute the following command, to
set an encryption key: ``EDITOR="mate --wait" bin/rails credentials:edit``
9. Make sure that the environment variable 'SECRET_KEY_BASE' has a value.
   If not, you can generate a key by running ``rake secret``. You either set
your environment variable to this value - for example by adding it to the start-app.sh
script - or set it in config/secrets.yml for production.
10. Start your Rails server: ``./start-app.sh``
11. Access the application on http://localhost:1234 or configure any kind of proxy forwarding in your webserver. If you run this application under an URL, make sure to add this URL to config.hosts at the end of the file ./config/environments/development.rb.
12. If you wish to use this application in your web browser, consider to install [EveryDocs Web](https://github.com/jonashellmann/everydocs-web/)!
13. Stop the application: ``./stop-app.sh``

## Backup

To backup your application, you can simply use the backup functionality of your
database. For example, a MySQL/MariaDB DBMS may use mysqldump.

Additionally you have to backup the place where the documents are stored. You
can configure this in config/settings.yml. To restore, just put the documents back in that location.

## Routes Documentation

To learn about the routes the API offers, run the following command: ``rake routes``
