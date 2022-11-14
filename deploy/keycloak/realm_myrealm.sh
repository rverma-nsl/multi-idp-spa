#!/usr/bin/env bash

REALM_NAME='myrealm'

TOKEN_EXCHANGE_POLICY_NAME='my-exchange-policy'

ORIGINAL_CLIENT_ID='originalclient'
ORIGINAL_CLIENT_DESCRIPTION='original-client'
ORIGINAL_CLIENT_SECRET='originalClientSecret'

INTERNAL_CLIENT_ID='internalclient'
INTERNAL_CLIENT_DESCRIPTION='internal-client'
INTERNAL_CLIENT_SECRET='internalClientSecret'


echo ""
echo ""
echo "================================="
echo "setting up realm $REALM_NAME..."
echo "================================="
echo ""

#######################
## REALM
#######################
$KCADM delete realms/$REALM_NAME
# create realm 'myrealm'
REALM_UUID=$(createUUID '9dadd715-ecf4-46df-a57e-be5895e20b85' $REALM_NAME)
createRealm $REALM_NAME $REALM_UUID
$KCADM update realms/$REALM_NAME -s enabled=true -s accessTokenLifespan=43200 -s ssoSessionIdleTimeout=43200 -s ssoSessionMaxLifespan=43200 -s accessCodeLifespanUserAction=43200 -s accessCodeLifespanLogin=43200

# record events
$KCADM update events/config -r $REALM_NAME -s eventsEnabled=true -s 'enabledEventTypes=["LOGIN", "LOGOUT", "CODE_TO_TOKEN", "REFRESH_TOKEN", "REFRESH_TOKEN", "LOGIN_ERROR","REGISTER_ERROR","LOGOUT_ERROR","CODE_TO_TOKEN_ERROR","CLIENT_LOGIN_ERROR","FEDERATED_IDENTITY_LINK_ERROR","REMOVE_FEDERATED_IDENTITY_ERROR","UPDATE_EMAIL_ERROR","UPDATE_PROFILE_ERROR","UPDATE_PASSWORD_ERROR","UPDATE_TOTP_ERROR","VERIFY_EMAIL_ERROR","REMOVE_TOTP_ERROR","SEND_VERIFY_EMAIL_ERROR","SEND_RESET_PASSWORD_ERROR","SEND_IDENTITY_PROVIDER_LINK_ERROR","RESET_PASSWORD_ERROR","IDENTITY_PROVIDER_FIRST_LOGIN_ERROR","IDENTITY_PROVIDER_POST_LOGIN_ERROR","CUSTOM_REQUIRED_ACTION_ERROR","EXECUTE_ACTIONS_ERROR","CLIENT_REGISTER_ERROR","CLIENT_UPDATE_ERROR","CLIENT_DELETE_ERROR"]' -s eventsExpiration=172800
$KCADM update events/config -r $REALM_NAME -s adminEventsEnabled=true -s adminEventsDetailsEnabled=true
$KCADM update events/config -r $REALM_NAME -s 'eventsListeners=["jboss-logging"]'

#######################
## CLIENT
#######################
# This is the client that gets us the original token. It is also called upon to exchange that token for one for client internal

# create client
createClient $REALM_NAME $ORIGINAL_CLIENT_ID $ORIGINAL_CLIENT_DESCRIPTION
MY_ID=$(getClient $REALM_NAME $ORIGINAL_CLIENT_ID)

$KCADM update clients/$MY_ID -r $REALM_NAME  -s secret=$ORIGINAL_CLIENT_SECRET -s fullScopeAllowed=false -s standardFlowEnabled=false -s serviceAccountsEnabled=true

#######################
## CLIENT INTERNAL
#######################
# This is the client that we want to get a token for in the end. It will be obtained by exchanging a token we originally got from the other client.

# create internal client
createClient $REALM_NAME $INTERNAL_CLIENT_ID $INTERNAL_CLIENT_DESCRIPTIONS
INTERNAL_ID=$(getClient $REALM_NAME $INTERNAL_CLIENT_ID)

$KCADM update clients/$INTERNAL_ID -r $REALM_NAME  -s secret=$INTERNAL_CLIENT_SECRET -s fullScopeAllowed=false -s standardFlowEnabled=false

######
## A lot of stuff for allowing token-exchange for the internal client. This is surprisingly complicated.
######

# turn on permissions for internal client
$KCADM update clients/$INTERNAL_ID/management/permissions -r "$REALM_NAME" -s enabled=true

# create token-exchange permission
REALM_MANAGEMENT_CLIENT_ID=$(getClient "$REALM_NAME" realm-management)

#create token-exchange client policy
$KCADM create clients/$REALM_MANAGEMENT_CLIENT_ID/authz/resource-server/policy -r "$REALM_NAME" -f - <<EOF
{
            "id": "a18a9428-261b-465d-a771-9a23a108cc92",
            "name": "$TOKEN_EXCHANGE_POLICY_NAME",
            "type": "client",
            "logic": "POSITIVE",
            "decisionStrategy": "UNANIMOUS",
            "config": {
              "clients": "[\"$ORIGINAL_CLIENT_ID\"]"
            }
          }

EOF

#configure permission for token-exchange

