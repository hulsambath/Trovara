#!/bin/bash -e
# Use this [bin/keystore.sh] to generate keystore in this project.
# 
# Commands:
# bin/keystore.sh -nm || --noteminds

function log_args() {
  msg="=    $*    ="
  edge=$(echo "$msg" | sed 's/./=/g')

  echo -e "\n$edge"
  echo -e "$msg"
  echo -e "$edge\n"
}

function run_command() {
  echo -e "\n[EXECUTING] $*\n"
  "$@"
}

function configure() {
  ALIAS_NAME=$1
  KEYSTORE_PASSWORD=$2
  KEY_PASSWORD=$3
  DNAME=$4
  VALIDITY_DAYS=$5
  KEY_ALG=$6
  KEY_SIZE=$7

  keystore_path="android/key-alias-$ALIAS_NAME.jks"

  echo "[INFO] Creating keystore at: $keystore_path"

  keytool -genkeypair \
    -v \
    -keystore "$keystore_path" \
    -alias "key-alias-$ALIAS_NAME" \
    -keyalg "$KEY_ALG" \
    -keysize "$KEY_SIZE" \
    -validity "$VALIDITY_DAYS" \
    -storepass "$KEYSTORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -dname "$DNAME"

  if [ $? -eq 0 ]; then
    echo "✅ Keystore successfully created at: $keystore_path"
  else
    echo "❌ Failed to create keystore"
    exit 1
  fi
}

function help() {
  echo "Usage: $0 -nm | --noteminds"
}

function main() {
  case $1 in
    -nm | --noteminds)
      configure \
        'noteminds' \
        '4s%_ctrB2F9' \
        '4s%_ctrB2F9' \
        'CN=Sambath HUL, OU=Developer, O=Reatrey, L=Phnom Penh, ST=Phnom Penh, C=KH' \
        '10000' \
        'RSA' \
        '2048'
      exit 0
      ;;
    *)
      help
      exit 0
      ;;
  esac
}

main "$@"
