#!/bin/bash

echo "BLAKE ~ loading environment variables"

export ACCOUNT=`aws sts get-caller-identity --query Account --output text`
export REGION=`aws configure get region`

