Feature: The deploy command

  Scenario: Deploying from master to staging

    Unfortunately, Aruba cannot run commands truly interactively. We need to
    answer prompts blindly, and check the output afterwards.

    When I run `geordi deploy` interactively
      # Answer three prompts
      And I type "staging"
      And I type "master"
      And I type ""
      # Confirm deployment
      And I type "yes"
    Then the output should contain:
      """
      # Checking whether your master branch is ready
      > All good.

      # You are about to:
      > Deploy to staging
      Go ahead with the deployment? [n]
      """
      And the output should contain:
      """
      > cap staging deploy:migrations
      Util.system! cap staging deploy:migrations

      > Deployment complete.
      """


  Scenario: Deploying the current branch

    Deploying the current branch requires support by the deployed application:
    its deploy config needs to pick up the DEPLOY_BRANCH environment variable.

    When I run `geordi deploy --current-branch` interactively
      # Answer deployment stage prompt
      And I type "staging"
      # Confirm deployment
      And I type "yes"
    Then the output should contain "DEPLOY_BRANCH=master cap staging deploy:migrations"