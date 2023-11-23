# Harmoniser CLI

Harmoniser CLI is a command line tool than run a Ruby process through `bundle exec harmoniser`. This utility accepts the following options:

```sh
    bundle exec harmoniser -h

    harmoniser [options]
        -e, --environment ENV            Application environment
        -r, --require [PATH|DIR]         File to require or location of Rails application
        -v, --[no-]verbose               Run verbosely
        -V, --version                    Print version and exit
        -h, --help                       Show help
```

The `environment` is automatically inferred from the environment variables `RAILS_ENV` or `RACK_ENV`, otherwise fallbacks to `production`. However you can specify your preferred value, for instance `development` or `test`.

The `require` is by default pointing at `.`, which means that this option when configured under a Rails application, might be ignored. Since Ruby is not Rails only, you can certainly specify the location path of your Ruby file that will be used to load the classes including Harmoniser::Subscriber. In contrast, if a path to a directory is passed, Harmoniser assumes that `./config/environment.rb` lives within the folder passed as option.

The `verbose` option, when passed, sets the severity of Harmoniser logs to `debug` being able to see fine-grained details of things like RabbitMQ interactions happening or messages published into exchanges. By default, the verbosity is disabled to prevent your production environment to be flooded with unnecessary logs, however if the environment is not set to `production`, the severity of the logs is `debug` mode too.
