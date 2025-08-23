# Use this [bin/run_app] to run Flutter project in specific flavor.
#
# Commands:
# bin/run_app -hmP || --hangmeasProd
# bin/run_app -hmS || --hangmeasStaging

FLAVOR=$1

case "$FLAVOR" in
-nm | --noteminds)
  CMD="flutter run --dart-define-from-file=configs/noteminds.json"
  ;;
*)
  echo "Invalid option: $FLAVOR"
  echo "Usage: bin/run_app [--noteminds]"
  exit 1
  ;;
esac

# Remove 1st args
shift

echo "Executing: $CMD $1"
eval $CMD $1
