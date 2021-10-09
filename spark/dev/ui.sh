#!/bin/bash
svc=${1///}
kubectl port-forward -n spark svc/$svc 4040

