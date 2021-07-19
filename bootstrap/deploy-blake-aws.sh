#!/bin/bash
source workflow/aws/profile-configuration.sh

echo "BLAKE ~ building bootstrap environment"
docker build -t blake-bootstrap .

echo "BLAKE ~ running deployment workflow"
docker run \
    --rm \
    --name blake-bootstrap \
    -e AWS_PROFILE=$AWS_PROFILE \
    -v ~/.aws:/root/.aws \
    -v `pwd`/workflow:/opt/blake \
    -w /opt/blake \
    blake-bootstrap aws/blue-green-deployment.sh

echo "BLAKE ~ deployment exit code: $?"

