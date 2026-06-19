Contributions to this project are [released](https://help.github.com/articles/github-terms-of-service/#6-contributions-under-repository-license) to the public under the [project's open source license](LICENSE).

Some useful tools in development are:

```
script/bootstrap
```

Sets up the development environment. The prerequisites are:

* Ruby 2.7+ (matches `gemoji.gemspec`)
* Bundler

```
script/test
```

Runs the full test suite via `bundle exec rake`.

You can also run individual files without Rake:

```bash
ruby -Ilib:test test/emoji_test.rb
```

Apps embedding gemoji may call `Emoji.preload!` at boot to eager-load the catalog instead of
paying the cost on the first lookup.

```
script/console
```

Opens `irb` console with gemoji library preloded for experimentation.

```
script/release
```

For maintainers only: after the gemspec has been edited, this commits the
change, tags a release, and pushes it to both GitHub and RubyGems.org.
