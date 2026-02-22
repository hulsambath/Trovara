#!/bin/bash -e

# Use this [scripts/flutterfire] to reconfigure firebase in this project.
#
# Commands:
# scripts/flutterfire -prod
# scripts/flutterfire -staging

function exit_if_file_not_exist() {
  if ! [[ -f $1 ]]; then
    echo "🚨 $2"
    exit 1
  fi
}

function log_args() {
  msg="=    $*    ="
  edge=$(echo "$msg" | sed 's/./=/g')

  echo -e "\n$edge"
  echo -e "$msg"
  echo -e "$edge\n"
}

function run_command() {
  echo -e "\n[EXECUTING] $1\n"
  (eval $1)
}

# eg. main_prod.dart
function save_dart_main_file() {
  TEMPLATE_DATA=$(cat "lib/main_flavor.dart.template")
  FLAVOR=$1
  DESTINATION="lib/main_$FLAVOR.dart"

  sed "s/#{FLAVOR}/$FLAVOR/g" <<<"$TEMPLATE_DATA" >$DESTINATION
  echo "[CREATED] main_flavor.dart.template -> $DESTINATION"
}

function ensure_generated_dart_define_exist() {
  touch ios/Flutter/GeneratedDartDefines.xcconfig
}

function configure() {
  FLAVOR=$1
  PRODUCT=$2
  PACKAGE_NAME=$3
  FLAVOR_IN_SNACKCASE=$4
  PLATFORMS=${PLATFORMS:-'android,ios,macos'}

  log_args "Configuring Firebase for $FLAVOR_IN_SNACKCASE ($PACKAGE_NAME)"

  run_command "flutterfire configure \
    --project=$PRODUCT \
    --ios-bundle-id=$PACKAGE_NAME \
    --android-package-name=$PACKAGE_NAME \
    --macos-bundle-id=$PACKAGE_NAME \
    --platforms=$PLATFORMS \
    --ios-out=ios/Firebase/$FLAVOR/GoogleService-Info.plist \
    --android-out=android/app/src/$FLAVOR/google-services.json \
    --macos-out=macos/Firebase/$FLAVOR/GoogleService-Info.plist \
    --out=lib/firebase_options/$FLAVOR_IN_SNACKCASE.dart \
    --yes"

  log_args "TO RUN PROJECT: ./scripts/run_app.sh --$FLAVOR_IN_SNACKCASE"

  save_dart_main_file $FLAVOR_IN_SNACKCASE
  ensure_generated_dart_define_exist
}

function main() {
  exit_if_file_not_exist "pubspec.yaml" "Make sure to execute scripts from project directory."

  case $1 in

  -dev | --dev)
    configure 'staging' 'trovara-team' 'com.trovara.app.staging' 'dev'
    exit 0
    ;;

  -staging | --staging)
    configure 'staging' 'trovara-team' 'com.trovara.app.staging' 'staging'
    exit 0
    ;;

  -prod | --prod)
    configure 'prod' 'trovara-team' 'com.trovara.app' 'prod'
    exit 0
    ;;

  *)
    help
    exit 0
    ;;

  esac
  shift
}

main $@
