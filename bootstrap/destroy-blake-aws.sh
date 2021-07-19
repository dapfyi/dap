#!/bin/bash
source workflow/aws/profile-configuration.sh

echo "BLAKE ~ going to destroy cluster and AWS objects"

docker run \
    --rm \
    --name blake-cleanup \
    -e AWS_PROFILE=$AWS_PROFILE \
    -v ~/.aws:/root/.aws \
    -v `pwd`/workflow:/opt/blake \
    -w /opt/blake \
    blake-bootstrap aws/cleanup.sh

echo "BLAKE ~ cleanup exit code: $?"

