#!/bin/bash

## set default parameters
# aws cli
profile=default
# template
Name=default
EMRVersion=6.3.0
InstanceType=m5.xlarge

# parse arguments
while test $# -gt 0; do 
    case $1 in  
        --profile|-p) 
            shift 
            profile=$1 
            shift 
            ;; 
        --action|-a) 
            shift 
            action=$1 
            shift 
            ;; 
        --template|-t) 
            shift 
            template=$1 
            shift 
            ;; 
        --Name)
            shift
            Name=$1
            shift
            ;;
        --EMRVersion)
            shift
            EMRVersion=$1
            shift
            ;;
        --InstanceType)
            shift
            InstanceType=$1
            shift
            ;;
    esac 
done 

# validate parameters
if [[ ! $action =~ ^(create|update)$ ]]; then
  echo "action parameter must be one of: create, update"
  exit 1 
fi

# set parameters and stack name for a template pattern or leave default values
K=ParameterKey
V=ParameterValue
name_arg="$K=Name,$V=$Name"
if [[ $template == *EMR* ]]; then

    parameters="$K=EMRVersion,$V=$EMRVersion $K=InstanceType,$V=$InstanceType"
    stack_name=blake-$Name-emr-`tr . - <<< $InstanceType`

else

    stack_name=blake-$Name-`cut -d. -f1 <<< $template`

fi

aws --profile $profile cloudformation $action-stack \
    --parameters $name_arg $parameters \
    --stack-name $stack_name \
    --template-body file://$template \
    --capabilities CAPABILITY_NAMED_IAM

