# :rocket: Mission Control [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/calendly/mission-control/blob/master/LICENSE) [![Build Status](https://travis-ci.org/calendly/mission-control.svg?branch=master)](https://travis-ci.org/calendly/mission-control) [![Coverage Status](https://coveralls.io/repos/github/calendly/mission-control/badge.svg?branch=master)](https://coveralls.io/github/calendly/mission-control?branch=master)

Mission Control is an application to enforce more complex Github Review rules.


#### Getting Started

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?env[MISSION_CONTROL_GITHUB_ACCESS_TOKEN]=access_token&env[MISSION_CONTROL_GITHUB_WEBHOOK_SECRET]=webhook_secret)

#### Run the App Locally

````
bundle install
bundle exec foreman start
````

#### Running Specs

````
bundle install
bundle exec rspec
````
