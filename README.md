# EveryDocs Core

**Please note: currently under development**

EveryDocs Core is the server-side part of EveryDocs. This project will contain an web interface and a mobile app in the near future. All in all, EveryDocs is a simple Document Management System (DMS) for private use. It contains basic functionality to organize your documents digitally. 

## Installation

1. Make sure you have Ruby installed. For an installation guide, check here: [Ruby installation guide](https://guides.rubyonrails.org/getting_started.html#installing-rails)
2. If you haven't installed the Rails Gem, you can run the following command: _gem install ruby_
3. Clone this repository in a location of your own choice: _git clone https://github.com/jonashellmann/everydocs-core_
4. Configure your database connection in config/database.yml
5. Start your Rails server on a specific port (or on port 3000, if you don't use the command line parameter): _rails server --port 1234_
6. Access the application on http://localhost:1234 or configure any kind of proxy forwarding in your webserver.

## Routes Documentation

To learn about the routes the API offers, run the following command: _rake routes_