# The id of the token exchange scope
TOKEN_EXCHANGE_SCOPE_ID=$($KCADM get clients/$REALM_MANAGEMENT_CLIENT_ID/authz/resource-server/scope -r "$REALM_NAME" | jq -r '.[] | select(.name==("token-exchange")) | .id')
# The id of the policy we created above.
EXCHANGE_POLICY_ID=$($KCADM get clients/$REALM_MANAGEMENT_CLIENT_ID/authz/resource-server/policy -r "$REALM_NAME" | jq -r '.[] | select(.name=="'$TOKEN_EXCHANGE_POLICY_NAME'") | .id')
# The id of a special policy that was created by Keycloak.
TOKEN_EXCHANGE_PERMISSION_POLICY_ID=$($KCADM get clients/$REALM_MANAGEMENT_CLIENT_ID/authz/resource-server/policy -r "$REALM_NAME" | jq -r '.[] | select(.name | startswith("token-exchange.permission.client.'$INTERNAL_ID'")) | .id')
# The id of the resource representing the client we want to get an exchanged token for.
CLIENT_RESOURCE_ID=$($KCADM get clients/$REALM_MANAGEMENT_CLIENT_ID/authz/resource-server/resource -r "$REALM_NAME" | jq -r '.[] | select(.name | startswith("client.resource.'$INTERNAL_ID'")) | ._id')


echo "TOKEN_EXCHANGE_SCOPE_ID is $TOKEN_EXCHANGE_SCOPE_ID"
echo "EXCHANGE_POLICY_ID is $EXCHANGE_POLICY_ID"
echo "TOKEN_EXCHANGE_PERMISSION_POLICY_ID is $TOKEN_EXCHANGE_PERMISSION_POLICY_ID"
echo "CLIENT_RESOURCE_ID is $CLIENT_RESOURCE_ID"


$KCADM update clients/$REALM_MANAGEMENT_CLIENT_ID/authz/resource-server/permission/scope/$TOKEN_EXCHANGE_PERMISSION_POLICY_ID -r "$REALM_NAME" \
-s 'scopes=["'$TOKEN_EXCHANGE_SCOPE_ID'"]' \
-s 'resources=["'$CLIENT_RESOURCE_ID'"]' \
-s 'policies=["'$EXCHANGE_POLICY_ID'"]'


######
## Finally done with the permission stuff.
######

curl 'http://localhost:8080/realms/master/broker/oidc/login?client_id=security-admin-console&tab_id=AGVJQdf0aXg&session_code=H25sB6IV4osEIpLSJ1Jc8rp7TSOEwa7uVjsOffBjOYs' \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
  -H 'Accept-Language: en-IN,en-GB;q=0.9,en-US;q=0.8,en;q=0.7,ko;q=0.6' \
  -H 'Connection: keep-alive' \
  -H 'Cookie: KEYCLOAK_SESSION=master/f8fee1ba-9d84-4da7-9086-25556e3a2304/cc25631e-907e-423d-a1b9-b37066af2905; KEYCLOAK_SESSION_LEGACY=master/f8fee1ba-9d84-4da7-9086-25556e3a2304/cc25631e-907e-423d-a1b9-b37066af2905; AUTH_SESSION_ID=3f69ad13-1eec-4cb4-8bb9-0d8e02d4ed17; AUTH_SESSION_ID_LEGACY=3f69ad13-1eec-4cb4-8bb9-0d8e02d4ed17; KC_RESTART=eyJhbGciOiJIUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICIyOWI1NWM2OS05OTU3LTQ4NjUtOTg3MS0zZGU2MWExOTljZjMifQ.eyJjaWQiOiJzZWN1cml0eS1hZG1pbi1jb25zb2xlIiwicHR5Ijoib3BlbmlkLWNvbm5lY3QiLCJydXJpIjoiaHR0cDovL2xvY2FsaG9zdDo4MDgwL2FkbWluL21hc3Rlci9jb25zb2xlLyIsImFjdCI6IkFVVEhFTlRJQ0FURSIsIm5vdGVzIjp7InNjb3BlIjoib3BlbmlkIiwiaXNzIjoiaHR0cDovL2xvY2FsaG9zdDo4MDgwL3JlYWxtcy9tYXN0ZXIiLCJyZXNwb25zZV90eXBlIjoiY29kZSIsImNvZGVfY2hhbGxlbmdlX21ldGhvZCI6IlMyNTYiLCJyZWRpcmVjdF91cmkiOiJodHRwOi8vbG9jYWxob3N0OjgwODAvYWRtaW4vbWFzdGVyL2NvbnNvbGUvIiwic3RhdGUiOiJiOGY3ZDdiZC0xNDRjLTRhNjYtODNmNi1mYjYzMDk0YzEzY2YiLCJub25jZSI6IjUyNzgwMTk0LTM3YWUtNDJmMC04ZGJlLTY4MmJlNzE5Zjg3OSIsImNvZGVfY2hhbGxlbmdlIjoiV2lsTTVLcG5zeDJBeGhfbWItRU1ITnpVM2ZrdnRMRWhDOXJNcUotNWEtSSIsInJlc3BvbnNlX21vZGUiOiJmcmFnbWVudCJ9fQ.UTp_8HoEN5bFTyucj6YPsX1fSZJv6Vxp2OSIqwAjAKw; Idea-f805e7c1=c13c7b5f-aad0-405d-95cf-d3ffc37a5eef; csrf_token_65a4ffb775aedfbc2bb74a919743c3cbad76e8a64e23287c671f9cbb044e8b99=AKFedCH1Tw8xitKSpyrJlmzCV+imeZxLPbrd1Su9mUQ=' \
  -H 'Sec-Fetch-Dest: document' \
  -H 'Sec-Fetch-Mode: navigate' \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-User: ?1' \
  -H 'Upgrade-Insecure-Requests: 1' \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36' \
  -H 'sec-ch-ua: "Google Chrome";v="107", "Chromium";v="107", "Not=A?Brand";v="24"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "macOS"' \
  --compressed
