## Overview

This tutorial demonstrates incorporating Datadog Code Security into a CI/CD pipeline (using Github actions) for a Python Flask application running on AWS Fargate.

## Prerequsites

- AWS account
- Terraform
- Docker (optionally, for confirming vulnerability effects in app)

## Code repo setup

### Github 

- Fork this repo

```sh
git clone https://github.com/mdorn/dd-code-sec-cicd-tutorial.git
```



#### Repository secrets

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
DD_API_KEY
DD_APP_KEY
```

#### Repository variables

```
AWS_ACCOUNT_ID=[Your AWS Account ID]
AWS_ECR_REPO=dd-sec-demo-repo
AWS_ECS_CLUSTER=dd-sec-demo-cluster
AWS_ECS_SERVICE=dd-sec-demo-service
AWS_REGION=[Your AWS region]
DD_SITE=datadoghq.com
IMAGE_NAME=dd-sec-simple-vuln-app
```

### Datadog 

#### Github repo integration

TODO

#### Quality Gate configuration

TODO

## Deploy AWS infrastructure

The included Terraform code will create an ECR repo and an ECS cluster, service, and task configuration.  The deployment includes a sample container to help ensure the deployment was successful before trying to deploy our application to ECS.

```sh
cp infra/terraform/terraform.tfvars.sample infra/terraform/terraform.tfvars
# Optionally change the values before executing terraform ^^^ default region is us-east-2
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

## Trigger the Github Action to deploy the application

```sh
git mv .github/workflows/dd-code-sec.yml.DISABLED .github/workflows/dd-code-sec.yml
git commit -a -m "Enable workflow"
git push origin main
```

After workflow completes:

```sh
# after a minute or two (the IP may not be immediately available)
FT_IP=`./scripts/get_fargate_task_ip.sh`
curl "http://${FT_IP}:5000"
```

The output of the curl command should be:

```
{"app_version":1,"endpoints":["/user?id=","/random"]}
```

## Investigate in Datadog Code Security console

Note that there are no critical vulns in either SAST or SCA.

## Introduce vulnerabilities 

```sh
git checkout -b vuln-branch
# introduce SCA vulns
cp requirements.vulnerable.txt requirements.txt
```

In `app.py`, uncomment line 30 and comment line 31 to introduce a SQL Injection vulnerabilty.

```python
cursor.execute("SELECT * FROM users WHERE id={}".format(uid))  # VULNERABLE
# cursor.execute("SELECT * FROM users WHERE id= ?", [uid])  # NOT VULNERABLE: parameterized query
```

(Optionally, there's a vulnerability in another function involving the `random` module that you can introduce as well, to showcase multiple vulnerabilities.)

Also, change the VERSION in line 6 to make it easier to confirm successful deployment of the application.

Confirm that your changes to the application do indeed introduce an exploitable SQL injection vulnerability.

```sh
docker build -t dd-sec-simple-vuln-app:latest .
docker run -p 5000:5000 dd-sec-simple-vuln-app:latest
# valid request to app
curl "http://localhost:5000/user?id=1"
# malicious request to app using SQLi returns all records in database
curl "http://localhost:5000/user?id=1%20OR%201=1
```

Push your changes to the branch:

```sh
git commit -a -m "Introduce vulns"
git push origin vuln-branch
```

## Create Pull Request in Github

- Observe automated comments on vulnerabilities from Datadog
- TODO

## Review vulnerabilities in Datadog console

TODO

## Attempt to merge PR containing vulnerabilities

- Observe that the Quality Gate prevents deployment of applicaiton

## Fix vulnerabilities and reissue PR

Revert the changes you made in `app.py` above, and fix the vulnerable package references as well:

```sh
cp requirements.vulnerable.txt requirements.txt
```

Confirm the app is no longer vulnerable to SQLi:

```sh
docker build -t dd-sec-simple-vuln-app:latest .
docker run -p 5000:5000 dd-sec-simple-vuln-app:latest
# malicious request to app should now return an harmless response: []
curl "http://localhost:5000/user?id=1%20OR%201=1"
```

## Commit the fixes and merge the PR

```sh
git commit -a -m "Fix vulns"
git push origin vuln-branch
```

In Github, notice on your PR that the auto-commented commits are now "outdated", so you can click "Resolve conversation" on the offending commit(s) if you like. Notice that the retriggered pipeline checks now pass, including the Quality Gate; the final 2 steps are skipped because we only do them on the main branch.

Once you merge the PR, all of the steps of the workflow are executed, including the deployment to ECS.

After workflow completes:

```sh
# after a minute or two (the IP may not be immediately available)
FT_IP=`./scripts/get_fargate_task_ip.sh`
# a request from curl should show your newest version, e.g.:
#   {"app_version":1,"endpoints":["/user?id=","/random"]}
curl "http://${FT_IP}:5000"
# Malicious request to app should return an harmless response: []
# No vulnerable code made it into our Fargate deployment
curl "http://localhost:5000/user?id=1%20OR%201=1"
```

## Clean up

Remove potentially costly AWS infrastructure:

```sh
terraform -chdir=infra/terraform destroy
```

NOTE: ECS task definitions remain, you can delete those manually if desired.