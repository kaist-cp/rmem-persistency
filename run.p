#!/usr/bin/env bash

if [ $# -lt 1 ]
then
  echo "usage : $0 litmus"
  exit 1
fi

ldir=`dirname $1`

./rmem -model promising -model promise_first -model promising_parallel_thread_state_search -model promising_parallel_without_follow_trace -priority_reduction false -interactive false -hash_prune false -pp_hex true -shared_memory $ldir/shared_memory.txt $1
