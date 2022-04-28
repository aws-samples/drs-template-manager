# What?

This package creates binaries that are built from cmd*/main.go

These binaries can be zipped into .zip files and then deployed as lambda functions.

# Description

When using AWS Elastic Disaster Recovery Service (DRS) every source machine has a corresponding launch template. Launch templates cannot be edited in a batch using the native DRS tooling. This package is a set of lambda functions that allow for editing a group of launch templates that all are tagged with a certain key in the DRS console.

For Example:
- Create one launch template for all servers tagged 'DB'.

- Create one launch template for all servers tagged to a certain application.

- Create one launch template that applies to all replicating DRS servers.

# The Architecture

![template-updated drawio](https://user-images.githubusercontent.com/97046295/165619622-780e7448-4832-4a10-8696-938336314847.png)

This solution is composed of the following components:

- S3 bucket for storing launch templates in the form of json files.

- Lambda function that pulls down a json launch template from the bucket and then updates DRS servers that are tagged with the prefix of that json. This function will be called 'set-drs-templates'.

- Lambda function that runs on a schedule and scans for any new replicating servers that have a matching tag to one of the existing templates in the bucket. This allows new servers that are added to DRS to inherit the launch template that they are tagged for. In this example we are going to just set the scheduler to run once daily to capture new servers added throughout the day. This function will be called 'schedule-drs-templates'.

# Prerequisites

In order to use this solution, it is required to have actively replicating servers in DRS. For more information on getting started with DRS reference the [quick start guide](https://docs.aws.amazon.com/drs/latest/userguide/getting-started.html).

Part of this solution is creating lambda functions which need to make API calls to  DRS, EC2, and S3. It is required to have a role with the proper permissions to access all three services. You can create a role with 3 managed policies for simplicity:

- "AWSElasticDisasterRecoveryReadOnlyAccess"

- "AmazonEC2FullAccess"

- "AmazonS3FullAccess"

Here is a full list of API calls made by the solution if you would like to create a more granular policy:

- "drs.DescribeSourceServers"

- "drs.GetLaunchConfiguration"

- "s3.GetObject"

- "s3.PutObject"

- "ec2.CreateLaunchTemplateVersion"

- "ec2.ModifyLaunchTemplate"

# Usage

Deploying the solution is composed of three main steps. Create the lambda functions, Create the S3 bucket trigger, and Creating a template.

Create the Lambda Functions:

* Clone the repo
```
git clone https://github.com/aws-samples/drs-template-manager.git
```

* Create the zip deployment package of the 'set-drs-templates' function.
```
cd drs-template-manager
cd cmd-template
zip template.zip drs-template-manager
```

* Create the zip deployment package of the 'schedule-drs-templates' function.
```
cd ../cmd-cron
zip cron.zip template-cron-automation
```

Make two new GO lambda function in the same region as your DRS replicating servers and use the '.zip' files created above as the deployment packages. Under "Runtime Settings" Set the Handler to 'drs-template-manager' for the function that sets the templates and 'template-cron-automation' for the scheduler. The architecture should be x86 and the Runtime should be Go 1.x . :

* Create the 'schedule-drs-templates' function, replace '$INSERTROLEARN' with the arn of the role you created for the solution.
```
aws lambda create-function \            
--function-name schedule-drs-templates \
--role $INSERTROLEARN \
--runtime go1.x \
--handler template-cron-automation \
--package-type Zip \
--zip-file fileb://cron.zip
```

* Create the 'set-drs-templates' function, replace '$INSERTROLEARN' with the arn of the role you created for the solution.
```
cd ../cmd-template
aws lambda create-function \            
--function-name set-drs-templates \
--role $INSERTROLEARN \
--runtime go1.x \
--handler drs-template-manager \
--package-type Zip \
--zip-file fileb://template.zip
```

- Once the scheduler is created you need to determine how often you would like it to run and then create a CloudWatch cron event to trigger it. For this example we will create an event rule that triggers once per day at 12:00 PM UTC. Once we make the rule it needs to be added to the lambda function as a trigger.

* Create the rule
```
aws events put-rule \
--schedule-expression "cron(0 12 * * ? *)" \
--name template-cron-rule
```

* Add the 'schedule-drs-templates' function as a target for the rule. Replace $FunctionARN with the ARN of the 'schedule-drs-templates' lambda function.
```
aws events put-targets \
--rule template-cron-rule \
--targets "Id"="1","Arn"=$FunctionARN
```



Create the S3 bucket trigger for the 'set-drs-templates' function:

- Create an S3 bucket in the same region as the lambda function.
```
aws s3api create-bucket \
--bucket $SOMEUNIQUEBUCKETNAME
```

- Create an Event Notification in the bucket you just created.

* Navigate to the bucket and select the *Properties* tab.

* Select *Create event notification* .

    - Event name: "DRS template Automation"
    - The suffix should be '.json'
    - Check the box for 'All object create events'
    - Set the destination as the previously created lambda function.

- Update the cron function to take in the bucket created earlier as an environment variable
```
aws lambda update-function-configuration \
--function-name schedule-drs-templates \
--environment Variables={BUCKET=$SOMEUNIQUEBUCKETNAME}
```

Create a template:

- The repo comes with an example [launch template](https://docs.aws.amazon.com/drs/latest/userguide/ec2-launch.html) called 'Name.json' in the 'cmd-template' directory. The prefix of the .json file indicates which tag will be updated.

For Example:

- All servers with the tag key 'Name' will be updated when 'Name.json' is uploaded to the S3 bucket. Since DRS tags all servers with a 'Name' tag by default. All servers will have their template updated.

- Add the tag key 'DB' to all replicating databases. Rename 'Name.json' to 'DB.json' . Change the fields in the template to what you would like the values to be for databases. Then upload 'DB.json' to the bucket you created.

# Build Locally

You can build the functions locally if you have the go tooling installed.
```
cd cmd-cron
GOOS=linux go build .
```

``` 
cd ../cmd-template
GOOS=linux go build .
```

# License

This library is licensed under the MIT-0 License. See the LICENSE file.

# Security

See CONTRIBUTING for more information.
