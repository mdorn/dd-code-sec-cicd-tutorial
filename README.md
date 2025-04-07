# Datadog Code Security CI/CD Pipeline Tutorial

## Table of Contents

- [Table of Contents](#table-of-contents)
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Code repo setup](#code-repo-setup)
   * [Github ](#github)
      + [Repository secrets](#repository-secrets)
      + [Repository variables](#repository-variables)
   * [Datadog ](#datadog)
      + [Github repo integration](#github-repo-integration)
- [Deploy AWS infrastructure and application](#deploy-aws-infrastructure-and-application)
- [Introduce vulnerabilities into application](#introduce-vulnerabilities-into-application)
   * [Create and Merge Pull Request in Github](#create-and-merge-pull-request-in-github)
   * [Confirm vulnerability in running application](#confirm-vulnerability-in-running-application)
   * [Investigate application vulnerabilities in Datadog Code Security console](#investigate-application-vulnerabilities-in-datadog-code-security-console)
- [Restore application without vulnerabilities](#restore-application-without-vulnerabilities)
- [Configure a Quality Gate in Datadog to ensure vulnerable code cannot be deployed](#configure-a-quality-gate-in-datadog-to-ensure-vulnerable-code-cannot-be-deployed)
- [Attempt to reintroduce vulnerabilities into application](#attempt-to-reintroduce-vulnerabilities-into-application)
- [Clean up](#clean-up)

## Overview

This tutorial demonstrates incorporating Datadog Code Security into a CI/CD pipeline (using Github actions) for a Python Flask application running on AWS Fargate with minimal infrastrcuture (an ECR repo and ECS cluster and service with a Fargate task definition will be created).

## Prerequisites

- AWS account
- Terraform

## Code repo setup

### Github 

Clone this repo to your Github account and check it out locally.

#### Repository secrets

Add the following key/value pairs to your Github repo:

```
AWS_ACCESS_KEY_ID=<your IAM user's access key id>
AWS_SECRET_ACCESS_KEY=<your IAM user's access key secret>
DD_API_KEY=<your Datadog API key>
DD_APP_KEY=<your Datadog application key>
```

#### Repository variables

```
AWS_ACCOUNT_ID=<Your AWS Account ID>
AWS_ECR_REPO=dd-sec-demo-repo
AWS_ECS_CLUSTER=dd-sec-demo-cluster
AWS_ECS_SERVICE=dd-sec-demo-service
AWS_REGION=us-east-2
DD_SITE=datadoghq.com
IMAGE_NAME=dd-sec-simple-vuln-app
```

IMPORTANT: You can change `AWS_REGION`, but make sure it matches the variable in your Terraform config (see below).

### Datadog 

#### Github repo integration

TODO - including automated pull request comments.

## Deploy AWS infrastructure and application

The included Terraform code will create an ECR repo and an ECS cluster, service, and task configuration.  The deployment includes a sample container to help ensure the deployment was successful before trying to deploy our application to ECS.

```sh
cp infra/terraform/terraform.tfvars.sample infra/terraform/terraform.tfvars
# ^^^ Optionally change the values before executing terraform: default region is us-east-2
terraform -chdir=infra/terraform apply
# answer "yes" to the prompt
# after a minute or two (the IP may not be immediately available)
FT_IP=`./scripts/get_fargate_task_ip.sh`
curl "http://${FT_IP}:8000"
```

The curl command should produce:

```html
<pre>
Hello World


                                       ##         .
                                 ## ## ##        ==
                              ## ## ## ## ##    ===
                           /""""""""""""""""\___/ ===
                      ~~~ {~~ ~~~~ ~~~ ~~~~ ~~ ~ /  ===- ~~~
                           \______ o          _,/
                            \      \       _,'
                             `'--.._\..--''
</pre>
```

## Introduce vulnerabilities into application

Now we'll introduce vulnerabilities into our application and deploy it.

```sh
git checkout -b clean-branch  # save this branch for later
git checkout -b vuln-branch 
git mv .github/workflows/dd-code-sec.yml.DISABLED .github/workflows/dd-code-sec.yml
# introduce SCA vulns first
cp requirements.vulnerable.txt requirements.txt
```

In `app.py`, uncomment line 30 and comment line 31 to introduce a SQL Injection vulnerabilty.

```python
cursor.execute("SELECT * FROM users WHERE id={}".format(uid))  # VULNERABLE
# cursor.execute("SELECT * FROM users WHERE id= ?", [uid])  # NOT VULNERABLE: parameterized query
```

(Optionally, there's a vulnerability in another function involving the `random` module that you can introduce as well, to showcase multiple vulnerabilities.)

Also, change `VERSION` in line 6 to `2` to help confirm successful deployment.

Push your changes to the branch:

```sh
git commit -a -m "Introduce vulns"
git push origin vuln-branch
```

### Create and Merge Pull Request in Github

- Observe the automated PR comments and merge it to main branch.  Do NOT delete the branch.
- TODO (more detail)

### Confirm vulnerability in running application

Note that after merging the pull request, the Github action deploys the application to your AWS infrastructure.

After the workflow completes:

```sh
# after a minute or two (the IP may not be immediately available):
FT_IP=`./scripts/get_fargate_task_ip.sh`
curl "http://${FT_IP}:5000"
```

The output of the curl command should be:

```
{"app_version":2,"endpoints":["/user?id=","/random"]}
```

Now confirm the app has a SQL injection vulnerability:

```sh
# valid request to app, returns a user record
curl "http://${FT_IP}:5000/user?id=1"
# malicious request to app using SQLi attack returns all records in database
curl "http://${FT_IP}:5000/user?id=1%20OR%201=1
```

### Investigate application vulnerabilities in Datadog Code Security console

TODO

## Restore application without vulnerabilities

Restore clean branch of repo without vulnerabilities, and redeploy the application:

```sh
git checkout clean-branch
git mv .github/workflows/dd-code-sec.yml.DISABLED .github/workflows/dd-code-sec.yml
git push origin clean-branch
```

In Github, create a pull request to merge `clean-branch` to the `main` branch.  This will trigger the Github workflow to redeploy the application to your AWS infrastructure.

```sh
# Note the Fargate task IP will have changed since the last deployment. The redeployment may take a few minutes to complete.
FT_IP=`./scripts/get_fargate_task_ip.sh`
curl "http://${FT_IP}:5000"
```

The output of the curl command should be as follows (note `app_version` is 1):

```
{"app_version":1,"endpoints":["/user?id=","/random"]}
```

Confirm the SQL injection vulnerability has been resolved:

```sh
# valid request to app, returns a user record
curl "http://${FT_IP}:5000/user?id=1"
# malicious request to app should return an harmless response: []
curl "http://${FT_IP}:5000/user?id=1%20OR%201=1
```

## Configure a Quality Gate in Datadog to ensure vulnerable code cannot be deployed

TODO

## Attempt to reintroduce vulnerabilities into application

- Create new pull request from `vuln-branch` -> `main`
- Attempt to merge the PR to the main branch.
- Observe in the Github action that the Quality Gate prevents the vulnerable branch from being merged and the application from being with faulty code.
- Observe the automated comments made on the PR.
- Observe in Datadog that the Quality Gate blocked the deployment.

## Clean up

Remove potentially costly AWS infrastructure:

```sh
terraform -chdir=infra/terraform destroy
```

NOTE: ECS task definitions remain, you can delete those manually if desired.

