# What?

This package creates a binary that is built from *cmd/main.go

This binary can be zipped into a .zip file and then deployed as a lambda function

# Description

When using AWS Elastic Disaster Recovery service every source machine has a corresponding launch templates. Launch templates cannot be edited in a batch using the native DRS tooling. This package is a lambda function that allows for editing a group of launch templates that all are tagged with a certain key in the DRS console.

For Example:
- Create one launch template for all servers tagged 'DB'.

- Create one launch template for all servers tagged to a certain application.

- Create one launch template that applies to all replicating DRS servers.

# Usage

Create the Lambda Function:

- Clone the repo
```
git clone https://github.com/aws-samples/drs-template-manager.git
```

- Create the zip
```
cd drs-template-manager
cd cmd
zip function.zip drs-template-manager
```

- Make a new GO lambda function in the same region as your DRS replicating servers and use the 'function.zip' as the deployment package. Under "Runtime Settings" Set the Handler to 'drs-template-manager'. The architecture should be x86 and the Runtime should be Go 1.x . The lambda needs a role with full access to DRS , as well as access to EC2 launch templates.
```
aws lambda create-function \            
--function-name sandboxGoTemplate \
--role $INSERTROLEARN
--runtime go1.x \
--handler drs-template-manager \
--package-type Zip \
--zip-file fileb://function.zip
```

Create the S3 bucket trigger:

- Create an S3 bucket in the same region as the lambda function.
```
aws s3api create-bucket \
--bucket $SOMEUNIQUEBUCKETNAME
```

- Create an Event Notification in the bucket you just created.

* Navigate to the bucket and select the *Properties* tab.

* Select *Create event notification* .

    - Event name can be "DRS template Automation"
    - The suffix should be '.json'
    - Check the box for 'All object create events'
    - Set the destination as the previously created lambda function.

Create a template:

- The repo comes with an example template called 'Name.json' . The prefix of the .json file indicates which tag will be updated.

For Example:

- All servers with the tag key 'Name' will be updated when 'Name.json' is uploaded to the S3 bucket. Since DRS tags all servers with a 'Name' tag by default. All servers will have their template updated.

- Add the tag key 'DB' to all replicating databases. Rename 'Name.json' to 'DB.json' . Change the fields in the template to what you would like the values to be for databases. Then upload 'DB.json' to the bucket you created.

# Build Locally

You can build this locally if you have the go tooling installed
```
cd cmd
GOOS=linux go build .
```

# License

This library is licensed under the MIT-0 License. See the LICENSE file.

# Security

See CONTRIBUTING for more information.
