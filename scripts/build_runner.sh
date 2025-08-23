# Use this [bin/run_build] to run Flutter project in specific flavor.
#
# Commands:
# bin/run_build -d || --delete-conflicting-outputs

FLAVOR=$1

case "$FLAVOR" in
-d | --delete-conflicting-outputs)
  CMD="flutter pub run build_runner build -d"
  ;;
*)

  echo "Invalid option: $FLAVOR"
  echo "Usage: bin/run_build [-d | --delete-conflicting-outputs]"
  exit 1
  ;;
esac

# Remove 1st args
shift

echo "Executing: $CMD $1"
eval $CMD $1
