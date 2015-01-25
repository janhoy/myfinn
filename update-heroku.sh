#!/bin/sh
git push heroku +HEAD:master
heroku run rake db:migrate
heroku restart
heroku open