#!/bin/bash

#Periodic Task class{
    PriodicTask.New(){
        o.New "PriodicTask"; local task="$_r"

        o.Set "$task.task" "${1:-"_f(){ :; }; _f"}" #default task is a no-op function
        o.Set "$task.interval" "${2:-"1"}" $1 second
        o.Set "$task.lastRun" "${3:-"0"}" #default last run is 0 (never run)
        o.Set "$periodicTask.taskInfo" "$taskInfo"
        o.Set "$periodicTask.state" "running" #running, paused, aborted
        o.Set "$periodicTask.remainShots" "-1" #-1 means unlimited shots, 0 means no shots (will abort the task after the first run)

        _r="$periodicTask"
    }

    PeriodicTask.Abort(){ local periodicTask="$1"
        #abort the periodic task
        o.Set "$periodicTask.state" "aborted"
    }

    PeriodicTask.Pause(){ local periodicTask="$1"
        #pause the periodic task
        o.Set "$periodicTask.state" "paused"
    }

    PeriodicTask.Resume(){ local periodicTask="$1"
        #resume the periodic task
        o.Set "$periodicTask.state" "running"
    }
#}


Scheduler.New(){
    o.New "Scheduler"; local scheduler="$_r"

    o.New; local periodicTasks="$_r"
    o.Set "$periodicTasks.count" "0"
    o.Set "$scheduler.periodic" "$periodicTasks"

    o.New; local taskQueue="$_r"
    o.Set "$taskQueue.count" "0"
    o.Set "$scheduler.taskQueue" "$taskQueue"

    _r="$scheduler"
}

Scheduler.RunOnRound(){ local scheduler="$1"
    Scheduler.runNormalTasks "$scheduler"
    Scheduler.runPeriodicTasks "$scheduler"
}

Scheduler.runNormalTasks(){ local scheduler="$1"
    #run all taskQueue tasks
    o.Get "$scheduler.taskQueue.count"; local count="$_r"
    if [ "$count" == "" ]; then
        count=0
    fi
    for ((i=0; i<count; i++)); do
        o.Get "$scheduler.taskQueue.item_$i"; local task="$_r"
        if [ "$task" != "" ]; then
            #run the task
            eval "$task"
        fi
        o.Delete "$scheduler.taskQueue.item_$i" #remove the task from the queue
    done
    #clear the taskQueue
    o.Set "$scheduler.taskQueue.count" "0"

    #TODO: run all periodic tasks
    o.Get "$scheduler.periodic.count"; local periodicCount="$_r"
    if [ "$periodicCount" == "" ]; then
        periodicCount=0
    fi
}

Scheduler.runPeriodicTasks(){ local scheduler="$1"
    for ((i=periodicCount; i>=0; i--)); do
        o.Get "$scheduler.periodic.item_$i"; local taskInfo="$_r"
        if [ "$taskInfo" != "" ]; then
            o.Get "$taskInfo.state"; local state="$_r"
            if [ "$state" == "running" ]; then
                o.Get "$taskInfo.lastRun"; local lastRun="$_r"
                o.Get "$taskInfo.interval"; local interval="$_r"
                local now=$(date +%s%3N) #current time in milliseconds

                if [ "$((now - lastRun))" -ge "$interval" ]; then
                    #run the task
                    eval "${taskInfo.task}"
                    o.Set "$taskInfo.lastRun" "$now"

                    #check max shots
                    o.Get "$taskInfo.remainShots"; local remainShots="$_r"
                    if [ "$remainShots" != "-1" ]; then
                        remainShots=$((remainShots - 1))
                        if [ "$remainShots" -le "0" ]; then
                            #abort the task
                            PriodicTask.Abort "$taskInfo"
                        else
                            o.Set "$taskInfo.remainShots" "$remainShots"
                        fi
                    fi
                fi
            elif [ "$state" == "aborted" ]; then
                #remove the task from the periodic tasks
                o.Destroy "$taskInfo" #destroy the taskInfo object

                for ((j=i; j<periodicCount-1; j++)); do
                    o.Get "$scheduler.periodic.item_$((j + 1))"; local nextTaskInfo="$_r"
                    o.Set "$scheduler.periodic.item_$j" "$nextTaskInfo" #shift the next task to the current position
                done
                o.Delete "$scheduler.periodic.item_$((periodicCount - 1))" #remove the last item
                periodicCount=$((periodicCount - 1)) #decrement the count
                o.Set "$scheduler.periodic.count" "$periodicCount"

                i=$((i - 1)) #decrement i to account for the removed item
            else
                echo "Unknown state '$state' for periodic task '$taskInfo'."
            fi
        fi
    done
}

Scheduler.RunLoop(){ local scheduler="$1"; local betweenRoundsInterval="$2"; 
    #run a task in a loop with a given interval
    while true; do
        Scheduler.RunOneRound "$scheduler"
        sleep "$betweenRoundsInterval"
    done
}

#append a task to the task queue to be runned as soon as possible
Scheduler.Run(){ local scheduler="$1"; local task="$2"
    o.Get "$scheduler.taskQueue.count"; local count="$_r"
    if [ "$count" == "" ]; then
        count=0
    fi
    o.Set "$scheduler.taskQueue.count" "$((count + 1))"
    o.Set "$scheduler.taskQueue.item_$count" "$task"
}

#returns the taskInfo 'pointer' via _r variable
Scheduler.Periodic(){ local scheduler="$1"; local task="$2"; local interval="$3"; local _firstShotImediatelly="${4:-false}"
    PriodicTask.New "$task" "$interval" "0"; local taskInfo="$_r"

    if [ "$_firstShotImediatelly" == "true" ]; then
        o.Set "$taskInfo.lastRun" "$(date +%s%3N)"
    else
        o.Set "$taskInfo.lastRun" "0"
    fi

    o.Get "$scheduler.periodic.count"; local count="$_r"
    if [ "$count" == "" ]; then
        count=0
    fi
    o.Set "$scheduler.periodic.count" "$((count + 1))"
    o.Set "$scheduler.periodic.item_$count" "$taskInfo"

    _r="$taskInfo"
}

#dalay a task to be runned after a given time
Scheduler.DelayedTask(){ local scheduler="$1"; local task="$2"; local delay="$3"; shift 2
    Scheduler.Periodic "$scheduler" "$task" "$delay" false; local taskInfo="$_r"
    o.Set "$taskInfo.remainShots" "1" #set max shots to 1, so it will run only once
}

Scheduler.RunWorkable(){ local scheduler="$1"; local workable="$2"; local interval="$3"; shift 3
    o.Implements "$workable" "IWorkable"; local _error="$_r"
    if [ "$_error" != "" ]; then
        _error="Object '$workable' does not implement IWorkable interface: $_error"
        return 1
    fi

    Scheduler.Periodic "$scheduler" '_f(){ local taskInfo="$1";
        o.call "'$workable'.WorkStep" "'$workable'" "$taskInfo"
    }; _f' "$interval" true;
}
