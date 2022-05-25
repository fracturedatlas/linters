# Fractured Atlas Linter Configurations

This will be the home for all of the linters on Fractured Atlas projects.

## Rubocop

To import the Rubocop config into your project, add one of the following lines to your `.rubocop.yml` file:

- To stay on the latest version (recommended):
  - ```yaml
    inherit_from:
      - https://raw.githubusercontent.com/fracturedatlas/linters/main/.rubocop.yml
    ```
- To lock to a specific version, replace `main` above with the commit SHA or git tag to lock to.
  - For example, to lock to a version:
    ```yaml
    inherit_from:
      - https://raw.githubusercontent.com/fracturedatlas/linters/v1.0.0/.rubocop.yml
    ```
  - To lock to a commit
    ```yaml
    inherit_from:
      - https://raw.githubusercontent.com/fracturedatlas/linters/12f8aea7712051d31da5f8aca5cdbb2482e1a49e/.rubocop.yml
    ```
  - Do not lock to branches because they may disappear. Tags and SHAs will live forever.

Your copy of `.rubocop.yml` should look like example_rubocop.yml
You may need to adjust `TargetRubyVersion` and `TargetRailsVersion` based on the current settings for the project.

Make sure to add `.rubocop-http*` to your `.gitignore`.

## Reek

There is currently no way to have Reek read a shared config apparently but we can leverage it in our Code Climate configuration as below.

## Code Climate

You can just manually copy `.codeclimate.yml` into your project. Please don't update it (other than pointing to a specific tag or branch) but instead open a PR against the linters repo. All apps should be in agreement about what rules we're using.
