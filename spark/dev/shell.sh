#!/bin/bash
app=$1
resolved_path=`echo $0 | awk -F'/shell.sh' '{print $1}'`
$resolved_path/../submit.sh $app shell

