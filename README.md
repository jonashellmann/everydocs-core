# EveryDocs Core

**Please note: currently under development**

EveryDocs Core is the server-side part of EveryDocs. This project will contain an [web interface](https://github.com/jonashellmann/everydocs-web/) and a mobile app in the near future. All in all, EveryDocs is a simple Document Management System (DMS) for private use. It contains basic functionality to organize your documents digitally. 

## Installation

1. Make sure you have Ruby installed. For an installation guide, check here: [Ruby installation guide](https://guides.rubyonrails.org/getting_started.html#installing-rails)
2. If you haven't installed the Rails Gem, you can run the following command: ``gem install ruby``
3. Clone this repository in a location of your own choice: ``git clone https://github.com/jonashellmann/everydocs-core``
4. Configure your database connection in config/database.yml
5. Configure the folder where documents are stored in config/settings.yml
6. Install required dependencies by ruuning: ``bundle install``
7. You might want to change the port of the application in start-app.sh.
8. Setup your database by running: ``rails db:migrate``
9. Start your Rails server: ``./start-app.sh``
10. Access the application on http://localhost:1234 or configure any kind of proxy forwarding in your webserver.
11. If you wish to use this application in your web browser, consider to install [EveryDocs Web](https://github.com/jonashellmann/everydocs-web/)!
12. Stop the application: ``./stop-app.sh``

## Backup

To backup your application, you can simply use the backup functionality of your
database. For example, a MySQL/MariaDB DBMS may use mysqldump.

Additionally you have to backup the place where the documents are stored. You
can configure this in config/settings.yml. To restore, just put the documents back in that location.

## Routes Documentation

To learn about the routes the API offers, run the following command: ``rake routes``
