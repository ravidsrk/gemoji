Contributions to this project are [released](https://help.github.com/articles/github-terms-of-service/#6-contributions-under-repository-license) to the public under the [project's open source license](LICENSE).

Some useful tools in development are:

```
script/bootstrap
```

Sets up the development environment. The prerequisites are:

* Ruby 2.7, 3.0, or 3.1
* Bundler

```
script/test
```

Runs the test suite.

```
script/console
```

Opens `irb` console with gemoji library preloded for experimentation.

```
script/release
```

For maintainers only: after the gemspec has been edited, this runs the tests,
builds the gem, commits `gemoji.gemspec` and `Gemfile.lock`, tags a release,
pushes `HEAD` and the tag to `origin`, and runs `gem push`.
