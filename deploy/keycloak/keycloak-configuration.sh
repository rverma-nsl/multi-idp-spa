#!/usr/bin/env bash

##########
#
# This script does the configuration of keycloak, so we don't have to do it in the UI.
#
#########

trap 'exit' ERR

echo " "
echo " "
echo "========================================================"
echo "==         STARTING KEYCLOAK CONFIGURATION            =="
echo "========================================================"
echo " "
echo " "

BASEDIR=$(dirname "$0")
source $BASEDIR/keycloak-configuration-helpers.sh

KCADM="$KEYCLOAK_HOME/bin/kcadm.sh"
$KCADM config credentials --server http://localhost:8080/auth --user $KEYCLOAK_USER --password $KEYCLOAK_PASSWORD --realm master

source $BASEDIR/realms.sh


echo " "
echo " "
echo "========================================================"
echo "==            KEYCLOAK CONFIGURATION DONE             =="
echo "========================================================"
echo " "
echo " "
