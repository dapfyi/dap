#!/bin/bash

echo "BLAKE ~ loading environment variables"

export AWS_ACCOUNT=`aws sts get-caller-identity --query Account --output text`
export REGION=`aws configure get region`

