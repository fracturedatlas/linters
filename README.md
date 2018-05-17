# Fractured Atlas Linter Configurations

This will be the home for all of the linters on Fractured Atlas projects.

To import this Rubocop config into your project, add one of the following lines to your `.rubocop.yml` file:

- To stay on the latest version:
  - ```yaml
    inherit_from:
      - https://raw.githubusercontent.com/fracturedatlas/linters/master/.rubocop.yml
    ```
- To lock to a specific version, replace `master` above with the commit SHA or git tag to lock to.
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
