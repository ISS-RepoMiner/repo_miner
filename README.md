# Description
A simple program to get the needed data from a single gem, in this case is oga.

# Run
  1. ```bundle install``` for no reason.
  2. copy the ```config/local.example.rb``` to ```config/local.rb```.
  3. replace the ```TOKEN```, ```GITHUB_ACCOUNT```, ```GITHUB_PASSWORD```, and ```USER_AGENT``` in the ```config/local.rb``` with yours.
  4. run your local Mongodb with command ```sudo mongod```.
  5. run ```ruby rubygems.rb``` to start the collecting process.