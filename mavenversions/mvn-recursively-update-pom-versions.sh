#!/bin/sh

# mvn-recursively-update-pom-versions

mvn || exit 1

echo "Updating versions..."
while ! mvn versions:update-child-modules | grep -q "All child modules are up to date.";
do
  echo "Updating versions..."
done
echo "✔ Done! All child modules are up to date."
