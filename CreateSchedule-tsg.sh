#!/bin/bash
# Instance scheduler documentation
# https://docs.aws.amazon.com/solutions/latest/instance-scheduler-on-aws/welcome.html
# https://docs.aws.amazon.com/solutions/latest/instance-scheduler-on-aws/scheduler-cli.html

if [ $# -lt 1 ]; then
  echo "usage: $0 region(=eu-west-1) dryrun/(empty)"
  exit 1
fi

#Region where is located the stack with the Instance Scheduler
REGION=$1
DRYRUN=$2

RUNNING_NAMES=(running 24/7)
STACK=Cld-InstanceScheduler
TIMEZONES=(America/Los_Angeles Asia/Kolkata Europe/Paris)
WORKINGDAYS_NAMES=(mon-fri 24/5)

if [ "$DRYRUN" = "dryrun" ] ; then
  CMD="echo scheduler-cli"
  echo "DRYRUN MODE"
else
  CMD="scheduler-cli"
  echo "NORMAL MODE"
fi

# First Delete schedule on the different TIMEZONE
for TIMEZONE in "${TIMEZONES[@]}"
do
  for ENDHOUR in 11 12 13 14 15 16 17 18 19 20 21 22 23
  do
    for BEGINHOUR in 1 2 3 4 5 6 7 8 9 10
    do
      for ENFORCED in true false
      do
        if [ $ENFORCED = "true" ] ; then
          NAME=from-${BEGINHOUR}-to-${ENDHOUR}-mon-fri-enforced-${TIMEZONE/\//}
        else
          NAME=from-${BEGINHOUR}-to-${ENDHOUR}-mon-fri-${TIMEZONE/\//}
        fi
        $CMD delete-schedule --stack "${STACK}" --region "${REGION}" --name "${NAME}"
      done
    done # BEGINHOUR
  done # ENDHOUR
done # TIMEZONE

# Secondly delete period when delete schedule on the different TIMEZONE is done
for ENDHOUR in 11 12 13 14 15 16 17 18 19 20 21 22 23
do
  for BEGINHOUR in 1 2 3 4 5 6 7 8 9 10
  do
    $CMD delete-period --stack "${STACK}" --region "${REGION}" --name from-${BEGINHOUR}-to-${ENDHOUR}-mon-fri
  done
done

# Thirdly create new period and TIMEZONE
# FROM...TO scheduler tags creation
# tag template : from-${BEGINHOUR}-to-${ENDHOUR}-mon-fri-EuropeParis
for TIMEZONE in "${TIMEZONES[@]}"
do
  for ENDHOUR in 11 12 13 14 15 16 17 18 19 20 21 22 23
  do
    for BEGINHOUR in 1 2 3 4 5 6 7 8 9 10
    do
      for ENFORCED in true false
      do
        if [ $ENFORCED = "true" ] ; then
          NAME=from-${BEGINHOUR}-to-${ENDHOUR}-mon-fri-enforced-${TIMEZONE/\//}
        else
          NAME=from-${BEGINHOUR}-to-${ENDHOUR}-mon-fri-${TIMEZONE/\//}
        fi
      done
      $CMD create-period --stack "${STACK}" --region "${REGION}" --name from-${BEGINHOUR}-to-${ENDHOUR}-mon-fri --begintime $((BEGINHOUR - 1)):30 --endtime ${ENDHOUR}:00 --weekdays mon-fri

      for ENFORCED in true false
      do
        if [ $ENFORCED = "true" ] ; then
          NAME=from-${BEGINHOUR}-to-${ENDHOUR}-mon-fri-enforced-${TIMEZONE/\//}
          ARG="--enforced"
        else
          NAME=from-${BEGINHOUR}-to-${ENDHOUR}-mon-fri-${TIMEZONE/\//}
          ARG=""
        fi
        $CMD create-schedule --stack "${STACK}" --region "${REGION}" --name "${NAME}" --periods from-${BEGINHOUR}-to-${ENDHOUR}-mon-fri --timezone "${TIMEZONE}" ${ARG}
      done # ENFORCED
    done # BEGINHOUR
  done # ENDHOUR
done # TIMEZONE

# TO scheduler tags creation
# tag template : to-${ENDHOUR}-${TIMEZONE/\//}
for TIMEZONE in "${TIMEZONES[@]}"
do
  for ENDHOUR in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23
  do
    $CMD delete-schedule --stack "${STACK}" --region "${REGION}" --name "to-${ENDHOUR}-${TIMEZONE/\//}"
    $CMD delete-period   --stack "${STACK}" --region "${REGION}" --name "to-${ENDHOUR}"
    $CMD create-period   --stack "${STACK}" --region "${REGION}" --name "to-${ENDHOUR}" --endtime ${ENDHOUR}:00
    $CMD create-schedule --stack "${STACK}" --region "${REGION}" --name "to-${ENDHOUR}-${TIMEZONE/\//}" --periods to-${ENDHOUR} --timezone "${TIMEZONE}"
  done
done

# TO scheduler tags creation
# tag template : to-${ENDHOUR}-mon-fri-${TIMEZONE/\//}
for TIMEZONE in "${TIMEZONES[@]}"
do
  for ENDHOUR in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23
  do
    $CMD delete-schedule --stack "${STACK}" --region "${REGION}" --name "to-${ENDHOUR}-mon-fri-${TIMEZONE/\//}"
    $CMD delete-period   --stack "${STACK}" --region "${REGION}" --name "to-${ENDHOUR}-mon-fri"
    $CMD create-period   --stack "${STACK}" --region "${REGION}" --name "to-${ENDHOUR}-mon-fri" --endtime ${ENDHOUR}:00 --weekdays mon-fri
    $CMD create-schedule --stack "${STACK}" --region "${REGION}" --name "to-${ENDHOUR}-mon-fri-${TIMEZONE/\//}" --periods to-${ENDHOUR} --timezone "${TIMEZONE}"
  done
done

# started during working days, stopped during weekends
# tag template : mon-fri or mon-fri-${TIMEZONE/\//} or 24/5 or 24/5-${TIMEZONE/\//}
for WORKINGDAYS_NAME in "${WORKINGDAYS_NAMES[@]}"; do
  $CMD delete-schedule --stack "${STACK}" --region "${REGION}" --name "${WORKINGDAYS_NAME}"
  $CMD create-schedule --stack "${STACK}" --region "${REGION}" --name "${WORKINGDAYS_NAME}" --periods working-days
  for TIMEZONE in "${TIMEZONES[@]}"; do
    $CMD delete-schedule --stack "${STACK}" --region "${REGION}" --name "${WORKINGDAYS_NAME}-${TIMEZONE/\//}"
    $CMD create-schedule --stack "${STACK}" --region "${REGION}" --name "${WORKINGDAYS_NAME}-${TIMEZONE/\//}" --periods working-days --timezone "${TIMEZONE}"
  done
done

# set instance status

# tag template : running or 24/7
for RUNNING_NAME in "${RUNNING_NAMES[@]}"; do
  $CMD delete-schedule --stack "${STACK}" --region "${REGION}" --name "${RUNNING_NAME}"
  $CMD create-schedule --stack "${STACK}" --region "${REGION}" --name "${RUNNING_NAME}" --override-status running
done

# tag template: stopped
$CMD delete-schedule --stack "${STACK}" --region "${REGION}" --name stopped
$CMD create-schedule --stack "${STACK}" --region "${REGION}" --name stopped --override-status stopped
