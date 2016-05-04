# Danger :no_entry_sign:

[![License](http://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/orta/danger/blob/master/LICENSE)
[![Gem](https://img.shields.io/gem/v/danger.svg?style=flat)](http://rubygems.org/gems/danger)

Formalize your Pull Request etiquette.

-------

<p align="center">
    <a href="#installation">Installation</a> &bull;
    <a href="#usage">Usage</a> &bull;
    <a href="#dsl">DSL</a> &bull;
    <a href="#constraints">Constraints</a> &bull;
    <a href="#advanced">Advanced</a> &bull;
    <a href="#contributing">Contributing</a>
</p>

-------

## Getting Started

Add this line to your application's [Gemfile](https://guides.cocoapods.org/using/a-gemfile.html):

```ruby
gem 'danger'
```

To get up and running quickly, just run

```
bundle exec danger init
```

## Usage on CI

```
bundle exec danger
```

This will look at your `Dangerfile` and update the pull request accordingly. While you are setting up Danger, you may want to use: `--verbose` for more debug information.

## CI Support

Danger currently is supported on Travis CI, Circle CI, Xcode Bots via Buildasaur, BuildKite and Jenkins. These work via environment variables, so it's easy to extend to include your own.

### Making your own
If the CI server you're using isn't available yet, you can build it yourself:

Take a look at some of the [already existing integrations](https://github.com/danger/danger/tree/master/lib/danger/ci_source). The class has 2 mandatory methods:

- `self.validates?` which should detect if the CI is active (detecting via ENV variables, mostly)
- `initialize` which should set 2 variables:
  - `self.repo_slug` the repo slug, in `org/repo` or `user/repo` format.
  - `self.pull_request_id` the number of the pull request that the CI is testing (often available in ENV variables)

We'd love to see pull requests for new integrations!

## What happens?

Danger runs at the end of a CI build, she will execute a `Dangerfile`. This file is given some special variables based on the git diff and the Pull Request being running. You can use these variables in Ruby to provide messages, warnings and failures for your build. You set up Danger with a GitHub user account and she will post updates via comments on the Pull Request, and can fail your build too.

## DSL

&nbsp;  | &nbsp; | Danger :no_entry_sign:
-------------: | ------------- | ----
:sparkles: | `lines_of_code` | The total amount of lines of code in the diff
:pencil2:  | `modified_files` |  The list of modified files
:ship: | `added_files` | The list of added files
:recycle: | `deleted_files` | The list of removed files
:abc:  | `pr_title` | The title of the PR
:book:  | `pr_body` | The body of the PR
:busts_in_silhouette:  | `pr_author` | The author who submitted the PR
:bookmark: | `pr_labels` | The labels added to the PR

The `Dangerfile` is a ruby file, so really, you can do anything. However, at this stage you might need selling on the idea a bit more, so lets take some real examples:

#### Dealing with WIP pull requests

```ruby
# Sometimes its a README fix, or something like that - which isn't relevant for
# including in a CHANGELOG for example
declared_trivial = pr_title.include? "#trivial"

# Just to let people know
warn("PR is classed as Work in Progress", sticky: false) if pr_title.include? "[WIP]"
```

#### Being cautious around specific files

``` ruby
# Devs shouldn't ship changes to this file
fail("Developer Specific file shouldn't be changed", sticky: false) if modified_files.include?("Artsy/View_Controllers/App_Navigation/ARTopMenuViewController+DeveloperExtras.m")

# Did you make analytics changes? Well you should also include a change to our analytics spec
made_analytics_changes = modified_files.include?("/Artsy/App/ARAppDelegate+Analytics.m")
made_analytics_specs_changes = modified_files.include?("/Artsy_Tests/Analytics_Tests/ARAppAnalyticsSpec.m")
if made_analytics_changes
  fail("Analytics changes should have reflected specs changes") if !made_analytics_specs_changes

  # And pay extra attention anyway
  message('Analytics dict changed, double check for ?: `@""` on new entries')
  message('Also, double check the [Analytics Eigen schema](https://docs.google.com/spreadsheets/u/1/d/1bLbeOgVFaWzLSjxLOBDNOKs757-zBGoLSM1lIz3OPiI/edit#gid=497747862) if the changes are non-trivial.')
end
```

#### Pinging people when a specific file has changed

```ruby
message("@orta something changed in elan!") if modified_files.include? "/components/lib/variables/colors.json"
```

#### Exposing aspects of CI logs into the PR discussion

```ruby
build_log = File.read(File.join(ENV["CIRCLE_ARTIFACTS"], "xcode_test_raw.log"))
snapshots_url = build_log.match(%r{https://eigen-ci.s3.amazonaws.com/\d+/index.html})
fail("There were [snapshot errors](#{snapshots_url})") if snapshots_url
```

#### Available commands

Command | Description
------------- | ----
`fail` | Causes the PR to fail and print out the error on the PR
`warn` | Prints out a warning to the PR, but still enables the merge button
`message` | Show neutral messages on the PR
`markdown` | Print raw markdown below the summary tables on the PR

## Plugins

Danger was built with a platform in mind: It can be used with any kind of software project and allows you to write your own action to have structured source code.

In your `Dangerfile` you can import local or remote actions using

```ruby
import "./danger_plugins/work_in_progress_warning"
# or
import "https://raw.githubusercontent.com/danger/danger/master/danger_plugins/work_in_progress_warning.rb"

# Call those actions using
work_in_progress_warning

custom_plugin(variable: "value")
```

To create a new plugin run

```
danger new_plugin
```

This will generate a new Ruby file which you can modify to fit your needs.

## Advanced

You can access more detailed information by accessing the following variables

&nbsp; | Danger :no_entry_sign:
------------- | ----
`env.request_source.pr_json` | The full JSON for the pull request
`env.scm.diff` | The full [Diff](https://github.com/mojombo/grit/blob/master/lib/grit/diff.rb) file for the diff.
`env.ci_source` | To get information like the repo slug or pull request ID

These are considered implementation details though, and may be subject to change in future releases. We're very
open to turning useful bits into the official API.

## Test locally with `danger local`

You can use `danger local` to run Danger in an environment similar to how it will be ran on CI. By default Danger will look
at the most recently merged PR, then run your `Dangerfile` against that Pull Request. This is really useful when making changes.

If you have a specific PR in mind that you'd like to work against, make sure you have it merged in your current git
history, then append `--use-merged-pr=[id]` to the command.

## Suppress Violations

You can tell Danger to ignore a specific warning or error by commenting on the PR body:

```
> Danger: Ignore "Developer Specific file shouldn't be changed"
```

## Sticky

Danger can keep its history if a warning/error/message is marked as *sticky*. When the violation is resolved,
Danger will update the comment to cross it out. If you don't want this behavior, just use `sticky: false`.

```ruby
fail("PR needs labels", sticky: false) if pr_labels.empty?
```

## Useful bits of knowledge

* You can set the base branch in the command line arguments see: `bundle exec danger --help`, if you commonly merge into non-master branches.
* Appending `--verbose` to `bundle exec danger` will expose all of the variables that Danger provides, and their values in the shell.

Here are some real-world Dangerfiles: [artsy/eigen](https://github.com/artsy/eigen/blob/master/Dangerfile), [danger/danger](https://github.com/danger/danger/blob/master/Dangerfile), [artsy/elan](https://github.com/artsy/elan/blob/master/Dangerfile) and more!

## License, Contributor's Guidelines and Code of Conduct

[Join our Slack Group](https://danger-slack.herokuapp.com/)

> This project is open source under the MIT license, which means you have full access to the source code and can modify it to fit your own needs.

> This project subscribes to the [Moya Contributors Guidelines](https://github.com/Moya/contributors) which TLDR: means we give out push access easily and often.

> Contributors subscribe to the [Contributor Code of Conduct](http://contributor-covenant.org/version/1/3/0/) based on the [Contributor Covenant](http://contributor-covenant.org) version 1.3.0.
