Note: keep the same default aws region configured across DaP modules.

### Create Network
`aws cloudformation create-stack --stack-name dap-network --template-body file://network.yaml`

### Deploy Geth
```
aws cloudformation create-stack --stack-name dap-geth --template-body file://geth.yaml --capabilities CAPABILITY_IAM \
    --parameters ParameterKey=InstanceSize,ParameterValue=xlarge
```

Replace `create` by `update` to deploy template or parameter changes: `aws cloudformation update-stack ...`. Values of previous configuration can be kept by overriding template defaults with parameters like `ParameterKey=NetRestrict,UsePreviousValue=true`.

