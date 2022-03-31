#!/bin/bash
set -eu

env_path () { [ -f ../$1/var ] && cat ../$1/var || cat ../$1/default;}
: ${DaP_ENV:=`env_path DaP/ENV`}

